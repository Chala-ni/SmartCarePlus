/// SMARTCARE+ Activity Log Screen
///
/// Owner: Devin
/// Timeline of elderly activity and events

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String _selectedDate = 'Today';
  
  final List<Map<String, dynamic>> _activities = [
    {'time': '8:45 AM', 'event': 'Woke up', 'location': 'Bedroom', 'icon': Icons.wb_sunny, 'color': AppColors.neonOrange},
    {'time': '9:00 AM', 'event': 'Breakfast started', 'location': 'Kitchen', 'icon': Icons.restaurant, 'color': AppColors.neonGreen},
    {'time': '9:30 AM', 'event': 'Medication taken', 'location': 'Kitchen', 'icon': Icons.medication, 'color': AppColors.neonCyan},
    {'time': '10:15 AM', 'event': 'Watching TV', 'location': 'Living Room', 'icon': Icons.tv, 'color': AppColors.neonPurple},
    {'time': '11:00 AM', 'event': 'Phone call received', 'location': 'Living Room', 'icon': Icons.phone, 'color': AppColors.neonCyan},
    {'time': '12:30 PM', 'event': 'Lunch started', 'location': 'Kitchen', 'icon': Icons.restaurant, 'color': AppColors.neonGreen},
    {'time': '1:15 PM', 'event': 'Nap time', 'location': 'Bedroom', 'icon': Icons.hotel, 'color': AppColors.neonPurple},
    {'time': '3:00 PM', 'event': 'Woke from nap', 'location': 'Bedroom', 'icon': Icons.wb_sunny, 'color': AppColors.neonOrange},
    {'time': '3:30 PM', 'event': 'Walking exercise', 'location': 'Living Room', 'icon': Icons.directions_walk, 'color': AppColors.neonGreen},
    {'time': '4:00 PM', 'event': 'Snack time', 'location': 'Kitchen', 'icon': Icons.cookie, 'color': AppColors.neonOrange},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppColors.backgroundGradient),
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
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Activity Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
                    ),
                  ],
                ),
              ),
              
              // Date Selector
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['Today', 'Yesterday', 'Dec 30', 'Dec 29'].map((date) {
                    final isSelected = _selectedDate == date;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDate = date),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.neonCyan.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppColors.neonCyan : Colors.transparent),
                          ),
                          child: Text(date, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.neonCyan : AppColors.textSecondary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Active Hours', '8.5h', AppColors.neonGreen),
                      Container(width: 1, height: 40, color: AppColors.glassBorder),
                      _buildSummaryItem('Rest Hours', '3.2h', AppColors.neonPurple),
                      Container(width: 1, height: 40, color: AppColors.glassBorder),
                      _buildSummaryItem('Events', '${_activities.length}', AppColors.neonCyan),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Activity Timeline
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    final isLast = index == _activities.length - 1;
                    return _buildTimelineItem(activity, isLast);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> activity, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (activity['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(activity['icon'], color: activity['color'], size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.glassBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(activity['event'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(activity['time'], style: TextStyle(fontSize: 11, color: activity['color'], fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(activity['location'], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
