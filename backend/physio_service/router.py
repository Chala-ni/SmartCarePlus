"""
SMARTCARE+ Physio Service Router

Owner: Neelaka
Endpoints for physiotherapy analysis, exercise monitoring, and progress tracking.
Uses MediaPipe pose estimation for real-time exercise form feedback.
"""

from fastapi import APIRouter, UploadFile, File, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any, Generator
from datetime import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import threading
import random
import cv2
import numpy as np
import base64
import asyncio
import tempfile
import os
import logging
import sys


def _setup_physio_logger(name: str) -> logging.Logger:
    """Configure a physio logger at DEBUG level with console output."""
    _logger = logging.getLogger(name)
    _logger.setLevel(logging.DEBUG)
    if not _logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(logging.DEBUG)
        handler.setFormatter(logging.Formatter(
            fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        ))
        _logger.addHandler(handler)
    return _logger

logger = _setup_physio_logger("smartcare.physio")

from .models import (
    PoseAnalyzer,
    PoseResult,
    ExerciseType,
    FormQuality,
    FormAssessment,
    RepCounter,
    ExerciseSession,
    ExerciseSessionHandler,
    SessionState,
    get_pose_analyzer,
    get_session_handler,
    # Face Pain Analysis
    FacePainAnalyzer,
    FacialPainResult,
    FacePainLevel,
    get_face_pain_analyzer,
    # Pain Data Storage
    PainLevel,
    get_pain_data_store,
    # Patient Profile
    PatientProfile,
    calculate_bmi,
    get_patient_profile_store,
    # Exercise Plan Generator
    get_exercise_plan_generator,
    EXERCISE_LIBRARY
)

# Phase tracking for progressive reference poses
from .models.phase_tracker import (
    get_or_create_phase_tracker,
    get_phase_tracker,
    remove_phase_tracker,
    ExercisePhaseTracker,
)
from .models.exercise_plan_generator import EXERCISE_PHASES

router = APIRouter()

# Frame counter per session for pain analysis throttling (every 3rd frame)
_session_frame_counts: Dict[str, int] = {}
PAIN_ANALYSIS_INTERVAL = 3  # Analyze pain every N frames


# ── Diagnostic endpoints ───────────────────────────────────────────────────────
@router.get("/diagnostic")
async def physio_diagnostic():
    """Check MediaPipe status and pose analyzer health."""
    from .models.pose_analyzer import MEDIAPIPE_AVAILABLE, MEDIAPIPE_TASKS_AVAILABLE
    pose_analyzer, _ = get_services()
    return {
        "mediapipe_installed": MEDIAPIPE_AVAILABLE,
        "mediapipe_tasks_available": MEDIAPIPE_TASKS_AVAILABLE,
        "pose_detector_initialized": pose_analyzer.pose_detector is not None,
        "using_mock_data": pose_analyzer.using_mock,
        "status": "REAL pose detection" if not pose_analyzer.using_mock else "⚠️ MOCK data (random)",
    }


@router.get("/diagnostic/face")
async def face_pain_diagnostic():
    """Check Face Mesh status for pain detection."""
    from .models.face_pain_analyzer import FACE_MESH_AVAILABLE
    face_analyzer = get_face_pain_analyzer()
    return {
        "face_landmarker_available": FACE_MESH_AVAILABLE,
        "face_detector_initialized": face_analyzer.face_landmarker is not None,
        "using_mock_data": face_analyzer.using_mock,
        "model_path": str(face_analyzer.model_path) if hasattr(face_analyzer, 'model_path') else "unknown",
        "status": "REAL face pain detection" if not face_analyzer.using_mock else "⚠️ MOCK data (random)",
    }


# Video configuration for exercise demonstrations
VIDEO_DIR = Path(__file__).parent.parent / "media" / "simulation_footage" / "physio" / "exercise"

# Map exercise types to video files
# Using best-matching videos for exercises without dedicated videos
EXERCISE_VIDEOS = {
    # Original exercises with dedicated videos
    "chair_stand": "ex1.mp4",
    "heel_toe_walk": "ex2.mp4",
    "single_leg_stand": "ex4.mp4",
    "ankle_circles": "ex5.mp4",
    "wall_pushup": "ex7.mp4",
    "tandem_stand": "ex8.mp4",
    "marching": "ex9.mp4",
    "leg_raise": "ex10.mp4",
    "arm_raise": "ex11.mp4",
    
    # Exercises using similar/related videos as fallback
    "squat": "ex1.mp4",              # Similar lower body motion to chair stand
    "neck_rotations": "ex11.mp4",    # Upper body focus
    "shoulder_rolls": "ex11.mp4",    # Upper body focus
    "seated_hamstring_stretch": "ex4.mp4",   # Leg-focused
    "seated_hip_stretch": "ex4.mp4",         # Leg-focused
    "calf_stretch": "ex10.mp4",              # Leg stretch
    "seated_leg_raise": "ex10.mp4",          # Leg raise motion
    "seated_arm_raises": "ex11.mp4",         # Arm motion
    "deep_breathing": "ex11.mp4",            # Upper body
    "gentle_spinal_twist": "ex11.mp4",       # Upper body
    "marching_in_place": "ex9.mp4",          # Same as marching
}

# Thread pool for video streaming
_video_thread_pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="physio_video")


def _generate_mjpeg_frames(video_path: str, fps: int = 15) -> Generator[bytes, None, None]:
    """
    Generate MJPEG frames from a video file.
    Loops the video for continuous playback.
    """
    cap = None
    try:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print(f"[Physio Video] Cannot open: {video_path}")
            return
        
        frame_interval = 1.0 / fps
        
        while True:
            ret, frame = cap.read()
            
            if not ret:
                # Loop video
                cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                ret, frame = cap.read()
                if not ret:
                    break
            
            # Resize for efficient streaming
            frame = cv2.resize(frame, (640, 480))
            
            # Encode as JPEG
            ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            if not ret:
                continue
            
            yield (
                b'--frame\r\n'
                b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n'
            )
            
            import time
            time.sleep(frame_interval)
            
    except GeneratorExit:
        pass
    except Exception as e:
        print(f"[Physio Video Error] {e}")
    finally:
        if cap is not None:
            cap.release()


async def _async_mjpeg_generator(video_path: str):
    """Async wrapper for MJPEG generator."""
    loop = asyncio.get_event_loop()
    frame_queue = asyncio.Queue(maxsize=5)
    stop_event = threading.Event()
    
    def producer():
        try:
            for frame in _generate_mjpeg_frames(video_path):
                if stop_event.is_set():
                    break
                try:
                    asyncio.run_coroutine_threadsafe(
                        frame_queue.put(frame), loop
                    ).result(timeout=1.0)
                except Exception:
                    break
        except Exception as e:
            print(f"[Video Producer Error] {e}")
        finally:
            asyncio.run_coroutine_threadsafe(frame_queue.put(None), loop)
    
    future = _video_thread_pool.submit(producer)
    
    try:
        while True:
            frame = await frame_queue.get()
            if frame is None:
                break
            yield frame
    except asyncio.CancelledError:
        pass
    finally:
        stop_event.set()
        future.cancel()


