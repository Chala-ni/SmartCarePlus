"""
SMARTCARE+ Guardian Service - Hybrid Fall Detector

Owner: Madhushani
Three-layer hybrid fall detection system combining:
  1. Skeleton-based geometric analysis (MediaPipe Pose)
  2. Motion-based frame analysis (Optical Flow / Frame Diff)
  3. Deep Learning classification (EfficientNet+LSTM)

This ensemble approach provides robust fall detection with:
  - Immediate response from geometric rules
  - Fallback detection when pose is unavailable
  - Context-aware confirmation from deep learning
"""

import numpy as np
import cv2
import time
import logging
import threading
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Any
from enum import Enum
from collections import deque
import math
import os

# MediaPipe Tasks API (new API for 0.10.x+)
try:
    from mediapipe.tasks.python import vision
    from mediapipe.tasks.python.vision import PoseLandmarker, PoseLandmarkerOptions
    from mediapipe.tasks.python.core.base_options import BaseOptions
    import mediapipe as mp
    
    # Find the model file
    _current_dir = os.path.dirname(os.path.abspath(__file__))
    _model_paths = [
        os.path.join(_current_dir, "..", "..", "scripts", "pose_landmarker_full.task"),
        os.path.join(_current_dir, "..", "..", "ml_models", "pose_landmarker.task"),
        os.path.join(_current_dir, "pose_landmarker.task"),
    ]
    POSE_MODEL_PATH = None
    for path in _model_paths:
        if os.path.exists(path):
            POSE_MODEL_PATH = os.path.abspath(path)
            break
    
    MEDIAPIPE_AVAILABLE = POSE_MODEL_PATH is not None
    if not MEDIAPIPE_AVAILABLE:
        logging.getLogger(__name__).warning("MediaPipe model file not found. Skeleton detection disabled.")
except (ImportError, Exception) as e:
    MEDIAPIPE_AVAILABLE = False
    mp = None
    POSE_MODEL_PATH = None
    logging.getLogger(__name__).warning(f"MediaPipe not available: {e}. Skeleton detection disabled.")

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════════════════
# ENUMS AND DATA CLASSES
# ═══════════════════════════════════════════════════════════════════════════════

class FallType(Enum):
    """Types of falls detected."""
    FORWARD = "forward"
    BACKWARD = "backward"
    SIDEWAYS = "sideways"
    COLLAPSE = "collapse"  # Straight down
    UNKNOWN = "unknown"
    NO_FALL = "no_fall"


class DetectionSource(Enum):
    """Which detector triggered the fall detection."""
    SKELETON = "skeleton"
    MOTION = "motion"
    DEEP_LEARNING = "deep_learning"
    CONSENSUS = "consensus"
    WEIGHTED = "weighted"
    NONE = "none"


@dataclass
class SkeletonMetrics:
    """Metrics from skeleton-based fall analysis."""
    head_velocity: float = 0.0  # Vertical velocity of head (pixels/second)
    hip_velocity: float = 0.0   # Vertical velocity of hip center
    height_width_ratio: float = 1.0  # Body height / width (< 0.5 indicates horizontal)
    spine_angle: float = 90.0  # Angle from horizontal (90 = upright, 0 = lying)
    center_of_mass_velocity: float = 0.0  # Speed of CoM movement
    support_base_ratio: float = 1.0  # CoM distance from feet / shoulder width
    confidence: float = 0.0
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "head_velocity": round(self.head_velocity, 2),
            "hip_velocity": round(self.hip_velocity, 2),
            "height_width_ratio": round(self.height_width_ratio, 3),
            "spine_angle": round(self.spine_angle, 1),
            "center_of_mass_velocity": round(self.center_of_mass_velocity, 2),
            "support_base_ratio": round(self.support_base_ratio, 3),
            "confidence": round(self.confidence, 3),
        }


@dataclass
class MotionMetrics:
    """Metrics from motion-based fall analysis."""
    motion_magnitude: float = 0.0  # Average motion between frames
    motion_spike: bool = False  # Sudden increase in motion
    vertical_motion: float = 0.0  # Predominant vertical motion
    motion_cessation: bool = False  # Motion stopped after spike (impact)
    motion_variance: float = 0.0  # Variance in motion (rhythmic vs chaotic)
    confidence: float = 0.0
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "motion_magnitude": round(self.motion_magnitude, 2),
            "motion_spike": self.motion_spike,
            "vertical_motion": round(self.vertical_motion, 2),
            "motion_cessation": self.motion_cessation,
            "motion_variance": round(self.motion_variance, 2),
            "confidence": round(self.confidence, 3),
        }


@dataclass
class HybridFallResult:
    """Complete result from hybrid fall detection."""
    is_fall: bool
    confidence: float
    fall_type: FallType
    detection_source: DetectionSource
    
    # Individual layer scores
    skeleton_score: float
    motion_score: float
    dl_score: float
    
    # Detailed metrics
    skeleton_metrics: Optional[SkeletonMetrics] = None
    motion_metrics: Optional[MotionMetrics] = None
    
    # Timing
    processing_time_ms: float = 0.0
    timestamp: float = field(default_factory=time.time)
    
    # Reasoning
    detection_reason: str = ""
    
    # DL activity classification (from video classifier)
    dl_activity: str = "unknown"  # e.g. "fall", "arthritis_gait", "adl", "good_gait"
    dl_probabilities: Optional[Dict[str, float]] = None  # All class probabilities
    gait_abnormal: bool = False  # True if arthritis_gait detected
    
    # Inactivity tracking
    inactivity_seconds: float = 0.0  # How long with near-zero motion
    inactivity_alert: bool = False  # True if prolonged inactivity detected
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "is_fall": self.is_fall,
            "confidence": round(self.confidence, 3),
            "fall_type": self.fall_type.value,
            "detection_source": self.detection_source.value,
            "scores": {
                "skeleton": round(self.skeleton_score, 3),
                "motion": round(self.motion_score, 3),
                "deep_learning": round(self.dl_score, 3),
            },
            "skeleton_metrics": self.skeleton_metrics.to_dict() if self.skeleton_metrics else None,
            "motion_metrics": self.motion_metrics.to_dict() if self.motion_metrics else None,
            "processing_time_ms": round(self.processing_time_ms, 1),
            "timestamp": self.timestamp,
            "detection_reason": self.detection_reason,
            "dl_activity": self.dl_activity,
            "dl_probabilities": {k: round(v, 3) for k, v in self.dl_probabilities.items()} if self.dl_probabilities else None,
            "gait_abnormal": self.gait_abnormal,
            "inactivity_seconds": round(self.inactivity_seconds, 1),
            "inactivity_alert": self.inactivity_alert,
        }


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 1: SKELETON-BASED FALL DETECTOR
# ═══════════════════════════════════════════════════════════════════════════════

