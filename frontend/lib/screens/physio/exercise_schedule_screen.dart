/// SMARTCARE+ Exercise Schedule Screen
///
/// Owner: Neelaka
/// View upcoming, completed, and missed exercises with reschedule options

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../widgets/physio/missed_exercise_alert.dart' hide ScheduledExercise;
import '../../providers/physio_provider.dart';
import '../../providers/auth_provider.dart';

class ExerciseScheduleScreen extends ConsumerStatefulWidget {
  const ExerciseScheduleScreen({super.key});

  @override
  ConsumerState<ExerciseScheduleScreen> createState() => _ExerciseScheduleScreenState();
}

class _ExerciseScheduleScreenState extends ConsumerState<ExerciseScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _hasLoadedPlan = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedPlan) {
        _hasLoadedPlan = true;
        final user = ref.read(currentUserProvider);
        final userId = user?.uid ?? 'demo_user';
        ref.read(physioProvider.notifier).loadTodayPlan(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Convert backend planned exercises to local ScheduledExercise format
  List<ScheduledExercise> _convertPlanToSchedule(DailyExercisePlan? plan) {
    if (plan == null) return [];
    return plan.exercises.map((e) {
      final status = plan.completed
          ? ScheduleStatus.completed
          : ScheduleStatus.upcoming;
      return ScheduledExercise(
        id: '${e.exerciseId}_${plan.date}',
        exerciseId: e.exerciseId,
        name: e.name,
        scheduledDate: plan.date,
        scheduledTime: e.category.replaceAll('_', ' '),
        duration: e.durationDisplay,
        difficulty: e.difficulty.replaceAll('_', ' '),
        status: status,
      );
    }).toList();
  }

  List<ScheduledExercise> get _todaySchedule {
    final plan = ref.read(physioProvider).todayPlan;
    return _convertPlanToSchedule(plan);
  }

  List<ScheduledExercise> get _missedExercises =>
      _todaySchedule.where((e) => e.status == ScheduleStatus.missed).toList();

  List<ScheduledExercise> get _upcomingExercises =>
      _todaySchedule.where((e) => e.status == ScheduleStatus.upcoming).toList();

  List<ScheduledExercise> get _completedExercises =>
      _todaySchedule.where((e) => e.status == ScheduleStatus.completed).toList();

  void _showRescheduleDialog(ScheduledExercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RescheduleSheet(
        exercise: exercise,
        onReschedule: (newTime) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${exercise.name} rescheduled to $newTime'),
              backgroundColor: AppColors.neonGreen,
            ),
          );
        },
      ),
    );
  }

  void _startExercise(ScheduledExercise exercise) {
    // Navigate to exercise session
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting ${exercise.name}...'),
        backgroundColor: AppColors.neonCyan,
      ),
    );
    // TODO: Navigator.pushNamed(context, AppRoutes.exerciseSession, arguments: exercise);
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
                            'Exercise Schedule',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Track your daily exercises',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add exercise button
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, color: AppColors.neonCyan),
                    ),
                  ],
                ),
              ),

              // Date selector
              _buildDateSelector(),

              const SizedBox(height: 16),

              // Stats summary
              _buildStatsSummary(),

              const SizedBox(height: 16),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.neonCyan,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'Missed (${_missedExercises.length})'),
                    Tab(text: 'Upcoming (${_upcomingExercises.length})'),
                    Tab(text: 'Done (${_completedExercises.length})'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMissedTab(),
                    _buildUpcomingTab(),
                    _buildCompletedTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final dates = List.generate(7, (i) => now.add(Duration(days: i - 3)));

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month;
          final isToday = date.day == now.day && date.month == now.month;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.neonCyan
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.neonCyan)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDayName(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.black : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : AppColors.neonGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getDayName(DateTime date) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7];
  }

  Widget _buildStatsSummary() {
    final total = _todaySchedule.length;
    final completed = _completedExercises.length;
    final missed = _missedExercises.length;
    final completionRate = total > 0 ? (completed / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', '$total', AppColors.neonCyan),
            _buildStatItem('Done', '$completed', AppColors.neonGreen),
            _buildStatItem('Missed', '$missed', AppColors.neonRed),
            _buildStatItem('Rate', '$completionRate%', AppColors.neonPurple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
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

  Widget _buildMissedTab() {
    if (_missedExercises.isEmpty) {
      return _buildEmptyState(
        icon: Icons.celebration,
        title: 'No Missed Exercises!',
        subtitle: 'Great job staying on track',
        color: AppColors.neonGreen,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _missedExercises.length,
      itemBuilder: (context, index) {
        final exercise = _missedExercises[index];
        return _buildExerciseCard(
          exercise,
          color: AppColors.neonRed,
          actions: [
            _buildActionButton(
              'Reschedule',
              Icons.schedule,
              AppColors.neonOrange,
              () => _showRescheduleDialog(exercise),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              'Start Now',
              Icons.play_arrow,
              AppColors.neonGreen,
              () => _startExercise(exercise),
              filled: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingTab() {
    if (_upcomingExercises.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'All Done for Today!',
        subtitle: 'No more exercises scheduled',
        color: AppColors.neonGreen,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _upcomingExercises.length,
      itemBuilder: (context, index) {
        final exercise = _upcomingExercises[index];
        return _buildExerciseCard(
          exercise,
          color: AppColors.neonCyan,
          actions: [
            _buildActionButton(
              'Start Early',
              Icons.play_arrow,
              AppColors.neonGreen,
              () => _startExercise(exercise),
              filled: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    if (_completedExercises.isEmpty) {
      return _buildEmptyState(
        icon: Icons.fitness_center,
        title: 'No Completed Exercises Yet',
        subtitle: 'Start your first exercise today',
        color: AppColors.textSecondary,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _completedExercises.length,
      itemBuilder: (context, index) {
        final exercise = _completedExercises[index];
        return _buildExerciseCard(
          exercise,
          color: AppColors.neonGreen,
          showCheckmark: true,
        );
      },
    );
  }

  Widget _buildExerciseCard(
    ScheduledExercise exercise, {
    required Color color,
    List<Widget>? actions,
    bool showCheckmark = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        glowColor: color,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
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
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(
                            exercise.scheduledTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            exercise.duration,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showCheckmark)
                  const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 28),
              ],
            ),
            if (actions != null && actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.black : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.black : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}


/// Bottom sheet for rescheduling exercises
class _RescheduleSheet extends StatefulWidget {
  final ScheduledExercise exercise;
  final Function(String) onReschedule;

  const _RescheduleSheet({
    required this.exercise,
    required this.onReschedule,
  });

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  String? _selectedTime;
  
  final List<String> _suggestedTimes = [
    'In 30 min',
    'In 1 hour',
    'In 2 hours',
    '3:00 PM',
    '5:00 PM',
    'Tomorrow 9:00 AM',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            'Reschedule ${widget.exercise.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a new time for this exercise',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestedTimes.map((time) {
              final isSelected = _selectedTime == time;
              return GestureDetector(
                onTap: () => setState(() => _selectedTime = time),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.neonCyan : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.neonCyan : AppColors.glassBorder,
                    ),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedTime != null
                  ? () => widget.onReschedule(_selectedTime!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonCyan,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.surfaceLight,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Reschedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