# Service instances (singleton pattern)
_pose_analyzer: Optional[PoseAnalyzer] = None
_session_handler: Optional[ExerciseSessionHandler] = None


def get_services():
    """Get or initialize service instances."""
    global _pose_analyzer, _session_handler
    if _pose_analyzer is None:
        _pose_analyzer = get_pose_analyzer()
    if _session_handler is None:
        _session_handler = get_session_handler()
    return _pose_analyzer, _session_handler


# ============= Pydantic Models =============

class Exercise(BaseModel):
    id: str
    name: str
    category: str
    duration: str
    difficulty: str
    reps: str
    description: str
    is_prescribed: bool = False


class StartSessionRequest(BaseModel):
    user_id: str
    exercise_type: str
    target_reps: int = 10
    target_sets: int = 3


class SessionFeedbackRequest(BaseModel):
    session_id: str
    pain_level: Optional[int] = None  # 0-10
    difficulty_rating: Optional[int] = None  # 1-5
    notes: Optional[str] = None


# ============= Mock Data =============

EXERCISES_DB = [
    {"id": "1", "name": "Chair Stand", "category": "Strength", "duration": "10 min", "difficulty": "Easy", "reps": "3 sets x 10 reps", "description": "Stand up from chair without using hands", "is_prescribed": True},
    {"id": "2", "name": "Heel-to-Toe Walk", "category": "Gait", "duration": "5 min", "difficulty": "Medium", "reps": "2 sets x 20 steps", "description": "Walk in a straight line, heel to toe", "is_prescribed": True},
    {"id": "3", "name": "Single Leg Stand", "category": "Balance", "duration": "8 min", "difficulty": "Medium", "reps": "3 sets x 30 sec", "description": "Stand on one leg while holding support", "is_prescribed": True},
    {"id": "4", "name": "Ankle Circles", "category": "Flexibility", "duration": "5 min", "difficulty": "Easy", "reps": "10 circles each direction", "description": "Rotate ankles to improve flexibility", "is_prescribed": False},
    {"id": "5", "name": "Wall Push-ups", "category": "Strength", "duration": "8 min", "difficulty": "Easy", "reps": "3 sets x 8 reps", "description": "Push-ups against the wall for upper body", "is_prescribed": False},
    {"id": "6", "name": "Tandem Stand", "category": "Balance", "duration": "5 min", "difficulty": "Hard", "reps": "3 sets x 20 sec", "description": "Stand with feet in tandem position", "is_prescribed": False},
    {"id": "7", "name": "Marching in Place", "category": "Gait", "duration": "10 min", "difficulty": "Easy", "reps": "100 steps", "description": "March in place lifting knees high", "is_prescribed": True},
    {"id": "8", "name": "Seated Leg Raises", "category": "Strength", "duration": "8 min", "difficulty": "Easy", "reps": "3 sets x 10 each leg", "description": "Lift legs while seated in chair", "is_prescribed": False},
]


# ============= Exercise Video Endpoints =============

@router.get("/exercise-video/{exercise_type}")
async def get_exercise_video(exercise_type: str):
    """
    Get the demonstration video for an exercise type.
    Returns an MP4 video file for the frontend to display.
    """
    if exercise_type not in EXERCISE_VIDEOS:
        raise HTTPException(
            status_code=404, 
            detail=f"No video for exercise type: {exercise_type}. Available: {list(EXERCISE_VIDEOS.keys())}"
        )
    
    video_file = EXERCISE_VIDEOS[exercise_type]
    video_path = VIDEO_DIR / video_file
    
    if not video_path.exists():
        raise HTTPException(status_code=404, detail=f"Video file not found: {video_file}")
    
    return FileResponse(
        path=str(video_path),
        media_type="video/mp4",
        filename=f"{exercise_type}_demo.mp4"
    )


@router.get("/exercise-videos")
async def list_exercise_videos():
    """List all available exercise demo videos."""
    available = {}
    for ex_type, filename in EXERCISE_VIDEOS.items():
        video_path = VIDEO_DIR / filename
        available[ex_type] = {
            "filename": filename,
            "exists": video_path.exists(),
            "url": f"/physio/exercise-video/{ex_type}",
            "stream_url": f"/physio/exercise-stream/{ex_type}"
        }
    return {
        "video_directory": str(VIDEO_DIR),
        "exercises": available
    }


@router.get("/exercise-stream/{exercise_type}")
async def stream_exercise_video(exercise_type: str):
    """
    Stream exercise demonstration video as MJPEG.
    
    This is for displaying the demo video in the Flutter app using
    the existing MjpegStream widget (same pattern as guardian CCTV).
    The video loops continuously for reference during exercise.
    """
    if exercise_type not in EXERCISE_VIDEOS:
        raise HTTPException(
            status_code=404,
            detail=f"No video for exercise type: {exercise_type}"
        )
    
    video_file = EXERCISE_VIDEOS[exercise_type]
    video_path = VIDEO_DIR / video_file
    
    if not video_path.exists():
        raise HTTPException(status_code=404, detail=f"Video file not found: {video_file}")
    
    return StreamingResponse(
        _async_mjpeg_generator(str(video_path)),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
        }
    )


# ============= REST Endpoints =============

@router.post("/analyze-exercise")
async def analyze_exercise(
    video: UploadFile = File(...),
    exercise_type: str = "chair_stand"
):
    """
    Analyze exercise form from uploaded video using MediaPipe pose estimation.
    
    Detects:
    - Joint angles and body posture
    - Repetition counting
    - Form quality assessment
    - Safety concerns
    """
    pose_analyzer, _ = get_services()
    
    # Validate exercise type
    try:
        ex_type = ExerciseType(exercise_type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid exercise type. Valid types: {[e.value for e in ExerciseType]}"
        )
    
    # Save uploaded video temporarily
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
        content = await video.read()
        tmp.write(content)
        tmp_path = tmp.name
    
    try:
        # Process video frames
        cap = cv2.VideoCapture(tmp_path)
        fps = cap.get(cv2.CAP_PROP_FPS) or 30
        
        rep_counter = RepCounter(ex_type)
        form_assessments = []
        frame_count = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            
            # Analyze pose in frame
            pose_result = pose_analyzer.process_frame(frame)
            
            if pose_result and pose_result.pose_detected:
                # Count reps
                rep_counter.update(pose_result)
                
                # Assess form periodically
                if frame_count % 30 == 0:  # Every 30 frames
                    assessment = pose_analyzer.assess_form(pose_result, ex_type)
                    if assessment:
                        form_assessments.append(assessment)
            
            frame_count += 1
        
        cap.release()
        
        # Calculate overall form quality
        if form_assessments:
            avg_score = sum(a.score for a in form_assessments) / len(form_assessments)
            if avg_score >= 0.9:
                overall_quality = FormQuality.EXCELLENT
            elif avg_score >= 0.75:
                overall_quality = FormQuality.GOOD
            elif avg_score >= 0.5:
                overall_quality = FormQuality.FAIR
            else:
                overall_quality = FormQuality.POOR
            
            # Collect all feedback
            all_feedback = []
            for a in form_assessments:
                all_feedback.extend(a.feedback)
            unique_feedback = list(set(all_feedback))[:5]
        else:
            avg_score = 0.0
            overall_quality = FormQuality.FAIR
            unique_feedback = ["Unable to detect clear pose in video"]
        
    finally:
        os.unlink(tmp_path)
    
    return {
        "status": "completed",
        "exercise_type": exercise_type,
        "frames_processed": frame_count,
        "reps_counted": rep_counter.count,
        "form_assessment": {
            "score": round(avg_score * 100, 1),
            "quality": overall_quality.value,
            "feedback": unique_feedback
        },
        "recommendations": [
            "Focus on controlled movement throughout the exercise",
            "Maintain proper alignment during each repetition"
        ]
    }