class SkeletonFallDetector:
    """
    Geometric fall detection using MediaPipe pose landmarks.
    
    Detects falls by analyzing:
    - Head/hip vertical velocity (rapid downward motion)
    - Height-to-width ratio (standing → horizontal transition)
    - Spine angle (upright → lying)
    - Center of mass trajectory
    - Support polygon (feet relative to body)
    """
    
    # MediaPipe landmark indices
    NOSE = 0
    LEFT_SHOULDER = 11
    RIGHT_SHOULDER = 12
    LEFT_HIP = 23
    RIGHT_HIP = 24
    LEFT_ANKLE = 27
    RIGHT_ANKLE = 28
    LEFT_EAR = 7
    RIGHT_EAR = 8
    
    # Thresholds for fall detection (calibrated for webcam/live video)
    # Lowered thresholds for better sensitivity in live detection
    VELOCITY_THRESHOLD = 0.08  # Normalized units per frame (head moving down fast) - lowered from 0.15
    HEIGHT_RATIO_THRESHOLD = 0.8  # Height/width ratio below this = horizontal - raised from 0.6
    SPINE_ANGLE_THRESHOLD = 55  # Degrees from horizontal (below = lying) - raised from 45
    COM_VELOCITY_THRESHOLD = 0.05  # Center of mass moving fast - lowered from 0.1
    
    def __init__(self, history_size: int = 30):
        """
        Initialize skeleton fall detector.
        
        Args:
            history_size: Number of frames to track for velocity calculation
        """
        self.history_size = history_size
        
        # Position history for velocity calculation
        self.head_history: deque = deque(maxlen=history_size)
        self.hip_history: deque = deque(maxlen=history_size)
        self.shoulder_history: deque = deque(maxlen=history_size)
        self.ankle_history: deque = deque(maxlen=history_size)
        
        # Time tracking
        self.last_timestamp = 0.0
        
        # Fall state tracking
        self.fall_detected_frames = 0
        self.normal_frames_since_fall = 0
        
        logger.info("SkeletonFallDetector initialized")
    
    def reset(self):
        """Reset all history buffers."""
        self.head_history.clear()
        self.hip_history.clear()
        self.shoulder_history.clear()
        self.ankle_history.clear()
        self.fall_detected_frames = 0
        self.normal_frames_since_fall = 0
    
    def _get_landmark_point(self, landmarks: Dict[int, Dict], idx: int) -> Optional[Tuple[float, float]]:
        """Extract (x, y) from landmark if visible."""
        lm = landmarks.get(idx)
        # Lowered visibility threshold from 0.3 to 0.1 for better detection in poor lighting
        if lm and lm.get("visibility", 0) > 0.1:
            return (lm.get("x", 0), lm.get("y", 0))
        return None
    
    def _calculate_velocity(self, history: deque, window: int = 5) -> float:
        """Calculate vertical velocity from position history."""
        if len(history) < window:
            return 0.0
        
        recent = list(history)[-window:]
        if len(recent) < 2:
            return 0.0
        
        # Calculate average velocity (positive = moving down in image coordinates)
        velocities = []
        for i in range(1, len(recent)):
            dy = recent[i][1] - recent[i-1][1]
            velocities.append(dy)
        
        return np.mean(velocities) if velocities else 0.0
    
    def _calculate_height_width_ratio(self, landmarks: Dict[int, Dict]) -> float:
        """Calculate body height to width ratio."""
        head = self._get_landmark_point(landmarks, self.NOSE)
        left_ankle = self._get_landmark_point(landmarks, self.LEFT_ANKLE)
        right_ankle = self._get_landmark_point(landmarks, self.RIGHT_ANKLE)
        left_shoulder = self._get_landmark_point(landmarks, self.LEFT_SHOULDER)
        right_shoulder = self._get_landmark_point(landmarks, self.RIGHT_SHOULDER)
        
        if not all([head, left_shoulder, right_shoulder]):
            return 1.0
        
        # Height: head to average ankle (or hip if ankles not visible)
        ankle_y = (left_ankle[1] + right_ankle[1]) / 2 if left_ankle and right_ankle else None
        if ankle_y is None:
            left_hip = self._get_landmark_point(landmarks, self.LEFT_HIP)
            right_hip = self._get_landmark_point(landmarks, self.RIGHT_HIP)
            if left_hip and right_hip:
                ankle_y = (left_hip[1] + right_hip[1]) / 2 + 0.2
            else:
                return 1.0
        
        height = abs(ankle_y - head[1])
        
        # Width: shoulder width + some body width estimation
        width = abs(right_shoulder[0] - left_shoulder[0])
        
        # Also consider horizontal spread of the body
        all_x = [p[0] for p in [head, left_shoulder, right_shoulder, left_ankle, right_ankle] if p]
        body_width = max(all_x) - min(all_x) if all_x else width
        
        width = max(width, body_width, 0.01)
        
        return height / width
    
    def _calculate_spine_angle(self, landmarks: Dict[int, Dict]) -> float:
        """Calculate spine angle from horizontal (90 = upright, 0 = lying)."""
        left_shoulder = self._get_landmark_point(landmarks, self.LEFT_SHOULDER)
        right_shoulder = self._get_landmark_point(landmarks, self.RIGHT_SHOULDER)
        left_hip = self._get_landmark_point(landmarks, self.LEFT_HIP)
        right_hip = self._get_landmark_point(landmarks, self.RIGHT_HIP)
        
        if not all([left_shoulder, right_shoulder, left_hip, right_hip]):
            return 90.0  # Assume upright if can't calculate
        
        # Spine vector: hip center to shoulder center
        shoulder_center = ((left_shoulder[0] + right_shoulder[0]) / 2,
                          (left_shoulder[1] + right_shoulder[1]) / 2)
        hip_center = ((left_hip[0] + right_hip[0]) / 2,
                     (left_hip[1] + right_hip[1]) / 2)
        
        dx = shoulder_center[0] - hip_center[0]
        dy = shoulder_center[1] - hip_center[1]
        
        # Angle from horizontal (in image coords, y increases downward)
        # Upright person has dy < 0 (shoulder above hip)
        angle = math.degrees(math.atan2(abs(dy), abs(dx)))
        
        return angle
    
    def _determine_fall_type(self, landmarks: Dict[int, Dict], 
                             head_velocity: float) -> FallType:
        """Determine the type of fall based on motion direction."""
        head = self._get_landmark_point(landmarks, self.NOSE)
        
        if len(self.head_history) < 5:
            return FallType.UNKNOWN
        
        # Get horizontal movement
        recent_head = list(self.head_history)[-5:]
        dx = recent_head[-1][0] - recent_head[0][0]
        dy = recent_head[-1][1] - recent_head[0][1]
        
        if abs(dx) < 0.02:
            return FallType.COLLAPSE  # Straight down
        elif dx > 0.05:
            return FallType.FORWARD
        elif dx < -0.05:
            return FallType.BACKWARD
        else:
            return FallType.SIDEWAYS
    
    def analyze(self, landmarks: Dict[int, Dict], timestamp: float = None) -> Tuple[float, SkeletonMetrics]:
        """
        Analyze pose landmarks for fall detection.
        
        Args:
            landmarks: Dict of landmark_id -> {x, y, z, visibility}
            timestamp: Frame timestamp (uses current time if None)
        
        Returns:
            Tuple of (fall_score 0-1, SkeletonMetrics)
        """
        if timestamp is None:
            timestamp = time.time()
        
        # Extract key landmarks
        head = self._get_landmark_point(landmarks, self.NOSE)
        left_hip = self._get_landmark_point(landmarks, self.LEFT_HIP)
        right_hip = self._get_landmark_point(landmarks, self.RIGHT_HIP)
        left_shoulder = self._get_landmark_point(landmarks, self.LEFT_SHOULDER)
        right_shoulder = self._get_landmark_point(landmarks, self.RIGHT_SHOULDER)
        left_ankle = self._get_landmark_point(landmarks, self.LEFT_ANKLE)
        right_ankle = self._get_landmark_point(landmarks, self.RIGHT_ANKLE)
        
        # Debug: Log visibility of key landmarks (every ~30 frames to avoid spam)
        frame_count = len(self.head_history) + 1
        if frame_count % 30 == 1:
            key_lm_vis = {
                "nose": landmarks.get(self.NOSE, {}).get("visibility", 0),
                "l_hip": landmarks.get(self.LEFT_HIP, {}).get("visibility", 0),
                "r_hip": landmarks.get(self.RIGHT_HIP, {}).get("visibility", 0),
                "l_ankle": landmarks.get(self.LEFT_ANKLE, {}).get("visibility", 0),
                "r_ankle": landmarks.get(self.RIGHT_ANKLE, {}).get("visibility", 0),
            }
            vis_str = ", ".join([f"{k}={v:.2f}" for k, v in key_lm_vis.items()])
            missing = [name for name, pt in [("head", head), ("hips", left_hip and right_hip), 
                       ("ankles", left_ankle and right_ankle)] if not pt]
            logger.debug(f"  👁️ Landmark visibility: {vis_str}. History: head={len(self.head_history)}")
            if missing:
                logger.debug(f"  ⚠️ Missing landmarks (vis<0.1): {', '.join(missing)}")
        
        # Update history
        if head:
            self.head_history.append(head)
        if left_hip and right_hip:
            hip_center = ((left_hip[0] + right_hip[0]) / 2, (left_hip[1] + right_hip[1]) / 2)
            self.hip_history.append(hip_center)
        if left_shoulder and right_shoulder:
            shoulder_center = ((left_shoulder[0] + right_shoulder[0]) / 2, 
                              (left_shoulder[1] + right_shoulder[1]) / 2)
            self.shoulder_history.append(shoulder_center)
        if left_ankle and right_ankle:
            ankle_center = ((left_ankle[0] + right_ankle[0]) / 2,
                           (left_ankle[1] + right_ankle[1]) / 2)
            self.ankle_history.append(ankle_center)
        
        # Calculate metrics
        head_velocity = self._calculate_velocity(self.head_history)
        hip_velocity = self._calculate_velocity(self.hip_history)
        height_width_ratio = self._calculate_height_width_ratio(landmarks)
        spine_angle = self._calculate_spine_angle(landmarks)
        
        # Center of mass velocity (approximated by hip velocity)
        com_velocity = math.sqrt(
            self._calculate_velocity(self.hip_history) ** 2
        )
        
        # Support base ratio (how far CoM is from support base)
        support_ratio = 1.0
        if self.hip_history and self.ankle_history:
            hip = list(self.hip_history)[-1]
            ankle = list(self.ankle_history)[-1]
            support_ratio = abs(hip[0] - ankle[0]) * 5  # Scaled for sensitivity
        
        metrics = SkeletonMetrics(
            head_velocity=head_velocity,
            hip_velocity=hip_velocity,
            height_width_ratio=height_width_ratio,
            spine_angle=spine_angle,
            center_of_mass_velocity=com_velocity,
            support_base_ratio=support_ratio,
        )
        
        # Debug: Log actual metric values vs thresholds
        logger.debug(f"  📐 Skeleton metrics: head_vel={head_velocity:.4f} (thresh>{self.VELOCITY_THRESHOLD}), "
                    f"h/w={height_width_ratio:.2f} (thresh<{self.HEIGHT_RATIO_THRESHOLD}), "
                    f"spine={spine_angle:.1f}° (thresh<{self.SPINE_ANGLE_THRESHOLD}), "
                    f"com_vel={com_velocity:.4f} (thresh>{self.COM_VELOCITY_THRESHOLD})")
        
        # Calculate fall score
        score = 0.0
        score_components = []
        
        # High downward velocity of head
        if head_velocity > self.VELOCITY_THRESHOLD:
            vel_contrib = 0.35 * min(head_velocity / self.VELOCITY_THRESHOLD, 2.0)
            score += vel_contrib
            score_components.append(f"vel={vel_contrib:.2f}")
        
        # Low height/width ratio (person is horizontal)
        if height_width_ratio < self.HEIGHT_RATIO_THRESHOLD:
            ratio_score = 1.0 - (height_width_ratio / self.HEIGHT_RATIO_THRESHOLD)
            ratio_contrib = 0.30 * ratio_score
            score += ratio_contrib
            score_components.append(f"h/w={ratio_contrib:.2f}")
        
        # Low spine angle (lying down)
        if spine_angle < self.SPINE_ANGLE_THRESHOLD:
            angle_score = 1.0 - (spine_angle / self.SPINE_ANGLE_THRESHOLD)
            angle_contrib = 0.25 * angle_score
            score += angle_contrib
            score_components.append(f"spine={angle_contrib:.2f}")
        
        # Fast center of mass movement
        if com_velocity > self.COM_VELOCITY_THRESHOLD:
            com_contrib = 0.10 * min(com_velocity / self.COM_VELOCITY_THRESHOLD, 2.0)
            score += com_contrib
            score_components.append(f"com={com_contrib:.2f}")
        
        score = min(score, 1.0)
        metrics.confidence = score
        
        if score > 0:
            logger.debug(f"  📊 Skeleton score={score:.2f} from: {', '.join(score_components)}")
        
        self.last_timestamp = timestamp
        
        return score, metrics


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 2: MOTION-BASED FALL DETECTOR
# ═══════════════════════════════════════════════════════════════════════════════

