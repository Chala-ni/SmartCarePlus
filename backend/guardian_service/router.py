"""
SMARTCARE+ Guardian Service Router

Owner: Madhushani
Endpoints for real-time monitoring, fall detection, alerts, and geofencing.
Uses pre-recorded videos simulated as live CCTV feeds for demo.
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, UploadFile, File, HTTPException, Response
from fastapi.responses import FileResponse, StreamingResponse
from typing import Optional, List, Generator
from pydantic import BaseModel
from datetime import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import random
import os
import cv2
import numpy as np
import base64
import asyncio
import logging
import io
import time
import threading

logger = logging.getLogger(__name__)

from .models import (
    GaitAnalyzer,
    GaitMetrics,
    GaitAnalysisResult,
    GaitPattern,
    FallRiskLevel,
    TUGTestHandler,
    TUGTestResult,
    TUGPhase,
    MobilityLevel,
    ActivityClassifier,
    ActivityType,
    get_gait_analyzer,
    get_tug_handler,
    # Deep learning video classifier
    VideoClassifier,
    VideoClassificationResult,
    VideoActivityType,
    get_video_classifier,
    # Hybrid Fall Detector (3-Layer Ensemble)
    HybridFallDetector,
    HybridFallResult,
    FallType,
    DetectionSource,
    get_hybrid_fall_detector,
    # Live Fall Detector (for real-time streams)
    LiveFallDetector,
    LiveDetectionState,
    get_live_fall_detector,
)

router = APIRouter()

# Thread pool for MJPEG streaming - isolated from main event loop
mjpeg_thread_pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="mjpeg_worker")

# Thread pool for ML analysis - separate from streaming (more workers for multiple videos)
analysis_thread_pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="analysis_worker")

# Video files directory
VIDEO_DIR = Path(__file__).parent.parent / "media" / "simulation_footage" / "guardian"
PLACEHOLDER_VIDEO = VIDEO_DIR / "placeholder.mp4"

# Pre-initialized live detector for frame-by-frame analysis
_live_detector_instance: Optional[LiveFallDetector] = None
_models_initialized = False

# ============= Session-Based Stream Detection =============
# Each active camera/elderly gets their own LiveFallDetector with frame buffer

class StreamSession:
    """Manages a live detection session for one camera/elderly."""
    
    def __init__(self, session_id: str, elderly_id: Optional[str] = None):
        self.session_id = session_id
        self.elderly_id = elderly_id
        self.detector = LiveFallDetector(enable_dl=True, target_fps=5)  # 5 FPS from frontend
        self.created_at = time.time()
        self.last_frame_at = time.time()
        self.frame_count = 0
        self.last_result: Optional[HybridFallResult] = None
        logger.info(f"📹 Stream session created: {session_id} (elderly: {elderly_id})")
    
    def process_frame(self, frame: np.ndarray) -> HybridFallResult:
        """Process a frame and return detection result."""
        self.last_frame_at = time.time()
        self.frame_count += 1
        result = self.detector.process_frame(frame)
        self.last_result = result
        return result
    
    def reset(self):
        """Reset the session for a new stream."""
        self.detector.reset()
        self.frame_count = 0
        self.last_result = None
        logger.info(f"🔄 Stream session reset: {self.session_id}")
    
    def get_status(self) -> dict:
        """Get session status."""
        return {
            "session_id": self.session_id,
            "elderly_id": self.elderly_id,
            "frame_count": self.frame_count,
            "buffer_size": len(self.detector.frame_buffer),
            "buffer_full": self.detector.state.buffer_full,
            "last_frame_ago": time.time() - self.last_frame_at,
            "created_ago": time.time() - self.created_at,
            "last_result": self.last_result.to_dict() if self.last_result else None
        }


class StreamSessionManager:
    """Manages multiple live detection sessions."""
    
    SESSION_TIMEOUT = 300  # 5 minutes of inactivity
    MAX_SESSIONS = 10  # Maximum concurrent sessions
    
    def __init__(self):
        self._sessions: dict[str, StreamSession] = {}
        self._lock = threading.Lock()
    
    def get_or_create_session(self, session_id: str, elderly_id: Optional[str] = None) -> StreamSession:
        """Get existing session or create new one."""
        with self._lock:
            # Clean up stale sessions first
            self._cleanup_stale_sessions()
            
            if session_id not in self._sessions:
                if len(self._sessions) >= self.MAX_SESSIONS:
                    # Remove oldest session
                    oldest = min(self._sessions.values(), key=lambda s: s.last_frame_at)
                    logger.warning(f"⚠️ Max sessions reached, removing oldest: {oldest.session_id}")
                    del self._sessions[oldest.session_id]
                
                self._sessions[session_id] = StreamSession(session_id, elderly_id)
            
            return self._sessions[session_id]
    
    def get_session(self, session_id: str) -> Optional[StreamSession]:
        """Get existing session or None."""
        return self._sessions.get(session_id)
    
    def remove_session(self, session_id: str):
        """Remove a session."""
        with self._lock:
            if session_id in self._sessions:
                logger.info(f"🗑️ Stream session removed: {session_id}")
                del self._sessions[session_id]
    
    def _cleanup_stale_sessions(self):
        """Remove sessions that haven't received frames recently."""
        now = time.time()
        stale = [sid for sid, s in self._sessions.items() 
                 if now - s.last_frame_at > self.SESSION_TIMEOUT]
        for sid in stale:
            logger.info(f"⏰ Removing stale session: {sid}")
            del self._sessions[sid]
    
    def get_all_sessions(self) -> list[dict]:
        """Get status of all sessions."""
        return [s.get_status() for s in self._sessions.values()]


# Global session manager
_stream_session_manager = StreamSessionManager()

# Minimal valid MP4 bytes for fallback (tiny valid MP4 header)
BLANK_MP4_BYTES = bytes([
    0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70,
    0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
    0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
    0x6D, 0x70, 0x34, 0x31, 0x00, 0x00, 0x00, 0x08,
    0x6D, 0x6F, 0x6F, 0x76,
])


def _get_video_fallback() -> tuple:
    """Returns fallback video content when requested video is not found."""
    if PLACEHOLDER_VIDEO.exists():
        return PLACEHOLDER_VIDEO.read_bytes(), "video/mp4"
    logger.warning("No placeholder video found, returning blank MP4 frame")
    return BLANK_MP4_BYTES, "video/mp4"


def _check_video_exists(video_path: Path) -> bool:
    """Check if video file exists and is a valid file."""
    return video_path.exists() and video_path.is_file()


# Service instances (singleton pattern)
_gait_analyzer: Optional[GaitAnalyzer] = None
_tug_handler: Optional[TUGTestHandler] = None
_activity_classifier: Optional[ActivityClassifier] = None
_video_classifier: Optional[VideoClassifier] = None
_hybrid_fall_detector: Optional[HybridFallDetector] = None
_live_fall_detector: Optional[LiveFallDetector] = None


def get_services():
    """Get or initialize service instances."""
    global _gait_analyzer, _tug_handler, _activity_classifier, _video_classifier, _hybrid_fall_detector, _live_fall_detector
    if _gait_analyzer is None:
        _gait_analyzer = get_gait_analyzer()
    if _tug_handler is None:
        _tug_handler = get_tug_handler()
    if _activity_classifier is None:
        _activity_classifier = ActivityClassifier()
    if _video_classifier is None:
        _video_classifier = get_video_classifier()
    if _hybrid_fall_detector is None:
        _hybrid_fall_detector = get_hybrid_fall_detector(enable_dl=True)
    if _live_fall_detector is None:
        _live_fall_detector = get_live_fall_detector(enable_dl=True, target_fps=15)
    return _gait_analyzer, _tug_handler, _activity_classifier, _video_classifier, _hybrid_fall_detector, _live_fall_detector


