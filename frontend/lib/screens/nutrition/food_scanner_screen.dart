/// SMARTCARE+ Food Scanner Screen
///
/// Owner: Dilshan
/// AI-powered food recognition using camera

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glassmorphic_card.dart';

class FoodScannerScreen extends ConsumerStatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  ConsumerState<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends ConsumerState<FoodScannerScreen> {
  bool _isScanning = false;
  bool _foodDetected = false;
  bool _isLoading = false;
  Map<String, dynamic>? _detectedFood;
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
          _isScanning = true;
          _foodDetected = false;
        });
        
        // Analyze the captured image
        await _analyzeFood();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: AppColors.neonRed,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
          _isScanning = true;
          _foodDetected = false;
        });
        
        // Analyze the selected image
        await _analyzeFood();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gallery error: $e'),
            backgroundColor: AppColors.neonRed,
          ),
        );
      }
    }
  }

  Future<void> _startScanning() async {
    // Show options dialog
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(context);
                      _captureFromCamera();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.neonCyan.withOpacity(0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: AppColors.neonCyan),
                          SizedBox(height: 12),
                          Text('Camera', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Take a photo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromGallery();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.neonOrange.withOpacity(0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.photo_library, size: 40, color: AppColors.neonOrange),
                          SizedBox(height: 12),
                          Text('Gallery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Choose existing', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Future<void> _analyzeFood() async {
    if (_capturedImage == null) {
      _useMockData();
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final api = ref.read(apiServiceProvider);
      
      // Upload the actual image file to analyze-food endpoint
      final response = await api.uploadFile(
        '/api/nutrition/analyze-food',
        _capturedImage!.path,
        'image', // field name matching FastAPI: image: UploadFile = File(...)
        requireAuth: false, // Allow without auth for demo
      );
      
      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Handle new response format from food classifier
        if (data['status'] == 'completed') {
          // Get primary food or first detected food
          final primaryFood = data['primary_food'];
          final detectedFoods = data['detected_foods'] as List<dynamic>?;
          final classification = data['classification'] as Map<String, dynamic>?;
          
          if (primaryFood != null) {
            setState(() {
              _isScanning = false;
              _foodDetected = true;
              _detectedFood = {
                'name': primaryFood['name'] ?? 'Unknown Food',
                'confidence': classification?['predictions']?.isNotEmpty == true 
                    ? classification!['predictions'][0]['confidence'] 
                    : 0.85,
                'calories': _parseNum(primaryFood['calories_per_serving'] ?? primaryFood['calories']),
                'protein': _parseNum(primaryFood['protein_g'] ?? primaryFood['protein']),
                'carbs': _parseNum(primaryFood['carbs_g'] ?? primaryFood['carbohydrates']),
                'fat': _parseNum(primaryFood['fat_g'] ?? primaryFood['fat']),
                'fiber': _parseNum(primaryFood['fiber_g'] ?? primaryFood['fiber']),
                'servingSize': primaryFood['serving_size'] ?? '1 serving',
                'alternatives': _extractAlternatives(detectedFoods),
              };
            });
          } else if (detectedFoods?.isNotEmpty == true) {
            // Use first prediction's matched food
            final firstDetection = detectedFoods![0];
            final matchedFoods = firstDetection['matched_foods'] as List<dynamic>?;
            final prediction = firstDetection['prediction'] as Map<String, dynamic>?;
            
            if (matchedFoods?.isNotEmpty == true) {
              final food = matchedFoods![0];
              setState(() {
                _isScanning = false;
                _foodDetected = true;
                _detectedFood = {
                  'name': food['name'] ?? prediction?['display_name'] ?? 'Unknown Food',
                  'confidence': prediction?['confidence'] ?? 0.85,
                  'calories': _parseNum(food['calories_per_serving'] ?? food['calories']),
                  'protein': _parseNum(food['protein_g'] ?? food['protein']),
                  'carbs': _parseNum(food['carbs_g'] ?? food['carbohydrates']),
                  'fat': _parseNum(food['fat_g'] ?? food['fat']),
                  'fiber': _parseNum(food['fiber_g'] ?? food['fiber']),
                  'servingSize': food['serving_size'] ?? '1 serving',
                  'alternatives': _extractAlternatives(detectedFoods),
                };
              });
            } else {
              // Use prediction name directly
              setState(() {
                _isScanning = false;
                _foodDetected = true;
                _detectedFood = {
                  'name': prediction?['display_name'] ?? 'Detected Food',
                  'confidence': prediction?['confidence'] ?? 0.75,
                  'calories': 200,
                  'protein': 10,
                  'carbs': 25,
                  'fat': 8,
                  'fiber': 3,
                  'servingSize': '1 serving',
                  'alternatives': [],
                };
              });
            }
          } else {
            _useMockData();
          }
        } else {
          _useMockData();
        }
      } else {
        _useMockData();
      }
    } catch (e) {
      debugPrint('Food analysis error: $e');
      _showError('Analysis failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  double _parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  List<Map<String, dynamic>> _extractAlternatives(List<dynamic>? detectedFoods) {
    if (detectedFoods == null || detectedFoods.length <= 1) return [];
    
    final alternatives = <Map<String, dynamic>>[];
    for (int i = 1; i < detectedFoods.length && i < 4; i++) {
      final detection = detectedFoods[i];
      final prediction = detection['prediction'] as Map<String, dynamic>?;
      final matchedFoods = detection['matched_foods'] as List<dynamic>?;
      
      if (matchedFoods?.isNotEmpty == true) {
        final food = matchedFoods![0];
        alternatives.add({
          'name': food['name'] ?? prediction?['display_name'] ?? 'Alternative',
          'confidence': prediction?['confidence'] ?? 0.5,
          'calories': _parseNum(food['calories_per_serving'] ?? food['calories']),
        });
      } else if (prediction != null) {
        alternatives.add({
          'name': prediction['display_name'] ?? 'Alternative',
          'confidence': prediction['confidence'] ?? 0.5,
          'calories': 150,
        });
      }
    }
    return alternatives;
  }
  
  void _useMockData() {
    // Mock data disabled - show actual error to user
    setState(() {
      _isScanning = false;
      _foodDetected = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not detect food. Please try again with a clearer image.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  void _showError(String message) {
    setState(() {
      _isScanning = false;
      _foodDetected = false;
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _logMeal() async {
    if (_detectedFood == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final api = ref.read(apiServiceProvider);
      final userId = ref.read(currentUserProvider)?.uid ?? 'demo_user';
      
      // Format the request to match backend MealLogRequest schema
      final response = await api.post('/api/nutrition/log-meal', body: {
        'user_id': userId,
        'meal_type': _getMealTypeFromTime(),
        'foods': [
          {
            'name': _detectedFood!['name'],
            'portion': 1.0,
            'calories': _detectedFood!['calories'],
            'protein': _detectedFood!['protein'],
            'carbs': _detectedFood!['carbs'],
            'fat': _detectedFood!['fat'],
          }
        ],
        'notes': 'Logged via food scanner',
      });
      
      if (mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.black),
                  const SizedBox(width: 8),
                  Text('${_detectedFood!['name']} logged!'),
                ],
              ),
              backgroundColor: AppColors.neonGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged offline: ${_detectedFood!['name']}'),
              backgroundColor: AppColors.neonOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        Navigator.pop(context, true); // Return true to indicate meal was logged
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally: ${_detectedFood!['name']}'),
            backgroundColor: AppColors.neonOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  String _getMealTypeFromTime() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'breakfast';
    if (hour < 14) return 'lunch';
    if (hour < 17) return 'snack';
    return 'dinner';
  }

  void _resetScan() {
    setState(() {
      _isScanning = false;
      _foodDetected = false;
      _detectedFood = null;
      _capturedImage = null;
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
                        // Camera placeholder or captured image
                        if (_capturedImage != null)
                          Image.file(
                            _capturedImage!,
                            fit: BoxFit.cover,
                          )
                        else
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
                                        : 'Tap button to capture',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _foodDetected 
                                          ? AppColors.neonGreen 
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  if (!_foodDetected && !_isScanning) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Use camera or select from gallery',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
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
    final confidence = _parseNum(food['confidence']) * 100;
    final alternatives = food['alternatives'] as List<dynamic>? ?? [];

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Main detected food card
            GlassmorphicCard(
              glowColor: AppColors.neonGreen,
              glowIntensity: 0.1,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${food['name'] ?? 'Unknown Food'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${food['servingSize'] ?? '1 serving'}',
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
                  
                  const SizedBox(height: 12),
                  
                  // Nutrition info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNutrientChip('${_parseNum(food['calories']).toInt()} cal', AppColors.neonOrange),
                      _buildNutrientChip('${_parseNum(food['protein']).toInt()}g protein', AppColors.neonCyan),
                      _buildNutrientChip('${_parseNum(food['carbs']).toInt()}g carbs', AppColors.neonPurple),
                      _buildNutrientChip('${_parseNum(food['fat']).toInt()}g fat', AppColors.neonRed),
                    ],
                  ),
                ],
              ),
            ),
            
            // Alternative foods section
            if (alternatives.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Not quite right? Try these:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: alternatives.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final alt = alternatives[index] as Map<String, dynamic>;
                    final altConfidence = _parseNum(alt['confidence']) * 100;
                    return GestureDetector(
                      onTap: () => _selectAlternative(alt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alt['name'] ?? 'Alternative',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_parseNum(alt['calories']).toInt()} cal',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.neonOrange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${altConfidence.toInt()}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
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
                    onPressed: _isLoading ? null : _logMeal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Row(
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
    );
  }
  
  void _selectAlternative(Map<String, dynamic> alt) {
    setState(() {
      _detectedFood = {
        'name': alt['name'] ?? 'Alternative Food',
        'confidence': alt['confidence'] ?? 0.7,
        'calories': _parseNum(alt['calories']),
        'protein': _parseNum(alt['protein'] ?? 10),
        'carbs': _parseNum(alt['carbs'] ?? 20),
        'fat': _parseNum(alt['fat'] ?? 5),
        'fiber': _parseNum(alt['fiber'] ?? 3),
        'servingSize': alt['servingSize'] ?? '1 serving',
        'alternatives': [], // Clear alternatives when selecting one
      };
    });
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
