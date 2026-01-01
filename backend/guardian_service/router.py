"""
SMARTCARE+ Guardian Service Router

Owner: Madhushani
Endpoints for real-time monitoring, fall detection, alerts, and geofencing.
Uses pre-recorded videos simulated as live CCTV feeds for demo.
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime
import random

router = APIRouter()


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
    {"id": "cam_1", "name": "Living Room", "location": "Main Floor", "status": "online", "video_file": "living_room.mp4"},
    {"id": "cam_2", "name": "Bedroom", "location": "Upper Floor", "status": "online", "video_file": "bedroom.mp4"},
    {"id": "cam_3", "name": "Kitchen", "location": "Main Floor", "status": "online", "video_file": "kitchen.mp4"},
    {"id": "cam_4", "name": "Hallway", "location": "Main Floor", "status": "offline", "video_file": "hallway.mp4"},
]


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


# ============= WebSocket Endpoints =============

@router.websocket("/ws/stream/{elderly_id}")
async def guardian_stream(websocket: WebSocket, elderly_id: str):
    """
    Live video monitoring stream.
    
    Uses worker threads for fall detection LSTM processing.
    Simulated CCTV using pre-recorded videos for university demo.
    """
    await websocket.accept()
    
    try:
        while True:
            # Receive control message or video frame
            data = await websocket.receive_json()
            
            if data.get("type") == "START_STREAM":
                # TODO: Start streaming pre-recorded video
                await websocket.send_json({
                    "type": "STREAM_STARTED",
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
        while True:
            # Keep connection alive, alerts pushed when detected
            await websocket.receive_text()
            
    except WebSocketDisconnect:
        print(f"Guardian {guardian_id} disconnected from alert socket")
