/// SMARTCARE+ Guardian Dashboard
///
/// Dashboard for guardians/caregivers to monitor elderly users,
/// view alerts, and access real-time monitoring features

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
import 'package:url_launcher/url_launcher.dart';

class GuardianDashboard extends ConsumerStatefulWidget {
  const GuardianDashboard({super.key});

  @override
  ConsumerState<GuardianDashboard> createState() => _GuardianDashboardState();
}

class _GuardianDashboardState extends ConsumerState<GuardianDashboard> {
  int _currentIndex = 0;
  ElderlyInfo? _selectedElderlyForMonitor;
  int _unacknowledgedAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAlertCount();
  }

  Future<void> _fetchAlertCount() async {
    try {
      final profile = ref.read(userProfileProvider);
      if (profile?.uid == null) return;
      
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/alerts/${profile!.uid}',
        requireAuth: false,
      );
      
      if (response.success && response.data != null) {
        final alerts = (response.data!['alerts'] as List?) ?? [];
        final unacknowledged = alerts.where((a) => a['resolved'] != true).toList();
        if (mounted) {
          setState(() {
            _unacknowledgedAlertCount = unacknowledged.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching alert count: $e');
    }
  }

  void _navigateToMonitor([ElderlyInfo? elderly]) {
    setState(() {
      _selectedElderlyForMonitor = elderly;
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
            _GuardianHomeTab(onNavigateToMonitor: _navigateToMonitor),
            _MonitorTab(
              initialElderly: _selectedElderlyForMonitor,
              onElderlyConsumed: () => _selectedElderlyForMonitor = null,
            ),
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
    final isAlertsTab = index == 2; // Alerts tab
    final badgeCount = isAlertsTab ? _unacknowledgedAlertCount : 0;
    
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (isAlertsTab) _fetchAlertCount(); // Refresh on navigation
      },
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
            if (badgeCount > 0)
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
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
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

class _GuardianHomeTab extends ConsumerStatefulWidget {
  final void Function([ElderlyInfo?]) onNavigateToMonitor;
  
  const _GuardianHomeTab({required this.onNavigateToMonitor});

  @override
  ConsumerState<_GuardianHomeTab> createState() => _GuardianHomeTabState();
}

class _GuardianHomeTabState extends ConsumerState<_GuardianHomeTab> {
  bool _hasLoadedElderly = false;
  List<Map<String, dynamic>> _recentAlerts = [];
  int _activeAlertCount = 0;
  int _criticalCount = 0;
  bool _isLoadingAlerts = false;
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedElderly) {
        _hasLoadedElderly = true;
        ref.read(connectionProvider.notifier).loadMyElderly();
        _fetchAlerts();
        // Refresh alerts every 30 seconds for real-time updates
        _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) _fetchAlerts();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _fetchAlerts() async {
    if (_isLoadingAlerts) return;
    setState(() => _isLoadingAlerts = true);
    
    try {
      final profile = ref.read(userProfileProvider);
      final guardianId = profile?.uid ?? '';
      final apiService = ref.read(apiServiceProvider);
      
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/alerts/$guardianId?limit=5',
        requireAuth: false,
      );
      
      if (response.success && response.data != null) {
        final alerts = (response.data!['alerts'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
        
        setState(() {
          _recentAlerts = alerts.take(3).toList();
          _activeAlertCount = response.data!['active_count'] ?? 0;
          _criticalCount = alerts.where((a) => a['severity'] == 'critical' && !(a['resolved'] ?? false)).length;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch alerts: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAlerts = false);
    }
  }
  
  /// Format timestamp to human-readable time ago
  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) return '${difference.inHours} hour${difference.inHours == 1 ? "" : "s"} ago';
      if (difference.inDays < 7) return '${difference.inDays} day${difference.inDays == 1 ? "" : "s"} ago';
      return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() == 1 ? "" : "s"} ago';
    } catch (e) {
      return 'Recently';
    }
  }
  
  /// Get activity info based on video ID
  Map<String, String> _getActivityFromVideo(String videoId) {
    if (videoId.contains('walking')) {
      return {'activity': 'Walking', 'status': 'Active', 'risk': 'Low'};
    } else if (videoId.contains('sitting') || videoId.contains('resting')) {
      return {'activity': 'Resting', 'status': 'Resting', 'risk': 'Low'};
    } else if (videoId.contains('standing')) {
      return {'activity': 'Standing', 'status': 'Active', 'risk': 'Low'};
    } else if (videoId.contains('lying')) {
      return {'activity': 'Lying Down', 'status': 'Resting', 'risk': 'Medium'};
    } else if (videoId.contains('fall')) {
      return {'activity': 'Alert!', 'status': 'Alert', 'risk': 'High'};
    } else if (videoId.contains('gait')) {
      return {'activity': 'Walking', 'status': 'Active', 'risk': videoId.contains('abnormal') ? 'Medium' : 'Low'};
    }
    return {'activity': 'Active', 'status': 'Online', 'risk': 'Low'};
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final connectionState = ref.watch(connectionProvider);
    final elderlyList = connectionState.myElderly;
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
                    _buildProfileAvatar(context),
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
            
            if (elderlyList.isEmpty)
              GlassmorphicCard(
                glowColor: AppColors.neonCyan,
                glowIntensity: 0.1,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.textSecondary.withOpacity(0.5)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No elderly connected. Add connections to start monitoring.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: elderlyList.take(2).map((elderly) {
                  final activityInfo = _getActivityFromVideo(elderly.assignedVideoId);
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    child: _buildElderlyStatusCard(
                      elderly: elderly,
                      status: activityInfo['status']!,
                      activity: activityInfo['activity']!,
                      riskLevel: activityInfo['risk']!,
                      color: activityInfo['risk'] == 'High' 
                          ? AppColors.neonRed 
                          : activityInfo['risk'] == 'Medium' 
                              ? AppColors.neonOrange 
                              : AppColors.neonGreen,
                    ),
                  );
                }).toList(),
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
                  onPressed: () {
                    // Navigate to Alerts tab
                    final dashboardState = context.findAncestorStateOfType<_GuardianDashboardState>();
                    dashboardState?.setState(() => dashboardState._currentIndex = 2);
                  },
                  child: const Text('View All', style: TextStyle(color: AppColors.neonCyan)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (_isLoadingAlerts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.neonCyan),
                ),
              )
            else if (_recentAlerts.isEmpty)
              GlassmorphicCard(
                glowColor: AppColors.neonGreen,
                glowIntensity: 0.1,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.neonGreen.withOpacity(0.7)),
                    const SizedBox(width: 12),
                    const Text(
                      'No recent alerts',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ..._recentAlerts.map((alert) {
                final alertType = alert['alert_type'] ?? 'unknown';
                final elderlyName = alert['elderly_name'] ?? 'Unknown';
                final createdAt = alert['created_at'] as String?;
                final timeAgo = _formatTimeAgo(createdAt);
                
                IconData icon;
                Color color;
                String displayType;
                String priority;
                
                switch (alertType) {
                  case 'fall':
                    icon = Icons.warning;
                    color = AppColors.neonRed;
                    displayType = 'Fall Detected';
                    priority = 'Critical';
                    break;
                  case 'gait':
                    icon = Icons.directions_walk;
                    color = AppColors.neonOrange;
                    displayType = 'Abnormal Gait';
                    priority = 'Warning';
                    break;
                  case 'inactivity':
                    icon = Icons.timer_off;
                    color = AppColors.neonOrange;
                    displayType = 'Inactivity Warning';
                    priority = 'Warning';
                    break;
                  default:
                    icon = Icons.notifications;
                    color = AppColors.neonCyan;
                    displayType = 'Alert';
                    priority = 'Info';
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildAlertCard(
                    type: displayType,
                    elderlyName: elderlyName,
                    time: timeAgo,
                    priority: priority,
                    icon: icon,
                    color: color,
                  ),
                );
              }),
            
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
                    onTap: widget.onNavigateToMonitor,
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

  Widget _buildProfileAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.guardianProfile),
      child: Container(
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
      ),
    );
  }

  Widget _buildAlertSummaryCard() {
    if (_activeAlertCount == 0) {
      return GlassmorphicCard(
        glowColor: AppColors.neonGreen,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Active Alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'All elderly are safe',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    final otherCount = _activeAlertCount - _criticalCount;
    final subtitle = _criticalCount > 0 
        ? '$_criticalCount critical${otherCount > 0 ? ", $otherCount require attention" : ""}'
        : '$otherCount require attention';
    
    return GestureDetector(
      onTap: () {
        // Navigate to Alerts tab (index 2)
        final dashboardState = context.findAncestorStateOfType<_GuardianDashboardState>();
        dashboardState?.setState(() => dashboardState._currentIndex = 2);
      },
      child: GlassmorphicCard(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_activeAlertCount Active Alert${_activeAlertCount == 1 ? "" : "s"}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
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
      ),
    );
  }

  Widget _buildElderlyStatusCard({
    required ElderlyInfo elderly,
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
                      elderly.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
              onPressed: () => widget.onNavigateToMonitor(elderly),
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

class _MonitorTab extends ConsumerStatefulWidget {
  final ElderlyInfo? initialElderly;
  final VoidCallback? onElderlyConsumed;
  
  const _MonitorTab({this.initialElderly, this.onElderlyConsumed});

  @override
  ConsumerState<_MonitorTab> createState() => _MonitorTabState();
}

class _MonitorTabState extends ConsumerState<_MonitorTab> {
  bool _isStreaming = false;
  bool _isLoading = false;
  ElderlyInfo? _selectedElderly;
  String _streamUrl = '';
  String _currentActivity = 'N/A';
  String _confidence = 'N/A';
  String _fallRisk = 'N/A';
  Timer? _timestampTimer;
  Timer? _analysisTimer;
  String _currentTimestamp = '';
  bool _hasLoadedElderly = false;
  ElderlyInfo? _consumedElderly; // Track consumed elderly to prevent re-consuming
  String _currentVideoId = '';
  
  // Hybrid detection state
  bool _isAnalyzing = false;
  bool _fallDetected = false;
  String _detectionSource = '';
  Map<String, double> _layerScores = {};
  String _fallType = 'none';
  
  // Activity & gait detection state
  String _dlActivity = 'unknown';
  bool _gaitAbnormal = false;
  double _inactivitySeconds = 0;
  bool _inactivityAlert = false;
  bool _fallAlertShown = false;
  bool _gaitAlertShown = false;
  bool _inactivityAlertShown = false;
  
  // Frame capture for live streaming detection
  Uint8List? _lastCapturedFrame;
  DateTime? _lastFrameSentAt;
  int _framesSent = 0;
  int _bufferSize = 0;
  bool _bufferReady = false;
  
  String _getVideoUrl(String videoId) {
    // Use /video/live endpoint which respects backend video_config.json
    // If source_type=camera, streams from webcam/USB camera
    // If source_type=simulated, streams the configured video
    return '${ApiConfig.streamBaseUrl}${ApiConfig.guardian}/video/live';
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
      final sessionId = _currentVideoId; // Use video ID as session ID
      
      // Encode frame as base64
      final frameBase64 = base64Encode(_lastCapturedFrame!);
      
      // Send to streaming detection endpoint
      final response = await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.guardian}/stream/$sessionId/frame',
        body: {
          'frame_base64': frameBase64,
          'elderly_id': _selectedElderly?.id,
          'elderly_name': _selectedElderly?.name,
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
          
          // Parse activity & gait data
          final activity = data['activity'] as Map<String, dynamic>?;
          if (activity != null) {
            _dlActivity = activity['dl_activity'] ?? 'unknown';
            _gaitAbnormal = activity['gait_abnormal'] ?? false;
          }
          
          // Parse inactivity data
          final inactivity = data['inactivity'] as Map<String, dynamic>?;
          if (inactivity != null) {
            _inactivitySeconds = (inactivity['seconds'] ?? 0.0).toDouble();
            _inactivityAlert = inactivity['alert'] ?? false;
          }
          
          // Update activity based on detection
          if (_fallDetected) {
            _currentActivity = 'FALL DETECTED';
            _fallRisk = 'Critical';
          } else if (_gaitAbnormal) {
            _currentActivity = 'Abnormal Gait';
            _fallRisk = 'Medium';
          } else if (_inactivityAlert) {
            _currentActivity = 'Inactive';
            _fallRisk = 'Medium';
          } else if (_bufferReady) {
            // Map DL activities to user-friendly labels
            if (_dlActivity == 'good_gait' || _dlActivity == 'adl') {
              _currentActivity = 'Normal';
            } else if (_dlActivity == 'tug') {
              _currentActivity = 'Walking';
            } else if (_dlActivity == 'arthritis_gait') {
              _currentActivity = 'Abnormal Gait';
            } else {
              _currentActivity = 'Normal';
            }
            _fallRisk = 'Low';
          } else {
            _currentActivity = 'Buffering...';
            _fallRisk = 'Analyzing';
          }
        });
        
        // Show alert if fall detected (once per session)
        if (_fallDetected && !_fallAlertShown && mounted) {
          _fallAlertShown = true;
          _showFallAlert();
        }
        
        // Show gait alert (once per session)
        if (_gaitAbnormal && !_gaitAlertShown && mounted) {
          _gaitAlertShown = true;
          _showGaitAlert();
        }
        
        // Show inactivity alert (once per session)
        if (_inactivityAlert && !_inactivityAlertShown && mounted) {
          _inactivityAlertShown = true;
          _showInactivityAlert();
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
    if (_currentVideoId.isEmpty) return;
    
    // Reset state
    _framesSent = 0;
    _bufferSize = 0;
    _bufferReady = false;
    _lastCapturedFrame = null;
    _lastFrameSentAt = null;
    _fallAlertShown = false;
    _gaitAlertShown = false;
    _inactivityAlertShown = false;
    
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              _showEmergencyContacts();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonRed),
            child: const Text('Call Emergency'),
          ),
        ],
      ),
    );
  }
  
  /// Show emergency contacts dialog with call options
  Future<void> _showEmergencyContacts() async {
    if (_selectedElderly == null) return;
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/emergency-contacts/${_selectedElderly!.id}',
        requireAuth: false,
      );
      
      if (!response.success || response.data == null) {
        // Fallback to 911
        final Uri phoneUri = Uri(scheme: 'tel', path: '911');
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        }
        return;
      }
      
      final contacts = (response.data!['contacts'] as List?) ?? [];
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.phone, color: AppColors.neonCyan),
              SizedBox(width: 12),
              Text('Emergency Contacts', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: contacts.map<Widget>((contact) {
              final name = contact['name'] ?? 'Unknown';
              final phone = contact['phone'] ?? '';
              final role = contact['role'] ?? '';
              final isEmergency = role == 'emergency';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isEmergency ? AppColors.neonRed.withOpacity(0.2) : AppColors.neonCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isEmergency ? Icons.local_hospital : Icons.person,
                        color: isEmergency ? AppColors.neonRed : AppColors.neonCyan,
                        size: 20,
                      ),
                    ),
                    title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(
                      phone,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.phone, color: AppColors.neonGreen),
                      onPressed: () async {
                        Navigator.pop(context);
                        final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(phoneUri)) {
                          await launchUrl(phoneUri);
                        }
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error fetching emergency contacts: $e');
      // Fallback to 911
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    }
  }
  
  /// Show gait abnormality alert
  void _showGaitAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_walk, color: AppColors.neonOrange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Abnormal Gait Detected', style: TextStyle(color: AppColors.neonOrange, fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedElderly?.name ?? "Elderly"} is showing signs of arthritic or abnormal gait pattern.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This may indicate joint pain, arthritis, or mobility issues. Consider scheduling a medical check-up.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonOrange),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }
  
  /// Show inactivity alert
  void _showInactivityAlert() {
    final minutes = (_inactivitySeconds / 60).round();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.timer_off, color: AppColors.neonOrange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Inactivity Alert', style: TextStyle(color: AppColors.neonOrange, fontSize: 18)),
            ),
          ],
        ),
        content: Text(
          '${_selectedElderly?.name ?? "Elderly"} has been inactive for approximately $minutes minutes. Please check on them.',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonOrange),
            child: const Text('Acknowledge'),
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
    // Load connected elderly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedElderly) {
        _hasLoadedElderly = true;
        ref.read(connectionProvider.notifier).loadMyElderly();
      }
      // Auto-start watching if initial elderly is passed
      _checkForInitialElderly();
    });
  }
  
  void _checkForInitialElderly() {
    if (widget.initialElderly != null && widget.initialElderly != _consumedElderly) {
      _consumedElderly = widget.initialElderly;
      _startWatching(widget.initialElderly!);
      widget.onElderlyConsumed?.call();
    }
  }
  
  @override
  void didUpdateWidget(covariant _MonitorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if new initial elderly was passed
    _checkForInitialElderly();
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
    _analysisTimer?.cancel();
    super.dispose();
  }

  void _startWatching(ElderlyInfo elderly) {
    final videoId = elderly.assignedVideoId;
    final videoUrl = _getVideoUrl(videoId);
    
    debugPrint('🎬 Guardian Monitor: Starting stream for ${elderly.name}');
    debugPrint('🎬 Video ID: $videoId');
    debugPrint('🎬 Stream URL: $videoUrl');

    setState(() {
      _selectedElderly = elderly;
      _currentVideoId = videoId;
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

  void _stopWatching() {
    _stopAnalysis();
    setState(() {
      _isStreaming = false;
      _streamUrl = '';
      _selectedElderly = null;
      _currentVideoId = '';
      _currentActivity = 'N/A';
      _confidence = 'N/A';
      _fallRisk = 'N/A';
      _fallDetected = false;
      _layerScores = {};
      _detectionSource = '';
    });
  }
  
  void _showFullscreenVideo(BuildContext context) {
    if (_streamUrl.isEmpty || _selectedElderly == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenVideoScreen(
          streamUrl: _streamUrl,
          elderlyName: _selectedElderly!.name,
          timestamp: _currentTimestamp,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final elderlyList = connectionState.myElderly;
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
                    ? 'Watching ${_selectedElderly!.name}'
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
                      color: _isStreaming ? AppColors.neonGreen : AppColors.glassBorder,
                      width: _isStreaming ? 2 : 1,
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
                        else if (_isStreaming && _streamUrl.isNotEmpty)
                          MjpegStream(
                            streamUrl: _streamUrl,
                            isLive: true,
                            fit: BoxFit.cover,
                            loadingWidget: const Center(
                              child: CircularProgressIndicator(color: AppColors.neonCyan),
                            ),
                            onError: (error) {
                              debugPrint('❌ Guardian Monitor Error: $error');
                            },
                            onFrame: _onFrameReceived,
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
                              color: _isStreaming 
                                ? AppColors.neonGreen.withOpacity(0.2)
                                : AppColors.neonRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle, 
                                  color: _isStreaming ? AppColors.neonGreen : AppColors.neonRed, 
                                  size: 8,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isStreaming ? 'LIVE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: _isStreaming ? AppColors.neonGreen : AppColors.neonRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Stop and Fullscreen buttons when playing
                        if (_isStreaming)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _showFullscreenVideo(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
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
                              ],
                            ),
                          ),
                        
                        // Elderly name overlay when playing
                        if (_isStreaming && _selectedElderly != null)
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
                                _selectedElderly!.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        
                        // Live timestamp overlay
                        if (_isStreaming)
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
                  glowColor: _fallDetected ? AppColors.neonRed : null,
                  glowIntensity: _fallDetected ? 0.3 : 0,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildOverlayInfo(
                            'Activity', 
                            _currentActivity, 
                            _fallDetected ? Icons.warning : Icons.directions_walk, 
                            _fallDetected ? AppColors.neonRed : AppColors.neonCyan,
                          ),
                          _buildOverlayInfo('Confidence', _confidence, Icons.verified, AppColors.neonGreen),
                          _buildOverlayInfo(
                            'Fall Risk', 
                            _fallRisk, 
                            Icons.health_and_safety, 
                            _fallRisk == 'Critical' ? AppColors.neonRed 
                                : _fallRisk == 'Medium' ? AppColors.neonOrange 
                                : AppColors.neonGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Layer scores (show when available)
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
                    child: connectionState.isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
                        : elderlyList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                                    const SizedBox(height: 12),
                                    const Text('No elderly connected', style: TextStyle(color: AppColors.textSecondary)),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(context, AppRoutes.connections),
                                      child: const Text('Add Connection', style: TextStyle(color: AppColors.neonCyan)),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: elderlyList.length,
                                itemBuilder: (context, index) {
                                  final elderly = elderlyList[index];
                                  return _buildElderlySelectCard(elderly);
                                },
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

  Widget _buildElderlySelectCard(ElderlyInfo elderly) {
    final isSelected = _selectedElderly?.id == elderly.id && _isStreaming;
    final lastActive = _getTimeAgo(elderly.connectedAt);
    
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
                      color: AppColors.neonGreen,
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
                    elderly.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Connected $lastActive',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _startWatching(elderly),
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
  
  String _getTimeAgo(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return 'recently';
    }
  }
}

// ============= Alerts Tab =============

class _AlertsTab extends ConsumerStatefulWidget {
  const _AlertsTab();

  @override
  ConsumerState<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends ConsumerState<_AlertsTab> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final profile = ref.read(authProvider).profile;
      final guardianId = profile?.uid ?? 'unknown';
      
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/alerts/$guardianId',
        requireAuth: false,
      );
      
      if (response.success && response.data != null) {
        final data = response.data!;
        final alertsList = data['alerts'] as List<dynamic>? ?? [];
        setState(() {
          _alerts = alertsList.map((a) => Map<String, dynamic>.from(a as Map)).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch alerts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_selectedFilter == 'All') return _alerts;
    if (_selectedFilter == 'Critical') return _alerts.where((a) => a['severity'] == 'critical').toList();
    if (_selectedFilter == 'Falls') return _alerts.where((a) => a['type'] == 'fall').toList();
    return _alerts;
  }

  /// Show emergency contacts for a specific elderly
  Future<void> _showEmergencyContactsForElderly(String? elderlyId) async {
    if (elderlyId == null || elderlyId.isEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
      return;
    }
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/emergency-contacts/$elderlyId',
        requireAuth: false,
      );
      
      if (!response.success || response.data == null) {
        final Uri phoneUri = Uri(scheme: 'tel', path: '911');
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        }
        return;
      }
      
      final contacts = (response.data!['contacts'] as List?) ?? [];
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.phone, color: AppColors.neonCyan),
              SizedBox(width: 12),
              Text('Emergency Contacts', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: contacts.map<Widget>((contact) {
              final name = contact['name'] ?? 'Unknown';
              final phone = contact['phone'] ?? '';
              final role = contact['role'] ?? '';
              final isEmergency = role == 'emergency';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isEmergency ? AppColors.neonRed.withOpacity(0.2) : AppColors.neonCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isEmergency ? Icons.local_hospital : Icons.person,
                        color: isEmergency ? AppColors.neonRed : AppColors.neonCyan,
                        size: 20,
                      ),
                    ),
                    title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.phone, color: AppColors.neonGreen),
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(phoneUri)) {
                          await launchUrl(phoneUri);
                        }
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error fetching emergency contacts: $e');
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    }
  }

  Color _getAlertColor(String? type, String? severity) {
    if (severity == 'critical') return AppColors.neonRed;
    if (type == 'gait') return AppColors.neonOrange;
    if (type == 'inactivity') return AppColors.neonOrange;
    if (severity == 'warning') return AppColors.neonOrange;
    return AppColors.neonCyan;
  }

  IconData _getAlertIcon(String? type) {
    switch (type) {
      case 'fall': return Icons.warning;
      case 'gait': return Icons.directions_walk;
      case 'inactivity': return Icons.timer_off;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _alerts.where((a) => !(a['resolved'] ?? false)).length;
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alerts',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$activeCount unacknowledged alerts',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _fetchAlerts,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          'Refresh',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
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
                _buildFilterChip('All', _selectedFilter == 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Critical', _selectedFilter == 'Critical'),
                const SizedBox(width: 8),
                _buildFilterChip('Falls', _selectedFilter == 'Falls'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Alerts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
                : _filteredAlerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'All' ? 'No alerts yet' : 'No ${_selectedFilter.toLowerCase()} alerts',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Alerts will appear here when fall, gait, or inactivity events are detected.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchAlerts,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredAlerts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final alert = _filteredAlerts[index];
                            return _buildDetailedAlertCard(alert);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
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
      ),
    );
  }

  Widget _buildDetailedAlertCard(Map<String, dynamic> alert) {
    final type = alert['type'] as String? ?? 'unknown';
    final severity = alert['severity'] as String? ?? 'info';
    final color = _getAlertColor(type, severity);
    final icon = _getAlertIcon(type);
    final isResolved = alert['resolved'] ?? false;
    final title = alert['title'] ?? type;
    final elderlyId = alert['elderly_id'] ?? '';
    final elderlyName = alert['elderly_name'] ?? elderlyId ?? 'Unknown';
    final createdAt = alert['created_at'] ?? '';
    
    // Format time
    String timeAgo = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    } catch (_) {}
    
    return GlassmorphicCard(
      glowColor: !isResolved ? color : null,
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
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isResolved) ...[
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
                      '$elderlyName • $timeAgo',
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
                  severity.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (!isResolved) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        final apiService = ref.read(apiServiceProvider);
                        await apiService.put<Map<String, dynamic>>(
                          '${ApiConfig.guardian}/alerts/${alert['id']}/acknowledge',
                          body: {'response_action': 'acknowledged', 'notes': ''},
                          requireAuth: false,
                        );
                        _fetchAlerts();
                      } catch (e) {
                        debugPrint('Failed to acknowledge: $e');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text('Acknowledge', style: TextStyle(color: color, fontSize: 12)),
                  ),
                ),
                if (type == 'fall') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showEmergencyContactsForElderly(elderlyId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Call Emergency', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============= Elderly List Tab =============

class _ElderlyListTab extends ConsumerStatefulWidget {
  final void Function([ElderlyInfo?]) onNavigateToMonitor;
  
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
                child: _buildElderlyProfileCard(elderly),
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

  Widget _buildElderlyProfileCard(ElderlyInfo elderly) {
    final name = elderly.name;
    final connectionType = elderly.connectionType;
    final connectedAt = elderly.connectedAt;
    final elderlyId = elderly.id;
    final color = connectionType == 'guardian' ? AppColors.neonGreen : AppColors.neonOrange;
    
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
          
          // Nutrition Summary Row
          _ElderlyNutritionSummary(elderlyId: elderly.id),
          
          const SizedBox(height: 12),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onNavigateToMonitor(elderly),
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

// ============= Elderly Nutrition Summary Widget =============

class _ElderlyNutritionSummary extends ConsumerStatefulWidget {
  final String elderlyId;
  
  const _ElderlyNutritionSummary({required this.elderlyId});

  @override
  ConsumerState<_ElderlyNutritionSummary> createState() => _ElderlyNutritionSummaryState();
}

class _ElderlyNutritionSummaryState extends ConsumerState<_ElderlyNutritionSummary> {
  bool _isLoading = true;
  int _calories = 0;
  int _caloriesTarget = 1800;
  int _hydrationGlasses = 0;
  int _mealsLogged = 0;

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
          _mealsLogged = (response.data['meals'] as List?)?.length ?? 0;
        });
      }
      
      // Also load hydration
      final hydrationResponse = await api.get('/api/nutrition/hydration/${widget.elderlyId}');
      if (hydrationResponse.success && hydrationResponse.data != null && mounted) {
        setState(() {
          _hydrationGlasses = (hydrationResponse.data['glasses'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading elderly nutrition: $e');
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
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final caloriePercent = _caloriesTarget > 0 ? (_calories / _caloriesTarget * 100).clamp(0, 100).toInt() : 0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.local_fire_department,
            label: 'Calories',
            value: '$_calories',
            subValue: '$caloriePercent%',
            color: AppColors.neonOrange,
          ),
          Container(
            width: 1,
            height: 35,
            color: AppColors.glassBorder,
          ),
          _buildStatItem(
            icon: Icons.water_drop,
            label: 'Hydration',
            value: '$_hydrationGlasses',
            subValue: '/8 glasses',
            color: AppColors.neonPurple,
          ),
          Container(
            width: 1,
            height: 35,
            color: AppColors.glassBorder,
          ),
          _buildStatItem(
            icon: Icons.restaurant,
            label: 'Meals',
            value: '$_mealsLogged',
            subValue: 'today',
            color: AppColors.neonGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              subValue,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
}

// ============= Fullscreen Video Screen =============

class _FullscreenVideoScreen extends StatefulWidget {
  final String streamUrl;
  final String elderlyName;
  final String timestamp;
  
  const _FullscreenVideoScreen({
    required this.streamUrl,
    required this.elderlyName,
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
          
          // Elderly name
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
                widget.elderlyName,
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