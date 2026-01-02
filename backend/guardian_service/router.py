"""
SMARTCARE+ Guardian Service Router

Owner: Madhushani
Endpoints for real-time monitoring, fall detection, alerts, and geofencing.
Uses pre-recorded videos simulated as live CCTV feeds for demo.
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, UploadFile, File, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime
from pathlib import Path
import random
import os
import cv2
import numpy as np
import base64
import asyncio

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
    get_tug_handler
)

router = APIRouter()

# Video files directory
VIDEO_DIR = Path(__file__).parent.parent / "media" / "simulation_footage" / "guardian"

# Service instances (singleton pattern)
_gait_analyzer: Optional[GaitAnalyzer] = None
_tug_handler: Optional[TUGTestHandler] = None
_activity_classifier: Optional[ActivityClassifier] = None


def get_services():
    """Get or initialize service instances."""
    global _gait_analyzer, _tug_handler, _activity_classifier
    if _gait_analyzer is None:
        _gait_analyzer = get_gait_analyzer()
    if _tug_handler is None:
        _tug_handler = get_tug_handler()
    if _activity_classifier is None:
        _activity_classifier = ActivityClassifier()
    return _gait_analyzer, _tug_handler, _activity_classifier


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
}


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


# ============= Video Streaming Endpoints =============

@router.get("/videos")
async def list_videos():
    """List all available demo videos for CCTV simulation."""
    videos = []
    for video_id, filename in VIDEO_FILES.items():
        video_path = VIDEO_DIR / filename
        exists = video_path.exists()
        videos.append({
            "id": video_id,
            "filename": filename,
            "available": exists,
            "url": f"/guardian/video/{video_id}" if exists else None
        })
    
    return {
        "videos": videos,
        "total": len(videos),
        "available": len([v for v in videos if v["available"]])
    }


@router.get("/video/{video_id}")
async def get_video(video_id: str):
    """Stream a pre-recorded video file for demo CCTV simulation."""
    if video_id not in VIDEO_FILES:
        raise HTTPException(status_code=404, detail=f"Video '{video_id}' not found")
    
    video_path = VIDEO_DIR / VIDEO_FILES[video_id]
    
    if not video_path.exists():
        raise HTTPException(status_code=404, detail=f"Video file not found on server")
    
    return FileResponse(
        path=str(video_path),
        media_type="video/mp4",
        filename=VIDEO_FILES[video_id]
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
    gait_analyzer, _, _ = get_services()
    
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
    _, tug_handler, _ = get_services()
    
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
    gait_analyzer, tug_handler, _ = get_services()
    
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
    Live video monitoring stream with real-time activity detection.
    
    Streams pre-recorded videos as simulated CCTV feeds.
    Performs activity classification and fall detection on frames.
    """
    await websocket.accept()
    _, _, activity_classifier = get_services()
    
    try:
        while True:
            # Receive control message
            data = await websocket.receive_json()
            
            if data.get("type") == "START_STREAM":
                video_id = data.get("video_id", "walking_normal_1")
                
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
                
                await websocket.send_json({
                    "type": "STREAM_STARTED",
                    "elderly_id": elderly_id,
                    "video_id": video_id
                })
                
                # Stream video frames with activity detection
                cap = cv2.VideoCapture(str(video_path))
                fps = cap.get(cv2.CAP_PROP_FPS) or 30
                frame_delay = 1.0 / fps
                frame_idx = 0
                
                while cap.isOpened():
                    ret, frame = cap.read()
                    if not ret:
                        # Loop video for continuous demo
                        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                        continue
                    
                    # Resize frame for transmission
                    frame_small = cv2.resize(frame, (640, 360))
                    
                    # Encode frame as base64 JPEG
                    _, buffer = cv2.imencode('.jpg', frame_small, [cv2.IMWRITE_JPEG_QUALITY, 70])
                    frame_b64 = base64.b64encode(buffer).decode('utf-8')
                    
                    # Classify activity (mock for now - would use pose estimation)
                    detected_activity = random.choice([
                        ActivityType.WALKING,
                        ActivityType.SITTING,
                        ActivityType.STANDING
                    ])
                    
                    # Check for fall in frame (mock detection)
                    fall_detected = "fall" in video_id and frame_idx > fps * 2
                    
                    await websocket.send_json({
                        "type": "FRAME",
                        "frame": frame_b64,
                        "frame_idx": frame_idx,
                        "timestamp": frame_idx / fps,
                        "activity": detected_activity.value,
                        "fall_detected": fall_detected,
                        "confidence": random.uniform(0.85, 0.99)
                    })
                    
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
                    "elderly_id": elderly_id
                })
            
            elif data.get("type") == "STOP_STREAM":
                await websocket.send_json({
                    "type": "STREAM_STOPPED",
                    "elderly_id": elderly_id
                })
                break
                
    except WebSocketDisconnect:
        print(f"Guardian disconnected from stream for {elderly_id}")


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