@router.post("/session/start")
async def start_exercise_session(request: StartSessionRequest):
    """
    Start a new exercise session for real-time monitoring.
    
    Returns a session ID for use with the WebSocket stream.
    """
    _, session_handler = get_services()
    
    try:
        ex_type = ExerciseType(request.exercise_type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid exercise type. Valid types: {[e.value for e in ExerciseType]}"
        )
    
    session = session_handler.create_session(
        user_id=request.user_id,
        exercise_type=ex_type,
        target_reps=request.target_reps,
        target_sets=request.target_sets
    )
    
    # Create phase tracker for progressive pose guidance
    phase_tracker = get_or_create_phase_tracker(
        session_id=session.session_id,
        exercise_id=request.exercise_type,
        target_reps=request.target_reps,
        target_sets=request.target_sets,
    )
    
    # Check if exercise has defined phases for reference skeleton
    has_phases = phase_tracker.has_phases
    phase_info = None
    if has_phases:
        phase_info = {
            "total_phases": len(phase_tracker.phase_sequence.phases),
            "phase_names": [p.name for p in phase_tracker.phase_sequence.phases],
        }
    
    return {
        "status": "created",
        "session_id": session.session_id,
        "user_id": request.user_id,
        "exercise_type": request.exercise_type,
        "target": {
            "reps": request.target_reps,
            "sets": request.target_sets
        },
        "has_phase_guidance": has_phases,
        "phase_info": phase_info,
        "websocket_url": f"/physio/ws/session/{session.session_id}"
    }


@router.post("/session/{session_id}/complete")
async def complete_session(session_id: str):
    """Complete an exercise session and get final results."""
    _, session_handler = get_services()
    
    session = session_handler.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    result = session_handler.complete_session(session_id)
    
    # Get phase tracker adaptation info before cleanup
    phase_tracker = get_phase_tracker(session_id)
    adaptation_info = None
    if phase_tracker:
        adaptation_info = phase_tracker._get_adaptation_info()
        # Cleanup phase tracker
        remove_phase_tracker(session_id)
    
    return {
        "status": "completed",
        "session_id": session_id,
        "result": result,
        "adaptation": adaptation_info,
    }


@router.post("/session/{session_id}/feedback")
async def submit_session_feedback(session_id: str, request: SessionFeedbackRequest):
    """Submit user feedback for a completed session."""
    _, session_handler = get_services()
    
    session = session_handler.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Store feedback (would save to database in production)
    return {
        "status": "feedback_recorded",
        "session_id": session_id,
        "pain_level": request.pain_level,
        "difficulty_rating": request.difficulty_rating
    }


# ============= Frame-by-Frame Analysis =============

class FrameRequest(BaseModel):
    """Request model for frame-by-frame analysis."""
    frame_base64: str


