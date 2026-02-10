/// SMARTCARE+ Physio Home Screen
///
/// Owner: Neelaka
/// Dashboard for physiotherapy features including gait analysis, TUG tests, and exercises

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../providers/physio_provider.dart';
import '../../providers/auth_provider.dart';

class PhysioHomeScreen extends ConsumerStatefulWidget {
  const PhysioHomeScreen({super.key});

  @override
  ConsumerState<PhysioHomeScreen> createState() => _PhysioHomeScreenState();
}

class _PhysioHomeScreenState extends ConsumerState<PhysioHomeScreen> {
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
        ref.read(physioProvider.notifier).loadPatientProfile(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final physioState = ref.watch(physioProvider);
    final todayPlan = physioState.todayPlan;
    final bmi = physioState.bmiResult;
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Physio Service',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Mobility & Exercise Tracking',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.accessibility_new, color: AppColors.neonCyan),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Profile setup prompt
                if (physioState.patientProfile == null || !physioState.patientProfile!.profileComplete)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GlassmorphicCard(
                      glowColor: AppColors.neonPurple,
                      glowIntensity: 0.2,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.neonPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.assignment_ind, color: AppColors.neonPurple, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Complete Your Physio Profile',
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                                SizedBox(height: 2),
                                Text('Set up medical history & preferences for personalized exercise plans',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.physioProfileSetup),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.neonPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Setup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Fall Risk Summary
                _buildFallRiskCard(),
                
                const SizedBox(height: 20),
                
                // Analysis Options
                const Text(
                  'Movement Analysis',
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
                      child: _buildAnalysisCard(
                        context,
                        title: 'Balance Test',
                        subtitle: 'Stability assessment',
                        icon: Icons.balance,
                        color: AppColors.neonPurple,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAnalysisCard(
                        context,
                        title: 'ROM Analysis',
                        subtitle: 'Range of motion',
                        icon: Icons.rotate_90_degrees_ccw,
                        color: AppColors.neonOrange,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalysisCard(
                        context,
                        title: 'Exercises',
                        subtitle: 'Daily workout routine',
                        icon: Icons.fitness_center,
                        color: AppColors.neonCyan,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAnalysisCard(
                        context,
                        title: 'Progress',
                        subtitle: 'View your history',
                        icon: Icons.show_chart,
                        color: AppColors.neonGreen,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Exercises Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Exercises',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.exerciseSchedule),
                      child: const Text('View All', style: TextStyle(color: AppColors.neonCyan)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                if (physioState.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppColors.neonCyan),
                    ),
                  )
                else if (todayPlan != null && todayPlan.exercises.isNotEmpty)
                  ...todayPlan.exercises.take(3).map((exercise) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildExerciseCard(
                      name: exercise.name,
                      duration: exercise.durationDisplay,
                      difficulty: exercise.difficulty.replaceAll('_', ' '),
                      reps: '${exercise.prescribedSets} sets x ${exercise.prescribedReps} reps',
                      isCompleted: todayPlan.completed,
                    ),
                  ))
                else
                  _buildExerciseCard(
                    name: 'No exercises yet',
                    duration: '--',
                    difficulty: '--',
                    reps: 'Generate a plan from your dashboard',
                    isCompleted: false,
                  ),
                
                const SizedBox(height: 24),
                
                // Progress Summary
                const Text(
                  'Weekly Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildProgressCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallRiskCard() {
    final physioState = ref.watch(physioProvider);
    final compliance = physioState.compliance?.complianceRate ?? 0.0;
    final bmi = physioState.bmiResult;
    
    // Derive risk from compliance and BMI
    final complianceScore = (compliance * 100).round();
    final riskLabel = complianceScore >= 70 ? 'LOW' : (complianceScore >= 40 ? 'MEDIUM' : 'HIGH');
    final riskColor = complianceScore >= 70 ? AppColors.neonGreen : (complianceScore >= 40 ? Colors.orange : Colors.redAccent);
    final riskMessage = bmi != null
        ? 'BMI: ${bmi.bmi.toStringAsFixed(1)} (${bmi.displayCategory}). Compliance: $complianceScore%'
        : 'Exercise compliance: $complianceScore%';
    
    return GlassmorphicCard(
      glowColor: riskColor,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Risk gauge
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: compliance,
                    strokeWidth: 10,
                    backgroundColor: riskColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$complianceScore',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                    const Text(
                      '%',
                      style: TextStyle(
                        fontSize: 12,
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
                    const Text(
                      'Health Score',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        riskLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  riskMessage,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.update, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
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
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard({
    required String name,
    required String duration,
    required String difficulty,
    required String reps,
    required bool isCompleted,
  }) {
    final color = isCompleted ? AppColors.neonGreen : AppColors.neonCyan;
    
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fitness_center,
              color: isCompleted ? color.withOpacity(0.6) : color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(duration, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    Text(reps, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          if (isCompleted)
            const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 28)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.neonCyan,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Start',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final physioState = ref.watch(physioProvider);
    final todayPlan = physioState.todayPlan;
    final totalExercises = todayPlan?.exercises.length ?? 0;
    final completedExercises = todayPlan?.completedExerciseCount ?? 0;
    final totalMinutes = todayPlan?.exercises.fold<int>(0, (sum, e) => sum + e.estimatedMinutes) ?? 0;
    final compliance = ((physioState.compliance?.complianceRate ?? 0.0) * 100).round();
    
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressStat('Compliance', '$compliance%', '', AppColors.neonCyan),
              _buildProgressStat('Exercises', '$completedExercises/$totalExercises', '', AppColors.neonGreen),
              _buildProgressStat('Minutes', '$totalMinutes', 'min', AppColors.neonPurple),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar for today
          if (todayPlan != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: todayPlan.progress,
                      minHeight: 8,
                      backgroundColor: AppColors.neonCyan.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonCyan),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(todayPlan.progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              todayPlan.completed ? 'Plan completed!' : 'Today\'s plan in progress',
              style: TextStyle(
                fontSize: 11,
                color: todayPlan.completed ? AppColors.neonGreen : AppColors.textSecondary,
              ),
            ),
          ] else
            const Text(
              'No plan generated yet',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, String change, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              change,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.neonGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

}
