"""
SMARTCARE+ Guardian Service Models

Fall detection, gait analysis, TUG test, and activity monitoring.
Includes hybrid 3-layer fall detection system.
"""

from .gait_analyzer import (
    GaitAnalyzer,
    GaitMetrics,
    GaitAnalysisResult,
    GaitPattern,
    FallRiskLevel,
    FootPosition,
    get_gait_analyzer
)

from .tug_handler import (
    TUGTestHandler,
    TUGTestResult,
    TUGPhase,
    TUGPhaseResult,
    MobilityLevel,
    ActivityClassifier,
    ActivityType,
    get_tug_handler
)

from .video_classifier import (
    VideoClassifier,
    VideoClassificationResult,
    VideoActivityType,
    get_video_classifier
)

from .hybrid_fall_detector import (
    HybridFallDetector,
    HybridFallResult,
    SkeletonFallDetector,
    MotionFallDetector,
    DeepLearningFallDetector,
    LiveFallDetector,
    LiveDetectionState,
    FallType,
    DetectionSource,
    SkeletonMetrics,
    MotionMetrics,
    get_hybrid_fall_detector,
    get_live_fall_detector,
)

__all__ = [
    # Gait Analyzer
    "GaitAnalyzer",
    "GaitMetrics",
    "GaitAnalysisResult",
    "GaitPattern",
    "FallRiskLevel",
    "FootPosition",
    "get_gait_analyzer",
    # TUG Handler
    "TUGTestHandler",
    "TUGTestResult",
    "TUGPhase",
    "TUGPhaseResult",
    "MobilityLevel",
    "ActivityClassifier",
    "ActivityType",
    "get_tug_handler",
    # Video Classifier (Deep Learning)
    "VideoClassifier",
    "VideoClassificationResult",
    "VideoActivityType",
    "get_video_classifier",
    # Hybrid Fall Detector (3-Layer Ensemble)
    "HybridFallDetector",
    "HybridFallResult",
    "SkeletonFallDetector",
    "MotionFallDetector",
    "DeepLearningFallDetector",
    "LiveFallDetector",
    "LiveDetectionState",
    "FallType",
    "DetectionSource",
    "SkeletonMetrics",
    "MotionMetrics",
    "get_hybrid_fall_detector",
    "get_live_fall_detector",
]
