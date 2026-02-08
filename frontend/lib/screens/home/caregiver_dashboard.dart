/// SMARTCARE+ Caregiver Dashboard
///
/// Dashboard for professional caregivers with patient management,
/// health reports, and task scheduling features

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../core/services/api_service.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../widgets/mjpeg_stream.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';

class CaregiverDashboard extends ConsumerStatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  ConsumerState<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends ConsumerState<CaregiverDashboard> {
  int _currentIndex = 0;
  ElderlyInfo? _selectedPatientForMonitor;

  void _navigateToPatients([ElderlyInfo? patient]) {
    setState(() {
      _selectedPatientForMonitor = patient;
      _currentIndex = 1;
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
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _CaregiverHomeTab(onNavigateToPatients: _navigateToPatients),
            _PatientsTab(
              initialPatient: _selectedPatientForMonitor,
              onPatientConsumed: () => _selectedPatientForMonitor = null,
            ),
            const _TasksTab(),
            const _ReportsTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonGreen.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Home', AppColors.neonGreen),
              _buildNavItem(1, Icons.people_outlined, Icons.people, 'Patients', AppColors.neonCyan),
              _buildNavItem(2, Icons.task_outlined, Icons.task, 'Tasks', AppColors.neonOrange),
              _buildNavItem(3, Icons.assessment_outlined, Icons.assessment, 'Reports', AppColors.neonPurple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, Color color) {
    final isSelected = _currentIndex == index;
    final hasBadge = index == 2; // Tasks tab
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? color : AppColors.textSecondary,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (hasBadge)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.neonOrange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonOrange.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '5',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

// ============= Caregiver Home Tab =============

class _CaregiverHomeTab extends ConsumerWidget {
  final void Function([ElderlyInfo?]) onNavigateToPatients;
  
  const _CaregiverHomeTab({required this.onNavigateToPatients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final fullName = profile?.name ?? 'Caregiver';
    final firstName = fullName.split(' ').first;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Caregiver Dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        firstName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Connections Button
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.connections),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.link, color: AppColors.neonCyan, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Logout Button
                    GestureDetector(
                      onTap: () => _showLogoutDialog(context, ref),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout, color: AppColors.neonRed, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildProfileAvatar(context),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Today's Summary
            _buildDaySummaryCard(),
            
            const SizedBox(height: 20),
            
            // Stats Row
            Row(
              children: [
                Expanded(child: _buildStatCard('Patients', '8', Icons.people, AppColors.neonCyan)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Tasks', '5', Icons.task, AppColors.neonOrange)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Alerts', '2', Icons.warning, AppColors.neonRed)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Upcoming Tasks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All', style: TextStyle(color: AppColors.neonCyan)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            _buildTaskItem(
              task: 'Physio session with Margaret',
              time: '10:00 AM',
              type: 'Exercise',
              icon: Icons.accessibility_new,
              color: AppColors.neonGreen,
            ),
            const SizedBox(height: 8),
            _buildTaskItem(
              task: 'Medication reminder for Robert',
              time: '11:30 AM',
              type: 'Medication',
              icon: Icons.medication,
              color: AppColors.neonPurple,
            ),
            const SizedBox(height: 8),
            _buildTaskItem(
              task: 'Health check for Eleanor',
              time: '2:00 PM',
              type: 'Check-up',
              icon: Icons.health_and_safety,
              color: AppColors.neonCyan,
            ),
            
            const SizedBox(height: 24),
            
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.fitness_center,
                    label: 'Prescribe\nExercise',
                    color: AppColors.neonGreen,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.restaurant_menu,
                    label: 'Create\nMeal Plan',
                    color: AppColors.neonOrange,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.assessment,
                    label: 'View\nReports',
                    color: AppColors.neonPurple,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.videocam,
                    label: 'Check\nPatient',
                    color: AppColors.neonCyan,
                    onTap: onNavigateToPatients,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recent Activity
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildActivityLog('Completed physio session', 'Margaret', '30 min ago', AppColors.neonGreen),
            _buildActivityLog('Updated meal plan', 'Robert', '1 hour ago', AppColors.neonOrange),
            _buildActivityLog('Fall risk assessment', 'Eleanor', '2 hours ago', AppColors.neonCyan),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.login,
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonRed),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, Routes.caregiverProfile);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.neonGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonGreen.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: const CircleAvatar(
          backgroundColor: AppColors.surface,
          child: Icon(Icons.person, color: AppColors.neonGreen),
        ),
      ),
    );
  }

  Widget _buildDaySummaryCard() {
    return GlassmorphicCard(
      glowColor: AppColors.neonGreen,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.today, color: AppColors.neonGreen),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'January 1, 2026',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDayStat('Completed', '3', AppColors.neonGreen),
              _buildDayStat('Pending', '5', AppColors.neonOrange),
              _buildDayStat('Overdue', '0', AppColors.neonRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return GlassmorphicCard(
      glowColor: color,
      glowIntensity: 0.1,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem({
    required String task,
    required String time,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.check_circle_outline, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicCard(
        glowColor: color,
        glowIntensity: 0.1,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLog(String action, String patient, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                children: [
                  TextSpan(text: action),
                  const TextSpan(text: ' - '),
                  TextSpan(
                    text: patient,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ============= Patients Tab =============

class _PatientsTab extends ConsumerStatefulWidget {
  final ElderlyInfo? initialPatient;
  final VoidCallback? onPatientConsumed;
  
  const _PatientsTab({this.initialPatient, this.onPatientConsumed});

  @override
  ConsumerState<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends ConsumerState<_PatientsTab> {
  bool _isStreaming = false;
  bool _isLoading = false;
  String? _selectedPatient;
  String _streamUrl = '';
  Timer? _timestampTimer;
  Timer? _analysisTimer;
  String _currentTimestamp = '';
  bool _hasLoadedElderly = false;
  String? _currentVideoId; // Track current video ID
  ElderlyInfo? _consumedPatient; // Track consumed patient to prevent re-consuming
  
  // Hybrid detection state
  String _currentActivity = 'N/A';
  String _confidence = 'N/A';
  String _fallRisk = 'N/A';
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
  
  /// Get the video URL from the backend
  String _getVideoUrl(String videoId) {
    return '${ApiConfig.streamBaseUrl}${ApiConfig.guardian}/video/$videoId';
  }
  
  /// Handle new frame from MJPEG stream
  void _onFrameReceived(Uint8List frameBytes) {
    _lastCapturedFrame = frameBytes;
  }
  
  /// Send a frame to the backend for live detection
  Future<void> _sendFrameForDetection() async {
    if (_currentVideoId == null || _currentVideoId!.isEmpty || _lastCapturedFrame == null) return;
    
    // Throttle: send max 1 frame per second
    final now = DateTime.now();
    if (_lastFrameSentAt != null && 
        now.difference(_lastFrameSentAt!).inMilliseconds < 900) {
      return;
    }
    _lastFrameSentAt = now;
    
    setState(() {
      _isAnalyzing = true;
    });
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final sessionId = _currentVideoId!;
      
      // Encode frame as base64
      final frameBase64 = base64Encode(_lastCapturedFrame!);
      
      // Send to streaming detection endpoint
      final response = await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.guardian}/stream/$sessionId/frame',
        body: {
          'frame_base64': frameBase64,
          'elderly_id': _selectedPatient,
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
            _confidence = '${((detection['confidence'] ?? 0.0) * 100).toInt()}%';
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
  
  /// Start streaming session and periodic frame sending
  Future<void> _startAnalysis() async {
    if (_currentVideoId == null || _currentVideoId!.isEmpty) return;
    
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
        body: {'elderly_id': _selectedPatient},
        requireAuth: false,
      );
      debugPrint('🎥 Stream session started: $_currentVideoId');
    } catch (e) {
      debugPrint('Failed to start stream session: $e');
    }
    
    // Start periodic frame sending (1 fps)
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    if (_currentVideoId != null && _currentVideoId!.isNotEmpty) {
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
              '${_selectedPatient ?? "Patient"} may have fallen.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fall Type: $_fallType', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text('Confidence: $_confidence', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text('Detection: $_detectionSource', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('Layer Scores:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (_layerScores.isNotEmpty) ...[
                    _buildScoreBar('Skeleton', _layerScores['skeleton'] ?? 0, AppColors.neonCyan),
                    _buildScoreBar('Motion', _layerScores['motion'] ?? 0, AppColors.neonGreen),
                    _buildScoreBar('Deep Learning', _layerScores['deep_learning'] ?? 0, AppColors.neonPurple),
                  ],
                ],
              ),
            ),
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonRed),
            child: const Text('Call Emergency'),
          ),
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

  @override
  void initState() {
    super.initState();
    _updateTimestamp();
    _timestampTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimestamp());
    // Load connected elderly - only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedElderly) {
        _hasLoadedElderly = true;
        ref.read(connectionProvider.notifier).loadMyElderly();
      }
      // Auto-start watching if initial patient is passed
      _checkForInitialPatient();
    });
  }
  
  void _checkForInitialPatient() {
    if (widget.initialPatient != null && widget.initialPatient != _consumedPatient) {
      _consumedPatient = widget.initialPatient;
      _startWatchingElderly(widget.initialPatient!);
      widget.onPatientConsumed?.call();
    }
  }
  
  @override
  void didUpdateWidget(covariant _PatientsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if new initial patient was passed
    _checkForInitialPatient();
  }
  
  void _startWatchingElderly(ElderlyInfo elderly) {
    final videoUrl = _getVideoUrl(elderly.assignedVideoId);
    
    debugPrint('🎬 Caregiver Monitor: Starting stream for ${elderly.name}');
    debugPrint('🎬 Stream URL: $videoUrl');

    setState(() {
      _selectedPatient = elderly.name;
      _currentVideoId = elderly.assignedVideoId;
      _streamUrl = videoUrl;
      _isStreaming = true;
      _isLoading = false;
      _currentActivity = 'Analyzing...';
      _confidence = '...';
      _fallRisk = '...';
      _fallDetected = false;
      _layerScores = {};
    });
    
    // Start hybrid ML analysis
    _startAnalysis();
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

  @override
  void dispose() {
    _timestampTimer?.cancel();
    _analysisTimer?.cancel();
    super.dispose();
  }

  void _stopWatching() {
    _stopAnalysis();
    setState(() {
      _isStreaming = false;
      _streamUrl = '';
      _selectedPatient = null;
      _currentVideoId = null;
      _currentActivity = 'N/A';
      _confidence = 'N/A';
      _fallRisk = 'N/A';
      _fallDetected = false;
      _layerScores = {};
      _detectionSource = '';
    });
  }
  
  void _showFullscreenVideo(BuildContext context) {
    if (_streamUrl.isEmpty || _selectedPatient == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenVideoScreen(
          streamUrl: _streamUrl,
          patientName: _selectedPatient!,
          timestamp: _currentTimestamp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final connectedElderly = connectionState.myElderly;
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Patients',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.connections),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add, color: AppColors.neonGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              connectedElderly.isEmpty 
                  ? 'No patients connected yet' 
                  : '${connectedElderly.length} patient${connectedElderly.length == 1 ? '' : 's'} under your care',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Video Feed Area (shows when watching)
            if (_isStreaming || _isLoading)
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neonGreen, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
                      else if (_streamUrl.isNotEmpty)
                        MjpegStream(
                          streamUrl: _streamUrl,
                          isLive: true,
                          fit: BoxFit.cover,
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(color: AppColors.neonCyan),
                          ),
                          onError: (error) {
                            debugPrint('❌ Caregiver Monitor Error: $error');
                          },
                          onFrame: _onFrameReceived,
                        ),
                      // LIVE indicator
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.neonGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: AppColors.neonGreen, size: 8),
                              SizedBox(width: 4),
                              Text('LIVE', style: TextStyle(color: AppColors.neonGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      // Close and Fullscreen buttons
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showFullscreenVideo(context),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _stopWatching,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Patient name & timestamp
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: Text(_selectedPatient ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time, color: AppColors.neonCyan, size: 12),
                                  const SizedBox(width: 4),
                                  Text(_currentTimestamp, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Activity Stats (show when streaming)
            if (_isStreaming) ...[
              const SizedBox(height: 12),
              GlassmorphicCard(
                glowColor: _fallDetected ? AppColors.neonRed : null,
                glowIntensity: _fallDetected ? 0.3 : 0,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          _fallDetected ? Icons.warning : Icons.directions_walk, 
                          _currentActivity, 
                          'Activity', 
                          _fallDetected ? AppColors.neonRed : AppColors.neonCyan,
                        ),
                        _buildStatItem(Icons.verified, _confidence, 'Confidence', AppColors.neonGreen),
                        _buildStatItem(
                          Icons.health_and_safety, 
                          _fallRisk, 
                          'Fall Risk', 
                          _fallRisk == 'Critical' ? AppColors.neonRed 
                              : _fallRisk == 'Medium' ? AppColors.neonOrange 
                              : AppColors.neonGreen,
                        ),
                      ],
                    ),
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPurple),
                          ),
                          const SizedBox(width: 8),
                          const Text('Analyzing with hybrid model...', style: TextStyle(fontSize: 10, color: AppColors.neonPurple)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Layer scores
              if (_layerScores.isNotEmpty) ...[
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
            
            const SizedBox(height: 16),
            
            // Connected Elderly Cards (from API)
            if (connectedElderly.isEmpty)
              _buildEmptyState()
            else ...[
              const Text(
                'My Patients',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neonGreen,
                ),
              ),
              const SizedBox(height: 12),
              ...connectedElderly.map((elderly) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildConnectedPatientCard(elderly),
              )),
            ],
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
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
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
  
  Widget _buildEmptyState() {
    return GlassmorphicCard(
      glowColor: AppColors.neonGreen,
      glowIntensity: 0.1,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Patients Connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect with elderly users by sharing your invite code or entering their code.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.connections),
            icon: const Icon(Icons.add),
            label: const Text('Add Patient'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonGreen,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedPatientCard(ElderlyInfo elderly) {
    final isSelected = _selectedPatient == elderly.name && _isStreaming;
    
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          _stopWatching();
        } else {
          _startWatchingElderly(elderly);
        }
      },
      child: GlassmorphicCard(
        glowColor: isSelected ? AppColors.neonGreen : AppColors.neonCyan,
        glowIntensity: isSelected ? 0.3 : 0.15,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.neonGreen, width: 2),
                  ),
                  child: const Icon(Icons.elderly, color: AppColors.neonGreen),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        elderly.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neonGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isSelected ? '📺 Watching' : '✓ Connected',
                              style: TextStyle(
                                fontSize: 10, 
                                color: isSelected ? AppColors.neonGreen : AppColors.neonCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isSelected ? AppColors.neonGreen : AppColors.neonCyan).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSelected ? Icons.stop_circle : Icons.videocam, 
                    color: isSelected ? AppColors.neonGreen : AppColors.neonCyan, 
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Nutrition Summary
            _PatientNutritionSummary(elderlyId: elderly.id),
          ],
        ),
      ),
    );
  }
}

// ============= Patient Nutrition Summary Widget =============

class _PatientNutritionSummary extends ConsumerStatefulWidget {
  final String elderlyId;
  
  const _PatientNutritionSummary({required this.elderlyId});

  @override
  ConsumerState<_PatientNutritionSummary> createState() => _PatientNutritionSummaryState();
}

class _PatientNutritionSummaryState extends ConsumerState<_PatientNutritionSummary> {
  bool _isLoading = true;
  int _calories = 0;
  int _caloriesTarget = 1800;
  int _hydrationGlasses = 0;

  @override
  void initState() {
    super.initState();
    _loadNutritionData();
  }

  Future<void> _loadNutritionData() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/api/nutrition/daily-summary/${widget.elderlyId}');
      if (response.success && response.data != null && mounted) {
        setState(() {
          _calories = (response.data['total_calories'] as num?)?.toInt() ?? 0;
          _caloriesTarget = (response.data['target_calories'] as num?)?.toInt() ?? 1800;
        });
      }
      
      final hydrationResponse = await api.get('/api/nutrition/hydration/${widget.elderlyId}');
      if (hydrationResponse.success && hydrationResponse.data != null && mounted) {
        setState(() {
          _hydrationGlasses = (hydrationResponse.data['glasses'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading patient nutrition: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 30,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final caloriePercent = _caloriesTarget > 0 ? (_calories / _caloriesTarget * 100).clamp(0, 100).toInt() : 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: AppColors.neonOrange, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_calories cal ($caloriePercent%)',
                style: const TextStyle(fontSize: 11, color: AppColors.neonOrange, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Container(width: 1, height: 20, color: AppColors.glassBorder),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.water_drop, color: AppColors.neonPurple, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_hydrationGlasses/8 glasses',
                style: const TextStyle(fontSize: 11, color: AppColors.neonPurple, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============= Tasks Tab =============

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Tasks',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        'Add Task',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Task filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('Today', true),
                const SizedBox(width: 8),
                _buildFilterChip('This Week', false),
                const SizedBox(width: 8),
                _buildFilterChip('All', false),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Task List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildTaskCard(
                  title: 'Physio session - Margaret',
                  time: '10:00 AM',
                  duration: '30 min',
                  type: 'Exercise',
                  color: AppColors.neonGreen,
                  isPriority: true,
                ),
                const SizedBox(height: 10),
                _buildTaskCard(
                  title: 'Medication reminder - Robert',
                  time: '11:30 AM',
                  duration: '5 min',
                  type: 'Medication',
                  color: AppColors.neonPurple,
                  isPriority: false,
                ),
                const SizedBox(height: 10),
                _buildTaskCard(
                  title: 'Health check - Eleanor',
                  time: '2:00 PM',
                  duration: '20 min',
                  type: 'Check-up',
                  color: AppColors.neonCyan,
                  isPriority: false,
                ),
                const SizedBox(height: 10),
                _buildTaskCard(
                  title: 'Update meal plan - James',
                  time: '3:30 PM',
                  duration: '15 min',
                  type: 'Nutrition',
                  color: AppColors.neonOrange,
                  isPriority: false,
                ),
                const SizedBox(height: 10),
                _buildTaskCard(
                  title: 'TUG test - Helen',
                  time: '4:00 PM',
                  duration: '10 min',
                  type: 'Assessment',
                  color: AppColors.neonGreen,
                  isPriority: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.neonGreen.withOpacity(0.15) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.neonGreen : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isSelected ? AppColors.neonGreen : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String time,
    required String duration,
    required String type,
    required Color color,
    required bool isPriority,
  }) {
    return GlassmorphicCard(
      glowColor: isPriority ? color : null,
      glowIntensity: 0.1,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.neonRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Priority',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.neonRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$time • $duration',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Checkbox(
            value: false,
            onChanged: (value) {},
            activeColor: AppColors.neonGreen,
            side: const BorderSide(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ============= Reports Tab =============

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Patient health and progress reports',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Report Types
            _buildReportTypeCard(
              title: 'Weekly Health Summary',
              description: 'Overview of all patients\' health metrics',
              icon: Icons.health_and_safety,
              color: AppColors.neonGreen,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              title: 'Physio Progress',
              description: 'Gait analysis and exercise completion',
              icon: Icons.accessibility_new,
              color: AppColors.neonCyan,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              title: 'Nutrition Tracking',
              description: 'Meal plans and dietary adherence',
              icon: Icons.restaurant_menu,
              color: AppColors.neonOrange,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              title: 'Fall Risk Assessment',
              description: 'TUG scores and risk analysis',
              icon: Icons.warning,
              color: AppColors.neonRed,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              title: 'Activity Logs',
              description: 'Daily activity patterns and anomalies',
              icon: Icons.timeline,
              color: AppColors.neonPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }
}

// ============= Fullscreen Video Screen =============

class _FullscreenVideoScreen extends StatefulWidget {
  final String streamUrl;
  final String patientName;
  final String timestamp;
  
  const _FullscreenVideoScreen({
    required this.streamUrl,
    required this.patientName,
    required this.timestamp,
  });

  @override
  State<_FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<_FullscreenVideoScreen> {
  Timer? _timestampTimer;
  String _currentTimestamp = '';
  
  @override
  void initState() {
    super.initState();
    _currentTimestamp = widget.timestamp;
    _timestampTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimestamp());
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
  
  @override
  void dispose() {
    _timestampTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video stream
          MjpegStream(
            streamUrl: widget.streamUrl,
            isLive: true,
            fit: BoxFit.contain,
            loadingWidget: const Center(
              child: CircularProgressIndicator(color: AppColors.neonCyan),
            ),
            onError: (error) {
              debugPrint('❌ Fullscreen Video Error: $error');
            },
          ),
          
          // LIVE indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: AppColors.neonGreen, size: 10),
                  SizedBox(width: 6),
                  Text('LIVE', style: TextStyle(color: AppColors.neonGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 24),
              ),
            ),
          ),
          
          // Patient name
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.patientName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
          
          // Timestamp
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: AppColors.neonCyan, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _currentTimestamp,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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
    );
  }
}