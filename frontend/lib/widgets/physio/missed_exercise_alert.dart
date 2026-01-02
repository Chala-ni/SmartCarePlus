/// SMARTCARE+ Missed Exercise Alert Widget
///
/// Owner: Neelaka
/// Displays alerts for missed or upcoming exercises with reschedule option

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../common/glassmorphic_card.dart';

/// Model for a scheduled exercise
class ScheduledExercise {
  final String id;
  final String name;
  final String scheduledTime;
  final String duration;
  final String difficulty;
  final ExerciseStatus status;
  final DateTime scheduledDate;

  ScheduledExercise({
    required this.id,
    required this.name,
    required this.scheduledTime,
    required this.duration,
    required this.difficulty,
    required this.status,
    required this.scheduledDate,
  });

  bool get isMissed => status == ExerciseStatus.missed;
  bool get isUpcoming => status == ExerciseStatus.upcoming;
  bool get isCompleted => status == ExerciseStatus.completed;
}

enum ExerciseStatus {
  upcoming,
  inProgress,
  completed,
  missed,
  rescheduled,
}

/// Alert widget for missed exercises
class MissedExerciseAlert extends StatelessWidget {
  final List<ScheduledExercise> missedExercises;
  final VoidCallback? onViewAll;
  final Function(ScheduledExercise)? onReschedule;
  final Function(ScheduledExercise)? onStartNow;

  const MissedExerciseAlert({
    super.key,
    required this.missedExercises,
    this.onViewAll,
    this.onReschedule,
    this.onStartNow,
  });

  @override
  Widget build(BuildContext context) {
    if (missedExercises.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassmorphicCard(
      glowColor: AppColors.neonRed,
      glowIntensity: 0.2,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neonRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.neonRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      missedExercises.length == 1
                          ? 'Missed Exercise'
                          : '${missedExercises.length} Missed Exercises',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonRed,
                      ),
                    ),
                    const Text(
                      'Staying active is important for your health',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onViewAll != null && missedExercises.length > 1)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text(
                    'View All',
                    style: TextStyle(color: AppColors.neonCyan, fontSize: 12),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Show first missed exercise (or all if few)
          ...missedExercises.take(2).map((exercise) => _buildMissedExerciseItem(exercise)),
          
          if (missedExercises.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${missedExercises.length - 2} more missed exercises',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMissedExerciseItem(ScheduledExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.neonRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: AppColors.neonRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: AppColors.neonRed.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Scheduled: ${exercise.scheduledTime}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.neonRed.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      exercise.duration,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onReschedule != null)
                GestureDetector(
                  onTap: () => onReschedule!(exercise),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: AppColors.neonOrange,
                      size: 18,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (onStartNow != null)
                GestureDetector(
                  onTap: () => onStartNow!(exercise),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen,
                      borderRadius: BorderRadius.circular(8),
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
                ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Compact banner for missed exercises (for dashboard header)
class MissedExerciseBanner extends StatelessWidget {
  final int missedCount;
  final VoidCallback? onTap;

  const MissedExerciseBanner({
    super.key,
    required this.missedCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (missedCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.neonRed.withOpacity(0.2),
              AppColors.neonOrange.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neonRed.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.fitness_center,
              color: AppColors.neonRed,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You have $missedCount missed exercise${missedCount == 1 ? '' : 's'} today',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.neonRed,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}


/// Upcoming exercise reminder widget
class UpcomingExerciseReminder extends StatelessWidget {
  final ScheduledExercise exercise;
  final VoidCallback? onStart;
  final VoidCallback? onSnooze;

  const UpcomingExerciseReminder({
    super.key,
    required this.exercise,
    this.onStart,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      glowColor: AppColors.neonGreen,
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
                  color: AppColors.neonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: AppColors.neonGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise Time!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonGreen,
                      ),
                    ),
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                exercise.scheduledTime,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neonGreen,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      exercise.duration,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        exercise.difficulty,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.neonCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onSnooze != null)
                TextButton(
                  onPressed: onSnooze,
                  child: const Text(
                    'Snooze',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              if (onStart != null)
                ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Start Now'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
