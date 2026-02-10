/// SMARTCARE+ Caregiver Dashboard
///
/// Dashboard for professional caregivers with patient management,
/// health reports, and task scheduling features

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
import '../../providers/physio_provider.dart';
import '../guardian/alerts_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class CaregiverDashboard extends ConsumerStatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  ConsumerState<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends ConsumerState<CaregiverDashboard> {
  int _currentIndex = 0;
  ElderlyInfo? _selectedPatientForMonitor;
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
      
      final baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
      final response = await http.get(
        Uri.parse('$baseUrl/guardian/alerts/${profile!.uid}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final alerts = (data['alerts'] as List?) ?? [];
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
            const AlertsScreen(),
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
              _buildNavItem(3, Icons.notifications_outlined, Icons.notifications, 'Alerts', AppColors.neonRed),
              _buildNavItem(4, Icons.assessment_outlined, Icons.assessment, 'Reports', AppColors.neonPurple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, Color color) {
    final isSelected = _currentIndex == index;
    final isAlertsTab = index == 3; // Alerts tab
    final badgeCount = isAlertsTab ? _unacknowledgedAlertCount : (index == 2 ? 5 : 0); // 5 for tasks demo
    
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
                    color: isAlertsTab ? AppColors.neonRed : AppColors.neonOrange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isAlertsTab ? AppColors.neonRed : AppColors.neonOrange).withOpacity(0.4),
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

// ============= Caregiver Home Tab =============

class _CaregiverHomeTab extends ConsumerStatefulWidget {
  final void Function([ElderlyInfo?]) onNavigateToPatients;
  
  const _CaregiverHomeTab({required this.onNavigateToPatients});

  @override
  ConsumerState<_CaregiverHomeTab> createState() => _CaregiverHomeTabState();
}

class _CaregiverHomeTabState extends ConsumerState<_CaregiverHomeTab> {
  List<Map<String, dynamic>> _recentAlerts = [];
  int _alertCount = 0;
  int _taskCount = 0;
  bool _isLoading = false;
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
    // Refresh alerts every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchData();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final profile = ref.read(userProfileProvider);
      if (profile?.uid == null) return;
      
      // Fetch alerts for caregiver (they see alerts for their elderly connections)
      final baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
      final alertsResponse = await http.get(
        Uri.parse('$baseUrl/guardian/alerts/${profile!.uid}?limit=10'),
      );
      
      if (alertsResponse.statusCode == 200) {
        final data = json.decode(alertsResponse.body);
        final alertsList = (data['alerts'] as List?) ?? [];
        final unacknowledged = alertsList.where((a) => a['resolved'] != true).toList();
        if (mounted) {
          setState(() {
            _recentAlerts = List<Map<String, dynamic>>.from(unacknowledged.take(5));
            _alertCount = unacknowledged.length;
          });
        }
      }
      
      // TODO: Fetch tasks count when tasks API is implemented
      // For now, show 0 tasks
      if (mounted) setState(() => _taskCount = 0);
    } catch (e) {
      debugPrint('Error fetching caregiver data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final fullName = profile?.name ?? 'Caregiver';
    final firstName = fullName.split(' ').first;
    final connectionState = ref.watch(connectionProvider);
    final patientCount = connectionState.myElderly.length;

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
                Expanded(child: _buildStatCard('Patients', '$patientCount', Icons.people, AppColors.neonCyan)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Tasks', '$_taskCount', Icons.task, AppColors.neonOrange)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Alerts', '$_alertCount', Icons.warning, AppColors.neonRed)),
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
            
            // Dynamic tasks based on connected patients
            ...List.generate(
              connectionState.myElderly.length.clamp(0, 3),
              (index) {
                final elderly = connectionState.myElderly[index];
                final tasks = [
                  ('Physio session with ${elderly.name}', '10:00 AM', 'Exercise', Icons.accessibility_new, AppColors.neonGreen),
                  ('Medication reminder for ${elderly.name}', '11:30 AM', 'Medication', Icons.medication, AppColors.neonPurple),
                  ('Health check for ${elderly.name}', '2:00 PM', 'Check-up', Icons.health_and_safety, AppColors.neonCyan),
                ];
                final task = tasks[index % tasks.length];
                return Column(
                  children: [
                    _buildTaskItem(
                      task: task.$1,
                      time: task.$2,
                      type: task.$3,
                      icon: task.$4,
                      color: task.$5,
                    ),
                    if (index < connectionState.myElderly.length.clamp(0, 3) - 1)
                      const SizedBox(height: 8),
                  ],
                );
              },
            ),
            // Fallback when no patients connected
            if (connectionState.myElderly.isEmpty) ...[
              _buildTaskItem(
                task: 'No tasks - Connect with patients first',
                time: '--:--',
                type: 'Info',
                icon: Icons.info_outline,
                color: AppColors.textSecondary,
              ),
            ],
            
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
                    onTap: widget.onNavigateToPatients,
                  ),
                ),
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
                  onPressed: () => widget.onNavigateToPatients(),
                  child: const Text('View All', style: TextStyle(color: AppColors.neonCyan)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_recentAlerts.isEmpty)
              GlassmorphicCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.neonGreen.withOpacity(0.7)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No recent alerts. All patients are doing well.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._recentAlerts.take(3).map((alert) {
                final type = alert['type'] as String? ?? 'unknown';
                final severity = alert['severity'] as String? ?? 'info';
                final elderlyName = alert['elderly_name'] ?? alert['elderly_id'] ?? 'Unknown';
                final createdAt = alert['created_at'] ?? '';
                
                IconData icon = Icons.notifications;
                Color color = AppColors.neonCyan;
                String title = alert['title'] ?? type;
                
                if (type == 'fall') {
                  icon = Icons.warning;
                  color = AppColors.neonRed;
                } else if (type == 'gait') {
                  icon = Icons.directions_walk;
                  color = AppColors.neonOrange;
                } else if (type == 'inactivity') {
                  icon = Icons.timer_off;
                  color = AppColors.neonOrange;
                }
                
                if (severity == 'critical') {
                  color = AppColors.neonRed;
                }
                
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
                
                return _buildAlertItem(title, elderlyName, timeAgo, icon, color);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(String title, String elderlyName, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        glowColor: color,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(elderlyName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(time, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
  String? _selectedElderlyId; // Actual elderly ID for backend calls
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
  
  // Activity & gait detection state
  String _dlActivity = 'unknown';
  bool _gaitAbnormal = false;
  double _inactivitySeconds = 0;
  bool _inactivityAlert = false;
  bool _fallAlertShown = false;
  bool _gaitAlertShown = false;
  bool _inactivityAlertShown = false;
  
  // Frame capture state for live streaming detection
  Uint8List? _lastCapturedFrame;
  DateTime? _lastFrameSentAt;
  int _framesSent = 0;
  int _bufferSize = 0;
  bool _bufferReady = false;
  
  /// Get the video URL from the backend
  /// Uses /video/live endpoint which respects backend video_config.json
  String _getVideoUrl(String videoId) {
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
    if (_currentVideoId == null || _currentVideoId!.isEmpty || _lastCapturedFrame == null) return;
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
      final sessionId = _currentVideoId!;
      
      // Encode frame as base64
      final frameBase64 = base64Encode(_lastCapturedFrame!);
      
      // Send to streaming detection endpoint
      final response = await apiService.post<Map<String, dynamic>>(
        '${ApiConfig.guardian}/stream/$sessionId/frame',
        body: {
          'frame_base64': frameBase64,
          'elderly_id': _selectedElderlyId ?? _selectedPatient,
          'elderly_name': _selectedPatient,
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
    if (_currentVideoId == null || _currentVideoId!.isEmpty) return;
    
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
        body: {
          'elderly_id': _selectedElderlyId ?? _selectedPatient,
          'elderly_name': _selectedPatient,
        },
        requireAuth: false,
      );
      debugPrint('🎥 Stream session started: $_currentVideoId for elderly: $_selectedElderlyId');
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
    if (_selectedPatient == null) return;
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/emergency-contacts/$_selectedPatient',
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
                    subtitle: Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
              '${_selectedPatient ?? "Patient"} is showing signs of arthritic or abnormal gait pattern.',
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
          '${_selectedPatient ?? "Patient"} has been inactive for approximately $minutes minutes. Please check on them.',
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
      _selectedElderlyId = elderly.id; // Store the actual ID for backend calls
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
      _selectedElderlyId = null;
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

class _TasksTab extends ConsumerWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);
    final patients = connectionState.myElderly;
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
          
          // Task List - Dynamic based on connected patients
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: patients.isEmpty
                  ? [
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.task_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connect with patients to see tasks',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  : _buildDynamicTaskList(patients),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate dynamic task list based on connected patients
  List<Widget> _buildDynamicTaskList(List<ElderlyInfo> patients) {
    final taskTemplates = [
      ('Physio session', 'Exercise', AppColors.neonGreen, '30 min', true),
      ('Medication reminder', 'Medication', AppColors.neonPurple, '5 min', false),
      ('Health check', 'Check-up', AppColors.neonCyan, '20 min', false),
      ('Update meal plan', 'Nutrition', AppColors.neonOrange, '15 min', false),
      ('TUG assessment', 'Assessment', AppColors.neonGreen, '10 min', false),
    ];
    
    final times = ['10:00 AM', '11:30 AM', '2:00 PM', '3:30 PM', '4:00 PM'];
    final List<Widget> widgets = [];
    
    for (int i = 0; i < patients.length && i < taskTemplates.length; i++) {
      final patient = patients[i];
      final template = taskTemplates[i];
      if (i > 0) widgets.add(const SizedBox(height: 10));
      widgets.add(
        _buildTaskCard(
          title: '${template.$1} - ${patient.name}',
          time: times[i % times.length],
          duration: template.$4,
          type: template.$2,
          color: template.$3,
          isPriority: template.$5,
        ),
      );
    }
    
    return widgets;
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

// ============= Caregiver Alerts Tab =============

class _CaregiverAlertsTab extends ConsumerStatefulWidget {
  const _CaregiverAlertsTab();
  
  @override
  ConsumerState<_CaregiverAlertsTab> createState() => _CaregiverAlertsTabState();
}

class _CaregiverAlertsTabState extends ConsumerState<_CaregiverAlertsTab> {
  String _filter = 'All';
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }
  
  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      final profile = ref.read(userProfileProvider);
      if (profile?.uid == null) return;
      
      final baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
      final response = await http.get(Uri.parse('$baseUrl/guardian/alerts/${profile!.uid}?limit=50'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _alerts = List<Map<String, dynamic>>.from(data);
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch alerts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_filter == 'All') return _alerts;
    if (_filter == 'Active') return _alerts.where((a) => !(a['acknowledged'] ?? false)).toList();
    if (_filter == 'Resolved') return _alerts.where((a) => a['acknowledged'] ?? false).toList();
    return _alerts;
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'critical': return AppColors.neonRed;
      case 'warning': return AppColors.neonOrange;
      default: return AppColors.neonCyan;
    }
  }

  IconData _getAlertIcon(String? type) {
    switch (type) {
      case 'fall': return Icons.person_off;
      case 'gait': return Icons.directions_walk;
      case 'inactivity': return Icons.hourglass_empty;
      case 'sos': return Icons.emergency;
      default: return Icons.notifications;
    }
  }
  
  String _getAlertTitle(String type) {
    switch (type) {
      case 'fall': return 'Fall Detected';
      case 'gait': return 'Abnormal Gait';
      case 'inactivity': return 'Inactivity Warning';
      case 'sos': return 'SOS Emergency';
      default: return 'Alert';
    }
  }
  
  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _alerts.where((a) => !(a['acknowledged'] ?? false)).length;
    
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Alerts',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activeCount > 0 ? AppColors.neonRed.withOpacity(0.15) : AppColors.neonGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$activeCount Active',
                    style: TextStyle(
                      fontSize: 12,
                      color: activeCount > 0 ? AppColors.neonRed : AppColors.neonGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['All', 'Active', 'Resolved'].map((filter) {
                final isSelected = _filter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.neonCyan.withOpacity(0.15) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppColors.neonCyan : Colors.transparent),
                      ),
                      child: Text(filter, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.neonCyan : AppColors.textSecondary)),
                    ),
                  ),
                );
              }).toList(),
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
                            Icon(Icons.check_circle_outline, size: 48, color: AppColors.neonGreen.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              _filter == 'All' ? 'No alerts yet' : 'No $_filter alerts',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchAlerts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredAlerts.length,
                          itemBuilder: (context, index) {
                            final alert = _filteredAlerts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildAlertCard(alert),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final type = alert['type'] as String? ?? 'unknown';
    final color = _getSeverityColor(severity);
    final icon = _getAlertIcon(type);
    final isResolved = alert['acknowledged'] ?? false;
    final title = alert['title'] ?? _getAlertTitle(type);
    final elderlyName = alert['elderly_name'] ?? 'Unknown';
    final createdAt = alert['created_at'] ?? '';
    final timeAgo = _formatTimeAgo(createdAt);
    
    return GestureDetector(
      onTap: () => _showAlertDetail(alert),
      child: GlassmorphicCard(
        glowColor: isResolved ? null : color,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(isResolved ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isResolved ? AppColors.textSecondary : color, size: 22),
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isResolved ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isResolved) const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(elderlyName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        severity.toUpperCase(),
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAlertDetail(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final type = alert['type'] as String? ?? 'unknown';
    final color = _getSeverityColor(severity);
    final isResolved = alert['acknowledged'] ?? false;
    final title = alert['title'] ?? _getAlertTitle(type);
    final description = alert['description'] ?? '';
    final alertId = alert['id'] ?? '';
    final elderlyName = alert['elderly_name'] ?? 'Unknown';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
              child: Icon(_getAlertIcon(type), color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('$elderlyName • ${severity.toUpperCase()}', style: const TextStyle(color: AppColors.textSecondary)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            if (!isResolved)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
                      await http.put(
                        Uri.parse('$baseUrl/guardian/alerts/$alertId/acknowledge'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({'response_action': 'resolved', 'notes': ''}),
                      );
                      if (mounted) Navigator.pop(context);
                      _fetchAlerts();
                    } catch (e) {
                      debugPrint('Failed to acknowledge alert: $e');
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Mark Resolved'),
                ),
              )
            else
              const Text('This alert has been resolved', style: TextStyle(color: AppColors.neonGreen)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============= Reports Tab =============

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  bool _isGenerating = false;
  String? _selectedReportType;

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
              context: context,
              type: 'health_summary',
              title: 'Weekly Health Summary',
              description: 'Overview of all patients\' health metrics',
              icon: Icons.health_and_safety,
              color: AppColors.neonGreen,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              context: context,
              type: 'physio_progress',
              title: 'Physio Progress',
              description: 'Gait analysis and exercise completion',
              icon: Icons.accessibility_new,
              color: AppColors.neonCyan,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              context: context,
              type: 'nutrition',
              title: 'Nutrition Tracking',
              description: 'Meal plans and dietary adherence',
              icon: Icons.restaurant_menu,
              color: AppColors.neonOrange,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              context: context,
              type: 'fall_risk',
              title: 'Fall Risk Assessment',
              description: 'Alert history and risk analysis',
              icon: Icons.warning,
              color: AppColors.neonRed,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              context: context,
              type: 'activity_logs',
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
    required BuildContext context,
    required String type,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isLoading = _isGenerating && _selectedReportType == type;
    
    return GestureDetector(
      onTap: isLoading ? null : () => _generateReport(type, title, color),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: color, strokeWidth: 2))
                  : Icon(icon, color: color, size: 26),
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
      ),
    );
  }

  Future<void> _generateReport(String type, String title, Color color) async {
    setState(() {
      _isGenerating = true;
      _selectedReportType = type;
    });
    
    try {
      final profile = ref.read(userProfileProvider);
      if (profile?.uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to generate reports')),
          );
        }
        return;
      }
      
      final baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
      Map<String, dynamic> reportData = {};
      
      switch (type) {
        case 'health_summary':
        case 'fall_risk':
          // Fetch alerts for summary
          final alertsResponse = await http.get(
            Uri.parse('$baseUrl/guardian/alerts/${profile!.uid}?limit=100'),
          );
          if (alertsResponse.statusCode == 200) {
            final alerts = json.decode(alertsResponse.body) as List<dynamic>;
            final fallAlerts = alerts.where((a) => a['type'] == 'fall').length;
            final gaitAlerts = alerts.where((a) => a['type'] == 'gait').length;
            final inactivityAlerts = alerts.where((a) => a['type'] == 'inactivity').length;
            final sosAlerts = alerts.where((a) => a['type'] == 'sos').length;
            final unresolvedAlerts = alerts.where((a) => !(a['acknowledged'] ?? false)).length;
            
            reportData = {
              'total_alerts': alerts.length,
              'fall_alerts': fallAlerts,
              'gait_alerts': gaitAlerts,
              'inactivity_alerts': inactivityAlerts,
              'sos_alerts': sosAlerts,
              'unresolved': unresolvedAlerts,
              'period': 'Last 7 days',
            };
          }
          break;
          
        case 'physio_progress':
          // Fetch real exercise plan data for connected elderly
          final connectionState = ref.read(connectionProvider);
          final elderly = connectionState.myElderly;
          int totalPlans = 0;
          int completedPlans = 0;
          final apiService = ref.read(apiServiceProvider);
          
          for (final e in elderly.take(3)) {
            try {
              final planResponse = await apiService.get<Map<String, dynamic>>(
                '/api/physio/plans/${e.id}',
                queryParams: {'days': 7},
                requireAuth: false,
              );
              if (planResponse.success && planResponse.data != null) {
                final plans = planResponse.data!['plans'] as List? ?? [];
                totalPlans += plans.length;
                completedPlans += plans.where((p) => p['completed'] == true).length;
              }
            } catch (_) {}
          }
          
          reportData = {
            'sessions_completed': completedPlans,
            'total_plans': totalPlans,
            'gait_improvement': totalPlans > 0 ? '${((completedPlans / totalPlans) * 100).round()}%' : 'N/A',
            'tug_score_avg': 'N/A',
            'period': 'Last 7 days',
            'note': elderly.isEmpty
                ? 'Connect with elderly patients to see their progress'
                : 'Showing data for ${elderly.length} patient(s)',
          };
          break;
          
        case 'nutrition':
          // Nutrition data would come from nutrition service
          reportData = {
            'meals_logged': 0,
            'avg_calories': 'N/A',
            'nutrition_score': 'N/A',
            'period': 'Last 7 days',
            'note': 'Log meals to track nutrition',
          };
          break;
          
        case 'activity_logs':
          // Activity pattern data
          reportData = {
            'active_hours': 'N/A',
            'resting_hours': 'N/A',
            'anomalies_detected': 0,
            'period': 'Last 7 days',
            'note': 'Activity data collected during monitoring',
          };
          break;
      }
      
      if (mounted) {
        _showReportDialog(title, type, color, reportData);
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _selectedReportType = null;
        });
      }
    }
  }

  void _showReportDialog(String title, String type, Color color, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIconForType(type), color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text(data['period'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            const Divider(color: AppColors.glassBorder),
            const SizedBox(height: 16),
            
            // Report Content
            Flexible(
              child: SingleChildScrollView(
                child: _buildReportContent(type, color, data),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.glassBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report shared successfully')),
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'health_summary': return Icons.health_and_safety;
      case 'physio_progress': return Icons.accessibility_new;
      case 'nutrition': return Icons.restaurant_menu;
      case 'fall_risk': return Icons.warning;
      case 'activity_logs': return Icons.timeline;
      default: return Icons.description;
    }
  }

  Widget _buildReportContent(String type, Color color, Map<String, dynamic> data) {
    switch (type) {
      case 'health_summary':
      case 'fall_risk':
        return Column(
          children: [
            _buildStatRow('Total Alerts', '${data['total_alerts'] ?? 0}', color),
            _buildStatRow('Fall Alerts', '${data['fall_alerts'] ?? 0}', AppColors.neonRed),
            _buildStatRow('Gait Warnings', '${data['gait_alerts'] ?? 0}', AppColors.neonOrange),
            _buildStatRow('Inactivity Alerts', '${data['inactivity_alerts'] ?? 0}', AppColors.neonPurple),
            _buildStatRow('SOS Emergencies', '${data['sos_alerts'] ?? 0}', AppColors.neonRed),
            const Divider(color: AppColors.glassBorder, height: 32),
            _buildStatRow('Unresolved', '${data['unresolved'] ?? 0}', AppColors.neonOrange),
          ],
        );
        
      case 'physio_progress':
        return Column(
          children: [
            _buildStatRow('Sessions Completed', '${data['sessions_completed'] ?? 0}', color),
            _buildStatRow('Gait Improvement', data['gait_improvement'] ?? 'N/A', AppColors.neonGreen),
            _buildStatRow('Avg TUG Score', data['tug_score_avg'] ?? 'N/A', AppColors.neonCyan),
            if (data['note'] != null) ...[
              const SizedBox(height: 16),
              GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(data['note'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
        
      case 'nutrition':
        return Column(
          children: [
            _buildStatRow('Meals Logged', '${data['meals_logged'] ?? 0}', color),
            _buildStatRow('Avg Calories', data['avg_calories'] ?? 'N/A', AppColors.neonOrange),
            _buildStatRow('Nutrition Score', data['nutrition_score'] ?? 'N/A', AppColors.neonGreen),
            if (data['note'] != null) ...[
              const SizedBox(height: 16),
              GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(data['note'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
        
      case 'activity_logs':
        return Column(
          children: [
            _buildStatRow('Active Hours', data['active_hours'] ?? 'N/A', AppColors.neonGreen),
            _buildStatRow('Resting Hours', data['resting_hours'] ?? 'N/A', AppColors.neonCyan),
            _buildStatRow('Anomalies Detected', '${data['anomalies_detected'] ?? 0}', AppColors.neonRed),
            if (data['note'] != null) ...[
              const SizedBox(height: 16),
              GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(data['note'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
        
      default:
        return const Text('Report data unavailable', style: TextStyle(color: AppColors.textSecondary));
    }
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
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