def initialize_models_sync():
    """Initialize all ML models synchronously. Call this in a background thread."""
    global _models_initialized, _live_detector_instance, _detection_cache
    if _models_initialized:
        return
    
    logger.info("🚀 Pre-initializing ML models...")
    start = time.time()
    
    # Initialize all services
    _, _, _, _, hybrid_detector, live_detector = get_services()
    _live_detector_instance = live_detector
    
    # Force model loading
    if hybrid_detector.dl_detector:
        hybrid_detector.dl_detector._ensure_loaded()
    
    model_load_time = time.time() - start
    logger.info(f"✅ ML models loaded in {model_load_time:.2f}s")
    
    # Run warmup detection on a test video to verify everything works
    logger.info("🔥 Running warmup detection...")
    warmup_start = time.time()
    
    # Try to find a small test video
    test_videos = [
        VIDEO_DIR / "fall" / "fall-01-cam0_cropped.mp4",
        VIDEO_DIR / "adl" / "adl-01-cam0_cropped.mp4",
        VIDEO_DIR / "fall_indoor_1.mp4",
    ]
    
    test_video = None
    for path in test_videos:
        if path.exists():
            test_video = path
            break
    
    if test_video:
        try:
            logger.info(f"  📂 Test video: {test_video.name}")
            result = hybrid_detector.analyze_video_file(str(test_video), sample_frames=8)
            
            # Log warmup results
            logger.info(f"  ✅ Warmup detection complete in {time.time() - warmup_start:.2f}s")
            logger.info(f"  📊 Test Result: Fall={'YES' if result.is_fall else 'NO'}, Confidence={result.confidence*100:.1f}%")
            logger.info(f"  📈 Scores: Skeleton={result.skeleton_score*100:.1f}%, Motion={result.motion_score*100:.1f}%, DL={result.dl_score*100:.1f}%")
            
            # Cache the warmup result
            cache_key = f"{test_video.stem}_8"
            _detection_cache[cache_key] = {
                "video_id": test_video.stem,
                "warmup": True,
                "detection": result.to_dict(),
                "summary": {
                    "fall_detected": result.is_fall,
                    "confidence": round(result.confidence, 3),
                    "fall_type": result.fall_type.value,
                }
            }
        except Exception as e:
            logger.warning(f"  ⚠️ Warmup detection failed: {e}")
    else:
        logger.warning("  ⚠️ No test video found for warmup")
    
    _models_initialized = True
    total_time = time.time() - start
    logger.info(f"🎉 ML initialization complete! Total time: {total_time:.2f}s")


async def initialize_models_async():
    """Initialize models in background thread to not block startup."""
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(analysis_thread_pool, initialize_models_sync)


def get_live_detector() -> Optional[LiveFallDetector]:
    """Get the pre-initialized live detector instance."""
    global _live_detector_instance
    if _live_detector_instance is None:
        _, _, _, _, _, _live_detector_instance = get_services()
    return _live_detector_instance


# ============= Pydantic Models =============

class FallAlertRequest(BaseModel):
    elderly_id: str
    confidence: float
    fall_type: str  # forward, backward, sideways, collapse
    location: Optional[dict] = None  # {lat, lng}


class SOSRequest(BaseModel):
    elderly_id: str
    location: Optional[dict] = None
    message: Optional[str] = None


class GeofenceRequest(BaseModel):
    elderly_id: str
    name: str
    coordinates: List[dict]  # List of {lat, lng}
    radius: Optional[float] = None


class AlertAcknowledgeRequest(BaseModel):
    response_action: str
    notes: Optional[str] = None


class FrameAnalysisRequest(BaseModel):
    """Request for single-frame fall detection analysis."""
    frame_base64: str  # Base64-encoded JPEG/PNG frame
    elderly_id: Optional[str] = None  # Optional elderly identifier


# ============= Mock Data =============

ELDERLY_DB = {
    "elderly_1": {"name": "Margaret Johnson", "age": 72, "location": "Living Room", "status": "Active"},
    "elderly_2": {"name": "Robert Smith", "age": 68, "location": "Bedroom", "status": "Resting"},
}

ALERTS_DB = [
    {"id": "alert_1", "type": "fall", "severity": "critical", "title": "Fall Detected", "location": "Living Room", "time": "5 min ago", "resolved": False, "elderly_id": "elderly_1", "elderly_name": "Margaret Johnson"},
    {"id": "alert_2", "type": "inactivity", "severity": "warning", "title": "Unusual Inactivity", "location": "Bedroom", "time": "15 min ago", "resolved": False, "elderly_id": "elderly_1", "elderly_name": "Margaret Johnson"},
    {"id": "alert_3", "type": "medication", "severity": "info", "title": "Medication Reminder Sent", "location": "System", "time": "1 hour ago", "resolved": True, "elderly_id": "elderly_2", "elderly_name": "Robert Smith"},
    {"id": "alert_4", "type": "sos", "severity": "critical", "title": "SOS Button Pressed", "location": "Kitchen", "time": "2 hours ago", "resolved": True, "elderly_id": "elderly_1", "elderly_name": "Margaret Johnson"},
    {"id": "alert_5", "type": "geofence", "severity": "warning", "title": "Left Safe Zone", "location": "Front Door", "time": "Yesterday", "resolved": True, "elderly_id": "elderly_2", "elderly_name": "Robert Smith"},
]

ACTIVITIES_DB = [
    {"time": "8:45 AM", "event": "Woke up", "location": "Bedroom", "type": "routine"},
    {"time": "9:00 AM", "event": "Breakfast started", "location": "Kitchen", "type": "meal"},
    {"time": "9:30 AM", "event": "Medication taken", "location": "Kitchen", "type": "medication"},
    {"time": "10:15 AM", "event": "Watching TV", "location": "Living Room", "type": "leisure"},
    {"time": "11:00 AM", "event": "Phone call received", "location": "Living Room", "type": "communication"},
    {"time": "12:30 PM", "event": "Lunch started", "location": "Kitchen", "type": "meal"},
    {"time": "1:15 PM", "event": "Nap time", "location": "Bedroom", "type": "rest"},
    {"time": "3:00 PM", "event": "Woke from nap", "location": "Bedroom", "type": "routine"},
    {"time": "3:30 PM", "event": "Walking exercise", "location": "Living Room", "type": "exercise"},
    {"time": "4:00 PM", "event": "Snack time", "location": "Kitchen", "type": "meal"},
]

CAMERAS_DB = [
    {"id": "cam_1", "name": "Living Room", "location": "Main Floor", "status": "online", "video_file": "walking_normal_1.mp4", "scenario": "Normal Walking"},
    {"id": "cam_2", "name": "Bedroom", "location": "Upper Floor", "status": "online", "video_file": "sitting_resting_1.mp4", "scenario": "Sitting/Resting"},
    {"id": "cam_3", "name": "Kitchen", "location": "Main Floor", "status": "online", "video_file": "walking_slow_1.mp4", "scenario": "Slow Walking"},
    {"id": "cam_4", "name": "Hallway", "location": "Main Floor", "status": "online", "video_file": "gait_normal_1.mp4", "scenario": "Normal Gait"},
    {"id": "cam_5", "name": "Guest Room", "location": "Upper Floor", "status": "online", "video_file": "lying_down_1.mp4", "scenario": "Lying Down"},
    {"id": "cam_6", "name": "Study", "location": "Main Floor", "status": "online", "video_file": "standing_idle_1.mp4", "scenario": "Standing Idle"},
]

