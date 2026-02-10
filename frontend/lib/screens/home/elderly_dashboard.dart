/// SMARTCARE+ Elderly Dashboard
///
/// Dashboard specifically designed for elderly users with focus on
/// personal health metrics, exercises, and nutrition tracking

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../core/services/api_service.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/physio_provider.dart';

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
  bool _hasLoadedPhysioData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedCaregivers) {
        _hasLoadedCaregivers = true;
        ref.read(connectionProvider.notifier).loadMyCaregivers();
      }
      if (!_hasLoadedPhysioData) {
        _hasLoadedPhysioData = true;
        final user = ref.read(currentUserProvider);
        final userId = user?.uid ?? 'demo_user';
        ref.read(physioProvider.notifier).loadAllUserData(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final connectionState = ref.watch(connectionProvider);
    final myCaregivers = connectionState.myCaregivers;
    final physioState = ref.watch(physioProvider);
    final todayPlan = physioState.todayPlan;
    final bmi = physioState.bmiResult;
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
                    icon: Icons.monitor_weight,
                    value: bmi != null ? bmi.bmi.toStringAsFixed(1) : '--',
                    label: bmi?.displayCategory ?? 'BMI',
                    color: bmi != null
                        ? (bmi.category == 'normal'
                            ? AppColors.neonGreen
                            : bmi.category == 'overweight'
                                ? AppColors.neonOrange
                                : AppColors.neonRed)
                        : AppColors.neonCyan,
                    progress: bmi != null ? (bmi.bmi / 40).clamp(0.0, 1.0) : 0.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.fitness_center,
                    value: todayPlan != null
                        ? '${todayPlan.completedExerciseCount}/${todayPlan.exerciseCount}'
                        : '0/0',
                    label: 'Exercises',
                    color: AppColors.neonGreen,
                    progress: todayPlan?.progress ?? 0.0,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.timer,
                    value: todayPlan != null
                        ? '${todayPlan.totalDurationMinutes}'
                        : '--',
                    label: 'Plan (min)',
                    color: AppColors.neonCyan,
                    progress: todayPlan != null
                        ? (todayPlan.totalDurationMinutes / 30).clamp(0.0, 1.0)
                        : 0.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.speed,
                    value: todayPlan?.difficultyDisplay ?? '--',
                    label: 'Difficulty',
                    color: AppColors.neonPurple,
                    progress: todayPlan != null
                        ? (todayPlan.difficultyLevel == 'easy'
                            ? 0.33
                            : todayPlan.difficultyLevel == 'moderate'
                                ? 0.66
                                : todayPlan.difficultyLevel == 'challenging'
                                    ? 1.0
                                    : 0.15)
                        : 0.0,
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
            
            // Show exercises from today's plan
            if (todayPlan != null && todayPlan.exercises.isNotEmpty)
              ...todayPlan.exercises.take(4).map((exercise) {
                final categoryColors = {
                  'warm_up': AppColors.neonOrange,
                  'stretching': AppColors.neonGreen,
                  'strength': AppColors.neonCyan,
                  'balance': AppColors.neonPurple,
                  'cool_down': AppColors.neonBlue,
                  'breathing': AppColors.neonGreen,
                };
                final color = categoryColors[exercise.category] ?? AppColors.neonCyan;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTaskCard(
                    title: exercise.name,
                    subtitle: '${exercise.prescribedSets}x${exercise.prescribedReps} reps · ${exercise.durationDisplay}',
                    time: exercise.category.replaceAll('_', ' '),
                    icon: Icons.fitness_center,
                    color: color,
                    isCompleted: todayPlan.completed,
                  ),
                );
              })
            else if (todayPlan == null && !physioState.isLoading)
              _buildTaskCard(
                title: 'No plan yet',
                subtitle: 'Set up your profile to get a personalized plan',
                time: '',
                icon: Icons.info_outline,
                color: AppColors.textSecondary,
                isCompleted: false,
              )
            else if (physioState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.neonGreen),
                ),
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
                    icon: Icons.fitness_center,
                    label: 'Start Exercise',
                    color: AppColors.neonGreen,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.exercises),
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

