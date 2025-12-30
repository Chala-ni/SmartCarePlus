"""
SMARTCARE+ Backend API
AI-Powered Elderly Care Ecosystem

FastAPI application entry point with WebSocket support and worker threads
for non-blocking video processing.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

# Service routers
from physio_service.router import router as physio_router
from nutrition_service.router import router as nutrition_router
from guardian_service.router import router as guardian_router
from core.users import router as users_router

# Core utilities
from core.config import settings
from core.database import init_firebase, get_db, is_mock_mode
from core.websocket import connection_manager
from core.threading import video_worker_pool, ml_worker_pool
from core.notifications import fcm_service
from shared.utils import setup_logger

# Setup logging
logger = setup_logger("smartcare.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup/shutdown."""
    # ===== STARTUP =====
    logger.info("🚀 SMARTCARE+ API starting up...")
    
    # Initialize Firebase
    if init_firebase():
        logger.info("🔥 Firebase connected")
    else:
        logger.warning("⚠️ Running in MOCK MODE (no Firebase)")
    
    # Start WebSocket heartbeat
    await connection_manager.start_heartbeat()
    logger.info("💓 WebSocket heartbeat started")
    
    # Initialize FCM
    fcm_service.initialize()
    
    # Create media directory for local storage
    media_path = Path(__file__).parent / "media"
    media_path.mkdir(exist_ok=True)
    
    logger.info("✅ SMARTCARE+ API ready!")
    
    yield  # Application runs here
    
    # ===== SHUTDOWN =====
    logger.info("👋 SMARTCARE+ API shutting down...")
    
    # Stop heartbeat
    await connection_manager.stop_heartbeat()
    
    # Shutdown thread pools
    video_worker_pool.shutdown(wait=True)
    ml_worker_pool.shutdown(wait=True)
    
    logger.info("✅ Shutdown complete")


app = FastAPI(
    title="SMARTCARE+ API",
    description="AI-Powered Elderly Care Ecosystem - Backend Services",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for media (local storage)
media_path = Path(__file__).parent / "media"
media_path.mkdir(exist_ok=True)
app.mount("/media", StaticFiles(directory=str(media_path)), name="media")


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring."""
    return {
        "status": "healthy",
        "service": "smartcare-api",
        "firebase": "connected" if not is_mock_mode() else "mock",
        "websocket_connections": connection_manager.connection_count
    }


@app.get("/stats")
async def get_stats():
    """Get service statistics."""
    return {
        "websocket": connection_manager.get_stats(),
        "video_pool": video_worker_pool.get_stats(),
        "ml_pool": ml_worker_pool.get_stats(),
        "fcm": fcm_service.get_stats()
    }


# Include service routers
app.include_router(users_router, prefix="/api/users", tags=["Users"])
app.include_router(physio_router, prefix="/api/physio", tags=["Physio Service"])
app.include_router(nutrition_router, prefix="/api/nutrition", tags=["Nutrition Service"])
app.include_router(guardian_router, prefix="/api/guardian", tags=["Guardian Service"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
