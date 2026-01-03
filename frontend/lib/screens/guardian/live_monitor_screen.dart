/// SMARTCARE+ Live Monitor Screen
///
/// Owner: Devin
/// Displays pre-recorded videos as simulated live CCTV feeds for demo
/// Uses connected elderly from Firebase with randomly assigned demo videos
/// Uses MJPEG streaming for reliable cross-platform video playback

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/services/api_service.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../widgets/mjpeg_stream.dart';

/// Available demo video IDs with their scenarios
const Map<String, String> demoVideos = {
  'walking_normal_1': 'Normal Walking',
  'walking_normal_2': 'Normal Walking',
  'walking_slow_1': 'Slow Walking',
  'sitting_resting_1': 'Resting',
  'lying_down_1': 'Lying Down',
  'standing_idle_1': 'Standing',
  'gait_normal_1': 'Normal Gait',
  'gait_abnormal_1': 'Abnormal Gait',
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
  String _currentTimestamp = '';
  String _currentVideoId = '';
  String _streamUrl = '';
  
  // Activity analysis (simulated)
  String _currentActivity = 'N/A';
  String _currentConfidence = 'N/A';
  String _fallRisk = 'N/A';
  
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
    return '${ApiConfig.baseUrl}${ApiConfig.guardian}/video/$videoId';
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
    });
    
    // Simulate ML analysis
    _simulateActivity();
  }
  
  void _stopStream() {
    setState(() {
      _isStreaming = false;
      _streamUrl = '';
    });
  }
  
  void _restartStream() {
    debugPrint('🔄 Restarting MJPEG stream...');
    _stopStream();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _startStream();
    });
  }
  
  /// Simulate activity detection (will be replaced with real ML later)
  void _simulateActivity() {
    final random = Random();
    final activities = ['Walking', 'Sitting', 'Standing', 'Resting', 'Moving'];
    final risks = ['Low', 'Low', 'Low', 'Medium', 'Low'];
    
    setState(() {
      _currentActivity = activities[random.nextInt(activities.length)];
      _currentConfidence = '${80 + random.nextInt(15)}%';
      _fallRisk = risks[random.nextInt(risks.length)];
    });
  }

  @override
  void dispose() {
    _timestampTimer?.cancel();
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
                    if (!_hasError && demoVideos[_currentVideoId] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.neonCyan.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'ML: ${demoVideos[_currentVideoId]}', 
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(Icons.directions_walk, _currentActivity, 'Activity', AppColors.neonCyan),
            Container(width: 1, height: 30, color: AppColors.surfaceLight),
            _buildStatItem(Icons.check_circle, _currentConfidence, 'Confidence', AppColors.neonGreen),
            Container(width: 1, height: 30, color: AppColors.surfaceLight),
            _buildStatItem(
              Icons.warning_amber, 
              _fallRisk, 
              'Fall Risk', 
              _fallRisk == 'Medium' ? AppColors.neonOrange : AppColors.neonGreen,
            ),
          ],
        ),
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
