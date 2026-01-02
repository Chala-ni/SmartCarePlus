/// SMARTCARE+ Guardian Dashboard
///
/// Dashboard for guardians/caregivers to monitor elderly users,
/// view alerts, and access real-time monitoring features

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';

class GuardianDashboard extends ConsumerStatefulWidget {
  const GuardianDashboard({super.key});

  @override
  ConsumerState<GuardianDashboard> createState() => _GuardianDashboardState();
}

class _GuardianDashboardState extends ConsumerState<GuardianDashboard> {
  int _currentIndex = 0;

  void _navigateToMonitor() {
    setState(() => _currentIndex = 1);
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
            _GuardianHomeTab(onNavigateToMonitor: _navigateToMonitor),
            const _MonitorTab(),
            const _AlertsTab(),
            _ElderlyListTab(onNavigateToMonitor: _navigateToMonitor),
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
            color: AppColors.neonPurple.withOpacity(0.1),
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
              _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', AppColors.neonPurple),
              _buildNavItem(1, Icons.videocam_outlined, Icons.videocam, 'Monitor', AppColors.neonCyan),
              _buildNavItem(2, Icons.notifications_outlined, Icons.notifications, 'Alerts', AppColors.neonOrange),
              _buildNavItem(3, Icons.people_outlined, Icons.people, 'Elderly', AppColors.neonGreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, Color color) {
    final isSelected = _currentIndex == index;
    final hasNotification = index == 2; // Alerts tab
    
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
            if (hasNotification)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.neonRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonRed.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '3',
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

// ============= Guardian Home Tab =============

class _GuardianHomeTab extends ConsumerWidget {
  final VoidCallback onNavigateToMonitor;
  
  const _GuardianHomeTab({required this.onNavigateToMonitor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final fullName = profile?.name ?? 'Guardian';
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
                        'Guardian Dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hello, $firstName',
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
                    _buildProfileAvatar(),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Alert Summary Card
            _buildAlertSummaryCard(),
            
            const SizedBox(height: 20),
            
            // Monitored Elderly Grid
            const Text(
              'Monitoring',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(child: _buildElderlyStatusCard(
                  name: 'Margaret',
                  status: 'Active',
                  activity: 'Walking',
                  riskLevel: 'Low',
                  color: AppColors.neonGreen,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildElderlyStatusCard(
                  name: 'Robert',
                  status: 'Resting',
                  activity: 'Sitting',
                  riskLevel: 'Medium',
                  color: AppColors.neonOrange,
                )),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recent Alerts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Alerts',
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
            
            _buildAlertCard(
              type: 'Fall Detected',
              elderlyName: 'Margaret',
              time: '2 min ago',
              priority: 'Critical',
              icon: Icons.warning,
              color: AppColors.neonRed,
            ),
            const SizedBox(height: 8),
            _buildAlertCard(
              type: 'Inactivity Warning',
              elderlyName: 'Robert',
              time: '15 min ago',
              priority: 'High',
              icon: Icons.timer_off,
              color: AppColors.neonOrange,
            ),
            const SizedBox(height: 8),
            _buildAlertCard(
              type: 'Geofence Breach',
              elderlyName: 'Margaret',
              time: '1 hour ago',
              priority: 'Medium',
              icon: Icons.location_off,
              color: AppColors.neonPurple,
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
                    icon: Icons.videocam,
                    label: 'Live\nMonitor',
                    color: AppColors.neonCyan,
                    onTap: onNavigateToMonitor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.map,
                    label: 'Geofence\nSetup',
                    color: AppColors.neonPurple,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.history,
                    label: 'Activity\nLog',
                    color: AppColors.neonGreen,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.call,
                    label: 'Call\nElderly',
                    color: AppColors.neonOrange,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.neonPurple, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurple.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: const CircleAvatar(
        backgroundColor: AppColors.surface,
        child: Icon(Icons.person, color: AppColors.neonPurple),
      ),
    );
  }

  Widget _buildAlertSummaryCard() {
    return GlassmorphicCard(
      glowColor: AppColors.neonRed,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.neonRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active, color: AppColors.neonRed, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 Active Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '1 critical, 2 require attention',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.neonRed,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonRed.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Text(
              'View',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElderlyStatusCard({
    required String name,
    required String status,
    required String activity,
    required String riskLevel,
    required Color color,
  }) {
    return GlassmorphicCard(
      glowColor: color,
      glowIntensity: 0.15,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.elderly, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  Text(
                    activity,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Risk',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  Text(
                    riskLevel,
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNavigateToMonitor,
              icon: Icon(Icons.videocam, size: 16, color: color),
              label: Text('Watch', style: TextStyle(color: color, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
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

  Widget _buildAlertCard({
    required String type,
    required String elderlyName,
    required String time,
    required String priority,
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
                  type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$elderlyName • $time',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              priority,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
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
            Icon(icon, color: color, size: 26),
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
}

// ============= Monitor Tab =============

class _MonitorTab extends StatefulWidget {
  const _MonitorTab();

  @override
  State<_MonitorTab> createState() => _MonitorTabState();
}

class _MonitorTabState extends State<_MonitorTab> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _selectedElderly;
  String _currentActivity = 'N/A';
  String _confidence = 'N/A';
  String _fallRisk = 'N/A';
  Timer? _timestampTimer;
  String _currentTimestamp = '';

  // Map elderly to their assigned camera feeds
  final Map<String, Map<String, dynamic>> _elderlyFeeds = {
    'Margaret': {
      'video': 'assets/videos/walking_normal_1.mp4',
      'activity': 'Walking',
      'confidence': '94%',
      'fallRisk': 'Low',
      'location': 'Living Room',
    },
    'Robert': {
      'video': 'assets/videos/sitting_resting_1.mp4',
      'activity': 'Resting',
      'confidence': '89%',
      'fallRisk': 'Low',
      'location': 'Bedroom',
    },
  };

  @override
  void initState() {
    super.initState();
    _updateTimestamp();
    _timestampTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimestamp());
  }

  void _updateTimestamp() {
    final now = DateTime.now();
    setState(() {
      _currentTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _timestampTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _startWatching(String elderlyName) async {
    final feed = _elderlyFeeds[elderlyName];
    if (feed == null) return;

    setState(() {
      _isLoading = true;
      _selectedElderly = elderlyName;
    });

    try {
      // Dispose old controller
      await _videoController?.dispose();
      
      // Initialize new video
      _videoController = VideoPlayerController.asset(feed['video']);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      await _videoController!.play();

      setState(() {
        _isPlaying = true;
        _isLoading = false;
        _currentActivity = feed['activity'];
        _confidence = feed['confidence'];
        _fallRisk = feed['fallRisk'];
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
      }
    }
  }

  void _stopWatching() {
    _videoController?.pause();
    setState(() {
      _isPlaying = false;
      _selectedElderly = null;
      _currentActivity = 'N/A';
      _confidence = 'N/A';
      _fallRisk = 'N/A';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Monitor',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedElderly != null 
                    ? 'Watching ${_selectedElderly} - ${_elderlyFeeds[_selectedElderly]?['location']}'
                    : 'Real-time elderly monitoring',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Live Feed Container
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPlaying ? AppColors.neonGreen : AppColors.glassBorder,
                      width: _isPlaying ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Video or Placeholder
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(color: AppColors.neonCyan),
                          )
                        else if (_isPlaying && _videoController != null && _videoController!.value.isInitialized)
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: VideoPlayer(_videoController!),
                            ),
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Select an elderly to start monitoring',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        
                        // Live/Offline indicator
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isPlaying 
                                ? AppColors.neonGreen.withOpacity(0.2)
                                : AppColors.neonRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle, 
                                  color: _isPlaying ? AppColors.neonGreen : AppColors.neonRed, 
                                  size: 8,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isPlaying ? 'LIVE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: _isPlaying ? AppColors.neonGreen : AppColors.neonRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Stop button when playing
                        if (_isPlaying)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: _stopWatching,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        
                        // Elderly name overlay when playing
                        if (_isPlaying && _selectedElderly != null)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedElderly!,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        
                        // Live timestamp overlay
                        if (_isPlaying)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                
                const SizedBox(height: 16),
                
                // Activity Overlay Info
                GlassmorphicCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildOverlayInfo('Activity', _currentActivity, Icons.directions_walk, AppColors.neonCyan),
                      _buildOverlayInfo('Confidence', _confidence, Icons.verified, AppColors.neonGreen),
                      _buildOverlayInfo('Fall Risk', _fallRisk, Icons.warning, AppColors.neonOrange),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Elderly Selection
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Elderly',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildElderlySelectCard('Margaret', 'Last active: 2 min ago', true),
                        _buildElderlySelectCard('Robert', 'Last active: 15 min ago', true),
                      ],
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

  Widget _buildOverlayInfo(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildElderlySelectCard(String name, String lastActive, bool isOnline) {
    final isSelected = _selectedElderly == name && _isPlaying;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        glowColor: isSelected ? AppColors.neonGreen : null,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.elderly, color: AppColors.textSecondary),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.neonGreen : AppColors.textSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    lastActive,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isOnline ? () => _startWatching(name) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? AppColors.neonGreen : AppColors.neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                isSelected ? 'Watching' : 'Watch', 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= Alerts Tab =============

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerts',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '3 unacknowledged alerts',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      const Text(
                        'Filter',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Alert Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('All', true),
                const SizedBox(width: 8),
                _buildFilterChip('Critical', false),
                const SizedBox(width: 8),
                _buildFilterChip('Falls', false),
                const SizedBox(width: 8),
                _buildFilterChip('Geofence', false),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Alerts List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildDetailedAlertCard(
                  type: 'Fall Detected',
                  elderlyName: 'Margaret',
                  time: '2 min ago',
                  description: 'Possible fall detected in living room. Immediate attention required.',
                  priority: 'Critical',
                  icon: Icons.warning,
                  color: AppColors.neonRed,
                  isNew: true,
                ),
                const SizedBox(height: 12),
                _buildDetailedAlertCard(
                  type: 'Extended Inactivity',
                  elderlyName: 'Robert',
                  time: '15 min ago',
                  description: 'No movement detected for 45 minutes. Last location: Bedroom.',
                  priority: 'High',
                  icon: Icons.timer_off,
                  color: AppColors.neonOrange,
                  isNew: true,
                ),
                const SizedBox(height: 12),
                _buildDetailedAlertCard(
                  type: 'Geofence Breach',
                  elderlyName: 'Margaret',
                  time: '1 hour ago',
                  description: 'Left designated safe zone "Home" at 2:30 PM.',
                  priority: 'Medium',
                  icon: Icons.location_off,
                  color: AppColors.neonPurple,
                  isNew: true,
                ),
                const SizedBox(height: 12),
                _buildDetailedAlertCard(
                  type: 'Activity Anomaly',
                  elderlyName: 'Robert',
                  time: '3 hours ago',
                  description: 'Unusual activity pattern detected. Consider check-in.',
                  priority: 'Low',
                  icon: Icons.psychology,
                  color: AppColors.neonCyan,
                  isNew: false,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.neonCyan.withOpacity(0.15) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.neonCyan : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? AppColors.neonCyan : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildDetailedAlertCard({
    required String type,
    required String elderlyName,
    required String time,
    required String description,
    required String priority,
    required IconData icon,
    required Color color,
    required bool isNew,
  }) {
    return GlassmorphicCard(
      glowColor: isNew ? color : null,
      glowIntensity: 0.15,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Row(
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neonRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$elderlyName • $time',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('Acknowledge', style: TextStyle(color: color, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Respond', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============= Elderly List Tab =============

class _ElderlyListTab extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToMonitor;
  
  const _ElderlyListTab({required this.onNavigateToMonitor});

  @override
  ConsumerState<_ElderlyListTab> createState() => _ElderlyListTabState();
}

class _ElderlyListTabState extends ConsumerState<_ElderlyListTab> {
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load connected elderly on init - only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoaded) {
        _hasLoaded = true;
        ref.read(connectionProvider.notifier).loadMyElderly();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final elderlyList = connectionState.myElderly;
    
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
                  'My Elderly',
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
                    child: const Icon(Icons.add, color: AppColors.neonGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              elderlyList.isEmpty 
                  ? 'No elderly connected yet'
                  : '${elderlyList.length} elderly under your care',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Connected Elderly Cards
            if (connectionState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (elderlyList.isEmpty)
              _buildEmptyState()
            else
              ...elderlyList.map((elderly) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildElderlyProfileCard(
                  name: elderly.name,
                  connectionType: elderly.connectionType,
                  connectedAt: elderly.connectedAt,
                  color: elderly.connectionType == 'guardian' 
                      ? AppColors.neonGreen 
                      : AppColors.neonOrange,
                ),
              )),
          ],
        ),
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
            Icons.elderly_woman,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Elderly Connected',
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
            label: const Text('Add Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonGreen,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElderlyProfileCard({
    required String name,
    required String connectionType,
    required String connectedAt,
    required Color color,
  }) {
    // Parse connection date
    String connectionDate = 'Connected';
    try {
      final date = DateTime.parse(connectedAt);
      final diff = DateTime.now().difference(date);
      if (diff.inDays == 0) {
        connectionDate = 'Connected today';
      } else if (diff.inDays == 1) {
        connectionDate = 'Connected yesterday';
      } else {
        connectionDate = 'Connected ${diff.inDays} days ago';
      }
    } catch (_) {}
    
    return GlassmorphicCard(
      glowColor: color,
      glowIntensity: 0.15,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(Icons.elderly, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connectionDate,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          connectionType == 'guardian' ? 'Guardian' : 'Caregiver',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Connection type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  connectionType == 'guardian' ? '👨‍👩‍👦 Family' : '👩‍⚕️ Care',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onNavigateToMonitor,
                  icon: const Icon(Icons.videocam, size: 18),
                  label: const Text('Watch'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withOpacity(0.5)),
                    foregroundColor: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('Reports'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
