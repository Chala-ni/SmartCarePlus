/// SMARTCARE+ Skeleton Overlay Painter
///
/// Owner: Neelaka
/// Animated skeleton overlay for exercise monitoring
/// Shows real-time pose skeleton with reference pose overlay
/// Helps patients match correct exercise form without reference videos

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

/// Represents a single landmark point from pose detection
class PoseLandmark {
  final double x; // Normalized 0-1 (left to right)
  final double y; // Normalized 0-1 (top to bottom)
  final double z; // Depth
  final double visibility; // 0-1 confidence
  
  const PoseLandmark({
    required this.x,
    required this.y,
    this.z = 0.0,
    this.visibility = 1.0,
  });
  
  factory PoseLandmark.fromJson(Map<String, dynamic> json) {
    return PoseLandmark(
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      z: (json['z'] ?? 0.0).toDouble(),
      visibility: (json['visibility'] ?? 1.0).toDouble(),
    );
  }
  
  Offset toOffset(Size size, {bool mirrorX = true}) {
    // Mirror X for front camera (selfie mode)
    final adjustedX = mirrorX ? (1.0 - x) : x;
    return Offset(adjustedX * size.width, y * size.height);
  }
}

/// Reference pose angles for an exercise phase
class ReferencePose {
  final String phase;
  final Map<String, double> angles; // e.g., {"knee": 90.0, "hip": 90.0}
  final List<String> visualCues;
  
  const ReferencePose({
    required this.phase,
    required this.angles,
    this.visualCues = const [],
  });
  
  factory ReferencePose.fromJson(Map<String, dynamic> json) {
    return ReferencePose(
      phase: json['current_phase'] ?? 'start',
      angles: Map<String, double>.from(
        (json['reference_angles'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v ?? 0.0).toDouble()),
        ),
      ),
      visualCues: List<String>.from(json['visual_cues'] ?? []),
    );
  }
}

/// Skeleton connections (MediaPipe landmark indices)
class SkeletonConnections {
  // MediaPipe Pose Landmark indices
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int mouthLeft = 9;
  static const int mouthRight = 10;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;
  
  // Body connections for drawing skeleton
  static const List<List<int>> bodyConnections = [
    // Face
    [nose, leftEyeInner],
    [leftEyeInner, leftEye],
    [leftEye, leftEyeOuter],
    [leftEyeOuter, leftEar],
    [nose, rightEyeInner],
    [rightEyeInner, rightEye],
    [rightEye, rightEyeOuter],
    [rightEyeOuter, rightEar],
    [mouthLeft, mouthRight],
    
    // Torso
    [leftShoulder, rightShoulder],
    [leftShoulder, leftHip],
    [rightShoulder, rightHip],
    [leftHip, rightHip],
    
    // Left arm
    [leftShoulder, leftElbow],
    [leftElbow, leftWrist],
    [leftWrist, leftPinky],
    [leftWrist, leftIndex],
    [leftWrist, leftThumb],
    
    // Right arm
    [rightShoulder, rightElbow],
    [rightElbow, rightWrist],
    [rightWrist, rightPinky],
    [rightWrist, rightIndex],
    [rightWrist, rightThumb],
    
    // Left leg
    [leftHip, leftKnee],
    [leftKnee, leftAnkle],
    [leftAnkle, leftHeel],
    [leftAnkle, leftFootIndex],
    
    // Right leg
    [rightHip, rightKnee],
    [rightKnee, rightAnkle],
    [rightAnkle, rightHeel],
    [rightAnkle, rightFootIndex],
  ];
  
  // Major joints for highlighting
  static const List<int> majorJoints = [
    leftShoulder, rightShoulder,
    leftElbow, rightElbow,
    leftWrist, rightWrist,
    leftHip, rightHip,
    leftKnee, rightKnee,
    leftAnkle, rightAnkle,
  ];
}

