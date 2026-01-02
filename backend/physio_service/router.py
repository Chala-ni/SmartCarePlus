"""
SMARTCARE+ Physio Service Router

Owner: Neelaka
Endpoints for physiotherapy analysis, exercise monitoring, and progress tracking.
Uses MediaPipe pose estimation for real-time exercise form feedback.
"""

from fastapi import APIRouter, UploadFile, File, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
import random
import cv2
import numpy as np
import base64
import asyncio
import tempfile
import os

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
    get_session_handler
)

router = APIRouter()


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
    
    return {
        "status": "created",
        "session_id": session.session_id,
        "user_id": request.user_id,
        "exercise_type": request.exercise_type,
        "target": {
            "reps": request.target_reps,
            "sets": request.target_sets
        },
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
    
    return {
        "status": "completed",
        "session_id": session_id,
        "result": result
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
