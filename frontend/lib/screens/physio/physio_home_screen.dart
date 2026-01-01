/// SMARTCARE+ Physio Home Screen
///
/// Owner: Neelaka
/// Dashboard for physiotherapy features including gait analysis, TUG tests, and exercises

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../widgets/common/glassmorphic_card.dart';

class PhysioHomeScreen extends ConsumerWidget {
  const PhysioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        title: 'Gait Analysis',
                        subtitle: 'Walk pattern & metrics',
                        icon: Icons.directions_walk,
                        color: AppColors.neonCyan,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.gaitAnalysis),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAnalysisCard(
                        context,
                        title: 'TUG Test',
                        subtitle: 'Timed Up & Go',
                        icon: Icons.timer,
                        color: AppColors.neonGreen,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.tugTest),
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
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.exercises),
                      child: const Text('View All', style: TextStyle(color: AppColors.neonCyan)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                _buildExerciseCard(
                  name: 'Chair Stand Exercise',
                  duration: '10 min',
                  difficulty: 'Easy',
                  reps: '3 sets x 10 reps',
                  isCompleted: true,
                ),
                const SizedBox(height: 8),
                _buildExerciseCard(
                  name: 'Heel-to-Toe Walk',
                  duration: '5 min',
                  difficulty: 'Medium',
                  reps: '2 sets x 20 steps',
                  isCompleted: false,
                ),
                const SizedBox(height: 8),
                _buildExerciseCard(
                  name: 'Single Leg Stand',
                  duration: '8 min',
                  difficulty: 'Medium',
                  reps: '3 sets x 30 sec',
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
                
                const SizedBox(height: 24),
                
                // Recent Sessions
                const Text(
                  'Recent Sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildSessionItem('Gait Analysis', 'Today, 10:30 AM', 'Stride: 45cm, Cadence: 98', AppColors.neonCyan),
                _buildSessionItem('TUG Test', 'Yesterday', 'Score: 12.5s (Low Risk)', AppColors.neonGreen),
                _buildSessionItem('Balance Assessment', '2 days ago', 'Score: 85/100', AppColors.neonPurple),
              ],
            ),
          ),
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
                    value: 0.25,
                    strokeWidth: 10,
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
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonGreen,
                      ),
                    ),
                    Text(
                      '/100',
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
                      'Fall Risk Score',
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
                        color: AppColors.neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LOW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your mobility is looking great! Keep up with your exercises.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.update, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    const Text(
                      'Updated today at 10:30 AM',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressStat('Sessions', '12', '+3', AppColors.neonCyan),
              _buildProgressStat('Exercises', '24', '+5', AppColors.neonGreen),
              _buildProgressStat('Minutes', '180', '+45', AppColors.neonPurple),
            ],
          ),
          const SizedBox(height: 16),
          // Simple bar chart representation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDayBar('M', 0.8, true),
              _buildDayBar('T', 0.6, true),
              _buildDayBar('W', 0.9, true),
              _buildDayBar('T', 0.4, true),
              _buildDayBar('F', 0.7, true),
              _buildDayBar('S', 0.5, false),
              _buildDayBar('S', 0.0, false),
            ],
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

  Widget _buildDayBar(String day, double value, bool isPast) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 28,
            height: 60 * value,
            decoration: BoxDecoration(
              color: isPast
                  ? AppColors.neonCyan.withOpacity(0.7)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            color: isPast ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionItem(String title, String time, String result, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.analytics, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    result,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
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
}
