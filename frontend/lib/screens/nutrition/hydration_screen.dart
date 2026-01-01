/// SMARTCARE+ Hydration Tracking Screen
///
/// Owner: Dilshan
/// Track daily water intake with reminders

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  int _glassesConsumed = 6;
  final int _dailyGoal = 8;
  
  final List<Map<String, dynamic>> _hydrationLog = [
    {'time': '7:30 AM', 'amount': 250, 'type': 'Water'},
    {'time': '9:00 AM', 'amount': 250, 'type': 'Water'},
    {'time': '10:30 AM', 'amount': 200, 'type': 'Tea'},
    {'time': '12:00 PM', 'amount': 250, 'type': 'Water'},
    {'time': '2:30 PM', 'amount': 250, 'type': 'Water'},
    {'time': '4:00 PM', 'amount': 250, 'type': 'Water'},
  ];

  final List<Map<String, dynamic>> _beverageTypes = [
    {'name': 'Water', 'icon': Icons.water_drop, 'color': AppColors.neonCyan, 'ml': 250},
    {'name': 'Tea', 'icon': Icons.emoji_food_beverage, 'color': AppColors.neonOrange, 'ml': 200},
    {'name': 'Coffee', 'icon': Icons.coffee, 'color': AppColors.neonPurple, 'ml': 150},
    {'name': 'Juice', 'icon': Icons.local_drink, 'color': AppColors.neonGreen, 'ml': 200},
  ];

  int get _totalMl => _hydrationLog.fold(0, (sum, log) => sum + (log['amount'] as int));
  double get _progressPercentage => (_glassesConsumed / _dailyGoal).clamp(0.0, 1.0);

  void _addBeverage(Map<String, dynamic> beverage) {
    final now = TimeOfDay.now();
    final timeString = '${now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
    
    setState(() {
      _hydrationLog.add({
        'time': timeString,
        'amount': beverage['ml'],
        'type': beverage['name'],
      });
      if (beverage['name'] == 'Water') {
        _glassesConsumed++;
      }
    });
    
    Navigator.pop(context);
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
                      child: Text(
                        'Hydration',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              
              // Main Progress Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassmorphicCard(
                  glowColor: AppColors.neonPurple,
                  glowIntensity: 0.15,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Water Drop Animation
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: _progressPercentage,
                              backgroundColor: AppColors.glassBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonPurple),
                              strokeWidth: 12,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            children: [
                              const Icon(
                                Icons.water_drop,
                                color: AppColors.neonPurple,
                                size: 36,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_glassesConsumed / $_dailyGoal',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'glasses',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Total', '$_totalMl ml', Icons.local_drink),
                          Container(width: 1, height: 40, color: AppColors.glassBorder),
                          _buildStatItem('Goal', '${_dailyGoal * 250} ml', Icons.flag),
                          Container(width: 1, height: 40, color: AppColors.glassBorder),
                          _buildStatItem('Remaining', '${(_dailyGoal - _glassesConsumed) * 250} ml', Icons.trending_up),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Glass Indicators
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_dailyGoal, (index) {
                    final filled = index < _glassesConsumed;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _glassesConsumed = index + 1;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 36,
                        height: 46,
                        decoration: BoxDecoration(
                          color: filled 
                              ? AppColors.neonPurple.withOpacity(0.2)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: filled ? AppColors.neonPurple : AppColors.glassBorder,
                            width: filled ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          Icons.water_drop,
                          size: 20,
                          color: filled ? AppColors.neonPurple : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Today's Log
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Today's Log",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _hydrationLog.length,
                        itemBuilder: (context, index) {
                          final log = _hydrationLog[_hydrationLog.length - 1 - index];
                          return _buildLogItem(log);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Add Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showAddBeverageSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Text(
                          'Add Drink',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.neonPurple, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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

  Widget _buildLogItem(Map<String, dynamic> log) {
    Color typeColor;
    switch (log['type']) {
      case 'Water':
        typeColor = AppColors.neonCyan;
        break;
      case 'Tea':
        typeColor = AppColors.neonOrange;
        break;
      case 'Coffee':
        typeColor = AppColors.neonPurple;
        break;
      default:
        typeColor = AppColors.neonGreen;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.water_drop, color: typeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log['type'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    log['time'],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${log['amount']} ml',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: typeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBeverageSheet() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text(
              'Add Drink',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _beverageTypes.length,
              itemBuilder: (context, index) {
                final beverage = _beverageTypes[index];
                return GestureDetector(
                  onTap: () => _addBeverage(beverage),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (beverage['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (beverage['color'] as Color).withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          beverage['icon'],
                          color: beverage['color'],
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          beverage['name'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${beverage['ml']} ml',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
