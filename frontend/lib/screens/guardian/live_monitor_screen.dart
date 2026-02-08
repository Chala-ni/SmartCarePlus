/// SMARTCARE+ Live Monitor Screen
///
/// Owner: Devin
/// Displays pre-recorded videos as simulated live CCTV feeds for demo
/// Uses connected elderly from Firebase with randomly assigned demo videos
/// Uses MJPEG streaming for reliable cross-platform video playback
/// Integrates with 3-layer hybrid fall detection system

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/services/api_service.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../widgets/mjpeg_stream.dart';

/// Available demo video IDs with their scenarios
/// Training videos for hybrid fall detection testing
const Map<String, String> demoVideos = {
  // Training dataset videos with clear skeleton visibility
  'fall-01-cam0': 'Fall Scenario 1',
  'fall-02-cam0': 'Fall Scenario 2',
  'fall-03-cam0': 'Fall Scenario 3',
  'fall-04-cam0': 'Fall Scenario 4',
  'fall-05-cam0': 'Fall Scenario 5',
  'adl-01-cam0': 'Normal Activity 1',
  'adl-02-cam0': 'Normal Activity 2',
  'adl-03-cam0': 'Normal Activity 3',
  'adl-04-cam0': 'Normal Activity 4',
  'adl-05-cam0': 'Normal Activity 5',
};

class LiveMonitorScreen extends ConsumerStatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  ConsumerState<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends ConsumerState<LiveMonitorScreen> {
  ElderlyInfo? _selectedElderly;
  bool _isStreaming = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _timestampTimer;
  Timer? _analysisTimer;
  String _currentTimestamp = '';
  String _currentVideoId = '';
  String _streamUrl = '';
  
  // Activity analysis from hybrid detection
  String _currentActivity = 'N/A';
  String _currentConfidence = 'N/A';
  String _fallRisk = 'N/A';
  
  // Hybrid detection state
  bool _isAnalyzing = false;
  bool _fallDetected = false;
  String _detectionSource = '';
  Map<String, double> _layerScores = {};
  String _fallType = 'none';
  
  // Frame capture state for live streaming detection
  Uint8List? _lastCapturedFrame;
  DateTime? _lastFrameSentAt;
  int _framesSent = 0;
  int _bufferSize = 0;
  bool _bufferReady = false;
  
  @override
  void initState() {
    super.initState();
    _updateTimestamp();
    _timestampTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimestamp());
    