/// Custom painter for skeleton overlay
class SkeletonPainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Color skeletonColor;
  final Color jointColor;
  final double strokeWidth;
  final double jointRadius;
  final bool mirrorX;
  final double minVisibility;
  
  // Optional reference skeleton (ghost)
  final List<PoseLandmark>? referenceLandmarks;
  final Color? referenceColor;
  
  // Form quality for coloring
  final String? formQuality;
  
  SkeletonPainter({
    required this.landmarks,
    this.skeletonColor = AppColors.neonCyan,
    this.jointColor = AppColors.neonCyan,
    this.strokeWidth = 3.0,
    this.jointRadius = 6.0,
    this.mirrorX = true,
    this.minVisibility = 0.5,
    this.referenceLandmarks,
    this.referenceColor,
    this.formQuality,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty || landmarks.length < 33) return;
    
    // Draw reference skeleton first (behind user skeleton)
    if (referenceLandmarks != null && referenceLandmarks!.length >= 33) {
      _drawSkeleton(
        canvas, 
        size, 
        referenceLandmarks!,
        referenceColor ?? AppColors.neonGreen.withOpacity(0.4),
        strokeWidth * 0.8,
        jointRadius * 0.7,
        isReference: true,
      );
    }
    
    // Draw user skeleton on top
    final effectiveColor = _getColorForFormQuality(formQuality);
    _drawSkeleton(
      canvas, 
      size, 
      landmarks,
      effectiveColor,
      strokeWidth,
      jointRadius,
      isReference: false,
    );
  }
  
  void _drawSkeleton(
    Canvas canvas,
    Size size,
    List<PoseLandmark> lms,
    Color color,
    double stroke,
    double radius,
    {bool isReference = false}
  ) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final jointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    // Draw connections
    for (final connection in SkeletonConnections.bodyConnections) {
      final start = lms[connection[0]];
      final end = lms[connection[1]];
      
      // Skip if either point is not visible enough
      if (start.visibility < minVisibility || end.visibility < minVisibility) {
        continue;
      }
      
      final startOffset = start.toOffset(size, mirrorX: mirrorX);
      final endOffset = end.toOffset(size, mirrorX: mirrorX);
      
      // Draw glow effect (only for user skeleton)
      if (!isReference) {
        canvas.drawLine(startOffset, endOffset, glowPaint);
      }
      
      // Draw the line
      canvas.drawLine(startOffset, endOffset, linePaint);
    }
    
    // Draw major joint points
    for (final jointIndex in SkeletonConnections.majorJoints) {
      if (jointIndex >= lms.length) continue;
      
      final joint = lms[jointIndex];
      if (joint.visibility < minVisibility) continue;
      
      final offset = joint.toOffset(size, mirrorX: mirrorX);
      
      // Outer glow (only for user skeleton)
      if (!isReference) {
        canvas.drawCircle(
          offset,
          radius + 3,
          Paint()
            ..color = color.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      
      // Main joint circle
      canvas.drawCircle(offset, radius, jointPaint);
      
      // Center dot
      canvas.drawCircle(
        offset,
        radius * 0.4,
        Paint()..color = Colors.white.withOpacity(isReference ? 0.5 : 0.8),
      );
    }
  }
  
  Color _getColorForFormQuality(String? quality) {
    // Use consistent neonCyan for user skeleton to avoid confusing
    // color changes. Form quality is communicated via the score badge
    // and quality label in the UI instead.
    return skeletonColor;
  }
  
  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return landmarks != oldDelegate.landmarks ||
           referenceLandmarks != oldDelegate.referenceLandmarks ||
           formQuality != oldDelegate.formQuality;
  }
}

/// Widget that displays skeleton overlay on camera preview
class SkeletonOverlay extends StatelessWidget {
  final List<Map<String, dynamic>>? landmarkData;
  final String? formQuality;
  final bool showReference;
  final Map<String, dynamic>? formGuidance;
  
  const SkeletonOverlay({
    super.key,
    this.landmarkData,
    this.formQuality,
    this.showReference = false,
    this.formGuidance,
  });
  
  @override
  Widget build(BuildContext context) {
    if (landmarkData == null || landmarkData!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Parse landmarks - handle both ordered list and index-based format
    // Create a 33-element list with default invisible landmarks
    final landmarks = List<PoseLandmark>.generate(
      33,
      (_) => const PoseLandmark(x: 0, y: 0, z: 0, visibility: 0),
    );
    
    // Fill in the landmarks at their correct indices
    for (final json in landmarkData!) {
      final data = json as Map<String, dynamic>;
      final landmarkIndex = data['index'] as int?;
      if (landmarkIndex != null && landmarkIndex >= 0 && landmarkIndex < 33) {
        landmarks[landmarkIndex] = PoseLandmark.fromJson(data);
      }
    }
    
    // Check if we have enough visible landmarks
    final visibleCount = landmarks.where((lm) => lm.visibility > 0.3).length;
    if (visibleCount < 10) {
      return const SizedBox.shrink();
    }
    
    return CustomPaint(
      painter: SkeletonPainter(
        landmarks: landmarks,
        formQuality: formQuality,
        mirrorX: true, // Front camera
      ),
      size: Size.infinite,
    );
  }
}

/// Form guidance overlay widget
class FormGuidanceOverlay extends StatelessWidget {
  final Map<String, dynamic>? formGuidance;
  final bool isVisible;
  
  const FormGuidanceOverlay({
    super.key,
    this.formGuidance,
    this.isVisible = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!isVisible || formGuidance == null) {
      return const SizedBox.shrink();
    }
    
    final matchScore = (formGuidance!['match_score'] ?? 100.0).toDouble();
    final isAcceptable = formGuidance!['is_acceptable'] ?? true;
    final priorityFix = formGuidance!['priority_fix'] ?? '';
    final visualCues = List<String>.from(formGuidance!['visual_cues'] ?? []);
    
    if (isAcceptable && priorityFix.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(matchScore).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(matchScore),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getBorderColor(matchScore).withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Match Score
            Row(
              children: [
                Icon(
                  _getIcon(matchScore),
                  color: _getBorderColor(matchScore),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Form: ${matchScore.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _getBorderColor(matchScore),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 100,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: matchScore / 100.0,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getBorderColor(matchScore),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Priority correction
            if (priorityFix.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      priorityFix,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            // Visual cues
            if (visualCues.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),
              ...visualCues.take(2).map((cue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white54, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cue,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getBackgroundColor(double score) {
    if (score >= 90) return Colors.black;
    if (score >= 70) return const Color(0xFF1A1A2E);
    if (score >= 50) return const Color(0xFF2E1A1A);
    return const Color(0xFF3D1A1A);
  }
  
  Color _getBorderColor(double score) {
    if (score >= 90) return AppColors.neonGreen;
    if (score >= 70) return AppColors.neonCyan;
    if (score >= 50) return AppColors.neonOrange;
    return AppColors.neonRed;
  }
  
  IconData _getIcon(double score) {
    if (score >= 90) return Icons.check_circle;
    if (score >= 70) return Icons.thumb_up;
    if (score >= 50) return Icons.info;
    return Icons.warning;
  }
}
