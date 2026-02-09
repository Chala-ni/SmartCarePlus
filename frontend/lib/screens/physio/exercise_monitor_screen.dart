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

/// Phase of the exercise session
enum ExercisePhase { preparation, exercise, complete }

class ExerciseMonitorScreen extends ConsumerStatefulWidget {
  final String exerciseName;
  final String exerciseType;
  final int targetReps;
  final int targetSets;

  const ExerciseMonitorScreen({
    super.key,
    required this.exerciseName,
    required this.exerciseType,
    this.targetReps = 10,
    this.targetSets = 3,
  });

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
  int _currentRep = 0;
  int _currentSet = 1;
  int _targetReps = 10;
  int _targetSets = 3;
  double _formScore = 0.0;
  String _formQuality = 'Ready';
  List<String> _feedback = [];
  bool _poseDetected = false;
  double _confidence = 0.0;
  bool _bodyVisible = false;

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
    _targetReps = widget.targetReps;
    _targetSets = widget.targetSets;
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

  Future<void> _startSession() async {
    if (!_isCameraInitialized) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      
      final response = await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.physio}/session/start',
        body: {
          'user_id': 'current_user', // TODO: Get from auth provider
          'exercise_type': widget.exerciseType,
          'target_reps': _targetReps,
          'target_sets': _targetSets,
        },
        requireAuth: false,
      );

      if (response.success && response.data != null) {
        setState(() {
          _sessionId = response.data!['session_id'];
          _isSessionActive = true;
          _currentRep = 0;
          _currentSet = 1;
          _formScore = 0.0;
          _formQuality = 'Analyzing...';
          _feedback = ['Position yourself in frame', 'Ensure full body is visible'];
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
          
          if (_poseDetected && _bodyVisible) {
            _currentRep = data['current_rep'] ?? _currentRep;
            _currentSet = data['current_set'] ?? _currentSet;
            _formScore = (data['form_score'] ?? 0.0).toDouble();
            _formQuality = data['form_quality'] ?? 'analyzing';
            _feedback = List<String>.from(data['feedback'] ?? []);
            _targetReps = data['target_reps'] ?? _targetReps;
            _targetSets = data['target_sets'] ?? _targetSets;
            
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
            // Face detected but body not visible enough
            _feedback = ['Show your full body in the camera', 'Step back so legs and arms are visible'];
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
            _buildSummaryRow('Total Reps', '$_currentRep'),
            _buildSummaryRow('Sets Completed', '$_currentSet'),
            _buildSummaryRow('Average Form Score', '${_formScore.toStringAsFixed(1)}%'),
            _buildSummaryRow('Form Quality', _formQuality.toUpperCase()),
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
    _cameraController?.dispose();
    super.dispose();
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
                          errorBuilder: (context, error) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.videocam_off, 
                                  color: AppColors.textSecondary, size: 48),
                                const SizedBox(height: 16),
                                const Text('Demo video not available',
                                  style: TextStyle(color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                Text('Tap "Begin Exercise" to start',
                                  style: TextStyle(color: AppColors.neonCyan.withOpacity(0.7), fontSize: 12)),
                              ],
                            ),
                          ),
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
                    _buildInfoItem('Sets', '${widget.targetSets}'),
                    _buildInfoItem('Reps', '${widget.targetReps}'),
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
                      width: 120,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonCyan, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: MjpegStream(
                          streamUrl: _demoStreamUrl,
                          fit: BoxFit.cover,
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
              onTap: () => setState(() => _showDemoPiP = true),
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
          child: CameraPreview(_cameraController!),
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
            // Rep Counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Set', '$_currentSet/$_targetSets'),
                Container(width: 1, height: 30, color: Colors.white24),
                _buildMetric('Rep', '$_currentRep/$_targetReps'),
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
