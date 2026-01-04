/// SMARTCARE+ Elderly Dashboard
///
/// Dashboard specifically designed for elderly users with focus on
/// personal health metrics, exercises, and nutrition tracking

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/nutrition_provider.dart';

class ElderlyDashboard extends ConsumerStatefulWidget {
  const ElderlyDashboard({super.key});

  @override
  ConsumerState<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends ConsumerState<ElderlyDashboard> {
  int _currentIndex = 0;

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
          children: const [
            _ElderlyHomeTab(),
            _MyPhysioTab(),
            _MyNutritionTab(),
            _SOSTab(),
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
            color: AppColors.neonCyan.withOpacity(0.1),
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
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home', AppColors.neonCyan),
              _buildNavItem(1, Icons.accessibility_new_outlined, Icons.accessibility_new, 'My Physio', AppColors.neonGreen),
              _buildNavItem(2, Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'My Meals', AppColors.neonOrange),
              _buildNavItem(3, Icons.sos_outlined, Icons.sos, 'SOS', AppColors.neonRed),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, Color color) {
    final isSelected = _currentIndex == index;
    
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
        child: Column(
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
      ),
    );
  }
}

// ============= Elderly Home Tab =============

class _ElderlyHomeTab extends ConsumerStatefulWidget {
  const _ElderlyHomeTab();

  @override
  ConsumerState<_ElderlyHomeTab> createState() => _ElderlyHomeTabState();
}

class _ElderlyHomeTabState extends ConsumerState<_ElderlyHomeTab> {
  bool _hasLoadedCaregivers = false;

  @override
  void initState() {
    super.initState();
    // Load caregivers only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedCaregivers) {
        _hasLoadedCaregivers = true;
        ref.read(connectionProvider.notifier).loadMyCaregivers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final connectionState = ref.watch(connectionProvider);
    final myCaregivers = connectionState.myCaregivers;
    final fullName = profile?.name ?? 'Friend';
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
                        'Good Day!',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        firstName,
                        style: const TextStyle(
                          fontSize: 28,
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
                    // My Caregivers Button
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.connections),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people, color: AppColors.neonPurple, size: 22),
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
            
            // Today's Health Summary
            _buildHealthSummaryCard(),
            
            const SizedBox(height: 20),
            