class MotionFallDetector:
    """
    Motion-based fall detection using frame difference analysis.
    
    Works without pose detection - analyzes raw pixel motion patterns.
    Detects:
    - Motion spikes (sudden movement)
    - Vertical motion direction
    - Motion cessation (impact)
    - Downward motion pattern (falling trajectory)
    """
    
    # Thresholds - tuned for fall detection
    MOTION_SPIKE_RATIO = 2.0  # Motion must be 2x the baseline (lowered from 3)
    MOTION_SPIKE_ABSOLUTE = 10.0  # Minimum absolute motion for spike (lowered from 15)
    CESSATION_THRESHOLD = 8.0  # Motion below this after spike = impact
    VERTICAL_MOTION_THRESHOLD = 1.5  # Significant vertical motion (lowered from 3)
    HIGH_MOTION_THRESHOLD = 25.0  # Very high motion indicating dramatic movement
    
    def __init__(self, history_size: int = 20):
        """
        Initialize motion fall detector.
        
        Args:
            history_size: Number of frames to analyze
        """
        self.history_size = history_size
        self.motion_history: deque = deque(maxlen=history_size)
        self.vertical_motion_history: deque = deque(maxlen=history_size)
        self.prev_frame = None
        self.spike_detected = False
        self.frames_since_spike = 0
        
        logger.info("MotionFallDetector initialized")
    
    def reset(self):
        """Reset all history."""
        self.motion_history.clear()
        self.vertical_motion_history.clear()
        self.prev_frame = None
        self.spike_detected = False
        self.frames_since_spike = 0
    
    def _preprocess_frame(self, frame: np.ndarray) -> np.ndarray:
        """Convert frame to grayscale and resize for faster processing."""
        if len(frame.shape) == 3:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        else:
            gray = frame
        return cv2.resize(gray, (64, 64))
    
    def analyze_frame(self, frame: np.ndarray) -> Tuple[float, MotionMetrics]:
        """
        Analyze a single frame for motion.
        
        Args:
            frame: BGR video frame
        
        Returns:
            Tuple of (fall_score 0-1, MotionMetrics)
        """
        current = self._preprocess_frame(frame)
        
        if self.prev_frame is None:
            self.prev_frame = current
            return 0.0, MotionMetrics()
        
        # Calculate frame difference
        diff = np.abs(current.astype(float) - self.prev_frame.astype(float))
        
        # Overall motion magnitude
        motion_magnitude = diff.mean()
        self.motion_history.append(motion_magnitude)
        
        # Vertical motion (top vs bottom half changes)
        top_motion = diff[:32, :].mean()
        bottom_motion = diff[32:, :].mean()
        vertical_motion = bottom_motion - top_motion  # Positive = downward
        self.vertical_motion_history.append(vertical_motion)
        
        # Detect motion spike
        motion_spike = False
        baseline_motion = np.mean(list(self.motion_history)[:-1]) if len(self.motion_history) > 1 else 0
        
        if (motion_magnitude > baseline_motion * self.MOTION_SPIKE_RATIO and 
            motion_magnitude > self.MOTION_SPIKE_ABSOLUTE):
            motion_spike = True
            self.spike_detected = True
            self.frames_since_spike = 0
        
        if self.spike_detected:
            self.frames_since_spike += 1
        
        # Detect motion cessation after spike
        motion_cessation = False
        if self.spike_detected and self.frames_since_spike > 3:
            if motion_magnitude < self.CESSATION_THRESHOLD:
                motion_cessation = True
        
        # Reset spike if too long ago
        if self.frames_since_spike > 15:
            self.spike_detected = False
        
        # Calculate variance
        motion_variance = np.var(list(self.motion_history)) if len(self.motion_history) > 3 else 0
        
        metrics = MotionMetrics(
            motion_magnitude=motion_magnitude,
            motion_spike=motion_spike,
            vertical_motion=vertical_motion,
            motion_cessation=motion_cessation,
            motion_variance=motion_variance,
        )
        
        # Calculate fall score with enhanced detection
        score = 0.0
        
        # Motion spike is a strong indicator
        if motion_spike:
            score += 0.35
        
        # Very high motion (dramatic movement like a fall)
        if motion_magnitude > self.HIGH_MOTION_THRESHOLD:
            score += 0.20 * min(motion_magnitude / 50.0, 1.0)
        
        # Significant downward motion (body moving down in frame)
        if vertical_motion > self.VERTICAL_MOTION_THRESHOLD:
            score += 0.25 * min(vertical_motion / 5.0, 1.0)
        
        # Motion cessation after spike (impact - body stopped moving)
        if motion_cessation:
            score += 0.25
        
        # High motion variance (chaotic movement)
        if motion_variance > 30:
            score += 0.05 * min(motion_variance / 100.0, 1.0)
        
        score = min(score, 1.0)
        metrics.confidence = score
        
        self.prev_frame = current
        
        return score, metrics
    
    def analyze_sequence(self, frames: List[np.ndarray]) -> Tuple[float, MotionMetrics]:
        """
        Analyze a sequence of frames with enhanced fall pattern detection.
        
        Distinguishes falls from normal activities like TUG tests and gait.
        KEY DIFFERENCE:
        - TUG: SUSTAINED high motion in middle (person walking for extended time)
        - FALL: BRIEF spike in motion (sudden fall event)
        
        Args:
            frames: List of BGR video frames
        
        Returns:
            Tuple of (max_fall_score, metrics_at_max)
        """
        self.reset()
        
        max_score = 0.0
        best_metrics = MotionMetrics()
        all_scores = []
        all_vertical = []
        all_magnitudes = []
        
        for frame in frames:
            score, metrics = self.analyze_frame(frame)
            all_scores.append(score)
            all_vertical.append(metrics.vertical_motion)
            all_magnitudes.append(metrics.motion_magnitude)
            if score > max_score:
                max_score = score
                best_metrics = metrics
        
        # Skip pattern analysis if not enough frames
        if len(all_magnitudes) < 8:
            best_metrics.confidence = max_score
            return max_score, best_metrics
        
        # Split into quarters for pattern analysis
        segment_size = len(all_magnitudes) // 4
        if segment_size == 0:
            best_metrics.confidence = max_score
            return max_score, best_metrics
            
        segments = [all_magnitudes[i*segment_size:(i+1)*segment_size] for i in range(4)]
        segment_means = [np.mean(s) if s else 0 for s in segments]
        avg_motion = np.mean(all_magnitudes)
        max_segment = max(segment_means)
        min_segment = min(segment_means)
        
        # ====== TUG/SUSTAINED ACTIVITY DETECTION ======
        # TUG pattern: BOTH middle segments have elevated motion compared to endpoints
        # The person walks from chair → walks back → sits down
        middle_seg_1 = segment_means[1]
        middle_seg_2 = segment_means[2]
        baseline = (segment_means[0] + segment_means[-1]) / 2  # Average of start/end
        
        # Both middle segments should be significantly above baseline
        middle_both_elevated = (middle_seg_1 > baseline * 1.5 and middle_seg_2 > baseline * 1.5)
        # At least one should be quite high
        has_high_middle = middle_seg_1 > 5.0 or middle_seg_2 > 5.0
        
        is_tug_pattern = middle_both_elevated and has_high_middle
        
        # ====== FALL PATTERN DETECTION ======  
        # Falls have a SINGLE spike - only ONE segment significantly elevated
        # The spike is sudden, not sustained
        elevated_count = sum(1 for s in segment_means if s > baseline * 2.0)
        spike_is_brief = elevated_count <= 1
        has_spike = max_segment > avg_motion * 1.5
        
        is_fall_pattern = has_spike and spike_is_brief
        
        # Apply pattern-based adjustments
        if is_tug_pattern:
            # Sustained high activity in middle - likely TUG or exercise, not a fall
            max_score = max_score * 0.15  # Very strong reduction
            best_metrics.motion_cessation = False
            best_metrics.motion_spike = False
        elif is_fall_pattern:
            # Single spike pattern - more likely a fall
            max_score = min(max_score + 0.25, 1.0)
            best_metrics.motion_spike = True
            best_metrics.motion_cessation = True
        
        # Additional check: sustained downward motion supports fall hypothesis  
        positive_vertical = sum(1 for v in all_vertical if v > 1.5)
        if positive_vertical > len(all_vertical) * 0.25 and is_fall_pattern:
            max_score = min(max_score + 0.10, 1.0)
        
        best_metrics.confidence = max_score
        return max_score, best_metrics
        
        best_metrics.confidence = max_score
        return max_score, best_metrics


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 3: DEEP LEARNING INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