    // Load connected elderly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectionProvider.notifier).loadMyElderly();
    });
  }

  void _updateTimestamp() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });
    }
  }
  
  /// Assign a random demo video based on elderly ID (deterministic but varied)
  String _getVideoIdForElderly(String elderlyId) {
    final videos = demoVideos.keys.toList();
    final hash = elderlyId.hashCode.abs();
    return videos[hash % videos.length];
  }
  
  String _getVideoUrl(String videoId) {
    return '${ApiConfig.streamBaseUrl}${ApiConfig.guardian}/video/$videoId';
  }

  void _startStream() {
    if (_selectedElderly == null) return;
    
    // Get video ID for this elderly
    _currentVideoId = _selectedElderly!.assignedVideoId.isNotEmpty 
        ? _selectedElderly!.assignedVideoId
        : _getVideoIdForElderly(_selectedElderly!.id);
    
    final videoUrl = _getVideoUrl(_currentVideoId);
    
    debugPrint('');
    debugPrint('🎬 ═══════════════════════════════════════════════════');
    debugPrint('🎬 MJPEG STREAM STARTING');
    debugPrint('🎬 ═══════════════════════════════════════════════════');
    debugPrint('🎬 Video ID: $_currentVideoId');
    debugPrint('🎬 Stream URL: $videoUrl');
    debugPrint('🎬 Base URL: ${ApiConfig.baseUrl}');
    debugPrint('🎬 ═══════════════════════════════════════════════════');
    
    setState(() {
      _streamUrl = videoUrl;
      _isStreaming = true;
      _hasError = false;
      _errorMessage = '';
      _fallDetected = false;
      _currentActivity = 'Analyzing...';
      _currentConfidence = '...';
      _fallRisk = '...';
      _layerScores = {};
    });
    
    // Start hybrid ML analysis
    _startAnalysis();
  }
  
  void _stopStream() {
    _analysisTimer?.cancel();
    setState(() {
      _isStreaming = false;
      _streamUrl = '';
      _fallDetected = false;
      _currentActivity = 'N/A';
      _currentConfidence = 'N/A';
      _fallRisk = 'N/A';
      _layerScores = {};
      _detectionSource = '';
    });
  }
  
  void _restartStream() {
    debugPrint('🔄 Restarting MJPEG stream...');
    _stopStream();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _startStream();
    });
  }
  
  /// Handle new frame from MJPEG stream
  void _onFrameReceived(Uint8List frameBytes) {
    _lastCapturedFrame = frameBytes;
  }
  
  /// Send a frame to the backend for live detection
  Future<void> _sendFrameForDetection() async {
    if (_currentVideoId.isEmpty || _lastCapturedFrame == null) return;
    if (_isAnalyzing) return; // Don't pile up requests
    
    // Throttle: send max 5 frames per second
    final now = DateTime.now();
    if (_lastFrameSentAt != null && 
        now.difference(_lastFrameSentAt!).inMilliseconds < 150) {
      return;
    }
    _lastFrameSentAt = now;
    
    setState(() {
      _isAnalyzing = true;
    });
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final sessionId = _currentVideoId;
      
      // Encode frame as base64
      final frameBase64 = base64Encode(_lastCapturedFrame!);
      
      // Send to streaming detection endpoint
      final response = await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.guardian}/stream/$sessionId/frame',
        body: {
          'frame_base64': frameBase64,
          'elderly_id': _selectedElderly?.id,
          'timestamp': now.millisecondsSinceEpoch / 1000,
        },
        requireAuth: false,
      ).timeout(const Duration(seconds: 5));
      
      if (response.success && response.data != null) {
        final data = response.data!;
        
        final detection = data['detection'] as Map<String, dynamic>?;
        final scores = data['scores'] as Map<String, dynamic>?;
        
        setState(() {
          _framesSent = data['frame_number'] ?? _framesSent + 1;
          _bufferSize = data['buffer_size'] ?? 0;
          _bufferReady = data['buffer_ready'] ?? false;
          
          if (detection != null) {
            _fallDetected = detection['fall_detected'] ?? false;
            _currentConfidence = '${((detection['confidence'] ?? 0.0) * 100).toInt()}%';
            _fallType = detection['fall_type'] ?? 'none';
            _detectionSource = detection['detection_source'] ?? 'none';
          }
          
          if (scores != null) {
            _layerScores = {
              'skeleton': (scores['skeleton'] ?? 0.0).toDouble(),
              'motion': (scores['motion'] ?? 0.0).toDouble(),
              'deep_learning': (scores['deep_learning'] ?? 0.0).toDouble(),
            };
          }
          
          // Update activity based on detection
          if (_fallDetected) {
            _currentActivity = 'FALL DETECTED';
            _fallRisk = 'Critical';
          } else if (_bufferReady) {
            _currentActivity = 'Normal';
            _fallRisk = 'Low';
          } else {
            _currentActivity = 'Buffering...';
            _fallRisk = 'Analyzing';
          }
        });
        
        // Show alert if fall detected
        if (_fallDetected && mounted) {
          _showFallAlert();
        }
      }
    } catch (e) {
      debugPrint('Stream detection error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }
  
  /// Legacy method for video file-based detection (kept for reference)
  Future<void> _runHybridDetection() async {
    // This now delegates to frame-based detection
    await _sendFrameForDetection();
  }
  
  /// Show fall alert dialog
  void _showFallAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning, color: AppColors.neonRed),
            ),
            const SizedBox(width: 12),
            const Text('Fall Detected!', style: TextStyle(color: AppColors.neonRed)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedElderly?.name ?? "Elderly"} may have fallen.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            _buildDetectionDetails(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Trigger emergency call
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonRed),
            child: const Text('Call Emergency'),
          ),
        ],
      ),
    );
  }
  
  /// Build detection details widget
  Widget _buildDetectionDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fall Type: $_fallType', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('Detection Source: $_detectionSource', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          const Text('Layer Scores:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          if (_layerScores.isNotEmpty) ...[
            _buildScoreBar('Skeleton', _layerScores['skeleton'] ?? 0, AppColors.neonCyan),
            _buildScoreBar('Motion', _layerScores['motion'] ?? 0, AppColors.neonGreen),
            _buildScoreBar('Deep Learning', _layerScores['deep_learning'] ?? 0, AppColors.neonPurple),
          ],
        ],
      ),
    );
  }
  
  Widget _buildScoreBar(String label, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
          Expanded(
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(score * 100).toInt()}%', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  /// Start streaming session and periodic frame sending
  Future<void> _startAnalysis() async {
    if (_currentVideoId.isEmpty) return;
    
    // Reset state
    _framesSent = 0;
    _bufferSize = 0;
    _bufferReady = false;
    _lastCapturedFrame = null;
    _lastFrameSentAt = null;
    
    // Start session on backend
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.guardian}/stream/$_currentVideoId/start',
        body: {'elderly_id': _selectedElderly?.id},
        requireAuth: false,
      );
      debugPrint('🎥 Stream session started: $_currentVideoId');
    } catch (e) {
      debugPrint('Failed to start stream session: $e');
    }
    
    // Start periodic frame sending (5 fps for ~6 second detection)
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_isStreaming && mounted && _lastCapturedFrame != null) {
        _sendFrameForDetection();
      }
    });
  }
  
  /// Stop analysis and clean up session
  Future<void> _stopAnalysis() async {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    
    // Stop session on backend
    if (_currentVideoId.isNotEmpty) {
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.post<Map<String, dynamic>>(
          '${ApiConfig.guardian}/stream/$_currentVideoId/stop',
          requireAuth: false,
        );
        debugPrint('🛑 Stream session stopped: $_currentVideoId');
      } catch (e) {
        debugPrint('Failed to stop stream session: $e');
      }
    }
    
    // Reset state
    _lastCapturedFrame = null;
    _lastFrameSentAt = null;
  }

  @override
  void dispose() {
    _timestampTimer?.cancel();
    _analysisTimer?.cancel();
    super.dispose();
  }

  void _selectElderly(ElderlyInfo elderly) {
    if (_selectedElderly?.id != elderly.id) {
      setState(() => _selectedElderly = elderly);
      _startStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final elderlyList = connectionState.linkedElderly;
    
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
              _buildHeader(),
              
              // Main Video Feed
              Expanded(
                flex: 3,
                child: _buildVideoFeed(),
              ),
              
              const SizedBox(height: 12),
              
              // Activity Stats
              _buildActivityStats(),
              
              const SizedBox(height: 12),
              
              // Elderly Selection
              _buildElderlySelection(elderlyList, connectionState.isLoading),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Monitor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(
                  _selectedElderly != null 
                      ? 'Watching ${_selectedElderly!.name}' 
                      : 'Select an elderly to monitor',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Analyze Now button
          if (_isStreaming)
            GestureDetector(
              onTap: _isAnalyzing ? null : _runHybridDetection,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _isAnalyzing 
                      ? AppColors.surfaceLight 
                      : AppColors.neonPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAnalyzing)
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPurple),
                      )
                    else
                      const Icon(Icons.psychology, size: 14, color: AppColors.neonPurple),
                    const SizedBox(width: 4),
                    Text(
                      _isAnalyzing ? 'Analyzing...' : 'Analyze',
                      style: const TextStyle(fontSize: 10, color: AppColors.neonPurple, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.neonRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.neonRed, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('DEMO', style: TextStyle(fontSize: 10, color: AppColors.neonRed, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoFeed() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedElderly != null ? AppColors.neonCyan : AppColors.surfaceLight, 
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video or Placeholder
            if (_selectedElderly == null)
              _buildSelectElderlyPlaceholder()
            else if (_hasError)
              _buildVideoPlaceholder()
            else if (_isStreaming && _streamUrl.isNotEmpty)
              MjpegStream(
                streamUrl: _streamUrl,
                isLive: true,
                fit: BoxFit.cover,
                timeout: const Duration(seconds: 10),
                loadingWidget: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.neonCyan),
                      SizedBox(height: 12),
                      Text('Connecting to stream...', 
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                onError: (error) {
                  debugPrint('❌ MJPEG Error: $error');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasError = true;
                        _errorMessage = error.toString();
                      });
                    }
                  });
                },
                errorBuilder: (context, error) => _buildVideoPlaceholder(),
                onFrame: _onFrameReceived,
              )
            else
              _buildSelectElderlyPlaceholder(),
            
            // Overlay - Status Badge
            if (_selectedElderly != null)
              Positioned(
                top: 12,
                left: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8, 
                            decoration: BoxDecoration(
                              color: _hasError ? AppColors.neonRed : AppColors.neonGreen, 
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _hasError ? 'OFFLINE' : 'LIVE', 
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Hybrid Detection Status
                    if (_isAnalyzing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.neonPurple.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10, height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 6),
                            Text('Analyzing...', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (_fallDetected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.neonRed, borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('FALL DETECTED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (!_hasError && _currentActivity != 'N/A')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.neonCyan.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'AI: $_currentActivity', 
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            
            // Fall Alert Overlay
            if (_fallDetected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.neonRed, width: 4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            
            // Timestamp
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, color: AppColors.neonCyan, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _currentTimestamp,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w500),
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
  
  Widget _buildSelectElderlyPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('Select an elderly to start monitoring', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.neonOrange),
            const SizedBox(height: 12),
            const Text('Video stream unavailable', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              _errorMessage.length > 50 ? 'Connection error' : _errorMessage,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _restartStream,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppColors.neonCyan),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityStats() {
    final activityColor = _fallDetected ? AppColors.neonRed : AppColors.neonCyan;
    final riskColor = _fallRisk == 'Critical' 
        ? AppColors.neonRed 
        : (_fallRisk == 'Medium' ? AppColors.neonOrange : AppColors.neonGreen);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Main stats row
          GlassmorphicCard(
            glowColor: _fallDetected ? AppColors.neonRed : null,
            glowIntensity: _fallDetected ? 0.3 : 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  _fallDetected ? Icons.warning : Icons.directions_walk, 
                  _currentActivity, 
                  'Activity', 
                  activityColor,
                ),
                Container(width: 1, height: 30, color: AppColors.surfaceLight),
                _buildStatItem(Icons.check_circle, _currentConfidence, 'Confidence', AppColors.neonGreen),
                Container(width: 1, height: 30, color: AppColors.surfaceLight),
                _buildStatItem(
                  Icons.health_and_safety, 
                  _fallRisk, 
                  'Fall Risk', 
                  riskColor,
                ),
              ],
            ),
          ),
          
          // Layer scores (show when analyzing or after detection)
          if (_layerScores.isNotEmpty && _isStreaming) ...[
            const SizedBox(height: 8),
            GlassmorphicCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 14, color: AppColors.neonPurple),
                      const SizedBox(width: 6),
                      const Text(
                        '3-Layer Hybrid Detection',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      if (_detectionSource.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _detectionSource,
                            style: const TextStyle(fontSize: 9, color: AppColors.neonPurple),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLayerScoreRow('Skeleton (Pose)', _layerScores['skeleton'] ?? 0, AppColors.neonCyan),
                  _buildLayerScoreRow('Motion (Frame)', _layerScores['motion'] ?? 0, AppColors.neonGreen),
                  _buildLayerScoreRow('Deep Learning', _layerScores['deep_learning'] ?? 0, AppColors.neonPurple),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildLayerScoreRow(String label, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score,
                minHeight: 6,
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 35,
            child: Text(
              '${(score * 100).toInt()}%',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
  
  Widget _buildElderlySelection(List<ElderlyInfo> elderlyList, bool isLoading) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Elderly', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
                  : elderlyList.isEmpty
                      ? _buildNoElderlyMessage()
                      : ListView.builder(
                          itemCount: elderlyList.length,
                          itemBuilder: (context, index) => _buildElderlyTile(elderlyList[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoElderlyMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          const Text('No connected elderly', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/connections'),
            child: const Text('Add Connection', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildElderlyTile(ElderlyInfo elderly) {
    final isSelected = _selectedElderly?.id == elderly.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        glowColor: isSelected ? AppColors.neonCyan : null,
        glowIntensity: 0.15,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isSelected ? AppColors.neonCyan.withOpacity(0.2) : AppColors.surfaceLight,
              child: Icon(Icons.elderly, color: isSelected ? AppColors.neonCyan : AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    elderly.name,
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w600, 
                      color: isSelected ? AppColors.neonCyan : AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppColors.neonGreen, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      const Text('Last active: 2 min ago', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _selectElderly(elderly),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.neonCyan : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSelected ? 'Watching' : 'Watch',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.black : AppColors.neonCyan,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
