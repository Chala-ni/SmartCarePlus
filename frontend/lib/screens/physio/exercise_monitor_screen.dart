/// SMARTCARE+ Exercise Monitor Screen
///
/// Owner: Neelaka
/// Live camera-based exercise form monitoring with real-time feedback
/// Shows demo video before starting, then switches to camera mode
/// Uses MediaPipe pose detection on backend for form assessment

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../core/constants/colors.dart';
import '../../core/services/api_service.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../widgets/mjpeg_stream.dart';
import '../../widgets/physio/skeleton_painter.dart';

/// Phase of the exercise session
enum ExercisePhase { preparation, exercise, complete }

class ExerciseMonitorScreen extends ConsumerStatefulWidget {
  final String exerciseName;
  final String exerciseType;
  final int targetReps;
  final int targetSets;
  final List<String>? instructions;

  const ExerciseMonitorScreen({
    super.key,
    required this.exerciseName,
    required this.exerciseType,
    this.targetReps = 10,
    this.targetSets = 3,
    this.instructions,
  });

  // Fallback instructions when video not available
  static const Map<String, List<String>> _fallbackInstructions = {
    'shoulder_rolls': [
      'Sit or stand comfortably',
      'Roll shoulders forward in circles',
      'Make 10 circles forward',
      'Reverse direction for 10 backward',
    ],
    'neck_rotations': [
      'Sit comfortably in a chair',
      'Slowly tilt head to the right',
      'Roll head forward and to the left',
      'Complete the circle back to center',
      'Repeat in opposite direction',
    ],
    'chair_stand': [
      'Sit on edge of sturdy chair',
      'Cross arms over chest',
      'Stand up using leg muscles',
      'Slowly sit back down with control',
    ],
    'seated_leg_raise': [
      'Sit with back against chair',
      'Extend one leg straight',
      'Hold for 2 seconds',
      'Lower slowly and switch legs',
    ],
    'seated_arm_raises': [
      'Sit with arms at sides',
      'Raise arms to shoulder height',
      'Hold for 2 seconds',
      'Lower slowly back down',
    ],
    'arm_raise': [
      'Stand or sit with arms at sides',
      'Raise both arms overhead',
      'Keep arms straight',
      'Lower slowly back down',
    ],
    'ankle_circles': [
      'Sit with one leg extended',
      'Rotate ankle clockwise 10 times',
      'Rotate counter-clockwise 10 times',
      'Switch to other leg',
    ],
    'wall_pushup': [
      'Stand facing wall at arm\'s length',
      'Place palms on wall at shoulder height',
      'Bend elbows, lean toward wall',
      'Push back to starting position',
    ],
    'deep_breathing': [
      'Sit comfortably with good posture',
      'Breathe in slowly through nose for 4 counts',
      'Hold for 4 counts',
      'Exhale slowly through mouth for 6 counts',
    ],
    'marching': [
      'Stand behind chair for support',
      'Lift one knee toward chest',
      'Lower and lift other knee',
      'Continue alternating at steady pace',
    ],
    'marching_in_place': [
      'Stand behind chair for support',
      'Lift one knee toward chest',
      'Lower and lift other knee',
      'Continue alternating at steady pace',
    ],
    'seated_hamstring_stretch': [
      'Sit on edge of chair',
      'Extend one leg straight with heel on floor',
      'Keep back straight, lean forward from hips',
      'Hold for 20 seconds, then switch legs',
    ],
    'seated_hip_stretch': [
      'Sit in chair with feet flat',
      'Cross one ankle over opposite knee',
      'Gently press down on raised knee',
      'Hold for 20 seconds, then switch sides',
    ],
    'gentle_spinal_twist': [
      'Sit tall in chair',
      'Place right hand on left knee',
      'Gently twist torso to the left',
      'Hold for 15 seconds, then switch sides',
    ],
  };

  @override
  ConsumerState<ExerciseMonitorScreen> createState() => _ExerciseMonitorScreenState();
}

class _ExerciseMonitorScreenState extends ConsumerState<ExerciseMonitorScreen> {
  // Phase management
  ExercisePhase _phase = ExercisePhase.preparation;
  bool _showDemoVideo = true;
  bool _showDemoPiP = false; // Picture-in-picture during exercise
  
  // Camera state
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isSessionActive = false;
  bool _isAnalyzing = false;
  String? _sessionId;
  Timer? _frameTimer;
  DateTime? _lastFrameSentAt;