class DeepLearningFallDetector:
    """
    Wrapper for the EfficientNet+LSTM video classifier.
    
    Provides fall detection scores from the pre-trained deep learning model.
    """
    
    def __init__(self):
        """Initialize DL detector."""
        self._classifier = None
        self._loaded = False
        logger.info("DeepLearningFallDetector initialized (lazy loading)")
    
    def _ensure_loaded(self):
        """Lazy load the video classifier."""
        if not self._loaded:
            try:
                from .video_classifier import get_video_classifier
                self._classifier = get_video_classifier()
                self._classifier.load_model()
                self._loaded = True
                logger.info("DeepLearningFallDetector: Model loaded")
            except Exception as e:
                logger.warning(f"DeepLearningFallDetector: Could not load model: {e}")
                self._loaded = True  # Mark as loaded to avoid retrying
    
    def analyze_frames(self, frames: List[np.ndarray]) -> Tuple[float, Dict[str, float]]:
        """
        Analyze frames using deep learning model.
        
        Args:
            frames: List of BGR video frames
        
        Returns:
            Tuple of (fall_probability, all_probabilities)
        """
        self._ensure_loaded()
        
        if self._classifier is None:
            return 0.0, {}
        
        try:
            result = self._classifier.classify_frames(frames)
            
            # Get fall probability
            fall_prob = result.all_probabilities.get("fall", 0.0)
            
            return fall_prob, result.all_probabilities
            
        except Exception as e:
            logger.error(f"DL analysis failed: {e}")
            return 0.0, {}
    
    def analyze_frames_full(self, frames: List[np.ndarray]):
        """Analyze frames and return full classification result."""
        self._ensure_loaded()
        if self._classifier is None:
            return None
        try:
            return self._classifier.classify_frames(frames)
        except Exception as e:
            logger.error(f"DL full analysis failed: {e}")
            return None