# Available video files for demo streaming
VIDEO_FILES = {
    "walking_normal_1": "walking_normal_1.mp4",
    "walking_normal_2": "walking_normal_2.mp4",
    "walking_slow_1": "walking_slow_1.mp4",
    "sitting_resting_1": "sitting_resting_1.mp4",
    "lying_down_1": "lying_down_1.mp4",
    "standing_idle_1": "standing_idle_1.mp4",
    "gait_normal_1": "gait_normal_1.mp4",
    "gait_abnormal_1": "gait_abnormal_1.mp4",
    "fall_indoor_1": "fall_indoor_1.mp4",
    "fall_outdoor_1": "fall_outdoor_1.mp4",
    # Training dataset videos for testing
    "fall-01-cam0": "fall/fall-01-cam0_cropped.mp4",
    "fall-02-cam0": "fall/fall-02-cam0_cropped.mp4",
    "fall-03-cam0": "fall/fall-03-cam0_cropped.mp4",
    "fall-04-cam0": "fall/fall-04-cam0_cropped.mp4",
    "fall-05-cam0": "fall/fall-05-cam0_cropped.mp4",
    "adl-01-cam0": "adl/adl-01-cam0_cropped.mp4",
    "adl-02-cam0": "adl/adl-02-cam0_cropped.mp4",
    "adl-03-cam0": "adl/adl-03-cam0_cropped.mp4",
    "adl-04-cam0": "adl/adl-04-cam0_cropped.mp4",
    "adl-05-cam0": "adl/adl-05-cam0_cropped.mp4",
}

# Cache for detection results (pre-recorded videos have stable results)
_detection_cache: dict = {}
_pending_detections: set = set()  # Track videos currently being analyzed


# ============= REST Endpoints =============

@router.get("/elderly/{elderly_id}/status")
async def get_elderly_status(elderly_id: str):
    """Get current status of elderly person."""
    elderly = ELDERLY_DB.get(elderly_id, ELDERLY_DB["elderly_1"])
    
    return {
        "elderly_id": elderly_id,
        "name": elderly["name"],
        "age": elderly["age"],
        "status": elderly["status"],
        "location": elderly["location"],
        "last_activity": random.choice(["Walking", "Sitting", "Standing", "Resting"]),
        "last_seen": f"{random.randint(1, 30)} min ago",
        "vitals": {
            "heart_rate": random.randint(60, 90),
            "activity_level": random.choice(["Low", "Moderate", "Active"])
        }
    }


@router.get("/elderly/list")
async def get_elderly_list(guardian_id: Optional[str] = None):
    """Get list of monitored elderly."""
    result = []
    for eid, elderly in ELDERLY_DB.items():
        result.append({
            "elderly_id": eid,
            **elderly,
            "last_seen": f"{random.randint(1, 30)} min ago"
        })
    return {"elderly": result, "total": len(result)}


@router.post("/fall-alert")
async def report_fall_alert(request: FallAlertRequest):
    """Report fall detection event."""
    alert_id = f"alert_{random.randint(100, 999)}"
    
    return {
        "status": "alert_created",
        "alert_id": alert_id,
        "elderly_id": request.elderly_id,
        "fall_type": request.fall_type,
        "confidence": request.confidence,
        "created_at": datetime.now().isoformat(),
        "notification_sent": True
    }


@router.post("/sos")
async def trigger_sos(request: SOSRequest):
    """Trigger SOS emergency."""
    return {
        "status": "sos_triggered",
        "elderly_id": request.elderly_id,
        "alert_id": f"sos_{random.randint(100, 999)}",
        "emergency_contacts_notified": 3,
        "created_at": datetime.now().isoformat()
    }


@router.get("/alerts/{guardian_id}")
async def get_alerts(guardian_id: str, status: Optional[str] = None, limit: int = 20):
    """Get all alerts for a guardian."""
    alerts = ALERTS_DB.copy()
    
    if status == "active":
        alerts = [a for a in alerts if not a["resolved"]]
    elif status == "resolved":
        alerts = [a for a in alerts if a["resolved"]]
    
    active_count = len([a for a in ALERTS_DB if not a["resolved"]])
    
    return {
        "guardian_id": guardian_id,
        "alerts": alerts[:limit],
        "total": len(alerts),
        "active_count": active_count
    }