  // Session metrics
  double _formScore = 0.0;
  String _formQuality = 'Ready';
  List<String> _feedback = [];
  bool _poseDetected = false;
  double _confidence = 0.0;
  bool _bodyVisible = false;
  DateTime? _sessionStartTime;
  int _currentRep = 0;
  int _currentSet = 1;
  Duration _sessionDuration = Duration.zero;
  Timer? _durationTimer;

  // Enhanced metrics (3-layer analysis)
  String _movementPhase = 'ready';
  double _smoothnessScore = 100.0;
  double _tempoScore = 100.0;
  String _currentFocus = '';
  String _adaptationSuggestion = '';
  List<String> _priorityFeedback = [];
  bool _painDetected = false;
  String _painRecommendation = 'continue';
  
  // Skeleton overlay data
  List<Map<String, dynamic>>? _landmarks;
  Map<String, dynamic>? _formGuidance;
  bool _showSkeletonOverlay = true;

  // Phase guidance for progressive reference poses
  Map<String, dynamic>? _phaseGuidance;
  Map<String, dynamic>? _currentPhase;
  Map<String, dynamic>? _nextPhase;
  String _phaseVisualCue = '';
  String _phaseMatchQuality = 'not_matching';
  double _phaseMatchScore = 0.0;
  int _adaptedTargetReps = 0;
  Map<String, dynamic>? _referencePose;
  bool _hasPhaseGuidance = false;

  // Session state
  String _sessionState = 'idle';
  bool _setCompleted = false;
  bool _sessionCompleted = false;
  int _restDuration = 30;

  /// Get the demo video stream URL
  String get _demoStreamUrl {
    return '${ApiConfig.streamBaseUrl}${ApiConfig.physio}/exercise-stream/${widget.exerciseType}';
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Use front camera for exercise monitoring (selfie mode)
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  /// Transition from preparation to exercise phase
  void _startExercisePhase() async {
    setState(() {
      _phase = ExercisePhase.exercise;
      _showDemoVideo = false;
    });
    
    // Initialize camera when entering exercise phase
    await _initializeCamera();
  }

  /// Toggle the demo video Picture-in-Picture view
  void _toggleDemoPiP() async {
    // Check if video is available by making a HEAD request
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.physio}/exercise-video/${widget.exerciseType}',
      );
      