# ═══════════════════════════════════════════════════════════════════════════════
# HYBRID FALL DETECTOR (MAIN CLASS)
# ═══════════════════════════════════════════════════════════════════════════════

class HybridFallDetector:
    """
    Three-layer hybrid fall detection system.
    
    Combines:
    1. Skeleton-based geometric analysis
    2. Motion-based frame analysis
    3. Deep learning classification
    
    Uses ensemble voting and weighted combination for robust detection.
    """
    
    # Thresholds for decision logic - balanced for sensitivity with reduced false positives
    SKELETON_HIGH_CONFIDENCE = 0.70
    MOTION_HIGH_CONFIDENCE = 0.80  # Raised - motion alone needs higher confidence
    DL_HIGH_CONFIDENCE = 0.70
    
    SKELETON_MEDIUM_CONFIDENCE = 0.40
    MOTION_MEDIUM_CONFIDENCE = 0.50  # Raised - motion needs confirmation
    DL_MEDIUM_CONFIDENCE = 0.35
    
    CONSENSUS_THRESHOLD = 2  # Two detectors must agree
    WEIGHTED_THRESHOLD = 0.50  # Balanced threshold
    
    # Weights for combination - motion gets more weight when skeleton is unavailable
    SKELETON_WEIGHT = 0.35
    MOTION_WEIGHT = 0.35
    DL_WEIGHT = 0.30
    
    def __init__(self, enable_dl: bool = True):
        """
        Initialize hybrid fall detector.
        
        Args:
            enable_dl: Whether to use deep learning (can be disabled for speed)
        """
        self.skeleton_detector = SkeletonFallDetector()
        self.motion_detector = MotionFallDetector()
        self.dl_detector = DeepLearningFallDetector() if enable_dl else None
        
        self.enable_dl = enable_dl
        
        # Initialize MediaPipe Pose Landmarker (Tasks API)
        self.pose_detector = None
        if MEDIAPIPE_AVAILABLE and POSE_MODEL_PATH:
            try:
                options = PoseLandmarkerOptions(
                    base_options=BaseOptions(model_asset_path=POSE_MODEL_PATH),
                    running_mode=vision.RunningMode.IMAGE,
                    num_poses=1,
                    min_pose_detection_confidence=0.5,
                    min_tracking_confidence=0.5
                )
                self.pose_detector = PoseLandmarker.create_from_options(options)
                logger.info(f"HybridFallDetector: MediaPipe Pose Landmarker initialized from {POSE_MODEL_PATH}")
            except Exception as e:
                logger.warning(f"HybridFallDetector: MediaPipe init failed: {e}")
        else:
            logger.warning("HybridFallDetector: MediaPipe not available - skeleton detection disabled")
        
        logger.info(f"HybridFallDetector initialized (DL enabled: {enable_dl}, Skeleton enabled: {self.pose_detector is not None})")
    
    def reset(self):
        """Reset all detectors."""
        self.skeleton_detector.reset()
        self.motion_detector.reset()
    
    def _extract_pose(self, frame: np.ndarray) -> Optional[Dict[int, Dict]]:
        """Extract pose landmarks from frame using MediaPipe Tasks API."""
        if self.pose_detector is None:
            return None
        
        try:
            # Convert to RGB for MediaPipe
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Create MediaPipe Image from numpy array
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
            
            # Detect pose
            results = self.pose_detector.detect(mp_image)
            
            if not results.pose_landmarks or len(results.pose_landmarks) == 0:
                return None
            
            # Get first person's landmarks
            pose_landmarks = results.pose_landmarks[0]
            
            landmarks = {}
            for idx, lm in enumerate(pose_landmarks):
                landmarks[idx] = {
                    "x": lm.x,
                    "y": lm.y,
                    "z": lm.z,
                    "visibility": lm.visibility if hasattr(lm, 'visibility') else 1.0
                }
            return landmarks
            
        except Exception as e:
            logger.debug(f"Pose extraction failed: {e}")
            return None
    
    def _determine_fall_type(self, skeleton_metrics: Optional[SkeletonMetrics],
                             motion_metrics: Optional[MotionMetrics]) -> FallType:
        """Determine fall type from metrics."""
        if skeleton_metrics and skeleton_metrics.confidence > 0.5:
            # Use skeleton-based determination
            if skeleton_metrics.spine_angle < 30:
                return FallType.COLLAPSE
            elif skeleton_metrics.head_velocity > 0.2:
                return FallType.FORWARD
            else:
                return FallType.SIDEWAYS
        
        if motion_metrics and motion_metrics.confidence > 0.5:
            if motion_metrics.vertical_motion > 5:
                return FallType.COLLAPSE
            else:
                return FallType.UNKNOWN
        
        return FallType.UNKNOWN
    
    def analyze_frame(self, frame: np.ndarray, 
                      pose_landmarks: Optional[Dict[int, Dict]] = None) -> HybridFallResult:
        """
        Analyze a single frame for fall detection.
        
        Args:
            frame: BGR video frame
            pose_landmarks: Pre-extracted pose landmarks (optional)
        
        Returns:
            HybridFallResult with detection details
        """
        start_time = time.time()
        
        # Layer 1: Skeleton analysis
        skeleton_score = 0.0
        skeleton_metrics = None
        
        landmarks = pose_landmarks or self._extract_pose(frame)
        if landmarks:
            skeleton_score, skeleton_metrics = self.skeleton_detector.analyze(landmarks)
        
        # Layer 2: Motion analysis
        motion_score, motion_metrics = self.motion_detector.analyze_frame(frame)
        
        # Layer 3: DL (not used for single frame - needs sequence)
        dl_score = 0.0
        
        # Combine scores
        is_fall, confidence, source, reason = self._combine_scores(
            skeleton_score, motion_score, dl_score
        )
        
        # Determine fall type
        fall_type = self._determine_fall_type(skeleton_metrics, motion_metrics) if is_fall else FallType.NO_FALL
        
        processing_time = (time.time() - start_time) * 1000
        
        return HybridFallResult(
            is_fall=is_fall,
            confidence=confidence,
            fall_type=fall_type,
            detection_source=source,
            skeleton_score=skeleton_score,
            motion_score=motion_score,
            dl_score=dl_score,
            skeleton_metrics=skeleton_metrics,
            motion_metrics=motion_metrics,
            processing_time_ms=processing_time,
            detection_reason=reason,
        )
    
    def analyze_sequence(self, frames: List[np.ndarray]) -> HybridFallResult:
        """
        Analyze a sequence of frames for fall detection.
        
        This is the main entry point for video analysis.
        
        Args:
            frames: List of BGR video frames
        
        Returns:
            HybridFallResult with detection details
        """
        start_time = time.time()
        
        if not frames:
            return HybridFallResult(
                is_fall=False,
                confidence=0.0,
                fall_type=FallType.NO_FALL,
                detection_source=DetectionSource.NONE,
                skeleton_score=0.0,
                motion_score=0.0,
                dl_score=0.0,
                detection_reason="No frames provided",
            )
        
        self.reset()
        
        # Layer 1: Skeleton analysis (process each frame)
        max_skeleton_score = 0.0
        best_skeleton_metrics = None
        
        for frame in frames:
            landmarks = self._extract_pose(frame)
            if landmarks:
                score, metrics = self.skeleton_detector.analyze(landmarks)
                if score > max_skeleton_score:
                    max_skeleton_score = score
                    best_skeleton_metrics = metrics
        
        # Layer 2: Motion analysis (process sequence)
        motion_score, motion_metrics = self.motion_detector.analyze_sequence(frames)
        
        # Layer 3: Deep learning analysis
        dl_score = 0.0
        dl_probs = {}
        if self.enable_dl and self.dl_detector:
            dl_score, dl_probs = self.dl_detector.analyze_frames(frames)
        
        # Combine scores
        is_fall, confidence, source, reason = self._combine_scores(
            max_skeleton_score, motion_score, dl_score
        )
        
        # Determine fall type
        fall_type = self._determine_fall_type(best_skeleton_metrics, motion_metrics) if is_fall else FallType.NO_FALL
        
        processing_time = (time.time() - start_time) * 1000
        
        return HybridFallResult(
            is_fall=is_fall,
            confidence=confidence,
            fall_type=fall_type,
            detection_source=source,
            skeleton_score=max_skeleton_score,
            motion_score=motion_score,
            dl_score=dl_score,
            skeleton_metrics=best_skeleton_metrics,
            motion_metrics=motion_metrics,
            processing_time_ms=processing_time,
            detection_reason=reason,
        )
    
    def _combine_scores(self, skeleton_score: float, motion_score: float, 
                        dl_score: float) -> Tuple[bool, float, DetectionSource, str]:
        """
        Combine scores from all three layers using ensemble logic.
        
        Returns:
            Tuple of (is_fall, confidence, detection_source, reason)
        """
        # HIGH CONFIDENCE: Single detector is very certain
        if skeleton_score > self.SKELETON_HIGH_CONFIDENCE:
            return True, skeleton_score, DetectionSource.SKELETON, \
                   f"Skeleton high confidence ({skeleton_score:.2f})"
        
        if motion_score > self.MOTION_HIGH_CONFIDENCE:
            return True, motion_score, DetectionSource.MOTION, \
                   f"Motion high confidence ({motion_score:.2f})"
        
        if dl_score > self.DL_HIGH_CONFIDENCE:
            return True, dl_score, DetectionSource.DEEP_LEARNING, \
                   f"DL high confidence ({dl_score:.2f})"
        
        # CONSENSUS: Two or more detectors agree
        votes = sum([
            skeleton_score > self.SKELETON_MEDIUM_CONFIDENCE,
            motion_score > self.MOTION_MEDIUM_CONFIDENCE,
            dl_score > self.DL_MEDIUM_CONFIDENCE,
        ])
        
        if votes >= self.CONSENSUS_THRESHOLD:
            avg_score = (skeleton_score + motion_score + dl_score) / 3
            return True, avg_score, DetectionSource.CONSENSUS, \
                   f"Consensus ({votes}/3 detectors agree)"
        
        # WEIGHTED COMBINATION
        weighted_score = (
            skeleton_score * self.SKELETON_WEIGHT +
            motion_score * self.MOTION_WEIGHT +
            dl_score * self.DL_WEIGHT
        )
        
        if weighted_score > self.WEIGHTED_THRESHOLD:
            return True, weighted_score, DetectionSource.WEIGHTED, \
                   f"Weighted threshold ({weighted_score:.2f})"
        
        # NO FALL DETECTED
        return False, weighted_score, DetectionSource.NONE, "No fall detected"
    
    def analyze_video_file(self, video_path: str, sample_frames: int = 32) -> HybridFallResult:
        """
        Analyze a video file for fall detection.
        
        Args:
            video_path: Path to video file
            sample_frames: Number of frames to sample
        
        Returns:
            HybridFallResult with detection details
        """
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            logger.error(f"Cannot open video: {video_path}")
            return HybridFallResult(
                is_fall=False,
                confidence=0.0,
                fall_type=FallType.NO_FALL,
                detection_source=DetectionSource.NONE,
                skeleton_score=0.0,
                motion_score=0.0,
                dl_score=0.0,
                detection_reason=f"Cannot open video: {video_path}",
            )
        
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        # Sample frames uniformly
        if total_frames >= sample_frames:
            indices = np.linspace(0, total_frames - 1, sample_frames, dtype=int)
        else:
            indices = list(range(total_frames))
        
        frames = []
        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if ret:
                frames.append(frame)
        
        cap.release()
        
        if not frames:
            return HybridFallResult(
                is_fall=False,
                confidence=0.0,
                fall_type=FallType.NO_FALL,
                detection_source=DetectionSource.NONE,
                skeleton_score=0.0,
                motion_score=0.0,
                dl_score=0.0,
                detection_reason="No frames extracted from video",
            )
        
        return self.analyze_sequence(frames)
    
    def cleanup(self):
        """Release resources."""
        if self.pose_detector:
            self.pose_detector.close()


