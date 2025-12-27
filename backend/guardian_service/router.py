"""
SMARTCARE+ Guardian Service Router

Owner: Madhushani
Endpoints for real-time monitoring, fall detection, alerts, and geofencing.
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Optional, List
from pydantic import BaseModel

router = APIRouter()


# ============= Pydantic Models =============

class FallAlertRequest(BaseModel):
    elderly_id: str
    confidence: float
    fall_type: str  # forward, backward, sideways, collapse
    location: dict  # {lat, lng}


class SOSRequest(BaseModel):
    elderly_id: str
    location: dict
    message: Optional[str] = None


class GeofenceRequest(BaseModel):
    elderly_id: str
    name: str
    coordinates: List[dict]  # List of {lat, lng}
    radius: Optional[float] = None


# ============= REST Endpoints =============

@router.get("/elderly/{elderly_id}/status")
async def get_elderly_status(elderly_id: str):
    """Get current status of elderly person."""
    # TODO: Fetch status from Firestore
    return {"elderly_id": elderly_id, "status": "active", "last_activity": "walking"}


@router.post("/fall-alert")
async def report_fall_alert(request: FallAlertRequest):
    """Report fall detection event."""
    # TODO: Store alert, send push notification
    return {"status": "alert_created", "elderly_id": request.elderly_id}


@router.post("/sos")
async def trigger_sos(request: SOSRequest):
    """Trigger SOS emergency."""
    # TODO: Send emergency notifications to all guardians
    return {"status": "sos_triggered", "elderly_id": request.elderly_id}


@router.get("/alerts/{guardian_id}")
async def get_alerts(guardian_id: str, status: Optional[str] = None, limit: int = 20):
    """Get all alerts for a guardian."""
    # TODO: Fetch alerts from Firestore
    return {"guardian_id": guardian_id, "alerts": []}


@router.put("/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(alert_id: str, response_action: str, notes: Optional[str] = None):
    """Acknowledge an alert."""
    # TODO: Update alert status
    return {"alert_id": alert_id, "status": "acknowledged"}


@router.post("/geofence")
async def create_geofence(request: GeofenceRequest):
    """Create geofence zone."""
    # TODO: Store geofence in Firestore
    return {"status": "created", "elderly_id": request.elderly_id}


@router.get("/geofence/{elderly_id}")
async def get_geofences(elderly_id: str):
    """Get user's geofences."""
    # TODO: Fetch geofences
    return {"elderly_id": elderly_id, "geofences": []}


@router.get("/activity-log/{elderly_id}")
async def get_activity_log(elderly_id: str, start: Optional[str] = None, end: Optional[str] = None):
    """Get activity history."""
    # TODO: Fetch activity log
    return {"elderly_id": elderly_id, "activities": []}


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