      // If we get here without error, video is available
      setState(() => _showDemoPiP = true);
    } catch (e) {
      // Video not available - show friendly message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Demo video not available for ${widget.exerciseName}. Follow the on-screen instructions.',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.neonCyan.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _startSession() async {
    if (!_isCameraInitialized) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      
      final response = await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.physio}/session/start',
        body: {
          'user_id': 'current_user', // TODO: Get from auth provider
          'exercise_type': widget.exerciseType,
          'target_reps': widget.targetReps,
          'target_sets': widget.targetSets,
        },
        requireAuth: false,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        
        setState(() {
          _sessionId = data['session_id'];
          _isSessionActive = true;
          _formScore = 0.0;
          _formQuality = 'Analyzing...';
          _sessionStartTime = DateTime.now();
          _sessionDuration = Duration.zero;
          
          // Check if exercise has phase guidance
          _hasPhaseGuidance = data['has_phase_guidance'] ?? false;
          if (_hasPhaseGuidance) {
            _feedback = ['Follow the guidance cues', 'Match the target pose'];
          } else {
            _feedback = ['Position yourself in frame', 'Ensure required body parts are visible'];
          }
        });
        
        // Start duration timer
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && _sessionStartTime != null) {
            setState(() {
              _sessionDuration = DateTime.now().difference(_sessionStartTime!);
            });
          }
        });

        // Start sending frames for analysis
        _startFrameCapture();
      } else {
        _showError('Failed to start session: ${response.error}');
      }
    } catch (e) {
      _showError('Session start error: $e');
    }
  }

  void _startFrameCapture() {
    // Capture and send frames every 200ms (5 fps for analysis)
    _frameTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _captureAndSendFrame();
    });
  }

  Future<void> _captureAndSendFrame() async {
    if (!_isSessionActive || _sessionId == null || _isAnalyzing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    // Throttle requests
    final now = DateTime.now();
    if (_lastFrameSentAt != null && 
        now.difference(_lastFrameSentAt!).inMilliseconds < 180) {
      return;
    }
    _lastFrameSentAt = now;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Capture frame as JPEG
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final frameBase64 = base64Encode(bytes);

      final apiService = ref.read(apiServiceProvider);
      
      final response = await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.physio}/session/$_sessionId/frame',
        body: {
          'frame_base64': frameBase64,
        },
        requireAuth: false,
      ).timeout(const Duration(seconds: 3));

      if (response.success && response.data != null) {
        final data = response.data!;
        
        setState(() {
          _poseDetected = data['pose_detected'] ?? false;
          _confidence = (data['confidence'] ?? 0.0).toDouble();
          _sessionState = data['state'] ?? 'active';
          _bodyVisible = data['body_visible'] ?? false;
          
          // ALWAYS parse landmarks for skeleton overlay (even partial detection)
          if (data['landmarks'] != null && (data['landmarks'] as List).isNotEmpty) {
            _landmarks = List<Map<String, dynamic>>.from(data['landmarks']);
          }
          
          if (_poseDetected && _bodyVisible) {
            _formScore = (data['form_score'] ?? 0.0).toDouble();
            _formQuality = data['form_quality'] ?? 'analyzing';
            _feedback = List<String>.from(data['feedback'] ?? []);
            
            // Parse phase guidance for progressive reference poses
            final phaseData = data['phase_guidance'] as Map<String, dynamic>?;
            if (phaseData != null) {
              _phaseGuidance = phaseData;
              _hasPhaseGuidance = true;
              _currentPhase = phaseData['current_phase'] as Map<String, dynamic>?;
              _nextPhase = phaseData['next_phase'] as Map<String, dynamic>?;
              _adaptedTargetReps = phaseData['target_reps'] ?? widget.targetReps;
              
              if (_currentPhase != null) {
                _phaseVisualCue = _currentPhase!['visual_cue'] ?? '';
                _phaseMatchQuality = _currentPhase!['match_quality'] ?? 'not_matching';
                _phaseMatchScore = (_currentPhase!['match_score'] ?? 0.0).toDouble();
              }
              
              // Update rep/set from phase tracker (more accurate)
              _currentRep = phaseData['current_rep'] ?? 0;
              _currentSet = phaseData['current_set'] ?? 1;
            }
            
            // Parse reference pose for ghost skeleton
            _referencePose = data['reference_pose'] as Map<String, dynamic>?;
            
            // Parse enhanced metrics if available
            final enhanced = data['enhanced_metrics'] as Map<String, dynamic>?;
            if (enhanced != null) {
              _movementPhase = enhanced['phase'] ?? 'ready';
              
              final velocity = enhanced['velocity'] as Map<String, dynamic>?;
              if (velocity != null) {
                _smoothnessScore = (velocity['smoothness_score'] ?? 100.0).toDouble();
                _tempoScore = (velocity['tempo_score'] ?? 100.0).toDouble();
              }
              
              final adaptive = enhanced['adaptive_feedback'] as Map<String, dynamic>?;
              if (adaptive != null) {
                _currentFocus = adaptive['focus'] ?? '';
                _adaptationSuggestion = adaptive['adaptation'] ?? '';
                _priorityFeedback = List<String>.from(adaptive['priority_list'] ?? []);
              }
              
              // Parse form guidance for skeleton reference
              _formGuidance = enhanced['form_guidance'] as Map<String, dynamic>?;
            }
            
            // Parse pain indicators
            final pain = data['pain_indicators'] as Map<String, dynamic>?;
            if (pain != null) {
              _painDetected = pain['detected'] ?? false;
              _painRecommendation = pain['recommendation'] ?? 'continue';
            }
            
            // Check for set/session completion
            if (data['set_completed'] == true) {
              _setCompleted = true;
              _restDuration = data['rest_duration'] ?? 30;
            }
            if (data['session_completed'] == true) {
              _sessionCompleted = true;
              _stopSession(showSummary: true);
            }
          } else if (_poseDetected && !_bodyVisible) {
            // Face detected but body not visible enough - use server message
            final visibilityMsg = data['message'] ?? 'Adjust your position in the camera';
            _feedback = [visibilityMsg, 'Make sure required body parts are visible'];
            _formQuality = 'Reposition';
          } else {
            _feedback = ['No pose detected', 'Ensure you are visible in frame'];
            _formQuality = 'Not visible';
          }
        });
      }
    } catch (e) {
      debugPrint('Frame analysis error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _stopSession({bool showSummary = false}) async {
    _frameTimer?.cancel();
    _durationTimer?.cancel();
    
    if (_sessionId != null) {
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.post<Map<String, dynamic>>(
          '${ApiConfig.physio}/session/$_sessionId/complete',
          body: {},
          requireAuth: false,
        );
      } catch (e) {
        debugPrint('Session complete error: $e');
      }
    }

    setState(() {
      _isSessionActive = false;
      if (showSummary) {
        _phase = ExercisePhase.complete;
      }
    });

    if (showSummary) {
      _showSessionSummary();
    }
  }

  void _showSessionSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: AppColors.neonGreen),
            ),
            const SizedBox(width: 12),
            const Text('Exercise Complete!', 
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Duration', _formatDuration(_sessionDuration)),
            _buildSummaryRow('Average Form Score', '${_formScore.toStringAsFixed(1)}%'),
            _buildSummaryRow('Form Quality', _formQuality.toUpperCase()),
            _buildSummaryRow('Movement Phase', _movementPhase.toUpperCase()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to exercise library
            },
            child: const Text('Done', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.neonRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _durationTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color _getFormQualityColor() {
    switch (_formQuality.toLowerCase()) {
      case 'excellent':
        return AppColors.neonGreen;
      case 'good':
        return AppColors.neonCyan;
      case 'fair':
        return AppColors.neonOrange;
      case 'poor':
        return AppColors.neonRed;
      case 'reposition':
        return AppColors.neonOrange;
      case 'not visible':
        return AppColors.neonRed;
      default:
        return AppColors.textSecondary;
    }
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
          child: _phase == ExercisePhase.preparation 
            ? _buildPreparationPhase()
            : _buildExercisePhase(),
        ),
      ),
    );
  }

  /// Build the preparation phase with demo video
  Widget _buildPreparationPhase() {
    return Column(
      children: [
        _buildHeader(),
        
        // Demo Video Section
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Demo Video Player
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.neonCyan, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: MjpegStream(
                          streamUrl: _demoStreamUrl,
                          fit: BoxFit.contain,
                          isLive: false, // Demo videos don't need auto-reconnect
                          timeout: const Duration(seconds: 5),
                          loadingWidget: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppColors.neonCyan),
                                SizedBox(height: 16),
                                Text('Loading demo video...', 
                                  style: TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          errorBuilder: (context, error) => _buildInstructionsFallback(),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Demo label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline, color: AppColors.neonCyan, size: 16),
                          SizedBox(width: 6),
                          Text('Watch the demo, then begin your exercise',
                            style: TextStyle(color: AppColors.neonCyan, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Exercise Info Card
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassmorphicCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem('Duration', widget.instructions?.length.toString() ?? 'Guided'),
                    _buildInfoItem('Type', widget.exerciseType.replaceAll('_', ' ')),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Begin Exercise Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startExercisePhase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center),
                  SizedBox(width: 8),
                  Text(
                    'Begin Exercise',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        )),
        Text(label, style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
        )),
      ],
    );
  }

  /// Build text instructions fallback when demo video is not available
  Widget _buildInstructionsFallback() {
    // Get instructions from passed parameter or fallback map
    final instructions = widget.instructions ?? 
        ExerciseMonitorScreen._fallbackInstructions[widget.exerciseType] ??
        ['Follow along with proper form', 'Complete the target repetitions', 'Rest as needed'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.3)),
            ),
            child: const Icon(Icons.fitness_center, 
              color: AppColors.neonCyan, size: 48),
          ),
          const SizedBox(height: 16),
          Text(widget.exerciseName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('Demo video not available',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt, color: AppColors.neonGreen, size: 20),
                    const SizedBox(width: 8),
                    const Text('How to perform:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  ],
                ),
                const SizedBox(height: 12),
                ...instructions.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text('${entry.key + 1}',
                            style: const TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            )),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(entry.value,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 1.3,
                          )),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Tap "Begin Exercise" when ready',
            style: TextStyle(color: AppColors.neonCyan.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  /// Build the exercise phase with camera
  Widget _buildExercisePhase() {
    return Column(
      children: [
        _buildHeader(),
        
        // Camera Preview with optional PiP demo
        Expanded(
          child: Stack(
            children: [
              _buildCameraPreview(),
              _buildOverlay(),
              
              // Picture-in-Picture demo video (optional toggle)
              if (_showDemoPiP)
                Positioned(
                  bottom: 16,
                  right: 32,
                  child: GestureDetector(
                    onTap: () => setState(() => _showDemoPiP = false),
                    child: Container(
                      width: 140,
                      height: 105,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonCyan, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          children: [
                            MjpegStream(
                              streamUrl: _demoStreamUrl,
                              fit: BoxFit.cover,
                              isLive: false,
                              timeout: const Duration(seconds: 5),
                              errorBuilder: (context, error) => Container(
                                color: AppColors.surface,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.videocam_off, 
                                      color: AppColors.textSecondary, size: 24),
                                    const SizedBox(height: 4),
                                    Text('Video unavailable',
                                      style: TextStyle(
                                        color: AppColors.textSecondary.withOpacity(0.8),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Close button overlay
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Controls and Metrics
        _buildBottomPanel(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isSessionActive) {
                _showExitConfirmation();
              } else {
                Navigator.pop(context);
              }
            },
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exerciseName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _phase == ExercisePhase.preparation 
                    ? 'Watch Demo' 
                    : (_isSessionActive ? 'Session Active' : 'Ready to Start'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isSessionActive ? AppColors.neonGreen : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_phase == ExercisePhase.exercise && !_showDemoPiP)
            GestureDetector(
              onTap: () => _toggleDemoPiP(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_in_picture, color: AppColors.neonCyan, size: 20),
              ),
            ),
          if (_isSessionActive)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.neonGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('LIVE', style: TextStyle(
                    color: AppColors.neonGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.neonCyan),
            SizedBox(height: 16),
            Text('Initializing camera...', 
              style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _poseDetected ? AppColors.neonGreen : AppColors.neonRed,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              CameraPreview(_cameraController!),
              
              // Skeleton overlay (when pose detected and enabled)
              // Show skeleton when landmarks available (regardless of full pose detection)
              if (_showSkeletonOverlay && _landmarks != null && _landmarks!.isNotEmpty)
                SkeletonOverlay(
                  landmarkData: _landmarks,
                  formQuality: _formQuality,
                ),
              
              // Form guidance overlay
              if (_formGuidance != null && _isSessionActive)
                FormGuidanceOverlay(
                  formGuidance: _formGuidance,
                  isVisible: !(_formGuidance?['is_acceptable'] ?? true),
                ),
              
              // Skeleton toggle button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _showSkeletonOverlay = !_showSkeletonOverlay),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _showSkeletonOverlay ? Icons.accessibility : Icons.accessibility_new,
                      color: _showSkeletonOverlay ? AppColors.neonCyan : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    if (!_isSessionActive) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 32,
      right: 32,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getFormQualityColor().withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Duration and Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Duration', _formatDuration(_sessionDuration)),
                Container(width: 1, height: 30, color: Colors.white24),
                _buildMetric('Phase', _movementPhase.toUpperCase()),
                Container(width: 1, height: 30, color: Colors.white24),
                _buildMetric('Score', '${_formScore.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 8),
            // Form Quality
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _getFormQualityColor().withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formQuality.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _getFormQualityColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 4,
            ),
          ],
        )),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          fontSize: 11,
          color: Colors.white.withOpacity(0.7),
        )),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pain Warning (Priority Alert)
          if (_painDetected && _painRecommendation != 'continue')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                backgroundColor: AppColors.neonRed.withOpacity(0.2),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.neonRed, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Discomfort Detected', style: TextStyle(
                            color: AppColors.neonRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          )),
                          Text(_getPainRecommendationText(), style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Enhanced Metrics Row (Smoothness & Tempo)
          if (_isSessionActive && _smoothnessScore < 100)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricChip(
                      'Smoothness',
                      '${_smoothnessScore.toInt()}%',
                      _getMetricColor(_smoothnessScore),
                      Icons.waves,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricChip(
                      'Tempo',
                      '${_tempoScore.toInt()}%',
                      _getMetricColor(_tempoScore),
                      Icons.speed,
                    ),
                  ),
                ],
              ),
            ),
          
          // Adaptive Focus (Single Most Important Tip)
          if (_currentFocus.isNotEmpty && _isSessionActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                backgroundColor: AppColors.neonPurple.withOpacity(0.15),
                child: Row(
                  children: [
                    const Icon(Icons.center_focus_strong, color: AppColors.neonPurple, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_currentFocus, style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          
          // Phase Guidance - Progressive Reference Pose
          if (_hasPhaseGuidance && _phaseVisualCue.isNotEmpty && _isSessionActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                borderColor: _getPhaseMatchColor(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getPhaseIcon(),
                          color: _getPhaseMatchColor(),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _phaseVisualCue,
                            style: TextStyle(
                              color: _getPhaseMatchColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // Match quality indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getPhaseMatchColor().withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_phaseMatchScore.toInt()}%',
                            style: TextStyle(
                              color: _getPhaseMatchColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar for phase match
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _phaseMatchScore / 100.0,
                        backgroundColor: AppColors.surfaceLight.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation(_getPhaseMatchColor()),
                        minHeight: 4,
                      ),
                    ),
                    // Next phase preview
                    if (_nextPhase != null && _nextPhase!['visual_cue'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.textSecondary.withOpacity(0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Next: ',
                              style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _nextPhase!['visual_cue'] ?? '',
                                style: TextStyle(
                                  color: AppColors.textSecondary.withOpacity(0.8),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_adaptedTargetReps > 0 && _adaptedTargetReps != widget.targetReps)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '⚡ Reps adjusted: ${widget.targetReps} → $_adaptedTargetReps',
                          style: TextStyle(
                            color: AppColors.neonOrange.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // Feedback
          if (_feedback.isNotEmpty)
            GlassmorphicCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: AppColors.neonCyan, size: 16),
                      SizedBox(width: 8),
                      Text('Feedback', style: TextStyle(
                        color: AppColors.neonCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(_feedback.take(3).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(f, style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          )),
                        ),
                      ],
                    ),
                  ))),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Start/Stop Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCameraInitialized 
                ? (_isSessionActive ? () => _stopSession() : _startSession)
                : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSessionActive ? AppColors.neonRed : AppColors.neonGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isSessionActive ? Icons.stop : Icons.play_arrow),
                  const SizedBox(width: 8),
                  Text(
                    _isSessionActive ? 'Stop Exercise' : 'Start Exercise',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Pose Status
          if (_isSessionActive)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _poseDetected && _bodyVisible 
                      ? Icons.visibility 
                      : _poseDetected 
                        ? Icons.person_search
                        : Icons.visibility_off,
                    color: _poseDetected && _bodyVisible 
                      ? AppColors.neonGreen 
                      : AppColors.neonRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _poseDetected && _bodyVisible
                      ? 'Body detected (${_confidence.toStringAsFixed(0)}% confidence)'
                      : _poseDetected 
                        ? 'Show full body — only face visible'
                        : 'No pose detected',
                    style: TextStyle(
                      color: _poseDetected && _bodyVisible 
                        ? AppColors.neonGreen 
                        : AppColors.neonRed,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build a compact metric chip for smoothness/tempo display
  Widget _buildMetricChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
              Text(label, style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 10,
              )),
            ],
          ),
        ],
      ),
    );
  }

  /// Get color based on metric value (green for good, orange for medium, red for poor)
  Color _getMetricColor(double value) {
    if (value >= 80) return AppColors.neonGreen;
    if (value >= 60) return AppColors.neonOrange;
    if (value >= 40) return AppColors.neonPink;
    return AppColors.neonRed;
  }

  /// Get human-readable pain recommendation text
  String _getPainRecommendationText() {
    switch (_painRecommendation) {
      case 'stop_exercise':
        return 'Consider stopping - potential injury risk detected';
      case 'take_break':
        return 'Take a short break before continuing';
      case 'reduce_intensity':
        return 'Try reducing the range of motion';
      default:
        return '';
    }
  }

  /// Get color based on phase match quality
  Color _getPhaseMatchColor() {
    switch (_phaseMatchQuality) {
      case 'matching':
      case 'holding':
        return AppColors.neonGreen;
      case 'approaching':
        return AppColors.neonOrange;
      default:
        return AppColors.neonCyan;
    }
  }

  /// Get icon for current phase match state
  IconData _getPhaseIcon() {
    switch (_phaseMatchQuality) {
      case 'matching':
        return Icons.check_circle;
      case 'holding':
        return Icons.timer;
      case 'approaching':
        return Icons.near_me;
      default:
        return Icons.adjust;
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('End Session?', 
          style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to end the exercise session?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopSession();
              Navigator.pop(context);
            },
            child: const Text('End Session', style: TextStyle(color: AppColors.neonRed)),
          ),
        ],
      ),
    );
  }
}