            // Quick Stats
            const Text(
              'Today\'s Progress',
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
                  child: _buildStatCard(
                    icon: Icons.directions_walk,
                    value: '2,456',
                    label: 'Steps',
                    color: AppColors.neonCyan,
                    progress: 0.65,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.water_drop,
                    value: '6/8',
                    label: 'Glasses',
                    color: AppColors.neonBlue,
                    progress: 0.75,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.favorite,
                    value: '72',
                    label: 'Heart Rate',
                    color: AppColors.neonRed,
                    progress: 0.9,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.fitness_center,
                    value: '2/3',
                    label: 'Exercises',
                    color: AppColors.neonGreen,
                    progress: 0.66,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Today's Tasks
            const Text(
              'Today\'s Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildTaskCard(
              title: 'Morning Exercise',
              subtitle: '10 min stretching routine',
              time: '8:00 AM',
              icon: Icons.accessibility_new,
              color: AppColors.neonGreen,
              isCompleted: true,
            ),
            const SizedBox(height: 8),
            _buildTaskCard(
              title: 'Take Medication',
              subtitle: 'Blood pressure pills',
              time: '9:00 AM',
              icon: Icons.medication,
              color: AppColors.neonPurple,
              isCompleted: true,
            ),
            const SizedBox(height: 8),
            _buildTaskCard(
              title: 'Log Lunch',
              subtitle: 'Record your meal',
              time: '12:30 PM',
              icon: Icons.restaurant,
              color: AppColors.neonOrange,
              isCompleted: false,
            ),
            const SizedBox(height: 8),
            _buildTaskCard(
              title: 'Afternoon Walk',
              subtitle: '15 min gait exercise',
              time: '4:00 PM',
              icon: Icons.directions_walk,
              color: AppColors.neonCyan,
              isCompleted: false,
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
                    context: context,
                    icon: Icons.camera_alt,
                    label: 'Scan Food',
                    color: AppColors.neonOrange,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.foodScanner),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    context: context,
                    icon: Icons.videocam,
                    label: 'Start Exercise',
                    color: AppColors.neonGreen,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.gaitAnalysis),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    context: context,
                    icon: Icons.add,
                    label: 'Log Water',
                    color: AppColors.neonBlue,
                    onTap: () => _logWater(context),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // My Caregivers Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Caregivers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.connections),
                  child: Text(
                    myCaregivers.isEmpty ? 'Add' : 'Manage',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.neonCyan,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (myCaregivers.isEmpty)
              _buildNoCaregiverCard(context)
            else
              ...myCaregivers.map((caregiver) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCaregiverCard(caregiver.name, caregiver.connectionType),
              )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoCaregiverCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.connections),
      child: GlassmorphicCard(
        glowColor: AppColors.neonPurple,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neonPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add, color: AppColors.neonPurple, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect with a Caregiver',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Invite your guardian or caregiver to monitor your health',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCaregiverCard(String name, String type) {
    final isGuardian = type == 'guardian';
    final color = isGuardian ? AppColors.neonGreen : AppColors.neonOrange;
    
    return GlassmorphicCard(
      glowColor: color,
      glowIntensity: 0.1,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGuardian ? Icons.family_restroom : Icons.medical_services,
              color: color,
              size: 22,
            ),
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isGuardian ? '👨‍👩‍👦 Guardian' : '👩‍⚕️ Caregiver',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '• Active',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.neonGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: color, size: 20),
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

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.elderlyProfile),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.neonCyan, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonCyan.withOpacity(0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: const CircleAvatar(
          backgroundColor: AppColors.surface,
          child: Icon(Icons.person, color: AppColors.neonCyan, size: 28),
        ),
      ),
    );
  }

  Widget _buildHealthSummaryCard() {
    return GlassmorphicCard(
      glowColor: AppColors.neonGreen,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.health_and_safety, color: AppColors.neonGreen, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'You\'re doing great today!',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.neonGreen,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.neonGreen.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.neonGreen, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Good',
                      style: TextStyle(
                        color: AppColors.neonGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Fall Risk', 'Low', AppColors.neonGreen),
              _buildMiniStat('Activity', 'Normal', AppColors.neonCyan),
              _buildMiniStat('Mood', 'Happy', AppColors.neonPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
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

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required double progress,
  }) {
    return GlassmorphicCard(
      glowColor: color,
      glowIntensity: 0.15,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color color,
    required bool isCompleted,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(isCompleted ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(isCompleted ? 0.4 : 0.2),
              ),
            ),
            child: Icon(
              icon,
              color: isCompleted ? color : color.withOpacity(0.6),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(isCompleted ? 0.6 : 1),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isCompleted ? AppColors.neonGreen : AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassmorphicCard(
        glowColor: color,
        glowIntensity: 0.1,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _logWater(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Water logged! 💧'),
        backgroundColor: AppColors.neonBlue,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ============= My Physio Tab =============

class _MyPhysioTab extends StatelessWidget {
  const _MyPhysioTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Physio',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track your mobility and exercises',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Fall Risk Card
            _buildFallRiskCard(),
            
            const SizedBox(height: 20),
            
            // Today's Exercises
            const Text(
              'Today\'s Exercises',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildExerciseCard(
              name: 'Morning Stretch',
              duration: '10 min',
              difficulty: 'Easy',
              isCompleted: true,
              color: AppColors.neonGreen,
            ),
            const SizedBox(height: 8),
            _buildExerciseCard(
              name: 'Balance Training',
              duration: '15 min',
              difficulty: 'Medium',
              isCompleted: true,
              color: AppColors.neonCyan,
            ),
            const SizedBox(height: 8),
            _buildExerciseCard(
              name: 'Gait Practice',
              duration: '20 min',
              difficulty: 'Medium',
              isCompleted: false,
              color: AppColors.neonPurple,
            ),
            
            const SizedBox(height: 24),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildPhysioAction(
                    icon: Icons.videocam,
                    label: 'Start\nGait Analysis',
                    color: AppColors.neonCyan,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhysioAction(
                    icon: Icons.timer,
                    label: 'TUG\nTest',
                    color: AppColors.neonGreen,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhysioAction(
                    icon: Icons.bar_chart,
                    label: 'View\nProgress',
                    color: AppColors.neonPurple,
                    onTap: () {},
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
            
            _buildActivityItem('Completed gait analysis', '2 hours ago', Icons.check_circle, AppColors.neonGreen),
            _buildActivityItem('TUG test score: 12s', 'Yesterday', Icons.timer, AppColors.neonCyan),
            _buildActivityItem('Balance improved 5%', '2 days ago', Icons.trending_up, AppColors.neonPurple),
          ],
        ),
      ),
    );
  }

  Widget _buildFallRiskCard() {
    return GlassmorphicCard(
      glowColor: AppColors.neonGreen,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Circular progress indicator
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: 0.25,
                    strokeWidth: 8,
                    backgroundColor: AppColors.neonGreen.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonGreen),
                  ),
                ),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '25',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonGreen,
                      ),
                    ),
                    Text(
                      'Low',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fall Risk Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your mobility is looking good!',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Last updated: Today',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.neonGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard({
    required String name,
    required String duration,
    required String difficulty,
    required bool isCompleted,
    required Color color,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(duration, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        difficulty,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isCompleted)
            const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 24)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Start',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhysioAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicCard(
        glowColor: color,
        glowIntensity: 0.15,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============= My Nutrition Tab =============

class _MyNutritionTab extends ConsumerStatefulWidget {
  const _MyNutritionTab();

  @override
  ConsumerState<_MyNutritionTab> createState() => _MyNutritionTabState();
}

class _MyNutritionTabState extends ConsumerState<_MyNutritionTab> {
  bool _isLoading = true;
  String? _error;
  
  // Today's logged meals from API
  List<Map<String, dynamic>> _todaysMeals = [];
  int _caloriesConsumed = 0;
  int _caloriesGoal = 1800;
  double _proteinConsumed = 0;
  double _proteinGoal = 80;
  double _carbsConsumed = 0;
  double _carbsGoal = 220;
  double _fatConsumed = 0;
  double _fatGoal = 60;
  int _hydrationGlasses = 0;
  int _hydrationGoal = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNutritionData();
    });
  }

  Future<void> _loadNutritionData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.uid ?? 'demo_user';
      
      // Load daily summary
      await ref.read(nutritionProvider.notifier).loadDailySummary(userId);
      await ref.read(nutritionProvider.notifier).loadHydration(userId);
      
      if (!mounted) return;
      final state = ref.read(nutritionProvider);
      
      if (state.summary != null) {
        setState(() {
          _caloriesConsumed = state.summary!.caloriesConsumed;
          _caloriesGoal = state.summary!.caloriesGoal;
          _proteinConsumed = state.summary!.proteinConsumed;
          _proteinGoal = state.summary!.proteinGoal;
          _carbsConsumed = state.summary!.carbsConsumed;
          _carbsGoal = state.summary!.carbsGoal;
          _fatConsumed = state.summary!.fatConsumed;
          _fatGoal = state.summary!.fatGoal;
          
          // Convert meals to the format we need
          _todaysMeals = state.summary!.meals.map((m) => {
            'type': m.type,
            'name': m.name,
            'calories': m.calories,
            'time': m.time,
          }).toList();
        });
      }
      
      if (state.hydration != null) {
        setState(() {
          _hydrationGlasses = state.hydration!.glasses;
          _hydrationGoal = state.hydration!.goalGlasses;
        });
      }
      
      setState(() {
        _isLoading = false;
        _error = state.error;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _addWater() async {
    final user = ref.read(currentUserProvider);
    final userId = user?.uid ?? 'demo_user';
    
    await ref.read(nutritionProvider.notifier).logHydration(userId, 250, 'water');
    
    setState(() {
      _hydrationGlasses++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadNutritionData,
        color: AppColors.neonGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Meals',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track your nutrition and hydration',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Calorie Progress Card
              _buildCalorieCard(),
              
              const SizedBox(height: 20),
              
              // Hydration Card
              _buildHydrationCard(),
              
              const SizedBox(height: 20),
              
              // Today's Meals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Meals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.neonRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Could not load data. Pull down to refresh.',
                    style: TextStyle(color: AppColors.neonRed.withOpacity(0.8), fontSize: 12),
                  ),
                ),
              
              // Show logged meals or empty state
              if (_todaysMeals.isEmpty && !_isLoading)
                _buildEmptyMealsState()
              else
                ..._buildMealCards(),
              
              const SizedBox(height: 8),
              _buildAddMealCard(context),
              
              const SizedBox(height: 24),
              
              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: _buildNutritionAction(
                      context: context,
                      icon: Icons.camera_alt,
                      label: 'Scan\nFood',
                      color: AppColors.neonOrange,
                      onTap: () async {
                        final result = await Navigator.pushNamed(context, AppRoutes.foodScanner);
                        if (result == true) {
                          _loadNutritionData(); // Refresh after logging food
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNutritionAction(
                      context: context,
                      icon: Icons.calendar_month,
                      label: 'Meal\nPlan',
                      color: AppColors.neonGreen,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.mealPlan),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNutritionAction(
                      context: context,
                      icon: Icons.bar_chart,
                      label: 'Weekly\nReport',
                      color: AppColors.neonPurple,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.nutritionHome),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMealsState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 12),
          const Text(
            'No meals logged today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan or add your first meal to start tracking!',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMealCards() {
    final mealIcons = {
      'breakfast': Icons.wb_sunny,
      'lunch': Icons.light_mode,
      'dinner': Icons.nightlight_round,
      'snack': Icons.cookie,
    };
    final mealColors = {
      'breakfast': AppColors.neonOrange,
      'lunch': AppColors.neonGreen,
      'dinner': AppColors.neonPurple,
      'snack': AppColors.neonCyan,
    };

    return _todaysMeals.map((meal) {
      final type = (meal['type'] as String? ?? 'lunch').toLowerCase();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildMealCard(
          mealType: meal['type'] ?? 'Meal',
          description: meal['name'] ?? 'Unknown',
          calories: meal['calories'] ?? 0,
          time: meal['time'] ?? '',
          icon: mealIcons[type] ?? Icons.restaurant,
          color: mealColors[type] ?? AppColors.neonGreen,
        ),
      );
    }).toList();
  }

  Widget _buildCalorieCard() {
    final progress = _caloriesGoal > 0 ? _caloriesConsumed / _caloriesGoal : 0.0;
    final progressPercent = (progress * 100).clamp(0, 100).toInt();
    
    return GlassmorphicCard(
      glowColor: AppColors.neonOrange,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories Today',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$_caloriesConsumed',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonOrange,
                        ),
                      ),
                      Text(
                        ' / $_caloriesGoal',
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 6,
                      backgroundColor: AppColors.neonOrange.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonOrange),
                    ),
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonOrange,
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
              _buildMacroIndicator('Protein', _proteinConsumed.toInt(), _proteinGoal.toInt(), AppColors.neonRed),
              _buildMacroIndicator('Carbs', _carbsConsumed.toInt(), _carbsGoal.toInt(), AppColors.neonCyan),
              _buildMacroIndicator('Fat', _fatConsumed.toInt(), _fatGoal.toInt(), AppColors.neonPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroIndicator(String label, int current, int goal, Color color) {
    return Column(
      children: [
        Text(
          '$current/${goal}g',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildHydrationCard() {
    final progress = _hydrationGoal > 0 ? _hydrationGlasses / _hydrationGoal : 0.0;
    
    return GlassmorphicCard(
      glowColor: AppColors.neonBlue,
      glowIntensity: 0.15,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: AppColors.neonBlue, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hydration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.neonBlue.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_hydrationGlasses of $_hydrationGoal glasses',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _addWater,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: AppColors.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required String mealType,
    required String description,
    required int calories,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealType,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$calories cal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddMealCard(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushNamed(context, AppRoutes.foodScanner),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.glassBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.textSecondary.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text(
              'Add Dinner',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassmorphicCard(
        glowColor: color,
        glowIntensity: 0.15,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
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

// ============= SOS Tab =============

class _SOSTab extends StatelessWidget {
  const _SOSTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            
            // SOS Button
            GestureDetector(
              onLongPress: () {
                // Trigger SOS
                _showSOSDialog(context);
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonRed.withOpacity(0.15),
                  border: Border.all(color: AppColors.neonRed, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonRed.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sos, color: AppColors.neonRed, size: 64),
                    SizedBox(height: 8),
                    Text(
                      'SOS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Hold for 3 seconds to trigger emergency',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            
            const Spacer(),
            
            // Emergency Contacts
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Emergency Contacts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            _buildContactCard('Dr. Smith', 'Primary Doctor', Icons.medical_services, AppColors.neonCyan),
            const SizedBox(height: 8),
            _buildContactCard('John (Guardian)', 'Family', Icons.person, AppColors.neonGreen),
            const SizedBox(height: 8),
            _buildContactCard('Emergency Services', '911', Icons.local_hospital, AppColors.neonRed),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.neonRed),
            SizedBox(width: 8),
            Text('SOS Triggered', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Text(
          'Emergency alert has been sent to your guardians and emergency contacts.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(String name, String role, IconData icon, Color color) {
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
          const SizedBox(width: 14),
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
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.phone, color: color),
          ),
        ],
      ),
    );
  }
}
