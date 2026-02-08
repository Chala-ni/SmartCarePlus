"""
Video Configuration Module for Guardian Service

Manages video source settings - switching between live cameras and simulated videos.
Supports multiple camera sources (webcam, USB cameras, dashcams).
"""

import json
import logging
from pathlib import Path
from typing import Optional, Dict, Any, List
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# Path to config file
CONFIG_FILE = Path(__file__).parent / "data" / "video_config.json"


class CameraInfo(BaseModel):
    """Camera configuration model."""
    index: int
    name: str
    location: str


class VideoSettings(BaseModel):
    """Video stream settings."""
    frame_width: int = 640
    frame_height: int = 480
    fps_limit: int = 20
    jpeg_quality: int = 80


class VideoConfig(BaseModel):
    """Main video configuration model."""
    source_type: str = "simulated"  # "simulated" or "camera"
    camera_index: int = 0
    fallback_to_simulated: bool = True
    cameras: List[CameraInfo] = []
    simulated_video_id: str = "fall_indoor_1"
    settings: VideoSettings = VideoSettings()


# Singleton config instance
_config: Optional[VideoConfig] = None


def load_config() -> VideoConfig:
    """
    Load video configuration from JSON file.
    Creates default config if file doesn't exist.
    """
    global _config
    
    if not CONFIG_FILE.exists():
        logger.info(f"Config file not found, creating default at: {CONFIG_FILE}")
        _config = VideoConfig(
            cameras=[
                CameraInfo(index=0, name="Webcam (Built-in)", location="Main Camera"),
                CameraInfo(index=1, name="USB Camera 1", location="Living Room"),
                CameraInfo(index=2, name="USB Camera 2", location="Bedroom"),
            ]
        )
        save_config(_config)
        return _config
    
    try:
        with open(CONFIG_FILE, "r") as f:
            data = json.load(f)
        _config = VideoConfig(**data)
        logger.info(f"✅ Loaded video config: source_type={_config.source_type}, camera_index={_config.camera_index}")
        return _config
    except Exception as e:
        logger.error(f"Error loading video config: {e}, using defaults")
        _config = VideoConfig()
        return _config


def save_config(config: VideoConfig) -> bool:
    """Save video configuration to JSON file."""
    global _config
    try:
        # Ensure data directory exists
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        
        with open(CONFIG_FILE, "w") as f:
            json.dump(config.model_dump(), f, indent=4)
        
        _config = config
        logger.info(f"✅ Saved video config: source_type={config.source_type}, camera_index={config.camera_index}")
        return True
    except Exception as e:
        logger.error(f"Error saving video config: {e}")
        return False


def get_config() -> VideoConfig:
    """Get current config (loads if not already loaded)."""
    global _config
    if _config is None:
        return load_config()
    return _config


def update_source_type(source_type: str) -> VideoConfig:
    """
    Switch between 'camera' and 'simulated' source types.
    
    Args:
        source_type: Either 'camera' or 'simulated'
    """
    if source_type not in ["camera", "simulated"]:
        raise ValueError(f"Invalid source_type: {source_type}. Must be 'camera' or 'simulated'")
    
    config = get_config()
    config.source_type = source_type
    save_config(config)
    logger.info(f"🎥 Switched video source to: {source_type}")
    return config


def update_camera_index(camera_index: int) -> VideoConfig:
    """
    Change which camera to use (0=webcam, 1=USB1, 2=USB2, etc.)
    
    Args:
        camera_index: The camera index (0, 1, 2, ...)
    """
    config = get_config()
    config.camera_index = camera_index
    save_config(config)
    logger.info(f"📷 Switched to camera index: {camera_index}")
    return config


def update_simulated_video(video_id: str) -> VideoConfig:
    """Update which pre-recorded video to use when in simulated mode."""
    config = get_config()
    config.simulated_video_id = video_id
    save_config(config)
    logger.info(f"🎬 Changed simulated video to: {video_id}")
    return config


def add_camera(index: int, name: str, location: str) -> VideoConfig:
    """Add a new camera to the configuration."""
    config = get_config()
    
    # Check if camera already exists
    for cam in config.cameras:
        if cam.index == index:
            # Update existing
            cam.name = name
            cam.location = location
            save_config(config)
            return config
    
    # Add new camera
    config.cameras.append(CameraInfo(index=index, name=name, location=location))
    save_config(config)
    return config


def get_active_source() -> Dict[str, Any]:
    """
    Get information about the currently active video source.
    
    Returns:
        Dict with source_type, details, and settings
    """
    config = get_config()
    
    if config.source_type == "camera":
        # Find camera info
        camera_info = None
        for cam in config.cameras:
            if cam.index == config.camera_index:
                camera_info = cam.model_dump()
                break
        
        return {
            "source_type": "camera",
            "camera_index": config.camera_index,
            "camera_info": camera_info or {"index": config.camera_index, "name": f"Camera {config.camera_index}", "location": "Unknown"},
            "fallback_enabled": config.fallback_to_simulated,
            "fallback_video": config.simulated_video_id,
            "settings": config.settings.model_dump()
        }
    else:
        return {
            "source_type": "simulated",
            "video_id": config.simulated_video_id,
            "settings": config.settings.model_dump()
        }


def is_camera_mode() -> bool:
    """Check if currently using live camera mode."""
    return get_config().source_type == "camera"


def get_fallback_video_id() -> str:
    """Get the fallback video ID for when camera fails."""
    return get_config().simulated_video_id


# Load config on module import
load_config()
