/// SMARTCARE+ Gait Analysis Screen
///
/// Owner: Neelaka
/// Real-time gait analysis with camera feed and pose overlay

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class GaitAnalysisScreen extends ConsumerStatefulWidget {
  const GaitAnalysisScreen({super.key});

  @override
  ConsumerState<GaitAnalysisScreen> createState() => _GaitAnalysisScreenState();
}

class _GaitAnalysisScreenState extends ConsumerState<GaitAnalysisScreen> {
  bool _isAnalyzing = false;
  bool _showResults = false;
  
  // Mock metrics
  final Map<String, dynamic> _metrics = {
    'strideLength': 45.2,
    'cadence': 98,
    'speed': 0.85,
    'symmetry': 0.92,
    'hipAngle': 28.5,
    'kneeAngle': 42.3,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Gait Analysis',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isAnalyzing 
                            ? AppColors.neonGreen.withOpacity(0.15)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: _isAnalyzing 
                            ? Border.all(color: AppColors.neonGreen)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: _isAnalyzing ? AppColors.neonGreen : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isAnalyzing ? 'LIVE' : 'READY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isAnalyzing ? AppColors.neonGreen : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Camera Preview Area
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isAnalyzing ? AppColors.neonCyan : AppColors.glassBorder,
                      width: _isAnalyzing ? 2 : 1,
                    ),
                    boxShadow: _isAnalyzing
                        ? [
                            BoxShadow(
                              color: AppColors.neonCyan.withOpacity(0.2),
                              blurRadius: 20,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // Camera placeholder
                      Center(
                        child: _isAnalyzing
                            ? _buildAnalyzingView()
                            : _buildReadyView(),
                      ),
                      
                      // Pose overlay (when analyzing)
                      if (_isAnalyzing)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: PoseOverlayPainter(),
                          ),
                        ),
                      
                      // Instructions
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isAnalyzing
                                ? 'Walk naturally. We\'re analyzing your gait pattern...'
                                : 'Position camera to capture full body and start walking',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Real-time Metrics Panel
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gait Metrics',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_showResults)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.neonGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: AppColors.neonGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    'Normal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.neonGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Metrics Grid
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(child: _buildMetricCard(
                                    'Stride Length',
                                    _showResults ? '${_metrics['strideLength']} cm' : '--',
                                    Icons.straighten,
                                    AppColors.neonCyan,
                                  )),
                                  const SizedBox(height: 8),
                                  Expanded(child: _buildMetricCard(
                                    'Speed',
                                    _showResults ? '${_metrics['speed']} m/s' : '--',
                                    Icons.speed,
                                    AppColors.neonGreen,
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(child: _buildMetricCard(
                                    'Cadence',
                                    _showResults ? '${_metrics['cadence']} spm' : '--',
                                    Icons.graphic_eq,
                                    AppColors.neonOrange,
                                  )),
                                  const SizedBox(height: 8),
                                  Expanded(child: _buildMetricCard(
                                    'Symmetry',
                                    _showResults ? '${(_metrics['symmetry'] * 100).toInt()}%' : '--',
                                    Icons.balance,
                                    AppColors.neonPurple,
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Start/Stop Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (_isAnalyzing) {
                                _isAnalyzing = false;
                                _showResults = true;
                              } else {
                                _isAnalyzing = true;
                                _showResults = false;
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isAnalyzing ? AppColors.neonRed : AppColors.neonCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_isAnalyzing ? Icons.stop : Icons.play_arrow, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                _isAnalyzing ? 'Stop Analysis' : 'Start Analysis',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadyView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.videocam_outlined,
          size: 64,
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'Camera Ready',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap start to begin gait analysis',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonCyan.withOpacity(0.5)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Analyzing...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.neonCyan,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _showResults ? color : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Simple pose overlay painter for visualization
class PoseOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neonCyan.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.neonCyan
      ..style = PaintingStyle.fill;

    // Simple skeleton representation (static for demo)
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Head
    canvas.drawCircle(Offset(centerX, centerY - 80), 8, dotPaint);
    
    // Shoulders
    canvas.drawLine(Offset(centerX - 40, centerY - 50), Offset(centerX + 40, centerY - 50), paint);
    
    // Spine
    canvas.drawLine(Offset(centerX, centerY - 50), Offset(centerX, centerY + 20), paint);
    
    // Arms
    canvas.drawLine(Offset(centerX - 40, centerY - 50), Offset(centerX - 60, centerY), paint);
    canvas.drawLine(Offset(centerX + 40, centerY - 50), Offset(centerX + 60, centerY), paint);
    
    // Hips
    canvas.drawLine(Offset(centerX - 25, centerY + 20), Offset(centerX + 25, centerY + 20), paint);
    
    // Legs
    canvas.drawLine(Offset(centerX - 25, centerY + 20), Offset(centerX - 30, centerY + 80), paint);
    canvas.drawLine(Offset(centerX + 25, centerY + 20), Offset(centerX + 30, centerY + 80), paint);

    // Joint dots
    final joints = [
      Offset(centerX - 40, centerY - 50),
      Offset(centerX + 40, centerY - 50),
      Offset(centerX, centerY - 50),
      Offset(centerX, centerY + 20),
      Offset(centerX - 25, centerY + 20),
      Offset(centerX + 25, centerY + 20),
      Offset(centerX - 30, centerY + 80),
      Offset(centerX + 30, centerY + 80),
    ];

    for (final joint in joints) {
      canvas.drawCircle(joint, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