@router.put("/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(alert_id: str, request: AlertAcknowledgeRequest):
    """Acknowledge an alert."""
    return {
        "alert_id": alert_id,
        "status": "acknowledged",
        "response_action": request.response_action,
        "acknowledged_at": datetime.now().isoformat()
    }


@router.post("/geofence")
async def create_geofence(request: GeofenceRequest):
    """Create geofence zone."""
    return {
        "status": "created",
        "geofence_id": f"geo_{random.randint(100, 999)}",
        "elderly_id": request.elderly_id,
        "name": request.name,
        "created_at": datetime.now().isoformat()
    }


@router.get("/geofence/{elderly_id}")
async def get_geofences(elderly_id: str):
    """Get user's geofences."""
    return {
        "elderly_id": elderly_id,
        "geofences": [
            {"id": "geo_1", "name": "Home", "type": "safe_zone", "radius": 50, "active": True},
            {"id": "geo_2", "name": "Park", "type": "allowed_zone", "radius": 200, "active": True},
        ]
    }


@router.get("/activity-log/{elderly_id}")
async def get_activity_log(elderly_id: str, date: Optional[str] = None, limit: int = 20):
    """Get activity history."""
    return {
        "elderly_id": elderly_id,
        "date": date or datetime.now().strftime("%Y-%m-%d"),
        "activities": ACTIVITIES_DB[:limit],
        "summary": {
            "active_hours": 8.5,
            "rest_hours": 3.2,
            "total_events": len(ACTIVITIES_DB)
        }
    }


@router.get("/cameras")
async def get_cameras(guardian_id: Optional[str] = None):
    """Get available camera feeds (pre-recorded videos for demo)."""
    return {
        "cameras": CAMERAS_DB,
        "total": len(CAMERAS_DB),
        "online": len([c for c in CAMERAS_DB if c["status"] == "online"]),
        "note": "Using pre-recorded videos for demonstration"
    }


@router.get("/cameras/{camera_id}/stream-url")
async def get_stream_url(camera_id: str):
    """Get video stream URL for camera (pre-recorded video path for demo)."""
    camera = next((c for c in CAMERAS_DB if c["id"] == camera_id), None)
    
    if not camera:
        return {"error": "Camera not found"}
    
    return {
        "camera_id": camera_id,
        "name": camera["name"],
        "status": camera["status"],
        "video_file": camera["video_file"],
        "stream_type": "pre-recorded",
        "note": "Video file to be played as simulated live feed"
    }


# ============= AI Video Classification Endpoints =============

@router.post("/classify-video/{video_id}")
async def classify_video(video_id: str):
    """
    Classify a video using the trained deep learning model.
    
    Uses EfficientNetV2-S + LSTM model trained on fall/gait dataset.
    Returns activity classification and fall/gait abnormality detection.
    """
    if video_id not in VIDEO_FILES:
        raise HTTPException(status_code=404, detail=f"Video '{video_id}' not found")
    
    video_path = VIDEO_DIR / VIDEO_FILES[video_id]
    
    if not video_path.exists():
        raise HTTPException(status_code=404, detail=f"Video file not found on server")
    
    # Get video classifier
    _, _, _, video_classifier, _, _ = get_services()
    
    # Ensure model is loaded
    if not video_classifier.is_loaded:
        if not video_classifier.load_model():
            raise HTTPException(status_code=500, detail="Failed to load video classification model")
    
    # Classify the video
    result = video_classifier.classify_video_file(str(video_path))
    
    return {
        "video_id": video_id,
        "classification": result.to_dict(),
        "alerts": {
            "fall_detected": result.is_fall_detected,
            "gait_abnormal": result.is_gait_abnormal,
            "requires_attention": result.is_fall_detected or result.is_gait_abnormal
        }
    }


@router.get("/classifier/status")
async def get_classifier_status():
    """Get the status of the video classification model."""
    _, _, _, video_classifier, _, _ = get_services()
    
    return {
        "model_loaded": video_classifier.is_loaded,
        "model_path": str(video_classifier.model_path),
        "class_mapping": video_classifier.class_mapping if video_classifier.is_loaded else None,
        "num_classes": len(video_classifier.class_mapping) if video_classifier.is_loaded else 0
    }


@router.post("/classifier/load")
async def load_classifier():
    """Explicitly load the video classification model."""
    _, _, _, video_classifier, _, _ = get_services()
    
    success = video_classifier.load_model()
    
    if success:
        return {
            "status": "success",
            "message": "Model loaded successfully",
            "model_path": str(video_classifier.model_path),
            "classes": video_classifier.class_mapping
        }
    else:
        raise HTTPException(status_code=500, detail="Failed to load model")


# ============= Hybrid Fall Detection Endpoints (3-Layer Ensemble) =============

@router.post("/hybrid-detect/init")
async def init_hybrid_detector():
    """
    Initialize the hybrid fall detection models.
    
    Call this on app startup or before first detection to pre-load models.
    Returns immediately after triggering background initialization.
    """
    global _models_initialized
    
    if _models_initialized:
        return {"status": "ready", "message": "Models already initialized"}
    
    # Start initialization in background
    asyncio.create_task(initialize_models_async())
    
    return {"status": "initializing", "message": "Model initialization started in background"}


@router.post("/hybrid-detect/frame")
async def analyze_frame(request: FrameAnalysisRequest):
    """
    Analyze a single frame for fall detection (EXPERIMENTAL).
    
    IMPORTANT LIMITATIONS:
    - Uses a SHARED LiveFallDetector instance with internal frame buffer
    - First ~16 frames are needed to fill buffer before DL layer activates
    - Only skeleton + motion scores are reliable immediately
    - NOT suitable for multi-user production use (need session-based buffers)
    
    For demo with pre-recorded videos, use /hybrid-detect/{video_id} instead!
    That endpoint analyzes the full video file with proper temporal context.
    
    Request body:
        frame_base64: Base64-encoded JPEG or PNG image
        elderly_id: Optional identifier for tracking
    
    Returns:
        Quick fall detection result using skeleton + motion layers,
        with DL layer activating after buffer fills (~16 frames).
    """
    try:
        # Decode base64 frame
        frame_data = base64.b64decode(request.frame_base64)
        nparr = np.frombuffer(frame_data, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if frame is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        
        # Get live detector
        live_detector = get_live_detector()
        
        if live_detector is None:
            raise HTTPException(status_code=503, detail="Live detector not initialized. Call /hybrid-detect/init first.")
        
        # Process frame (this is fast - designed for real-time)
        start_time = time.time()
        result = live_detector.process_frame(frame)
        processing_time = (time.time() - start_time) * 1000
        
        return {
            "success": True,
            "elderly_id": request.elderly_id,
            "detection": {
                "fall_detected": result.is_fall,
                "confidence": round(result.confidence, 3),
                "fall_type": result.fall_type.value,
                "detection_source": result.detection_source.value,
            },
            "scores": {
                "skeleton": round(result.skeleton_score, 3),
                "motion": round(result.motion_score, 3),
                "deep_learning": round(result.dl_score, 3),
            },
            "processing_time_ms": round(processing_time, 1),
            "state": {
                "consecutive_falls": live_detector.state.consecutive_fall_frames,
                "confirmed": live_detector.state.fall_confirmed,
            }
        }
        
    except Exception as e:
        logger.error(f"Frame analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============= LIVE STREAMING DETECTION (Session-Based) =============
# This is the production-ready approach for real camera feeds

class StreamFrameRequest(BaseModel):
    """Request model for streaming frame analysis."""
    frame_base64: str
    elderly_id: Optional[str] = None
    timestamp: Optional[float] = None  # Client-side timestamp


@router.post("/stream/{session_id}/frame")
async def stream_analyze_frame(session_id: str, request: StreamFrameRequest):
    """
    Process a frame from a live video stream.
    
    This is the PRODUCTION-READY endpoint for real-time fall detection.
    Each session maintains its own sliding window buffer of frames.
    
    How it works:
    1. Frontend captures frames from video stream (MJPEG or webcam)
    2. Frontend sends 1 frame per second to this endpoint
    3. Backend adds frame to session's rolling buffer (32 frames)
    4. Backend runs 3-layer detection when buffer has enough frames
    5. Returns detection result immediately
    
    Args:
        session_id: Unique session ID (e.g., "camera_elderly123" or video_id)
        request.frame_base64: Base64-encoded JPEG image
        request.elderly_id: Optional elderly person ID for tracking
        request.timestamp: Optional client-side timestamp
    
    Returns:
        Detection result with fall status, confidence, and layer scores
    """
    try:
        # Decode base64 frame
        frame_data = base64.b64decode(request.frame_base64)
        nparr = np.frombuffer(frame_data, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if frame is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        
        # Get or create session
        session = _stream_session_manager.get_or_create_session(
            session_id, 
            request.elderly_id
        )
        
        # Process frame in thread pool to not block
        def process():
            return session.process_frame(frame)
        
        loop = asyncio.get_event_loop()
        start_time = time.time()
        result = await loop.run_in_executor(analysis_thread_pool, process)
        processing_time = (time.time() - start_time) * 1000
        
        # Log processing
        if session.frame_count % 10 == 1 or result.is_fall:  
            logger.info(f"📊 Frame #{session.frame_count} [{session_id}] "
                        f"S={result.skeleton_score:.2f} M={result.motion_score:.2f} "
                        f"DL={result.dl_score:.2f} ({processing_time:.0f}ms)")
        if result.is_fall:
            logger.warning(f"🚨 FALL DETECTED in session {session_id}! Confidence: {result.confidence*100:.1f}%")
        
        return {
            "success": True,
            "session_id": session_id,
            "elderly_id": request.elderly_id,
            "frame_number": session.frame_count,
            "buffer_size": len(session.detector.frame_buffer),
            "buffer_ready": session.detector.state.buffer_full,
            "detection": {
                "fall_detected": result.is_fall,
                "confidence": round(result.confidence, 3),
                "fall_type": result.fall_type.value,
                "detection_source": result.detection_source.value,
            },
            "scores": {
                "skeleton": round(result.skeleton_score, 3),
                "motion": round(result.motion_score, 3),
                "deep_learning": round(result.dl_score, 3),
            },
            "processing_time_ms": round(processing_time, 1),
            "state": {
                "consecutive_falls": session.detector.state.consecutive_fall_frames,
                "fall_confirmed": session.detector.state.fall_confirmed,
            }
        }
        
    except Exception as e:
        logger.error(f"Stream frame analysis error: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stream/{session_id}/start")
async def stream_start_session(session_id: str, elderly_id: Optional[str] = None):
    """
    Start or reset a streaming detection session.
    
    Call this when starting to watch a camera feed.
    Creates a fresh session with empty frame buffer.
    """
    session = _stream_session_manager.get_or_create_session(session_id, elderly_id)
    session.reset()
    
    logger.info(f"")
    logger.info(f"{'='*60}")
    logger.info(f"🎥 LIVE STREAM SESSION STARTED")
    logger.info(f"{'='*60}")
    logger.info(f"  📹 Session ID: {session_id}")
    logger.info(f"  👴 Elderly ID: {elderly_id or 'N/A'}")
    logger.info(f"  🧠 3-Layer Detection: ACTIVE")
    logger.info(f"  📊 Buffer size: 32 frames (sliding window)")
    logger.info(f"  ⚡ DL runs every 16 frames")
    logger.info(f"{'='*60}")
    
    return {
        "success": True,
        "session_id": session_id,
        "elderly_id": elderly_id,
        "message": "Stream session started - send frames to /stream/{session_id}/frame",
        "config": {
            "buffer_size": session.detector.BUFFER_SIZE,
            "dl_interval": session.detector.DL_ANALYSIS_INTERVAL,
            "recommended_fps": 1,  # 1 frame per second
        }
    }


@router.post("/stream/{session_id}/stop")
async def stream_stop_session(session_id: str):
    """
    Stop a streaming detection session.
    
    Call this when stopping the camera feed.
    Cleans up resources and removes session.
    """
    session = _stream_session_manager.get_session(session_id)
    
    if session:
        stats = {
            "session_id": session_id,
            "total_frames": session.frame_count,
            "duration_seconds": round(time.time() - session.created_at, 1),
            "last_result": session.last_result.to_dict() if session.last_result else None
        }
        _stream_session_manager.remove_session(session_id)
        logger.info(f"🛑 Stream session stopped: {session_id} ({session.frame_count} frames processed)")
        return {"success": True, **stats}
    else:
        return {"success": False, "message": f"Session {session_id} not found"}


@router.get("/stream/{session_id}/status")
async def stream_session_status(session_id: str):
    """Get the status of a streaming session."""
    session = _stream_session_manager.get_session(session_id)
    
    if session:
        return {"success": True, **session.get_status()}
    else:
        raise HTTPException(status_code=404, detail=f"Session {session_id} not found")


@router.get("/stream/sessions")
async def stream_list_sessions():
    """List all active streaming sessions."""
    return {
        "sessions": _stream_session_manager.get_all_sessions(),
        "count": len(_stream_session_manager._sessions)
    }


@router.post("/hybrid-detect/{video_id}")
async def hybrid_fall_detect(video_id: str, sample_frames: int = 16, force_reanalyze: bool = False):
    """
    Detect falls using the 3-layer hybrid system.
    
    Combines:
    - Layer 1: Skeleton-based geometric analysis (MediaPipe)
    - Layer 2: Motion-based frame analysis (frame difference)
    - Layer 3: Deep learning classification (EfficientNet+LSTM)
    
    Args:
        video_id: ID of the video to analyze
        sample_frames: Number of frames to sample (default 16, use less for faster results)
        force_reanalyze: If True, skip cache and re-analyze
    
    Returns detailed detection results with scores from each layer.
    
    Note: Results are cached for pre-recorded videos (same video = same result).
    """
    global _detection_cache, _pending_detections
    
    cache_key = f"{video_id}_{sample_frames}"
    
    # Return cached result if available (pre-recorded videos have stable results)
    if not force_reanalyze and cache_key in _detection_cache:
        logger.info(f"📦 Using cached detection result for {video_id}")
        return _detection_cache[cache_key]
    
    # Skip if detection is already pending for this video
    if cache_key in _pending_detections:
        logger.info(f"⏳ Detection already in progress for {video_id}, skipping duplicate request")
        return {"status": "pending", "message": f"Detection in progress for {video_id}"}
    
    # Check for video in multiple locations
    video_path = None
    
    # Check VIDEO_FILES mapping first
    if video_id in VIDEO_FILES:
        video_path = VIDEO_DIR / VIDEO_FILES[video_id]
    else:
        # Check subfolders (fall/, adl/, good_gait/, etc.)
        for subfolder in ["fall", "adl", "good_gait", "arthritis_gait", "tug"]:
            potential_path = VIDEO_DIR / subfolder / f"{video_id}.mp4"
            if potential_path.exists():
                video_path = potential_path
                break
        
        # Check root folder with .mp4 extension
        if not video_path:
            potential_path = VIDEO_DIR / f"{video_id}.mp4"
            if potential_path.exists():
                video_path = potential_path
    
    if not video_path or not video_path.exists():
        raise HTTPException(status_code=404, detail=f"Video '{video_id}' not found")
    
    # Mark as pending
    _pending_detections.add(cache_key)
    
    logger.info(f"")
    logger.info(f"{'='*60}")
    logger.info(f"🔬 HYBRID FALL DETECTION - {video_id}")
    logger.info(f"{'='*60}")
    logger.info(f"  📂 Video: {video_path.name}")
    logger.info(f"  🎞️  Sample frames: {sample_frames}")
    
    try:
        # Get hybrid fall detector
        _, _, _, _, hybrid_detector, _ = get_services()
        
        # Run analysis in background thread to not block event loop
        def analyze():
            start = time.time()
            logger.info(f"  🧠 Running 3-layer analysis...")
            result = hybrid_detector.analyze_video_file(str(video_path), sample_frames=sample_frames)
            elapsed = time.time() - start
            
            # Log detailed results
            logger.info(f"  ✅ Analysis complete in {elapsed:.2f}s")
            logger.info(f"  📊 RESULTS:")
            logger.info(f"     • Fall Detected: {'🚨 YES' if result.is_fall else '✅ NO'}")
            logger.info(f"     • Confidence: {result.confidence*100:.1f}%")
            logger.info(f"     • Fall Type: {result.fall_type.value}")
            logger.info(f"     • Detection Source: {result.detection_source.value}")
            logger.info(f"  📈 LAYER SCORES:")
            logger.info(f"     • Skeleton: {result.skeleton_score*100:.1f}%")
            logger.info(f"     • Motion: {result.motion_score*100:.1f}%")
            logger.info(f"     • Deep Learning: {result.dl_score*100:.1f}%")
            logger.info(f"{'='*60}")
            
            return result
        
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(analysis_thread_pool, analyze)
        
        response = {
            "video_id": video_id,
            "video_path": str(video_path.name),
            "detection": result.to_dict(),
            "summary": {
                "fall_detected": result.is_fall,
                "confidence": round(result.confidence, 3),
                "fall_type": result.fall_type.value,
                "detection_method": result.detection_source.value,
                "requires_attention": result.is_fall
            },
            "scores": {
                "skeleton": round(result.skeleton_score, 3),
                "motion": round(result.motion_score, 3),
                "deep_learning": round(result.dl_score, 3),
            }
        }
        
        # Cache the result
        _detection_cache[cache_key] = response
        
        return response
        
    except Exception as e:
        logger.error(f"  ❌ Detection failed: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Remove from pending
        _pending_detections.discard(cache_key)


@router.get("/hybrid-detect/status")
async def hybrid_detector_status():
    """Get the status of the hybrid fall detection system."""
    _, _, _, _, hybrid_detector, _ = get_services()
    
    return {
        "system": "Hybrid Fall Detection (3-Layer Ensemble)",
        "layers": {
            "skeleton": {
                "name": "Skeleton-Based Detector",
                "technology": "MediaPipe Pose",
                "status": "active" if hybrid_detector.pose_detector else "unavailable",
                "weight": hybrid_detector.SKELETON_WEIGHT
            },
            "motion": {
                "name": "Motion-Based Detector",
                "technology": "Frame Difference Analysis",
                "status": "active",
                "weight": hybrid_detector.MOTION_WEIGHT
            },
            "deep_learning": {
                "name": "Deep Learning Detector",
                "technology": "EfficientNet+LSTM",
                "status": "active" if hybrid_detector.enable_dl else "disabled",
                "weight": hybrid_detector.DL_WEIGHT
            }
        },
        "thresholds": {
            "skeleton_high": hybrid_detector.SKELETON_HIGH_CONFIDENCE,
            "motion_high": hybrid_detector.MOTION_HIGH_CONFIDENCE,
            "dl_high": hybrid_detector.DL_HIGH_CONFIDENCE,
            "weighted_threshold": hybrid_detector.WEIGHTED_THRESHOLD
        },
        "cache": {
            "cached_videos": len(_detection_cache),
            "pending_detections": len(_pending_detections),
            "models_initialized": _models_initialized
        }
    }


@router.get("/hybrid-detect/cache")
async def get_detection_cache():
    """Get cached detection results."""
    return {
        "cached_count": len(_detection_cache),
        "pending_count": len(_pending_detections),
        "cached_videos": list(_detection_cache.keys()),
        "pending_videos": list(_pending_detections)
    }


@router.post("/hybrid-detect/cache/clear")
async def clear_detection_cache():
    """Clear the detection cache."""
    global _detection_cache
    count = len(_detection_cache)
    _detection_cache = {}
    logger.info(f"🗑️ Detection cache cleared ({count} entries)")
    return {"cleared": count, "message": "Detection cache cleared"}


@router.post("/hybrid-detect/batch")
async def hybrid_batch_detect(video_ids: List[str]):
    """
    Run hybrid fall detection on multiple videos.
    
    Useful for testing accuracy across different video types.
    """
    _, _, _, _, hybrid_detector, _ = get_services()
    
    results = []
    for video_id in video_ids:
        # Find video path
        video_path = None
        
        if video_id in VIDEO_FILES:
            video_path = VIDEO_DIR / VIDEO_FILES[video_id]
        else:
            for subfolder in ["fall", "adl", "good_gait", "arthritis_gait", "tug"]:
                potential_path = VIDEO_DIR / subfolder / f"{video_id}.mp4"
                if potential_path.exists():
                    video_path = potential_path
                    break
        
        if video_path and video_path.exists():
            result = hybrid_detector.analyze_video_file(str(video_path))
            results.append({
                "video_id": video_id,
                "is_fall": result.is_fall,
                "confidence": round(result.confidence, 3),
                "detection_source": result.detection_source.value,
                "scores": {
                    "skeleton": round(result.skeleton_score, 3),
                    "motion": round(result.motion_score, 3),
                    "dl": round(result.dl_score, 3)
                }
            })
        else:
            results.append({
                "video_id": video_id,
                "error": "Video not found"
            })
    
    # Calculate summary statistics
    detected = [r for r in results if r.get("is_fall", False)]
    
    return {
        "results": results,
        "summary": {
            "total_videos": len(results),
            "falls_detected": len(detected),
            "detection_rate": len(detected) / len(results) if results else 0
        }
    }


# ============= Live Fall Detection Endpoints =============

class LiveFrameRequest(BaseModel):
    """Request model for live frame processing."""
    frame_base64: str  # Base64 encoded JPEG frame
    elderly_id: str
    session_id: Optional[str] = None  # To maintain state across frames


# Store live detector sessions per elderly
_live_sessions: dict = {}


@router.post("/live-detect/frame")
async def process_live_frame(request: LiveFrameRequest):
    """
    Process a single frame from a live camera stream.
    
    This endpoint is designed for mobile apps that capture camera frames
    and send them for analysis. The detector maintains state across
    frames for the same session/elderly to enable proper fall detection.
    
    Returns:
        Detection result including fall status, confidence, and layer scores.
    """
    global _live_sessions
    
    try:
        # Decode base64 frame
        frame_bytes = base64.b64decode(request.frame_base64)
        nparr = np.frombuffer(frame_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if frame is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        
        # Get or create session detector
        session_key = request.session_id or request.elderly_id
        if session_key not in _live_sessions:
            _live_sessions[session_key] = get_live_fall_detector(enable_dl=True, target_fps=15)
            _live_sessions[session_key].reset()
        
        live_detector = _live_sessions[session_key]
        
        # Process frame
        result = live_detector.process_frame(frame)
        
        return {
            "success": True,
            "elderly_id": request.elderly_id,
            "session_id": session_key,
            "detection": {
                "is_fall": result.is_fall,
                "fall_confirmed": live_detector.state.fall_confirmed,
                "confidence": round(result.confidence, 3),
                "fall_type": result.fall_type.value,
                "detection_source": result.detection_source.value,
                "reason": result.detection_reason,
                "should_alert": live_detector.should_send_alert(),
            },
            "layer_scores": {
                "skeleton": round(result.skeleton_score, 3),
                "motion": round(result.motion_score, 3),
                "deep_learning": round(result.dl_score, 3)
            },
            "state": {
                "frame_count": live_detector.state.frame_count,
                "consecutive_fall_frames": live_detector.state.consecutive_fall_frames,
                "buffer_full": live_detector.state.buffer_full,
            },
            "processing_time_ms": round(result.processing_time_ms, 2)
        }
        
    except Exception as e:
        logger.error(f"Live frame processing error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/live-detect/reset/{session_id}")
async def reset_live_session(session_id: str):
    """Reset a live detection session."""
    global _live_sessions
    
    if session_id in _live_sessions:
        _live_sessions[session_id].reset()
        return {"success": True, "message": f"Session {session_id} reset"}
    
    return {"success": False, "message": "Session not found"}


@router.get("/live-detect/sessions")
async def list_live_sessions():
    """List all active live detection sessions."""
    global _live_sessions
    
    sessions = []
    for session_id, detector in _live_sessions.items():
        sessions.append({
            "session_id": session_id,
            "frame_count": detector.state.frame_count,
            "fall_confirmed": detector.state.fall_confirmed,
            "avg_processing_ms": round(detector.get_avg_processing_time(), 2),
            "realtime_capable": detector.can_process_realtime()
        })
    
    return {
        "active_sessions": len(sessions),
        "sessions": sessions
    }


@router.delete("/live-detect/sessions/{session_id}")
async def delete_live_session(session_id: str):
    """Delete a live detection session and release resources."""
    global _live_sessions
    
    if session_id in _live_sessions:
        _live_sessions[session_id].cleanup()
        del _live_sessions[session_id]
        return {"success": True, "message": f"Session {session_id} deleted"}
    
    return {"success": False, "message": "Session not found"}


@router.get("/test-videos")
async def list_test_videos():
    """List all available test videos organized by category."""
    categories = {}
    
    # Check subfolders
    for subfolder in ["fall", "adl", "good_gait", "arthritis_gait", "tug"]:
        folder_path = VIDEO_DIR / subfolder
        if folder_path.exists():
            videos = list(folder_path.glob("*.mp4"))
            categories[subfolder] = {
                "count": len(videos),
                "videos": [v.stem for v in videos[:10]]  # First 10
            }
    
    # Check root folder
    root_videos = list(VIDEO_DIR.glob("*.mp4"))
    if root_videos:
        categories["root"] = {
            "count": len(root_videos),
            "videos": [v.stem for v in root_videos]
        }
    
    return {
        "categories": categories,
        "total_videos": sum(c["count"] for c in categories.values())
    }


# ============= Video Streaming Endpoints =============

@router.get("/videos")
async def list_videos():
    """List all available demo videos for CCTV simulation."""
    logger.info(f"📋 GET /videos - Listing all demo videos")
    logger.info(f"  📁 Video directory: {VIDEO_DIR}")
    logger.info(f"  📁 Directory exists: {VIDEO_DIR.exists()}")
    
    videos = []
    for video_id, filename in VIDEO_FILES.items():
        video_path = VIDEO_DIR / filename
        exists = video_path.exists()
        if exists:
            size_mb = video_path.stat().st_size / (1024 * 1024)
            logger.debug(f"  ✅ {video_id}: {filename} ({size_mb:.2f} MB)")
        else:
            logger.warning(f"  ❌ {video_id}: {filename} (NOT FOUND)")
        videos.append({
            "id": video_id,
            "filename": filename,
            "available": exists,
            "url": f"/api/guardian/video/{video_id}" if exists else None
        })
    
    available_count = len([v for v in videos if v["available"]])
    logger.info(f"  📊 Total: {len(videos)}, Available: {available_count}")
    
    return {
        "videos": videos,
        "total": len(videos),
        "available": available_count,
        "video_dir": str(VIDEO_DIR)
    }


def generate_mjpeg_frames(video_path: str) -> Generator[bytes, None, None]:
    """
    Generator function that yields MJPEG frames from a video file.
    Runs in a separate worker thread to avoid blocking the main event loop.
    """
    cap = None
    try:
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            logger.error(f"Cannot open video: {video_path}")
            return
        
        logger.info(f"🎬 MJPEG stream started for: {video_path}")
        frame_count = 0
        
        while True:
            ret, frame = cap.read()
            
            # Loop video when it ends
            if not ret:
                cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                logger.debug(f"🔄 Video looped after {frame_count} frames")
                frame_count = 0
                continue
            
            frame_count += 1
            
            # Resize frame to save bandwidth (640x480)
            frame = cv2.resize(frame, (640, 480))
            
            # Encode frame to JPEG
            ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            
            if not ret:
                continue
            
            frame_bytes = buffer.tobytes()
            
            # Yield frame in multipart format
            yield (
                b'--frame\r\n'
                b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n'
            )
            
            # Control frame rate (~20 FPS) - prevents CPU overload
            time.sleep(0.05)
            
    except GeneratorExit:
        logger.info(f"🛑 MJPEG stream closed by client")
    except Exception as e:
        logger.error(f"[MJPEG Stream Error] {e}")
    finally:
        if cap is not None:
            cap.release()
            logger.info(f"🎬 MJPEG stream ended, video released")


async def async_mjpeg_generator(video_path: str):
    """
    Async wrapper that runs the blocking MJPEG generator in a thread pool.
    This prevents blocking the main asyncio event loop.
    """
    loop = asyncio.get_event_loop()
    
    # Create a queue for frame communication between threads
    frame_queue = asyncio.Queue(maxsize=5)
    stop_event = threading.Event()
    
    def producer():
        """Runs in worker thread - produces frames"""
        try:
            for frame in generate_mjpeg_frames(video_path):
                if stop_event.is_set():
                    break
                # Use thread-safe way to put frames
                try:
                    asyncio.run_coroutine_threadsafe(
                        frame_queue.put(frame), loop
                    ).result(timeout=1.0)
                except Exception:
                    break
        except Exception as e:
            logger.error(f"[Producer Error] {e}")
        finally:
            asyncio.run_coroutine_threadsafe(
                frame_queue.put(None), loop  # Signal end
            )
    
    # Start producer in thread pool
    future = mjpeg_thread_pool.submit(producer)
    
    try:
        while True:
            frame = await frame_queue.get()
            if frame is None:
                break
            yield frame
    except asyncio.CancelledError:
        logger.info("MJPEG stream cancelled")
    finally:
        stop_event.set()
        future.cancel()


@router.get("/video/{video_id}")
async def get_video(video_id: str):
    """
    Stream a pre-recorded video as MJPEG for live CCTV simulation.
    Uses worker thread pool to prevent blocking other API endpoints.
    
    Args:
        video_id: The ID of the video to stream
    """
    logger.info(f"")
    logger.info(f"{'='*60}")
    logger.info(f"🎥 MJPEG STREAM REQUEST")
    logger.info(f"{'='*60}")
    logger.info(f"  🎬 Video ID: {video_id}")
    
    if video_id not in VIDEO_FILES:
        logger.warning(f"  ❌ Video ID not in catalog: {video_id}")
        logger.debug(f"  📁 Available videos: {list(VIDEO_FILES.keys())}")
        raise HTTPException(status_code=404, detail=f"Video '{video_id}' not found in catalog")
    
    video_path = VIDEO_DIR / VIDEO_FILES[video_id]
    logger.info(f"  📂 Full path: {video_path}")
    
    if not _check_video_exists(video_path):
        logger.error(f"  ❌ Video file not found on disk: {video_path}")
        raise HTTPException(status_code=404, detail=f"Video file not found: {video_path}")
    
    file_size = video_path.stat().st_size / (1024 * 1024)  # MB
    logger.info(f"  ✅ File exists ({file_size:.2f} MB)")
    logger.info(f"  📤 Starting MJPEG stream...")
    logger.info(f"{'='*60}")
    
    return StreamingResponse(
        async_mjpeg_generator(str(video_path)),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
        }
    )


@router.get("/video/{video_id}/info")
async def get_video_info(video_id: str):
    """Get video metadata and associated scenario."""
    if video_id not in VIDEO_FILES:
        raise HTTPException(status_code=404, detail=f"Video '{video_id}' not found")
    
    video_path = VIDEO_DIR / VIDEO_FILES[video_id]
    
    if not video_path.exists():
        raise HTTPException(status_code=404, detail=f"Video file not found on server")
    
    # Get video info using OpenCV
    try:
        cap = cv2.VideoCapture(str(video_path))
        fps = cap.get(cv2.CAP_PROP_FPS)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        duration = frame_count / fps if fps > 0 else 0
        cap.release()
    except Exception:
        fps, frame_count, width, height, duration = 30, 0, 0, 0, 0
    
    # Determine scenario from filename
    scenario = "Unknown"
    if "fall" in video_id:
        scenario = "Fall Detection Demo"
    elif "gait_normal" in video_id:
        scenario = "Normal Gait"
    elif "gait_abnormal" in video_id:
        scenario = "Abnormal Gait / Fall Risk"
    elif "walking_normal" in video_id:
        scenario = "Normal Walking"
    elif "walking_slow" in video_id:
        scenario = "Slow Walking"
    elif "sitting" in video_id:
        scenario = "Sitting/Resting"
    elif "lying" in video_id:
        scenario = "Lying Down"
    elif "standing" in video_id:
        scenario = "Standing Idle"
    
    return {
        "video_id": video_id,
        "filename": VIDEO_FILES[video_id],
        "scenario": scenario,
        "stream_url": f"/guardian/video/{video_id}",
        "metadata": {
            "fps": fps,
            "frame_count": frame_count,
            "width": width,
            "height": height,
            "duration_seconds": round(duration, 2)
        }
    }


# ============= Gait Analysis Endpoints =============

@router.post("/analyze-gait")
async def analyze_gait_video(video: UploadFile = File(...)):
    """
    Analyze gait from uploaded video for fall risk assessment.
    
    Uses MediaPipe pose estimation and calculates:
    - Stride length, cadence, gait speed
    - Symmetry and variability metrics
    - Fall risk score and pattern classification
    """
    gait_analyzer, _, _, _, _, _ = get_services()
    
    # Save uploaded video temporarily
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
        content = await video.read()
        tmp.write(content)
        tmp_path = tmp.name
    
    try:
        # Process video with OpenCV and gait analyzer
        cap = cv2.VideoCapture(tmp_path)
        frame_count = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            
            # Process frame (simulated pose landmarks for now)
            # In production, this would use MediaPipe
            frame_count += 1
            
            # Add mock foot positions for gait analysis
            if frame_count % 5 == 0:  # Every 5 frames
                mock_left_foot = {"x": 0.4 + random.uniform(-0.05, 0.05), "y": 0.9, "z": 0}
                mock_right_foot = {"x": 0.6 + random.uniform(-0.05, 0.05), "y": 0.9, "z": 0}
                gait_analyzer.add_foot_position(mock_left_foot, mock_right_foot)
        
        cap.release()
        
        # Get gait analysis results
        result = gait_analyzer.analyze()
        gait_analyzer.reset()  # Reset for next analysis
        
    finally:
        os.unlink(tmp_path)
    
    return {
        "status": "completed",
        "frames_processed": frame_count,
        "metrics": result.metrics.to_dict() if result else None,
        "gait_pattern": result.gait_pattern.value if result else "unknown",
        "fall_risk": {
            "level": result.fall_risk_level.value if result else "unknown",
            "score": round(result.fall_risk_score, 1) if result else 0,
            "factors": result.risk_factors if result else []
        },
        "recommendations": result.recommendations if result else []
    }


@router.post("/tug-test")
async def process_tug_test(video: UploadFile = File(...)):
    """
    Process Timed Up and Go (TUG) test video.
    
    Detects 5 phases:
    1. Sit to Stand
    2. Walk Out (3 meters)
    3. Turn Around
    4. Walk Back
    5. Turn and Sit
    
    Returns mobility assessment and fall risk.
    """
    _, tug_handler, _, _, _, _ = get_services()
    
    # Save uploaded video temporarily
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
        content = await video.read()
        tmp.write(content)
        tmp_path = tmp.name
    
    try:
        # Start TUG test session
        test_id = tug_handler.start_test("user_from_video")
        
        # Process video frames
        cap = cv2.VideoCapture(tmp_path)
        fps = cap.get(cv2.CAP_PROP_FPS) or 30
        frame_idx = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            
            # Simulate pose detection and activity classification
            timestamp = frame_idx / fps
            
            # Mock activity detection based on frame position
            # In production, would use actual pose estimation
            if frame_idx < 30:
                activity = ActivityType.SITTING
            elif frame_idx < 60:
                activity = ActivityType.STANDING
            elif frame_idx < 150:
                activity = ActivityType.WALKING
            elif frame_idx < 180:
                activity = ActivityType.TURNING
            elif frame_idx < 270:
                activity = ActivityType.WALKING
            elif frame_idx < 300:
                activity = ActivityType.TURNING
            else:
                activity = ActivityType.SITTING
            
            # Process frame
            tug_handler.process_frame(test_id, None, activity, timestamp)
            frame_idx += 1
        
        cap.release()
        
        # Complete test and get results
        result = tug_handler.complete_test(test_id)
        
    finally:
        os.unlink(tmp_path)
    
    if result:
        return {
            "status": "completed",
            "result": result.to_dict()
        }
    else:
        return {
            "status": "error",
            "message": "Failed to process TUG test"
        }


@router.get("/fall-risk/{elderly_id}")
async def get_fall_risk_assessment(elderly_id: str):
    """
    Get comprehensive fall risk assessment for an elderly person.
    
    Combines gait analysis history, TUG test results, and activity patterns.
    """
    gait_analyzer, tug_handler, _, _, _, _ = get_services()
    
    # Get latest gait analysis (simulated - would come from database)
    # For demo, generate mock risk assessment
    risk_score = random.uniform(15, 55)
    
    if risk_score < 25:
        risk_level = FallRiskLevel.LOW
    elif risk_score < 40:
        risk_level = FallRiskLevel.MODERATE
    elif risk_score < 60:
        risk_level = FallRiskLevel.HIGH
    else:
        risk_level = FallRiskLevel.VERY_HIGH
    
    return {
        "elderly_id": elderly_id,
        "risk_score": round(risk_score, 1),
        "risk_level": risk_level.value,
        "assessment_date": datetime.now().isoformat(),
        "contributing_factors": [
            "Gait asymmetry detected in recent analysis",
            "Reduced stride length compared to baseline",
            "TUG test time above normal threshold"
        ][:random.randint(1, 3)],
        "gait_metrics": {
            "stride_length": round(random.uniform(0.4, 0.6), 2),
            "cadence": round(random.uniform(90, 120), 0),
            "gait_speed": round(random.uniform(0.7, 1.1), 2),
            "symmetry": round(random.uniform(0.85, 0.98), 2)
        },
        "recommendations": [
            "Continue daily balance exercises",
            "Use assistive device when walking outside",
            "Schedule follow-up gait assessment in 2 weeks"
        ],
        "trend": random.choice(["improving", "stable", "declining"])
    }


# ============= WebSocket Endpoints =============

@router.websocket("/ws/stream/{elderly_id}")
async def guardian_stream(websocket: WebSocket, elderly_id: str):
    """
    Live video monitoring stream with real-time fall detection.
    
    Uses the 3-layer hybrid fall detection system:
    - Layer 1: Skeleton-based geometric analysis
    - Layer 2: Motion-based frame analysis  
    - Layer 3: Deep learning (periodic)
    
    Streams pre-recorded videos as simulated CCTV feeds for demo,
    but the detection logic works the same for live camera feeds.
    """
    await websocket.accept()
    _, _, activity_classifier, _, _, live_detector = get_services()
    
    # Reset live detector for new stream
    live_detector.reset()
    
    try:
        while True:
            # Receive control message
            data = await websocket.receive_json()
            
            if data.get("type") == "START_STREAM":
                video_id = data.get("video_id", "walking_normal_1")
                enable_detection = data.get("enable_detection", True)
                
                if video_id not in VIDEO_FILES:
                    await websocket.send_json({
                        "type": "ERROR",
                        "message": f"Video '{video_id}' not found"
                    })
                    continue
                
                video_path = VIDEO_DIR / VIDEO_FILES[video_id]
                
                if not video_path.exists():
                    await websocket.send_json({
                        "type": "ERROR", 
                        "message": "Video file not available"
                    })
                    continue
                
                # Reset detector for new video
                live_detector.reset()
                
                await websocket.send_json({
                    "type": "STREAM_STARTED",
                    "elderly_id": elderly_id,
                    "video_id": video_id,
                    "detection_enabled": enable_detection
                })
                
                # Stream video frames with real-time fall detection
                cap = cv2.VideoCapture(str(video_path))
                fps = cap.get(cv2.CAP_PROP_FPS) or 30
                frame_delay = 1.0 / fps
                frame_idx = 0
                
                while cap.isOpened():
                    ret, frame = cap.read()
                    if not ret:
                        # Loop video for continuous demo
                        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                        frame_idx = 0
                        live_detector.reset()  # Reset on loop
                        continue
                    
                    # Resize frame for transmission
                    frame_small = cv2.resize(frame, (640, 360))
                    
                    # Encode frame as base64 JPEG
                    _, buffer = cv2.imencode('.jpg', frame_small, [cv2.IMWRITE_JPEG_QUALITY, 70])
                    frame_b64 = base64.b64encode(buffer).decode('utf-8')
                    
                    # Real-time fall detection using hybrid detector
                    fall_result = None
                    if enable_detection:
                        # Process frame through live detector
                        fall_result = live_detector.process_frame(frame)
                    
                    # Build response
                    response = {
                        "type": "FRAME",
                        "frame": frame_b64,
                        "frame_idx": frame_idx,
                        "timestamp": frame_idx / fps,
                    }
                    
                    if fall_result:
                        response.update({
                            "fall_detected": fall_result.is_fall,
                            "fall_confirmed": live_detector.state.fall_confirmed,
                            "confidence": fall_result.confidence,
                            "fall_type": fall_result.fall_type.value,
                            "detection_source": fall_result.detection_source.value,
                            "layer_scores": {
                                "skeleton": fall_result.skeleton_score,
                                "motion": fall_result.motion_score,
                                "deep_learning": fall_result.dl_score
                            },
                            "detection_reason": fall_result.detection_reason,
                            "processing_time_ms": fall_result.processing_time_ms,
                            "should_alert": live_detector.should_send_alert(),
                        })
                    else:
                        response.update({
                            "fall_detected": False,
                            "fall_confirmed": False,
                            "confidence": 0.0,
                        })
                    
                    await websocket.send_json(response)
                    
                    frame_idx += 1
                    await asyncio.sleep(frame_delay)
                    
                    # Check for stop command
                    try:
                        stop_check = await asyncio.wait_for(
                            websocket.receive_json(),
                            timeout=0.01
                        )
                        if stop_check.get("type") == "STOP_STREAM":
                            break
                    except asyncio.TimeoutError:
                        pass
                
                cap.release()
                await websocket.send_json({
                    "type": "STREAM_STOPPED",
                    "elderly_id": elderly_id,
                    "detection_state": live_detector.get_state_summary()
                })
            
            elif data.get("type") == "STOP_STREAM":
                await websocket.send_json({
                    "type": "STREAM_STOPPED",
                    "elderly_id": elderly_id
                })
                break
            
            elif data.get("type") == "RESET_DETECTOR":
                # Allow client to reset the detector state
                live_detector.reset()
                await websocket.send_json({
                    "type": "DETECTOR_RESET",
                    "elderly_id": elderly_id
                })
                
    except WebSocketDisconnect:
        logger.info(f"Guardian disconnected from stream for {elderly_id}")


@router.websocket("/ws/alerts/{guardian_id}")
async def alert_socket(websocket: WebSocket, guardian_id: str):
    """
    Real-time alert notifications for guardians.
    
    Pushes fall alerts, inactivity warnings, geofence breaches.
    """
    await websocket.accept()
    
    try:
        # Send initial connection confirmation
        await websocket.send_json({
            "type": "CONNECTED",
            "guardian_id": guardian_id,
            "message": "Alert stream connected"
        })
        
        while True:
            # Keep connection alive, alerts pushed when detected
            data = await websocket.receive_text()
            
            # Echo heartbeat
            if data == "ping":
                await websocket.send_json({"type": "pong"})
            
    except WebSocketDisconnect:
        print(f"Guardian {guardian_id} disconnected from alert socket")