# ═══════════════════════════════════════════════════════════════════════════════
# LIVE/STREAMING FALL DETECTOR
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class LiveDetectionState:
    """State for live/streaming fall detection."""
    frame_count: int = 0
    last_result: Optional[HybridFallResult] = None
    fall_confirmed: bool = False
    fall_confirmation_frames: int = 0
    alert_sent: bool = False
    buffer_full: bool = False
    
    # For continuous monitoring
    consecutive_fall_frames: int = 0
    last_fall_time: Optional[float] = None
    recovery_frames: int = 0
    
    # Inactivity tracking
    low_motion_start: Optional[float] = None  # When low motion started
    inactivity_seconds: float = 0.0
    inactivity_alert_sent: bool = False
    
    # Gait tracking (from DL)
    gait_alert_sent: bool = False


class LiveFallDetector:
    """
    Real-time fall detection for live video streams.
    
    Features:
    - Sliding window buffer for temporal context
    - Frame-by-frame processing with immediate response
    - Fall confirmation logic to reduce false positives
    - Efficient processing optimized for real-time
    - DL analysis runs periodically (not every frame)
    """
    
    # Configuration for live detection
    BUFFER_SIZE = 32  # Frames to keep in sliding window
    DL_ANALYSIS_INTERVAL = 16  # Run DL every N frames (for efficiency)
    FALL_CONFIRMATION_FRAMES = 3  # Must detect fall for N consecutive frames
    RECOVERY_THRESHOLD = 30  # Frames to wait before re-alerting
    MIN_ALERT_INTERVAL = 5.0  # Minimum seconds between alerts
    
    # Thresholds for live detection (slightly lower for faster response)
    LIVE_HIGH_CONFIDENCE = 0.75
    LIVE_MEDIUM_CONFIDENCE = 0.45
    
    def __init__(self, enable_dl: bool = True, target_fps: int = 15):
        """
        Initialize live fall detector.
        
        Args:
            enable_dl: Whether to use deep learning (can slow down processing)
            target_fps: Expected input FPS for timing calculations
        """
        self.hybrid_detector = HybridFallDetector(enable_dl=enable_dl)
        self.enable_dl = enable_dl
        self.target_fps = target_fps
        
        # Sliding window buffer
        self.frame_buffer: deque = deque(maxlen=self.BUFFER_SIZE)
        
        # State tracking
        self.state = LiveDetectionState()
        
        # Performance tracking
        self.processing_times: deque = deque(maxlen=100)
        
        # Background DL inference state
        self._dl_running = False
        self._last_dl_score = 0.0
        self._last_dl_activity = "unknown"
        self._last_dl_probabilities: Dict[str, float] = {}
        self._last_dl_gait_abnormal = False
        self._dl_lock = threading.Lock()
        
        # Inactivity config
        self.INACTIVITY_THRESHOLD = 120.0  # seconds of low motion to trigger alert
        self.LOW_MOTION_THRESHOLD = 0.08  # motion score below this = "low motion"
        
        logger.info(f"LiveFallDetector initialized (DL: {enable_dl}, FPS: {target_fps})")
    
    def reset(self):
        """Reset detector state for new stream."""
        self.frame_buffer.clear()
        self.hybrid_detector.reset()
        self.state = LiveDetectionState()
        self.processing_times.clear()
        self._dl_running = False
        self._last_dl_score = 0.0
        self._last_dl_activity = "unknown"
        self._last_dl_probabilities = {}
        self._last_dl_gait_abnormal = False
        logger.info("LiveFallDetector reset")
    
    def _run_dl_background(self, frames: list):
        """Run DL inference in background thread — does NOT block process_frame."""
        self._dl_running = True
        try:
            start = time.time()
            # Use full classification to get activity + gait info
            full_result = self.hybrid_detector.dl_detector.analyze_frames_full(frames)
            elapsed = (time.time() - start) * 1000
            
            if full_result:
                dl_score = full_result.all_probabilities.get("fall", 0.0)
                with self._dl_lock:
                    self._last_dl_score = dl_score
                    self._last_dl_activity = full_result.activity.value
                    self._last_dl_probabilities = full_result.all_probabilities.copy()
                    self._last_dl_gait_abnormal = full_result.is_gait_abnormal
                logger.info(f"🧠 DL inference complete: activity={full_result.activity.value} "
                           f"fall={dl_score:.3f} arthritis={full_result.all_probabilities.get('arthritis_gait', 0):.3f} "
                           f"gait_abnormal={full_result.is_gait_abnormal} ({elapsed:.0f}ms)")
            else:
                dl_score, all_probs = self.hybrid_detector.dl_detector.analyze_frames(frames)
                with self._dl_lock:
                    self._last_dl_score = dl_score
                logger.info(f"🧠 DL inference (fallback): score={dl_score:.3f} ({elapsed:.0f}ms)")
        except Exception as e:
            logger.error(f"DL background inference failed: {e}")
        finally:
            self._dl_running = False
    
    def process_frame(self, frame: np.ndarray) -> HybridFallResult:
        """
        Process a single frame from live video stream.
        
        This is the main entry point for live detection.
        Call this for each frame received from the camera.
        
        Args:
            frame: BGR video frame from camera
        
        Returns:
            HybridFallResult with current detection state
        """
        start_time = time.time()
        self.state.frame_count += 1
        
        # Add frame to sliding window buffer
        self.frame_buffer.append(frame.copy())
        self.state.buffer_full = len(self.frame_buffer) >= self.BUFFER_SIZE // 2
        
        # Layer 1 & 2: Skeleton + Motion analysis (every frame)
        landmarks = self.hybrid_detector._extract_pose(frame)
        
        skeleton_score = 0.0
        skeleton_metrics = None
        if landmarks:
            skeleton_score, skeleton_metrics = self.hybrid_detector.skeleton_detector.analyze(landmarks)
            if self.state.frame_count <= 3:  # Only log first few frames
                logger.debug(f"  🦴 Skeleton: {len(landmarks)} landmarks, score={skeleton_score:.3f}")
        elif self.state.frame_count <= 3:  # Only log first few frames
            pose_enabled = self.hybrid_detector.pose_detector is not None
            logger.debug(f"  🦴 Skeleton: No landmarks detected (pose_detector enabled: {pose_enabled})")
        
        motion_score, motion_metrics = self.hybrid_detector.motion_detector.analyze_frame(frame)
        
        # Layer 3: DL analysis (NON-BLOCKING - runs in background thread)
        dl_score = self._last_dl_score * 0.95 if self._last_dl_score > 0 else 0.0
        if self.state.last_result and self.state.last_result.dl_score > dl_score:
            dl_score = self.state.last_result.dl_score * 0.95
        
        if (self.enable_dl and 
            self.state.frame_count % self.DL_ANALYSIS_INTERVAL == 0 and
            len(self.frame_buffer) >= self.BUFFER_SIZE // 2 and
            not self._dl_running):
            
            # Snapshot buffer for background DL analysis
            frames_for_dl = list(self.frame_buffer)
            dl_thread = threading.Thread(
                target=self._run_dl_background, 
                args=(frames_for_dl,),
                daemon=True,
                name="dl-inference"
            )
            dl_thread.start()
            logger.info(f"🧠 DL inference started in background (frame #{self.state.frame_count}, {len(frames_for_dl)} frames)")
        
        # Combine scores with live-optimized thresholds
        is_fall, confidence, source, reason = self._combine_live_scores(
            skeleton_score, motion_score, dl_score
        )
        
        # Apply fall confirmation logic
        is_fall, confidence, reason = self._apply_confirmation_logic(
            is_fall, confidence, reason
        )
        
        # Determine fall type
        fall_type = FallType.NO_FALL
        if is_fall:
            fall_type = self.hybrid_detector._determine_fall_type(skeleton_metrics, motion_metrics)
        
        processing_time = (time.time() - start_time) * 1000
        self.processing_times.append(processing_time)
        
        # Get DL activity/gait info (thread-safe read)
        with self._dl_lock:
            dl_activity = self._last_dl_activity
            dl_probabilities = self._last_dl_probabilities.copy() if self._last_dl_probabilities else None
            gait_abnormal = self._last_dl_gait_abnormal
        
        # Inactivity tracking (based on motion score)
        now = time.time()
        if motion_score < self.LOW_MOTION_THRESHOLD:
            if self.state.low_motion_start is None:
                self.state.low_motion_start = now
            self.state.inactivity_seconds = now - self.state.low_motion_start
        else:
            self.state.low_motion_start = None
            self.state.inactivity_seconds = 0.0
        
        inactivity_alert = (self.state.inactivity_seconds >= self.INACTIVITY_THRESHOLD 
                           and not self.state.inactivity_alert_sent)
        if inactivity_alert:
            self.state.inactivity_alert_sent = True
            logger.warning(f"⏰ INACTIVITY ALERT: No movement for {self.state.inactivity_seconds:.0f}s")
        
        result = HybridFallResult(
            is_fall=is_fall,
            confidence=confidence,
            fall_type=fall_type,
            detection_source=source,
            skeleton_score=skeleton_score,
            motion_score=motion_score,
            dl_score=dl_score,
            skeleton_metrics=skeleton_metrics,
            motion_metrics=motion_metrics,
            processing_time_ms=processing_time,
            detection_reason=reason,
            dl_activity=dl_activity,
            dl_probabilities=dl_probabilities,
            gait_abnormal=gait_abnormal,
            inactivity_seconds=self.state.inactivity_seconds,
            inactivity_alert=inactivity_alert,
        )
        
        self.state.last_result = result
        return result
    
    def _combine_live_scores(self, skeleton_score: float, motion_score: float,
                             dl_score: float) -> Tuple[bool, float, DetectionSource, str]:
        """
        Combine scores with logic optimized for live detection.
        
        Slightly more aggressive than batch processing for faster response.
        """
        # High confidence from any single detector
        if skeleton_score > self.LIVE_HIGH_CONFIDENCE:
            return True, skeleton_score, DetectionSource.SKELETON, \
                   f"Live: Skeleton high ({skeleton_score:.2f})"
        
        if motion_score > self.LIVE_HIGH_CONFIDENCE and dl_score > 0.4:
            # Motion needs DL confirmation for live detection
            return True, (motion_score + dl_score) / 2, DetectionSource.CONSENSUS, \
                   f"Live: Motion+DL ({motion_score:.2f}, {dl_score:.2f})"
        
        if dl_score > self.LIVE_HIGH_CONFIDENCE:
            return True, dl_score, DetectionSource.DEEP_LEARNING, \
                   f"Live: DL high ({dl_score:.2f})"
        
        # Consensus detection
        votes = sum([
            skeleton_score > self.LIVE_MEDIUM_CONFIDENCE,
            motion_score > self.LIVE_MEDIUM_CONFIDENCE,
            dl_score > self.LIVE_MEDIUM_CONFIDENCE,
        ])
        
        if votes >= 2:
            avg_score = (skeleton_score + motion_score + dl_score) / 3
            return True, avg_score, DetectionSource.CONSENSUS, \
                   f"Live: Consensus ({votes}/3)"
        
        # Weighted combination
        weighted = (skeleton_score * 0.35 + motion_score * 0.35 + dl_score * 0.30)
        
        return False, weighted, DetectionSource.NONE, "Live: No fall"
    
    def _apply_confirmation_logic(self, is_fall: bool, confidence: float,
                                   reason: str) -> Tuple[bool, float, str]:
        """
        Apply confirmation logic to reduce false positives.
        
        Requires multiple consecutive fall detections before confirming.
        """
        current_time = time.time()
        
        if is_fall:
            self.state.consecutive_fall_frames += 1
            self.state.recovery_frames = 0
            
            # Check if we have enough consecutive detections
            if self.state.consecutive_fall_frames >= self.FALL_CONFIRMATION_FRAMES:
                self.state.fall_confirmed = True
                
                # Check minimum alert interval
                if (self.state.last_fall_time is None or 
                    current_time - self.state.last_fall_time >= self.MIN_ALERT_INTERVAL):
                    
                    self.state.last_fall_time = current_time
                    self.state.alert_sent = True
                    
                    return True, confidence, f"{reason} [CONFIRMED]"
                else:
                    # Within alert cooldown
                    return True, confidence * 0.8, f"{reason} [Cooldown]"
            else:
                # Still confirming
                return False, confidence * 0.5, f"{reason} [Confirming: {self.state.consecutive_fall_frames}/{self.FALL_CONFIRMATION_FRAMES}]"
        else:
            # No fall detected - track recovery
            self.state.recovery_frames += 1
            
            if self.state.recovery_frames >= self.RECOVERY_THRESHOLD:
                self.state.consecutive_fall_frames = 0
                self.state.fall_confirmed = False
                self.state.alert_sent = False
            
            return False, confidence, reason
    
    def should_send_alert(self) -> bool:
        """Check if an alert should be sent now."""
        return self.state.fall_confirmed and self.state.alert_sent
    
    def get_avg_processing_time(self) -> float:
        """Get average processing time in milliseconds."""
        if not self.processing_times:
            return 0.0
        return sum(self.processing_times) / len(self.processing_times)
    
    def can_process_realtime(self) -> bool:
        """Check if processing is fast enough for real-time."""
        avg_time = self.get_avg_processing_time()
        frame_budget = 1000.0 / self.target_fps
        return avg_time < frame_budget
    
    def get_state_summary(self) -> Dict[str, Any]:
        """Get current detection state for debugging/monitoring."""
        return {
            "frame_count": self.state.frame_count,
            "buffer_size": len(self.frame_buffer),
            "buffer_full": self.state.buffer_full,
            "fall_confirmed": self.state.fall_confirmed,
            "consecutive_fall_frames": self.state.consecutive_fall_frames,
            "alert_sent": self.state.alert_sent,
            "avg_processing_ms": self.get_avg_processing_time(),
            "realtime_capable": self.can_process_realtime(),
            "last_result": self.state.last_result.to_dict() if self.state.last_result else None,
        }
    
    def cleanup(self):
        """Release resources."""
        self.hybrid_detector.cleanup()


