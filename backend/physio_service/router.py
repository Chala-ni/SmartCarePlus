"""
SMARTCARE+ Physio Service Router

Owner: Neelaka
Endpoints for physiotherapy analysis, gait metrics, TUG tests, and exercises.
"""

from fastapi import APIRouter, UploadFile, File, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import random

router = APIRouter()


# ============= Models =============

class Exercise(BaseModel):
    id: str
    name: str
    category: str
    duration: str
    difficulty: str
    reps: str
    description: str
    is_prescribed: bool = False


class FallRiskResponse(BaseModel):
    user_id: str
    risk_score: float
    risk_level: str
    contributing_factors: List[str]
    last_assessment: str


class GaitMetrics(BaseModel):
    stride_length: float
    cadence: float
    speed: float
    symmetry: float
    step_width: float


class TUGResult(BaseModel):
    time_seconds: float
    risk_level: str
    interpretation: str


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

@router.post("/analyze-gait")
async def analyze_gait(video: UploadFile = File(...)):
    """Analyze gait from uploaded video using MediaPipe."""
    # Simulated gait analysis results
    return {
        "status": "completed",
        "metrics": {
            "stride_length": round(random.uniform(0.45, 0.65), 2),
            "cadence": round(random.uniform(95, 115), 1),
            "speed": round(random.uniform(0.8, 1.2), 2),
            "symmetry": round(random.uniform(85, 98), 1),
            "step_width": round(random.uniform(0.08, 0.15), 2),
        },
        "risk_indicators": {
            "fall_risk": "Low" if random.random() > 0.3 else "Moderate",
            "gait_quality": "Good" if random.random() > 0.4 else "Fair",
        },
        "recommendations": [
            "Continue daily walking exercises",
            "Practice heel-to-toe walking for better balance",
        ]
    }


@router.post("/tug-test")
async def tug_test(video: UploadFile = File(...)):
    """Process TUG (Timed Up and Go) test video."""
    # Simulated TUG test result
    time_seconds = round(random.uniform(8, 18), 1)
    
    if time_seconds < 10:
        risk_level = "Low"
        interpretation = "Normal mobility. Low fall risk."
    elif time_seconds < 20:
        risk_level = "Moderate"
        interpretation = "Some mobility issues. Consider balance exercises."
    elif time_seconds < 30:
        risk_level = "High"
        interpretation = "Significant mobility impairment. Fall prevention measures recommended."
    else:
        risk_level = "Very High"
        interpretation = "Severe mobility impairment. Immediate intervention needed."
    
    return {
        "status": "completed",
        "result": {
            "time_seconds": time_seconds,
            "risk_level": risk_level,
            "interpretation": interpretation,
        },
        "phases": {
            "sit_to_stand": round(random.uniform(1.5, 3.0), 1),
            "walk_out": round(random.uniform(2.5, 5.0), 1),
            "turn": round(random.uniform(1.0, 2.5), 1),
            "walk_back": round(random.uniform(2.5, 5.0), 1),
            "turn_and_sit": round(random.uniform(1.5, 3.0), 1),
        }
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


# ============= WebSocket Endpoint =============

@router.websocket("/ws/stream/{user_id}")
async def physio_stream(websocket: WebSocket, user_id: str):
    """
    Real-time video stream for gait analysis.
    
    Uses worker threads for MediaPipe processing to avoid blocking.
    """
    await websocket.accept()
    
    try:
        while True:
            # Receive video frame
            data = await websocket.receive_bytes()
            
            # TODO: Process frame in worker thread
            # - Extract pose landmarks with MediaPipe
            # - Calculate gait metrics
            # - Send results back via WebSocket
            
            await websocket.send_json({
                "type": "POSE_RESULT",
                "landmarks": [],
                "message": "Processing frame..."
            })
            
    except WebSocketDisconnect:
        print(f"Client {user_id} disconnected from physio stream")
