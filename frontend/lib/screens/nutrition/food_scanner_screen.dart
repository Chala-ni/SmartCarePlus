/// SMARTCARE+ Food Scanner Screen
///
/// Owner: Dilshan
/// AI-powered food recognition using camera

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  bool _isScanning = false;
  bool _foodDetected = false;
  Map<String, dynamic>? _detectedFood;

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _foodDetected = false;
    });
    
    // Simulate food detection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _foodDetected = true;
          _detectedFood = {
            'name': 'Grilled Chicken Salad',
            'confidence': 0.92,
            'calories': 320,
            'protein': 28,
            'carbs': 15,
            'fat': 18,
            'fiber': 6,
            'servingSize': '1 bowl (250g)',
          };
        });
      }
    });
  }

  void _resetScan() {
    setState(() {
      _isScanning = false;
      _foodDetected = false;
      _detectedFood = null;
    });
  }

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
                        'Food Scanner',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              
              // Camera Preview Area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isScanning 
                          ? AppColors.neonCyan 
                          : _foodDetected 
                              ? AppColors.neonGreen 
                              : AppColors.glassBorder,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Camera placeholder
                        Container(
                          color: AppColors.surfaceLight,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _foodDetected ? Icons.check_circle : Icons.camera_alt,
                                  size: 64,
                                  color: _foodDetected 
                                      ? AppColors.neonGreen 
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _foodDetected 
                                      ? 'Food Detected!' 
                                      : 'Camera Preview',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _foodDetected 
                                        ? AppColors.neonGreen 
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Scanning overlay
                        if (_isScanning)
                          Container(
                            color: AppColors.neonCyan.withOpacity(0.1),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.neonCyan,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Analyzing food...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neonCyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Corner guides
                        if (!_foodDetected && !_isScanning) ...[
                          Positioned(
                            top: 30,
                            left: 30,
                            child: _buildCornerGuide(true, true),
                          ),
                          Positioned(
                            top: 30,
                            right: 30,
                            child: _buildCornerGuide(true, false),
                          ),
                          Positioned(
                            bottom: 30,
                            left: 30,
                            child: _buildCornerGuide(false, true),
                          ),
                          Positioned(
                            bottom: 30,
                            right: 30,
                            child: _buildCornerGuide(false, false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Results or Scan Button
              if (_foodDetected && _detectedFood != null)
                _buildFoodResults()
              else
                _buildScanButton(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerGuide(bool isTop, bool isLeft) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: CornerGuidePainter(
          isTop: isTop,
          isLeft: isLeft,
          color: AppColors.neonCyan,
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isScanning ? null : _startScanning,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isScanning 
                    ? AppColors.surfaceLight 
                    : AppColors.neonCyan,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonCyan.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isScanning ? Icons.hourglass_empty : Icons.camera,
                color: _isScanning ? AppColors.textSecondary : Colors.black,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning ? 'Scanning...' : 'Tap to scan food',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodResults() {
    final food = _detectedFood!;
    final confidence = (food['confidence'] as double) * 100;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassmorphicCard(
          glowColor: AppColors.neonGreen,
          glowIntensity: 0.1,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          food['servingSize'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${confidence.toInt()}% match',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.neonGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Nutrition info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNutrientChip('${food['calories']} cal', AppColors.neonOrange),
                  _buildNutrientChip('${food['protein']}g protein', AppColors.neonCyan),
                  _buildNutrientChip('${food['carbs']}g carbs', AppColors.neonPurple),
                  _buildNutrientChip('${food['fat']}g fat', AppColors.neonRed),
                ],
              ),
              
              const Spacer(),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetScan,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.glassBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Scan Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Add to meal log
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 6),
                          Text(
                            'Add to Meal',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class CornerGuidePainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color color;

  CornerGuidePainter({
    required this.isTop,
    required this.isLeft,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