# ═══════════════════════════════════════════════════════════════════════════════
# SINGLETON ACCESSORS
# ═══════════════════════════════════════════════════════════════════════════════

_hybrid_detector: Optional[HybridFallDetector] = None
_live_detector: Optional[LiveFallDetector] = None


def get_hybrid_fall_detector(enable_dl: bool = True) -> HybridFallDetector:
    """Get singleton HybridFallDetector instance."""
    global _hybrid_detector
    if _hybrid_detector is None:
        _hybrid_detector = HybridFallDetector(enable_dl=enable_dl)
    return _hybrid_detector


def get_live_fall_detector(enable_dl: bool = True, target_fps: int = 15) -> LiveFallDetector:
    """Get singleton LiveFallDetector instance for real-time streams."""
    global _live_detector
    if _live_detector is None:
        _live_detector = LiveFallDetector(enable_dl=enable_dl, target_fps=target_fps)
    return _live_detector


# ═══════════════════════════════════════════════════════════════════════════════
# CLI TEST
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import sys
    
    logging.basicConfig(level=logging.INFO)
    
    print("=" * 70)
    print("SMARTCARE+ Hybrid Fall Detection System")
    print("Three-Layer Ensemble: Skeleton + Motion + Deep Learning")
    print("=" * 70)
    
    detector = get_hybrid_fall_detector(enable_dl=True)
    
    # Test with video file if provided
    if len(sys.argv) > 1:
        video_path = sys.argv[1]
        print(f"\nAnalyzing: {video_path}")
        result = detector.analyze_video_file(video_path)
        
        print(f"\n{'='*50}")
        print(f"RESULT: {'🚨 FALL DETECTED' if result.is_fall else '✅ NO FALL'}")
        print(f"{'='*50}")
        print(f"Confidence: {result.confidence:.1%}")
        print(f"Fall Type: {result.fall_type.value}")
        print(f"Detection Source: {result.detection_source.value}")
        print(f"Reason: {result.detection_reason}")
        print(f"\nLayer Scores:")
        print(f"  Skeleton: {result.skeleton_score:.3f}")
        print(f"  Motion: {result.motion_score:.3f}")
        print(f"  Deep Learning: {result.dl_score:.3f}")
        print(f"\nProcessing Time: {result.processing_time_ms:.1f}ms")
    else:
        print("\nUsage: python hybrid_fall_detector.py <video_path>")
        print("\nNo video provided. Run with a video file to test.")
