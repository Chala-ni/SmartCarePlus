/// SMARTCARE+ Caregiver Dashboard
///
/// Dashboard for professional caregivers with patient management,
/// health reports, and task scheduling features

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../providers/auth_provider.dart';

class CaregiverDashboard extends ConsumerStatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  ConsumerState<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends ConsumerState<CaregiverDashboard> {
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
            _CaregiverHomeTab(),
            _PatientsTab(),
            _TasksTab(),
            _ReportsTab(),
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
  const _CaregiverHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final userName = profile?.name ?? 'Caregiver';

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
                Column(
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
                      userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                _buildProfileAvatar(),
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
            
            _buildActivityLog('Completed physio session', 'Margaret', '30 min ago', AppColors.neonGreen),
            _buildActivityLog('Updated meal plan', 'Robert', '1 hour ago', AppColors.neonOrange),
            _buildActivityLog('Fall risk assessment', 'Eleanor', '2 hours ago', AppColors.neonCyan),
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

class _PatientsTab extends StatelessWidget {
  const _PatientsTab();

  @override
  Widget build(BuildContext context) {
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.search, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '8 patients under your care',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Patient Cards
            _buildPatientCard('Margaret Johnson', 78, 'Low Risk', 'Active', AppColors.neonGreen),
            const SizedBox(height: 12),
            _buildPatientCard('Robert Smith', 82, 'Medium Risk', 'Resting', AppColors.neonOrange),
            const SizedBox(height: 12),
            _buildPatientCard('Eleanor Brown', 75, 'Low Risk', 'Active', AppColors.neonGreen),
            const SizedBox(height: 12),
            _buildPatientCard('James Wilson', 80, 'High Risk', 'Inactive', AppColors.neonRed),
            const SizedBox(height: 12),
            _buildPatientCard('Helen Davis', 77, 'Low Risk', 'Active', AppColors.neonGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(String name, int age, String risk, String status, Color color) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.elderly, color: color),
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
                Row(
                  children: [
                    Text(
                      '$age years • ',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        risk,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
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
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
