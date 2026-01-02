/// SMARTCARE+ Live Monitor Screen
///
/// Owner: Devin
/// Displays pre-recorded videos as simulated live CCTV feeds for demo

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  int _selectedCameraIndex = 0;
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _timestampTimer;
  String _currentTimestamp = '';

  // Pre-recorded videos as simulated CCTV feeds (ML-test ready naming)
  // Large videos (>10MB) excluded to avoid memory issues
  final List<Map<String, dynamic>> _cameras = [
    {'name': 'Living Room', 'location': 'Main Floor', 'status': 'Online', 'video': 'assets/videos/walking_normal_1.mp4', 'scenario': 'Normal Walking'},
    {'name': 'Bedroom', 'location': 'Upper Floor', 'status': 'Online', 'video': 'assets/videos/sitting_resting_1.mp4', 'scenario': 'Sitting/Resting'},
    {'name': 'Kitchen', 'location': 'Main Floor', 'status': 'Online', 'video': 'assets/videos/walking_slow_1.mp4', 'scenario': 'Slow Walking'},
    {'name': 'Hallway', 'location': 'Main Floor', 'status': 'Online', 'video': 'assets/videos/gait_normal_1.mp4', 'scenario': 'Normal Gait'},
    {'name': 'Guest Room', 'location': 'Upper Floor', 'status': 'Online', 'video': 'assets/videos/lying_down_1.mp4', 'scenario': 'Lying Down'},
    {'name': 'Study', 'location': 'Main Floor', 'status': 'Online', 'video': 'assets/videos/standing_idle_1.mp4', 'scenario': 'Standing Idle'},
  ];

  @override
  void initState() {
    super.initState();
    _updateTimestamp();
    _timestampTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimestamp());
    _initializeVideo();
  }

  void _updateTimestamp() {
    final now = DateTime.now();
    setState(() {
      _currentTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _videoController?.dispose();
      
      // For demo: Use asset video. In production, would be network stream
      final videoPath = _cameras[_selectedCameraIndex]['video'];
      _videoController = VideoPlayerController.asset(videoPath);
      
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      
      setState(() => _isLoading = false);
    } catch (e) {
      // If video asset not found, show placeholder
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _timestampTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _selectCamera(int index) {
    if (index != _selectedCameraIndex) {
      setState(() => _selectedCameraIndex = index);
      _initializeVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCamera = _cameras[_selectedCameraIndex];
    
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
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.neonRed, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('DEMO MODE', style: TextStyle(fontSize: 10, color: AppColors.neonRed, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.fullscreen, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              
              // Main Video Feed
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.neonCyan, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Video or Placeholder
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
                        else if (_hasError || _videoController == null || !_videoController!.value.isInitialized)
                          _buildVideoPlaceholder(selectedCamera)
                        else
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                        
                        // Overlay Info
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
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: selectedCamera['status'] == 'Online' ? AppColors.neonGreen : AppColors.neonRed, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(selectedCamera['name'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              // ML Scenario Tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.neonCyan.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                                child: Text('ML: ${selectedCamera['scenario']}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
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
              ),
              
              const SizedBox(height: 16),
              
              // Camera Grid
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('All Cameras', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                          itemCount: _cameras.length,
                          itemBuilder: (context, index) => _buildCameraTile(index),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(Map<String, dynamic> camera) {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              camera['status'] == 'Online' ? Icons.videocam : Icons.videocam_off,
              size: 48,
              color: camera['status'] == 'Online' ? AppColors.neonCyan : AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              camera['status'] == 'Online' ? 'Simulated Feed' : 'Camera Offline',
              style: TextStyle(color: camera['status'] == 'Online' ? AppColors.neonCyan : AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text('Pre-recorded video for demo', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraTile(int index) {
    final camera = _cameras[index];
    final isSelected = _selectedCameraIndex == index;
    final isOnline = camera['status'] == 'Online';
    
    return GestureDetector(
      onTap: isOnline ? () => _selectCamera(index) : null,
      child: GlassmorphicCard(
        glowColor: isSelected ? AppColors.neonCyan : null,
        glowIntensity: 0.15,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(isOnline ? Icons.videocam : Icons.videocam_off, color: isOnline ? AppColors.neonCyan : AppColors.textSecondary, size: 18),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: isOnline ? AppColors.neonGreen : AppColors.neonRed, shape: BoxShape.circle)),
              ],
            ),
            const Spacer(),
            Text(camera['name'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isOnline ? AppColors.textPrimary : AppColors.textSecondary)),
            Text(camera['location'], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