class _MyPhysioTab extends ConsumerStatefulWidget {
  const _MyPhysioTab();

  @override
  ConsumerState<_MyPhysioTab> createState() => _MyPhysioTabState();
}

class _MyPhysioTabState extends ConsumerState<_MyPhysioTab> {
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedData) {
        _hasLoadedData = true;
        final user = ref.read(currentUserProvider);
        final userId = user?.uid ?? 'demo_user';
        ref.read(physioProvider.notifier).loadTodayPlan(userId);
        ref.read(physioProvider.notifier).loadBMI(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final physioState = ref.watch(physioProvider);
    final todayPlan = physioState.todayPlan;
    final bmi = physioState.bmiResult;
    final patientProfile = physioState.patientProfile;

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
            
            // BMI Card (real data)
            if (bmi != null) _buildBMICard(bmi),
            if (bmi != null) const SizedBox(height: 20),
            
            // Today's Plan Summary
            if (todayPlan != null) _buildTodayPlanSummary(todayPlan),
            if (todayPlan != null) const SizedBox(height: 20),
            
            // Today's Exercises
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Exercises',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (todayPlan != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${todayPlan.exerciseCount} exercises',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.neonGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (physioState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.neonGreen),
                ),
              )
            else if (todayPlan != null && todayPlan.exercises.isNotEmpty)
              ...todayPlan.exercises.map((exercise) {
                final categoryColors = {
                  'warm_up': AppColors.neonOrange,
                  'stretching': AppColors.neonGreen,
                  'strength': AppColors.neonCyan,
                  'balance': AppColors.neonPurple,
                  'cool_down': AppColors.neonBlue,
                  'breathing': AppColors.neonGreen,
                };
                final color = categoryColors[exercise.category] ?? AppColors.neonCyan;
                final isDone = todayPlan.isExerciseCompleted(exercise.exerciseId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildExerciseCard(
                    name: exercise.name,
                    duration: exercise.durationDisplay,
                    difficulty: exercise.difficulty.replaceAll('_', ' '),
                    isCompleted: isDone,
                    color: color,
                    reps: '${exercise.prescribedSets}x${exercise.prescribedReps}',
                    notes: exercise.notes,
                    exerciseId: exercise.exerciseId,
                    targetReps: exercise.prescribedReps,
                    targetSets: exercise.prescribedSets,
                    instructions: exercise.instructions,
                    planId: todayPlan.planId,
                  ),
                );
              })
            else
              GlassmorphicCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    const Text(
                      'No exercise plan yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete your health profile to get a personalized plan',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: physioState.isLoading ? null : () async {
                        // Check if profile is complete
                        if (patientProfile == null || !patientProfile.profileComplete) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('⚠️ Please complete your physio profile first'),
                              backgroundColor: Colors.orange,
                              action: SnackBarAction(
                                label: 'Setup', 
                                textColor: Colors.white,
                                onPressed: () => Navigator.pushNamed(context, AppRoutes.physioProfileSetup),
                              ),
                            ),
                          );
                          return;
                        }
                        
                        final user = ref.read(currentUserProvider);
                        final userId = user?.uid ?? 'demo_user';
                        
                        // Show generating message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Text('Generating personalized plan...'),
                              ],
                            ),
                            backgroundColor: AppColors.neonCyan,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        
                        await ref.read(physioProvider.notifier).generatePlan(userId);
                        
                        // Check result and show feedback
                        final newState = ref.read(physioProvider);
                        if (mounted) {
                          if (newState.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${newState.error}'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          } else if (newState.todayPlan != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✨ Generated ${newState.todayPlan!.exercises.length} exercises!'),
                                backgroundColor: AppColors.neonGreen,
                              ),
                            );
                          }
                        }
                      },
                      icon: physioState.isLoading 
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(physioState.isLoading ? 'Generating...' : 'Generate Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Quick Actions 
            Row(
              children: [
                Expanded(
                  child: _buildPhysioAction(
                    icon: Icons.auto_fix_high,
                    label: 'New\nPlan',
                    color: AppColors.neonPurple,
                    onTap: physioState.isLoading ? () {} : () async {
                      if (patientProfile == null || !patientProfile.profileComplete) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('⚠️ Please complete your physio profile first'),
                            backgroundColor: Colors.orange,
                            action: SnackBarAction(
                              label: 'Setup',
                              textColor: Colors.white,
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.physioProfileSetup),
                            ),
                          ),
                        );
                        return;
                      }
                      
                      final user = ref.read(currentUserProvider);
                      final userId = user?.uid ?? 'demo_user';
                      await ref.read(physioProvider.notifier).generatePlan(userId);
                      
                      final newState = ref.read(physioProvider);
                      if (mounted && newState.todayPlan != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✨ Generated ${newState.todayPlan!.exercises.length} exercises!'),
                            backgroundColor: AppColors.neonGreen,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhysioAction(
                    icon: Icons.fitness_center,
                    label: 'Start\nExercise',
                    color: AppColors.neonCyan,
                    onTap: todayPlan != null && todayPlan.exercises.isNotEmpty
                        ? () {
                            // Navigate to first incomplete exercise
                            final firstIncomplete = todayPlan.exercises.firstWhere(
                              (e) => !todayPlan.completed,
                              orElse: () => todayPlan.exercises.first,
                            );
                            Navigator.pushNamed(
                              context,
                              AppRoutes.exerciseMonitor,
                              arguments: {
                                'exerciseName': firstIncomplete.name,
                                'exerciseType': firstIncomplete.exerciseId,
                                'targetReps': firstIncomplete.prescribedReps,
                                'targetSets': firstIncomplete.prescribedSets,
                                'instructions': firstIncomplete.instructions,
                              },
                            );
                          }
                        : () => Navigator.pushNamed(context, AppRoutes.exercises),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhysioAction(
                    icon: Icons.check_circle,
                    label: 'Mark\nDone',
                    color: AppColors.neonGreen,
                    onTap: todayPlan != null && !todayPlan.completed
                        ? () {
                            ref.read(physioProvider.notifier).completePlan(todayPlan.planId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('\u{1F389} Great job! Plan marked as completed!'),
                                backgroundColor: AppColors.neonGreen,
                              ),
                            );
                          }
                        : () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Physio Profile Setup button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.physioProfileSetup),
                icon: const Icon(Icons.assignment_ind, size: 18),
                label: Text(
                  patientProfile != null && patientProfile.profileComplete
                      ? 'Edit Physio Profile'
                      : 'Setup Physio Profile',
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.neonPurple),
                  foregroundColor: AppColors.neonPurple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Plan Notes
            if (todayPlan != null && todayPlan.additionalNotes.isNotEmpty) ...[
              const Text(
                'Plan Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...todayPlan.additionalNotes.map((note) => 
                _buildActivityItem(note, '', Icons.info_outline, AppColors.neonCyan),
              ),
            ],
            
            // Pain Adaptation Alert
            if (todayPlan != null && todayPlan.adaptedForPain) ...[
              const SizedBox(height: 16),
              GlassmorphicCard(
                glowColor: AppColors.neonOrange,
                glowIntensity: 0.15,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.healing, color: AppColors.neonOrange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pain-Adapted Plan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neonOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            todayPlan.painAdaptationNotes.isNotEmpty 
                                ? todayPlan.painAdaptationNotes 
                                : 'Exercises adjusted based on your recent pain levels',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBMICard(BMIResult bmi) {
    final bmiColor = bmi.category == 'normal'
        ? AppColors.neonGreen
        : bmi.category == 'overweight'
            ? AppColors.neonOrange
            : bmi.category == 'underweight'
                ? AppColors.neonCyan
                : AppColors.neonRed;

    return GlassmorphicCard(
      glowColor: bmiColor,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
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
                    value: (bmi.bmi / 40).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: bmiColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(bmiColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bmi.bmi.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: bmiColor,
                      ),
                    ),
                    const Text(
                      'BMI',
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
                Row(
                  children: [
                    Flexible(
                      child: const Text(
                        'Body Mass Index',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bmiColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bmi.displayCategory,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: bmiColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Health Risk: ${bmi.healthRisk}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (bmi.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bmi.recommendations.first,
                    style: TextStyle(
                      fontSize: 11,
                      color: bmiColor.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPlanSummary(DailyExercisePlan plan) {
    return GlassmorphicCard(
      glowColor: plan.completed ? AppColors.neonGreen : AppColors.neonCyan,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                plan.completed ? Icons.check_circle : Icons.today,
                color: plan.completed ? AppColors.neonGreen : AppColors.neonCyan,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.completed ? 'Today\'s Plan Completed!' : 'Today\'s Exercise Plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: plan.completed ? AppColors.neonGreen : AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (plan.completed ? AppColors.neonGreen : AppColors.neonCyan).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  plan.difficultyDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: plan.completed ? AppColors.neonGreen : AppColors.neonCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPlanStat('Exercises', '${plan.exerciseCount}', AppColors.neonCyan),
              _buildPlanStat('Duration', '${plan.totalDurationMinutes} min', AppColors.neonGreen),
              _buildPlanStat('Areas', plan.focusAreas.isNotEmpty ? '${plan.focusAreas.length}' : '0', AppColors.neonPurple),
            ],
          ),
          if (plan.focusAreas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: plan.focusAreas.take(4).map((area) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  area.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
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

  Widget _buildExerciseCard({
    required String name,
    required String duration,
    required String difficulty,
    required bool isCompleted,
    required Color color,
    String reps = '',
    String notes = '',
    String? exerciseId,
    int? targetReps,
    int? targetSets,
    List<String>? instructions,
    String? planId,
  }) {
    return GestureDetector(
      onTap: isCompleted ? null : () {
        if (exerciseId != null && targetReps != null && targetSets != null) {
          // Navigate to exercise monitor with this specific exercise
          Navigator.pushNamed(
            context,
            AppRoutes.exerciseMonitor,
            arguments: {
              'exerciseName': name,
              'exerciseType': exerciseId,
              'targetReps': targetReps,
              'targetSets': targetSets,
              'instructions': instructions,
            },
          );
        } else {
          // Fallback to exercise library
          Navigator.pushNamed(context, AppRoutes.exercises);
        }
      },
      child: GlassmorphicCard(
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
                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(duration, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (reps.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(reps, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                      const SizedBox(width: 8),
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
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (isCompleted)
              const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 24)
            else
              GestureDetector(
                onTap: () {
                  if (planId != null && exerciseId != null) {
                    ref.read(physioProvider.notifier).completeExerciseInPlan(planId, exerciseId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('\u2705 $name marked as done!'),
                        backgroundColor: AppColors.neonGreen,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
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
          if (time.isNotEmpty)
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

class _SOSTab extends ConsumerStatefulWidget {
  const _SOSTab();
  
  @override
  ConsumerState<_SOSTab> createState() => _SOSTabState();
}

class _SOSTabState extends ConsumerState<_SOSTab> {
  List<Map<String, dynamic>> _emergencyContacts = [];
  bool _isLoading = false;
  bool _isTriggeringSOS = false;
  
  @override
  void initState() {
    super.initState();
    _fetchEmergencyContacts();
  }
  
  Future<void> _fetchEmergencyContacts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profile = ref.read(userProfileProvider);
      if (profile?.uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/emergency-contacts/${profile!.uid}',
        requireAuth: false,
      );
      
      if (response.success && response.data != null) {
        if (mounted) {
          setState(() {
            _emergencyContacts = List<Map<String, dynamic>>.from(response.data!['contacts'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching emergency contacts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _triggerSOS() async {
    setState(() => _isTriggeringSOS = true);
    try {
      final profile = ref.read(userProfileProvider);
      if (profile?.uid == null) return;
      
      final baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
      final response = await http.post(
        Uri.parse('$baseUrl/guardian/sos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'elderly_id': profile!.uid,
          'message': 'Emergency SOS button activated',
        }),
      );
      
      if (response.statusCode == 200 && mounted) {
        _showSOSConfirmation();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send SOS. Try calling emergency contacts directly.')),
        );
      }
    } catch (e) {
      debugPrint('Error triggering SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send SOS. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTriggeringSOS = false);
    }
  }
  
  void _showSOSConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.neonGreen),
            SizedBox(width: 8),
            Text('SOS Sent', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Text(
          'Emergency alert has been sent to your guardians and caregivers. They will contact you shortly.',
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
  
  Future<void> _callContact(String? phone, String? name) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No phone number for $name')),
      );
      return;
    }
    
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot call $phone')),
        );
      }
    }
  }

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
              onLongPress: _isTriggeringSOS ? null : _triggerSOS,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isTriggeringSOS 
                      ? AppColors.neonOrange.withOpacity(0.15)
                      : AppColors.neonRed.withOpacity(0.15),
                  border: Border.all(
                    color: _isTriggeringSOS ? AppColors.neonOrange : AppColors.neonRed, 
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isTriggeringSOS ? AppColors.neonOrange : AppColors.neonRed).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isTriggeringSOS)
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(color: AppColors.neonOrange, strokeWidth: 3),
                      )
                    else
                      const Icon(Icons.sos, color: AppColors.neonRed, size: 64),
                    const SizedBox(height: 8),
                    Text(
                      _isTriggeringSOS ? 'Sending...' : 'SOS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _isTriggeringSOS ? AppColors.neonOrange : AppColors.neonRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              _isTriggeringSOS ? 'Sending emergency alert...' : 'Hold for 3 seconds to trigger emergency',
              style: TextStyle(
                fontSize: 14,
                color: _isTriggeringSOS ? AppColors.neonOrange : AppColors.textSecondary,
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
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
            else if (_emergencyContacts.isEmpty)
              GlassmorphicCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.textSecondary.withOpacity(0.5)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No emergency contacts. Ask your guardian to add contacts.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._emergencyContacts.map((contact) {
                final name = contact['name'] ?? 'Contact';
                final relation = contact['relationship'] ?? contact['relation'] ?? 'Emergency';
                final phone = contact['phone']?.toString() ?? '';
                
                IconData icon = Icons.person;
                Color color = AppColors.neonCyan;
                
                if (relation.toLowerCase().contains('doctor')) {
                  icon = Icons.medical_services;
                  color = AppColors.neonCyan;
                } else if (relation.toLowerCase().contains('guardian') || 
                           relation.toLowerCase().contains('family') ||
                           relation.toLowerCase().contains('son') ||
                           relation.toLowerCase().contains('daughter')) {
                  icon = Icons.person;
                  color = AppColors.neonGreen;
                } else if (relation.toLowerCase().contains('911') || 
                           relation.toLowerCase().contains('emergency')) {
                  icon = Icons.local_hospital;
                  color = AppColors.neonRed;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildContactCard(name, relation, phone, icon, color),
                );
              }),
            
            // Always show 911
            _buildContactCard('Emergency Services', '911', '911', Icons.local_hospital, AppColors.neonRed),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(String name, String role, String phone, IconData icon, Color color) {
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
            onPressed: () => _callContact(phone, name),
            icon: Icon(Icons.phone, color: color),
          ),
        ],
      ),
    );
  }
}
