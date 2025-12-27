"""
SMARTCARE+ Backend API
AI-Powered Elderly Care Ecosystem

FastAPI application entry point with WebSocket support and worker threads
for non-blocking video processing.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Service routers
from physio_service.router import router as physio_router
from nutrition_service.router import router as nutrition_router
from guardian_service.router import router as guardian_router

# Core utilities
from core.config import settings


app = FastAPI(
    title="SMARTCARE+ API",
    description="AI-Powered Elderly Care Ecosystem - Backend Services",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring."""
    return {"status": "healthy", "service": "smartcare-api"}


# Include service routers
app.include_router(physio_router, prefix="/api/physio", tags=["Physio Service"])
app.include_router(nutrition_router, prefix="/api/nutrition", tags=["Nutrition Service"])
app.include_router(guardian_router, prefix="/api/guardian", tags=["Guardian Service"])


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup."""
    print("🚀 SMARTCARE+ API starting up...")
    # Initialize Firebase, ML models, thread pools here


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    print("👋 SMARTCARE+ API shutting down...")
    # Cleanup thread pools, close connections here


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