@router.post("/session/{session_id}/frame")
async def analyze_session_frame(session_id: str, request: FrameRequest):
    """
    Analyze a single video frame during exercise session.
    
    Expects base64-encoded JPEG image frame.
    Returns real-time form assessment and rep counting.
    """
    pose_analyzer, session_handler = get_services()
    
    # Verify session exists and is active
    session = session_handler.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Start session if idle (first frame)
    if session.state == SessionState.IDLE:
        session_handler.start_session(session_id)
    
    try:
        # Decode base64 frame
        frame_data = base64.b64decode(request.frame_base64)
        nparr = np.frombuffer(frame_data, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if frame is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        
        # Convert BGR to RGB for MediaPipe
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Detect pose
        timestamp_ms = int(asyncio.get_event_loop().time() * 1000)
        pose_result = pose_analyzer.detect_pose(frame_rgb, timestamp_ms)
        
        if pose_result is None:
            logger.debug(f"  ❌ No pose detected in frame for session {session_id}")
            return {
                "session_id": session_id,
                "pose_detected": False,
                "message": "No pose detected - ensure full body is visible",
                "state": session.state.value,
                "current_set": session.current_set,
                "current_rep": session.current_rep,
                "target_reps": session.target_reps_per_set,
                "target_sets": session.target_sets
            }
        
        # Log pose detection details
        angles = pose_analyzer.get_joint_angles(pose_result)
        logger.debug(
            f"  📐 Pose [{session_id}] confidence={pose_result.confidence:.2f} | "
            f"L_knee={angles.get('left_knee', 0):.1f}° R_knee={angles.get('right_knee', 0):.1f}° | "
            f"L_hip={angles.get('left_hip', 0):.1f}° R_hip={angles.get('right_hip', 0):.1f}° | "
            f"L_shoulder={angles.get('left_shoulder', 0):.1f}° R_shoulder={angles.get('right_shoulder', 0):.1f}° | "
            f"trunk={angles.get('trunk_vertical', 0):.1f}°"
        )
        
        # Process frame through session handler
        result = session_handler.process_frame(session_id, pose_result)
        result["pose_detected"] = True
        result["confidence"] = round(pose_result.confidence * 100, 1)
        result["target_sets"] = session.target_sets
        
        # Check landmark visibility for this exercise
        is_body_visible, missing_landmarks = pose_analyzer.check_landmark_visibility(
            pose_result, session.exercise_type
        )
        result["body_visible"] = is_body_visible
        if not is_body_visible:
            # Get exercise-specific visibility message
            visibility_msg = pose_analyzer._get_visibility_feedback(session.exercise_type, missing_landmarks)
            result["message"] = visibility_msg
        
        # Include joint angles in response for frontend display
        result["joint_angles"] = {
            k: round(v, 1) for k, v in angles.items()
        }
        
        # Include landmark positions for skeleton overlay (normalized 0-1 coordinates)
        # landmarks is Dict[int, Landmark], so iterate over items to get both index and landmark
        if pose_result.landmarks:
            result["landmarks"] = [
                {
                    "index": idx,
                    "x": round(lm.x, 4),
                    "y": round(lm.y, 4),
                    "z": round(lm.z, 4) if hasattr(lm, 'z') else 0.0,
                    "visibility": round(lm.visibility, 2) if hasattr(lm, 'visibility') else 1.0,
                }
                for idx, lm in pose_result.landmarks.items()
            ]
        
        # ── Phase Tracking for Progressive Reference Poses ───────────────────
        phase_tracker = get_phase_tracker(session_id)
        if phase_tracker and phase_tracker.has_phases:
            # Detect trembling from movement analysis
            trembling = result.get("trembling_detected", False)
            
            # Get pain level from facial analysis (if available)
            pain_level = None
            pain_confidence = 0.0
            facial_pain = result.get("facial_pain", {})
            if facial_pain.get("detected"):
                pain_level = facial_pain.get("pain_level")
                pain_confidence = facial_pain.get("confidence", 0.0) / 100.0
            
            # Update phase tracker with current state
            phase_progress = phase_tracker.update(
                current_angles=angles,
                pain_level=pain_level,
                pain_confidence=pain_confidence,
                trembling=trembling,
            )
            
            # Include phase guidance in response
            result["phase_guidance"] = {
                "current_phase": phase_progress.get("current_phase"),
                "next_phase": phase_progress.get("next_phase"),
                "phase_index": phase_progress.get("phase_index"),
                "total_phases": phase_progress.get("total_phases"),
                "rep_completed": phase_progress.get("rep_completed", False),
                "current_rep": phase_progress.get("current_rep"),
                "current_set": phase_progress.get("current_set"),
                "target_reps": phase_progress.get("target_reps"),
                "target_sets": phase_progress.get("target_sets"),
                "adaptation": phase_progress.get("adaptation"),
            }
            
            # Override result rep/set from phase tracker (more accurate)
            result["current_rep"] = phase_progress.get("current_rep", 0)
            result["current_set"] = phase_progress.get("current_set", 1)
            result["adapted_target_reps"] = phase_progress.get("target_reps")
            
            # Add dynamic phase-based feedback
            current_phase = phase_progress.get("current_phase")
            if current_phase:
                match_quality = current_phase.get("match_quality", "not_matching")
                visual_cue = current_phase.get("visual_cue", "")
                hold_required = current_phase.get("hold_required", 0)
                hold_progress = current_phase.get("hold_progress", 0)
                
                # Generate dynamic feedback based on match quality
                dynamic_feedback = []
                if match_quality == "matching" or match_quality == "holding":
                    if hold_required > 0:
                        remaining = max(0, hold_required - hold_progress)
                        if remaining > 0:
                            dynamic_feedback.append(f"Hold for {remaining:.1f}s more ✓")
                        else:
                            dynamic_feedback.append("Great hold! ✓")
                    else:
                        dynamic_feedback.append("Good position! ✓")
                elif match_quality == "approaching":
                    dynamic_feedback.append(f"Almost there — {visual_cue}")
                else:
                    if visual_cue:
                        dynamic_feedback.append(visual_cue)
                
                # Prepend dynamic feedback to existing feedback
                existing_feedback = result.get("feedback", [])
                result["feedback"] = dynamic_feedback + [f for f in existing_feedback if f not in dynamic_feedback]
            
            # Include reference pose for ghost skeleton
            ref_pose = phase_tracker.get_reference_pose_data()
            if ref_pose:
                result["reference_pose"] = ref_pose
        
        # Log rep/form results
        logger.debug(
            f"  🏋️ Result [{session_id}] set={result.get('current_set')}/{session.target_sets} "
            f"rep={result.get('current_rep')}/{session.target_reps_per_set} | "
            f"score={result.get('form_score', 0):.1f} quality={result.get('form_quality', '?')} | "
            f"feedback={result.get('feedback', [])}"
        )
        
        # ── Face Pain Analysis (every Nth frame to reduce compute) ───────────
        if session_id not in _session_frame_counts:
            _session_frame_counts[session_id] = 0
        _session_frame_counts[session_id] += 1
        
        face_pain_result = None
        if _session_frame_counts[session_id] % PAIN_ANALYSIS_INTERVAL == 0:
            try:
                face_analyzer = get_face_pain_analyzer()
                face_pain_result = face_analyzer.analyze_pain(frame_rgb, timestamp_ms)
                
                if face_pain_result and face_pain_result.face_detected:
                    result["facial_pain"] = {
                        "detected": True,
                        "pain_level": face_pain_result.pain_level.value,
                        "confidence": round(face_pain_result.confidence * 100, 1),
                        "pain_score": round(face_pain_result.pain_score * 100, 1),
                        "details": face_pain_result.details,
                    }
                    
                    # Store significant pain events (MILD or higher)
                    if face_pain_result.pain_level.value != "none":
                        pain_store = get_pain_data_store()
                        pain_store.record_pain_event(
                            session_id=session_id,
                            user_id=session.user_id,
                            pain_level=PainLevel(face_pain_result.pain_level.value),
                            confidence=face_pain_result.confidence,
                            source="face",
                            exercise_type=session.exercise_type.value if hasattr(session.exercise_type, 'value') else str(session.exercise_type),
                            rep_number=session.current_rep,
                            set_number=session.current_set,
                            action_units=face_pain_result.action_units,
                            details=face_pain_result.details
                        )
                        
                        logger.info(
                            f"  😣 Pain detected [{session_id}] level={face_pain_result.pain_level.value} "
                            f"confidence={face_pain_result.confidence:.0%}"
                        )
                else:
                    result["facial_pain"] = {"detected": False, "message": "No face detected"}
                    
            except Exception as pain_err:
                logger.warning(f"  ⚠️ Face pain analysis error: {pain_err}")
                result["facial_pain"] = {"detected": False, "error": str(pain_err)}
        
        return result
        
    except Exception as e:
        logger.error(f"Frame processing error for session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Frame processing error: {str(e)}")


# ============= Pain History Endpoints =============

@router.get("/pain/session/{session_id}")
async def get_session_pain_events(session_id: str):
    """Get all pain events for a session."""
    pain_store = get_pain_data_store()
    events = pain_store.get_session_events(session_id)
    
    return {
        "session_id": session_id,
        "total_events": len(events),
        "events": [e.to_dict() for e in events]
    }


@router.get("/pain/history/{user_id}")
async def get_user_pain_history(user_id: str, days: int = 7):
    """Get aggregated pain history for a user."""
    pain_store = get_pain_data_store()
    history = pain_store.get_user_pain_history(user_id, days)
    
    return history.to_dict()


@router.get("/pain/report/{user_id}")
async def get_caregiver_pain_report(user_id: str, days: int = 7):
    """
    Generate a caregiver-friendly pain report.
    
    Includes:
    - Summary statistics
    - Per-exercise breakdown  
    - Recommendations
    - Recent session details
    """
    pain_store = get_pain_data_store()
    report = pain_store.get_caregiver_report(user_id, days)
    
    return report


@router.post("/session/{session_id}/pain-summary")
async def finalize_session_pain_summary(session_id: str, exercise_stopped: bool = False, intensity_reduced: bool = False):
    """
    Create final pain summary when session ends.
    Called automatically when session completes.
    """
    _, session_handler = get_services()
    session = session_handler.get_session(session_id)
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    pain_store = get_pain_data_store()
    summary = pain_store.create_session_summary(
        session_id=session_id,
        user_id=session.user_id,
        exercise_type=session.exercise_type.value if hasattr(session.exercise_type, 'value') else str(session.exercise_type),
        start_time=session.created_at,
        end_time=datetime.now(),
        exercise_stopped=exercise_stopped,
        intensity_reduced=intensity_reduced
    )
    
    # Clean up frame counter
    if session_id in _session_frame_counts:
        del _session_frame_counts[session_id]
    
    return summary.to_dict()


@router.get("/exercises")
async def get_exercises(category: Optional[str] = None, difficulty: Optional[str] = None):
    """Get exercise library."""
    exercises = EXERCISES_DB.copy()
    
    if category and category != "All":
        exercises = [e for e in exercises if e["category"] == category]
    
    if difficulty:
        exercises = [e for e in exercises if e["difficulty"] == difficulty]
    
    return {
        "exercises": exercises,
        "total": len(exercises),
        "categories": ["All", "Balance", "Strength", "Flexibility", "Gait"]
    }


@router.get("/exercises/{user_id}")
async def get_user_exercises(user_id: str):
    """Get prescribed exercises for a user."""
    prescribed = [e for e in EXERCISES_DB if e["is_prescribed"]]
    return {
        "user_id": user_id,
        "exercises": prescribed,
        "total_prescribed": len(prescribed),
        "completion_rate": round(random.uniform(60, 95), 1)
    }


@router.get("/fall-risk/{user_id}")
async def get_fall_risk(user_id: str):
    """Get current fall risk score for a user."""
    risk_score = round(random.uniform(15, 45), 1)
    
    if risk_score < 20:
        risk_level = "Low"
    elif risk_score < 35:
        risk_level = "Moderate"
    else:
        risk_level = "High"
    
    return {
        "user_id": user_id,
        "risk_score": risk_score,
        "risk_level": risk_level,
        "contributing_factors": [
            "Gait asymmetry detected",
            "Previous fall history",
            "Medication side effects"
        ][:random.randint(1, 3)],
        "last_assessment": datetime.now().isoformat(),
        "trend": "improving" if random.random() > 0.5 else "stable"
    }


@router.get("/progress/{user_id}")
async def get_progress(user_id: str, days: int = 7):
    """Get physiotherapy progress over time."""
    progress = []
    for i in range(days):
        progress.append({
            "date": f"2026-01-{max(1, 31-i):02d}",
            "exercises_completed": random.randint(2, 5),
            "total_duration_minutes": random.randint(15, 45),
            "fall_risk_score": round(random.uniform(20, 40), 1),
            "gait_score": round(random.uniform(70, 95), 1)
        })
    
    return {
        "user_id": user_id,
        "progress": progress,
        "summary": {
            "total_sessions": random.randint(10, 20),
            "avg_daily_minutes": round(random.uniform(20, 35), 1),
            "improvement_percentage": round(random.uniform(5, 15), 1)
        }
    }


@router.get("/sessions/{user_id}")
async def get_recent_sessions(user_id: str, limit: int = 5):
    """Get recent physio sessions for a user."""
    sessions = []
    for i in range(limit):
        sessions.append({
            "id": f"session_{i+1}",
            "date": f"2026-01-{max(1, 31-i):02d}",
            "type": random.choice(["Gait Analysis", "TUG Test", "Balance Exercise", "Strength Training"]),
            "duration_minutes": random.randint(10, 30),
            "score": round(random.uniform(70, 95), 1),
            "status": "completed"
        })
    
    return {"user_id": user_id, "sessions": sessions}


# ============= WebSocket Endpoints =============

@router.websocket("/ws/stream/{user_id}")
async def physio_stream(websocket: WebSocket, user_id: str):
    """
    Real-time video stream for exercise monitoring.
    
    Receives video frames, processes with MediaPipe, returns pose analysis.
    """
    await websocket.accept()
    pose_analyzer, _ = get_services()
    
    try:
        await websocket.send_json({
            "type": "CONNECTED",
            "user_id": user_id,
            "message": "Physio stream connected"
        })
        
        while True:
            # Receive video frame as base64 or bytes
            data = await websocket.receive_bytes()
            
            # Decode frame
            try:
                nparr = np.frombuffer(data, np.uint8)
                frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                
                if frame is None:
                    await websocket.send_json({
                        "type": "ERROR",
                        "message": "Invalid frame data"
                    })
                    continue
                
                # Process frame with pose analyzer
                pose_result = pose_analyzer.process_frame(frame)
                
                if pose_result and pose_result.pose_detected:
                    # Get key joint angles for feedback
                    angles = {}
                    for angle in pose_result.joint_angles:
                        angles[angle.name] = round(angle.angle, 1)
                    
                    await websocket.send_json({
                        "type": "POSE_RESULT",
                        "pose_detected": True,
                        "landmark_count": len(pose_result.landmarks) if pose_result.landmarks else 0,
                        "joint_angles": angles,
                        "timestamp": pose_result.timestamp
                    })
                else:
                    await websocket.send_json({
                        "type": "POSE_RESULT",
                        "pose_detected": False,
                        "message": "No pose detected in frame"
                    })
                    
            except Exception as e:
                await websocket.send_json({
                    "type": "ERROR",
                    "message": f"Processing error: {str(e)}"
                })
            
    except WebSocketDisconnect:
        print(f"Client {user_id} disconnected from physio stream")


@router.websocket("/ws/session/{session_id}")
async def exercise_session_stream(websocket: WebSocket, session_id: str):
    """
    Real-time exercise session monitoring with form feedback.
    
    Provides:
    - Live rep counting
    - Form quality assessment
    - Pain detection warnings
    - Session progress updates
    """
    await websocket.accept()
    pose_analyzer, session_handler = get_services()
    
    session = session_handler.get_session(session_id)
    if not session:
        await websocket.send_json({
            "type": "ERROR",
            "message": f"Session {session_id} not found"
        })
        await websocket.close()
        return
    
    try:
        await websocket.send_json({
            "type": "SESSION_STARTED",
            "session_id": session_id,
            "exercise_type": session.exercise_type.value,
            "target_reps": session.target_reps,
            "target_sets": session.target_sets
        })
        
        session.state = SessionState.ACTIVE
        
        while True:
            data = await websocket.receive_bytes()
            
            try:
                nparr = np.frombuffer(data, np.uint8)
                frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                
                if frame is None:
                    continue
                
                # Process frame
                pose_result = pose_analyzer.process_frame(frame)
                
                if pose_result and pose_result.pose_detected:
                    # Update session with new frame
                    frame_result = session_handler.process_session_frame(
                        session_id, 
                        pose_result
                    )
                    
                    if frame_result:
                        await websocket.send_json({
                            "type": "FRAME_RESULT",
                            "reps_completed": frame_result.get("reps", 0),
                            "sets_completed": frame_result.get("sets", 0),
                            "current_form": frame_result.get("form_quality", "unknown"),
                            "form_score": frame_result.get("form_score", 0),
                            "feedback": frame_result.get("feedback", []),
                            "session_progress": frame_result.get("progress", 0)
                        })
                        
                        # Check if set completed
                        if frame_result.get("set_completed"):
                            await websocket.send_json({
                                "type": "SET_COMPLETED",
                                "set_number": frame_result.get("sets", 0),
                                "set_score": frame_result.get("set_score", 0)
                            })
                        
                        # Check if session completed
                        if frame_result.get("session_completed"):
                            await websocket.send_json({
                                "type": "SESSION_COMPLETED",
                                "total_score": frame_result.get("total_score", 0),
                                "summary": frame_result.get("summary", {})
                            })
                            break
                
            except Exception as e:
                await websocket.send_json({
                    "type": "ERROR",
                    "message": str(e)
                })
                
    except WebSocketDisconnect:
        print(f"Session {session_id} disconnected")
        # Mark session as paused
        if session:
            session.state = SessionState.PAUSED


# ============= Video Comparison Endpoints =============

class VideoCompareRequest(BaseModel):
    reference_video_path: str
    comparison_video_path: str
    exercise_type: str = "chair_stand"
    sample_rate: int = 10  # Analyze every Nth frame


@router.post("/compare-videos")
async def compare_videos(request: VideoCompareRequest):
    """
    Compare two exercise videos and calculate similarity score.
    
    Uses pose estimation to extract joint angles and compares
    the movement patterns between reference and comparison videos.
    """
    pose_analyzer, _ = get_services()
    
    # Validate exercise type
    try:
        ex_type = ExerciseType(request.exercise_type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid exercise type. Valid types: {[e.value for e in ExerciseType]}"
        )
    
    # Check if files exist
    if not os.path.exists(request.reference_video_path):
        raise HTTPException(status_code=404, detail=f"Reference video not found: {request.reference_video_path}")
    if not os.path.exists(request.comparison_video_path):
        raise HTTPException(status_code=404, detail=f"Comparison video not found: {request.comparison_video_path}")
    
    # Extract poses from both videos
    ref_poses = _extract_poses_from_video(pose_analyzer, request.reference_video_path, request.sample_rate)
    comp_poses = _extract_poses_from_video(pose_analyzer, request.comparison_video_path, request.sample_rate)
    
    if not ref_poses or not comp_poses:
        return {
            "status": "error",
            "message": "Could not extract poses from one or both videos",
            "reference_frames": len(ref_poses),
            "comparison_frames": len(comp_poses)
        }
    
    # Compare poses and calculate similarity
    similarity_results = _compare_pose_sequences(pose_analyzer, ref_poses, comp_poses, ex_type)
    
    return {
        "status": "completed",
        "exercise_type": request.exercise_type,
        "reference_video": os.path.basename(request.reference_video_path),
        "comparison_video": os.path.basename(request.comparison_video_path),
        "reference_frames_analyzed": len(ref_poses),
        "comparison_frames_analyzed": len(comp_poses),
        "similarity": similarity_results
    }


@router.get("/analyze-local-video/{video_name}")
async def analyze_local_video(video_name: str, exercise_type: str = "chair_stand"):
    """
    Analyze a video from the local media/simulation_footage/physio/exercise folder.
    """
    pose_analyzer, _ = get_services()
    
    # Construct path to video
    base_path = os.path.dirname(os.path.dirname(__file__))
    video_path = os.path.join(base_path, "media", "simulation_footage", "physio", "exercise", video_name)
    
    if not os.path.exists(video_path):
        raise HTTPException(status_code=404, detail=f"Video not found: {video_name}")
    
    # Validate exercise type
    try:
        ex_type = ExerciseType(exercise_type)
    except ValueError:
        ex_type = ExerciseType.CHAIR_STAND
    
    # Extract and analyze poses
    poses = _extract_poses_from_video(pose_analyzer, video_path, sample_rate=5)
    
    if not poses:
        return {
            "status": "error",
            "video": video_name,
            "message": "Could not detect poses in video"
        }
    
    # Analyze form for each pose
    form_scores = []
    all_feedback = []
    joint_angle_history = []
    
    for pose in poses:
        assessment = pose_analyzer.assess_form(pose, ex_type)
        if assessment:
            form_scores.append(assessment.score)
            all_feedback.extend(assessment.feedback)
            
            # Get joint angles
            angles = pose_analyzer.get_joint_angles(pose)
            joint_angle_history.append(angles)
    
    avg_score = sum(form_scores) / len(form_scores) if form_scores else 0
    unique_feedback = list(set(all_feedback))[:5]
    
    # Calculate average joint angles
    avg_angles = {}
    if joint_angle_history:
        for key in joint_angle_history[0].keys():
            values = [angles.get(key, 0) for angles in joint_angle_history]
            avg_angles[key] = round(sum(values) / len(values), 1)
    
    return {
        "status": "completed",
        "video": video_name,
        "exercise_type": exercise_type,
        "frames_analyzed": len(poses),
        "form_assessment": {
            "average_score": round(avg_score, 1),
            "quality": _score_to_quality(avg_score),
            "feedback": unique_feedback
        },
        "average_joint_angles": avg_angles,
        "analysis_timestamp": datetime.now().isoformat()
    }


@router.get("/compare-local-videos")
async def compare_local_videos(
    video1: str,
    video2: str,
    exercise_type: str = "chair_stand"
):
    """
    Compare two local videos from the physio exercise folder.
    
    Example: /api/physio/compare-local-videos?video1=ex1.mp4&video2=ex2.mp4
    """
    pose_analyzer, _ = get_services()
    
    base_path = os.path.dirname(os.path.dirname(__file__))
    video_dir = os.path.join(base_path, "media", "simulation_footage", "physio", "exercise")
    
    video1_path = os.path.join(video_dir, video1)
    video2_path = os.path.join(video_dir, video2)
    
    if not os.path.exists(video1_path):
        raise HTTPException(status_code=404, detail=f"Video not found: {video1}")
    if not os.path.exists(video2_path):
        raise HTTPException(status_code=404, detail=f"Video not found: {video2}")
    
    try:
        ex_type = ExerciseType(exercise_type)
    except ValueError:
        ex_type = ExerciseType.CHAIR_STAND
    
    # Extract poses
    poses1 = _extract_poses_from_video(pose_analyzer, video1_path, sample_rate=10)
    poses2 = _extract_poses_from_video(pose_analyzer, video2_path, sample_rate=10)
    
    if not poses1 or not poses2:
        return {
            "status": "error",
            "message": "Could not extract poses from one or both videos",
            "video1_frames": len(poses1) if poses1 else 0,
            "video2_frames": len(poses2) if poses2 else 0
        }
    
    # Compare
    similarity = _compare_pose_sequences(pose_analyzer, poses1, poses2, ex_type)
    
    # Also get individual form assessments
    form1 = _assess_video_form(pose_analyzer, poses1, ex_type)
    form2 = _assess_video_form(pose_analyzer, poses2, ex_type)
    
    return {
        "status": "completed",
        "video1": {
            "name": video1,
            "frames_analyzed": len(poses1),
            "form_score": form1["score"],
            "form_quality": form1["quality"]
        },
        "video2": {
            "name": video2,
            "frames_analyzed": len(poses2),
            "form_score": form2["score"],
            "form_quality": form2["quality"]
        },
        "comparison": similarity,
        "analysis_timestamp": datetime.now().isoformat()
    }


@router.get("/list-exercise-videos")
async def list_exercise_videos():
    """List all available exercise videos in the media folder."""
    base_path = os.path.dirname(os.path.dirname(__file__))
    video_dir = os.path.join(base_path, "media", "simulation_footage", "physio", "exercise")
    
    if not os.path.exists(video_dir):
        return {"videos": [], "path": video_dir, "error": "Directory not found"}
    
    videos = [f for f in os.listdir(video_dir) if f.endswith(('.mp4', '.avi', '.mov'))]
    
    return {
        "videos": videos,
        "count": len(videos),
        "path": video_dir
    }


# ============= Helper Functions =============

def _extract_poses_from_video(pose_analyzer: PoseAnalyzer, video_path: str, sample_rate: int = 10) -> List[PoseResult]:
    """Extract pose results from video at specified sample rate."""
    poses = []
    
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Could not open video: {video_path}")
        return poses
    
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    frame_count = 0
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        if frame_count % sample_rate == 0:
            # Convert BGR to RGB
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            timestamp_ms = (frame_count / fps) * 1000
            
            pose = pose_analyzer.detect_pose(rgb_frame, timestamp_ms)
            if pose:
                poses.append(pose)
        
        frame_count += 1
    
    cap.release()
    return poses


def _compare_pose_sequences(
    pose_analyzer: PoseAnalyzer,
    poses1: List[PoseResult],
    poses2: List[PoseResult],
    exercise_type: ExerciseType
) -> Dict[str, Any]:
    """Compare two sequences of poses and calculate similarity metrics."""
    
    # Get joint angles for all poses
    angles1 = [pose_analyzer.get_joint_angles(p) for p in poses1]
    angles2 = [pose_analyzer.get_joint_angles(p) for p in poses2]
    
    if not angles1 or not angles2:
        return {"overall_similarity": 0, "error": "No angles extracted"}
    
    # Key angles for comparison based on exercise type
    key_angles = ["left_knee", "right_knee", "left_hip", "right_hip", "left_shoulder", "right_shoulder"]
    
    # Normalize sequence lengths using dynamic time warping concept (simplified)
    min_len = min(len(angles1), len(angles2))
    
    # Sample to same length
    step1 = len(angles1) / min_len
    step2 = len(angles2) / min_len
    
    sampled1 = [angles1[int(i * step1)] for i in range(min_len)]
    sampled2 = [angles2[int(i * step2)] for i in range(min_len)]
    
    # Calculate per-angle similarity
    angle_similarities = {}
    overall_diffs = []
    
    for angle_name in key_angles:
        diffs = []
        for a1, a2 in zip(sampled1, sampled2):
            v1 = a1.get(angle_name, 0)
            v2 = a2.get(angle_name, 0)
            diff = abs(v1 - v2)
            diffs.append(diff)
        
        avg_diff = sum(diffs) / len(diffs) if diffs else 0
        # Convert to similarity (0-100), where 0 diff = 100% similar
        # 45 degree diff = 0% similar
        similarity = max(0, 100 - (avg_diff / 45 * 100))
        angle_similarities[angle_name] = round(similarity, 1)
        overall_diffs.append(avg_diff)
    
    # Overall similarity
    overall_similarity = sum(angle_similarities.values()) / len(angle_similarities) if angle_similarities else 0
    
    # Movement pattern similarity (variance comparison)
    pattern_score = _compare_movement_patterns(sampled1, sampled2, key_angles)
    
    return {
        "overall_similarity": round(overall_similarity, 1),
        "pattern_similarity": round(pattern_score, 1),
        "combined_score": round((overall_similarity + pattern_score) / 2, 1),
        "angle_similarities": angle_similarities,
        "frames_compared": min_len
    }


def _compare_movement_patterns(angles1: List[Dict], angles2: List[Dict], key_angles: List[str]) -> float:
    """Compare the movement patterns (variance and range) between two sequences."""
    
    pattern_scores = []
    
    for angle_name in key_angles:
        values1 = [a.get(angle_name, 0) for a in angles1]
        values2 = [a.get(angle_name, 0) for a in angles2]
        
        if not values1 or not values2:
            continue
        
        # Compare range of motion
        range1 = max(values1) - min(values1)
        range2 = max(values2) - min(values2)
        range_diff = abs(range1 - range2)
        range_similarity = max(0, 100 - (range_diff / 90 * 100))
        
        # Compare variance (movement smoothness)
        var1 = np.var(values1) if len(values1) > 1 else 0
        var2 = np.var(values2) if len(values2) > 1 else 0
        var_ratio = min(var1, var2) / max(var1, var2) if max(var1, var2) > 0 else 1
        var_similarity = var_ratio * 100
        
        pattern_scores.append((range_similarity + var_similarity) / 2)
    
    return sum(pattern_scores) / len(pattern_scores) if pattern_scores else 0


def _assess_video_form(pose_analyzer: PoseAnalyzer, poses: List[PoseResult], exercise_type: ExerciseType) -> Dict[str, Any]:
    """Assess overall form quality for a video."""
    scores = []
    
    for pose in poses:
        assessment = pose_analyzer.assess_form(pose, exercise_type)
        if assessment:
            scores.append(assessment.score)
    
    avg_score = sum(scores) / len(scores) if scores else 0
    
    return {
        "score": round(avg_score, 1),
        "quality": _score_to_quality(avg_score)
    }


def _score_to_quality(score: float) -> str:
    """Convert numeric score to quality label."""
    if score >= 90:
        return "excellent"
    elif score >= 75:
        return "good"
    elif score >= 50:
        return "fair"
    else:
        return "poor"


# ══════════════════════════════════════════════════════════════════════════════
# PATIENT PROFILE ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════

class PatientProfileRequest(BaseModel):
    """Request model for creating/updating patient profile."""
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    date_of_birth: Optional[str] = None  # ISO format: YYYY-MM-DD
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    pain_tolerance: Optional[str] = None
    baseline_pain_level: Optional[int] = None
    baseline_fatigue_level: Optional[int] = None
    baseline_mobility_score: Optional[int] = None
    primary_goal: Optional[str] = None
    secondary_goals: Optional[List[str]] = None
    medical_history: Optional[Dict[str, Any]] = None
    lifestyle: Optional[Dict[str, Any]] = None


@router.get("/profile/{user_id}")
async def get_patient_profile(user_id: str):
    """Get patient profile for a user."""
    profile_store = get_patient_profile_store()
    profile = profile_store.get_profile(user_id)
    
    if not profile:
        return {
            "user_id": user_id,
            "exists": False,
            "message": "Profile not found. Create one first."
        }
    
    return {
        "exists": True,
        "profile": profile.to_dict()
    }


@router.post("/profile/{user_id}")
async def create_or_update_profile(user_id: str, request: PatientProfileRequest):
    """Create or update patient profile."""
    profile_store = get_patient_profile_store()
    
    # Get or create profile
    profile = profile_store.get_or_create_profile(user_id)
    
    # Update with provided data
    updates = request.model_dump(exclude_none=True)
    if updates:
        profile = profile_store.update_profile(user_id, updates)
    
    return {
        "status": "profile_updated",
        "user_id": user_id,
        "profile": profile.to_dict()
    }


@router.delete("/profile/{user_id}")
async def delete_profile(user_id: str):
    """Delete a patient profile."""
    profile_store = get_patient_profile_store()
    deleted = profile_store.delete_profile(user_id)
    
    return {
        "status": "deleted" if deleted else "not_found",
        "user_id": user_id
    }


# ══════════════════════════════════════════════════════════════════════════════
# BMI CALCULATION ENDPOINTS  
# ══════════════════════════════════════════════════════════════════════════════

class BMIRequest(BaseModel):
    """Request model for BMI calculation."""
    weight_kg: float
    height_cm: float
    age: Optional[int] = 0


@router.post("/bmi/calculate")
async def calculate_bmi_endpoint(request: BMIRequest):
    """
    Calculate BMI with health category and recommendations.
    
    Args:
        weight_kg: Weight in kilograms
        height_cm: Height in centimeters
        age: Age in years (optional, for age-specific recommendations)
    
    Returns:
        BMI value, category, health risk level, and recommendations
    """
    result = calculate_bmi(request.weight_kg, request.height_cm, request.age or 0)
    return result.to_dict()


@router.get("/bmi/{user_id}")
async def get_user_bmi(user_id: str):
    """Get BMI for a user based on their profile."""
    profile_store = get_patient_profile_store()
    profile = profile_store.get_profile(user_id)
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    if profile.height_cm <= 0 or profile.weight_kg <= 0:
        raise HTTPException(status_code=400, detail="Height and weight required in profile")
    
    result = profile.calculate_bmi_result()
    return {
        "user_id": user_id,
        "height_cm": profile.height_cm,
        "weight_kg": profile.weight_kg,
        "age": profile.age,
        **result.to_dict()
    }


# ══════════════════════════════════════════════════════════════════════════════
# EXERCISE PLAN GENERATION ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════

class GeneratePlanRequest(BaseModel):
    """Request model for generating exercise plan."""
    date: Optional[str] = None  # ISO format: YYYY-MM-DD
    difficulty: Optional[str] = None  # very_easy, easy, moderate, challenging


@router.post("/plan/generate/{user_id}")
async def generate_exercise_plan(user_id: str, request: GeneratePlanRequest):
    """
    Generate a personalized daily exercise plan.
    
    The plan is generated based on:
    - Patient profile (BMI, age, arthritis, affected joints)
    - Pain history from recent sessions
    - Mobility level and available equipment
    
    Args:
        user_id: Patient user ID
        date: Target date for the plan (default: today)
        difficulty: Override difficulty level (optional)
    
    Returns:
        Complete daily exercise plan with personalized exercises
    """
    from datetime import date as date_cls
    
    plan_generator = get_exercise_plan_generator()
    
    # Parse date
    plan_date = None
    if request.date:
        plan_date = date_cls.fromisoformat(request.date)
    
    # Generate plan
    plan = plan_generator.generate_daily_plan(
        user_id=user_id,
        plan_date=plan_date,
        override_difficulty=request.difficulty
    )
    
    return plan.to_dict()


@router.get("/plan/{plan_id}")
async def get_exercise_plan(plan_id: str):
    """Get an exercise plan by ID."""
    plan_generator = get_exercise_plan_generator()
    plan = plan_generator.get_plan(plan_id)
    
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    
    return plan.to_dict()


@router.get("/plans/{user_id}")
async def get_user_plans(user_id: str, days: int = 7):
    """Get recent exercise plans for a user."""
    plan_generator = get_exercise_plan_generator()
    plans = plan_generator.get_user_plans(user_id, days)
    
    return {
        "user_id": user_id,
        "period_days": days,
        "total_plans": len(plans),
        "plans": [p.to_dict() for p in plans]
    }


@router.post("/plan/{plan_id}/complete")
async def complete_exercise_plan(plan_id: str, feedback: Optional[str] = None):
    """Mark an exercise plan as completed."""
    plan_generator = get_exercise_plan_generator()
    plan = plan_generator.mark_plan_completed(plan_id, feedback)
    
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    
    return {
        "status": "completed",
        "plan_id": plan_id,
        "completed_at": plan.completed_at.isoformat() if plan.completed_at else None
    }


@router.post("/plan/{plan_id}/exercise/{exercise_id}/complete")
async def complete_single_exercise(plan_id: str, exercise_id: str):
    """Mark a single exercise as completed within a plan."""
    plan_generator = get_exercise_plan_generator()
    plan = plan_generator.mark_exercise_completed(plan_id, exercise_id)
    
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    
    return {
        "status": "exercise_completed",
        "plan_id": plan_id,
        "exercise_id": exercise_id,
        "completed_exercises": plan.completed_exercises,
        "completed_exercise_count": plan.completed_exercise_count,
        "exercise_count": plan.exercise_count,
        "plan_completed": plan.completed,
    }


@router.get("/exercise-library")
async def get_exercise_library(category: Optional[str] = None):
    """
    Get the exercise library with all available exercises.
    
    Args:
        category: Filter by category (optional)
    """
    exercises = list(EXERCISE_LIBRARY.values())
    
    if category:
        exercises = [e for e in exercises if e.category.value == category]
    
    return {
        "total": len(exercises),
        "categories": list(set(e.category.value for e in EXERCISE_LIBRARY.values())),
        "exercises": [e.to_dict() for e in exercises]
    }


@router.get("/plan/today/{user_id}")
async def get_or_create_today_plan(user_id: str):
    """
    Get today's exercise plan for a user, creating one if it doesn't exist.
    
    This is the main endpoint for the elderly user's daily exercise screen.
    """
    from datetime import date as date_cls
    
    plan_generator = get_exercise_plan_generator()
    today = date_cls.today()
    
    # Check if plan exists for today
    plans = plan_generator.get_user_plans(user_id, days=1)
    today_plan = next((p for p in plans if p.date == today), None)
    
    if not today_plan:
        # Generate new plan
        today_plan = plan_generator.generate_daily_plan(user_id, today)
    
    return today_plan.to_dict()
