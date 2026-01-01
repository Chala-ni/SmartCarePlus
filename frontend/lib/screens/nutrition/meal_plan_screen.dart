/// SMARTCARE+ Meal Plan Screen
///
/// Owner: Dilshan
/// Weekly meal planning with dietary recommendations

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  int _selectedDayIndex = 0;
  
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _dates = ['6', '7', '8', '9', '10', '11', '12'];
  
  final Map<int, List<Map<String, dynamic>>> _mealPlan = {
    0: [
      {'type': 'Breakfast', 'name': 'Oatmeal with Berries', 'calories': 320, 'time': '8:00 AM'},
      {'type': 'Lunch', 'name': 'Grilled Chicken Salad', 'calories': 450, 'time': '12:30 PM'},
      {'type': 'Snack', 'name': 'Greek Yogurt', 'calories': 150, 'time': '3:30 PM'},
      {'type': 'Dinner', 'name': 'Baked Salmon with Vegetables', 'calories': 520, 'time': '7:00 PM'},
    ],
    1: [
      {'type': 'Breakfast', 'name': 'Scrambled Eggs & Toast', 'calories': 380, 'time': '8:00 AM'},
      {'type': 'Lunch', 'name': 'Vegetable Soup & Bread', 'calories': 420, 'time': '12:30 PM'},
      {'type': 'Snack', 'name': 'Apple & Almonds', 'calories': 180, 'time': '3:30 PM'},
      {'type': 'Dinner', 'name': 'Grilled Fish with Rice', 'calories': 480, 'time': '7:00 PM'},
    ],
    2: [
      {'type': 'Breakfast', 'name': 'Smoothie Bowl', 'calories': 350, 'time': '8:00 AM'},
      {'type': 'Lunch', 'name': 'Turkey Sandwich', 'calories': 480, 'time': '12:30 PM'},
      {'type': 'Snack', 'name': 'Carrot Sticks & Hummus', 'calories': 120, 'time': '3:30 PM'},
      {'type': 'Dinner', 'name': 'Chicken Stir-fry', 'calories': 550, 'time': '7:00 PM'},
    ],
  };

  List<Map<String, dynamic>> get _todaysMeals => _mealPlan[_selectedDayIndex] ?? _mealPlan[0]!;
  int get _totalCalories => _todaysMeals.fold(0, (sum, meal) => sum + (meal['calories'] as int));

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                            'Meal Plan',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'January 2026',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_calendar, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              
              // Day Selector
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _days.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedDayIndex == index;
                    final isToday = index == 2; // Wednesday is "today"
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = index),
                        child: Container(
                          width: 50,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.neonGreen.withOpacity(0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected 
                                  ? AppColors.neonGreen 
                                  : isToday 
                                      ? AppColors.neonCyan.withOpacity(0.5) 
                                      : Colors.transparent,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _days[index],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected 
                                      ? AppColors.neonGreen 
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dates[index],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                      ? AppColors.neonGreen 
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (isToday)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.neonCyan,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Daily Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_days[_selectedDayIndex]}\'s Plan',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_totalCalories calories',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildMacroIndicator('P', 85, AppColors.neonCyan),
                          const SizedBox(width: 8),
                          _buildMacroIndicator('C', 180, AppColors.neonOrange),
                          const SizedBox(width: 8),
                          _buildMacroIndicator('F', 55, AppColors.neonPurple),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Meals List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _todaysMeals.length,
                  itemBuilder: (context, index) {
                    final meal = _todaysMeals[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildMealCard(meal, index),
                    );
                  },
                ),
              ),
              
              // Dietary Notes
              Padding(
                padding: const EdgeInsets.all(20),
                child: GlassmorphicCard(
                  glowColor: AppColors.neonCyan,
                  glowIntensity: 0.08,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lightbulb_outline, color: AppColors.neonCyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dietary Tip',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neonCyan,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Try to include more leafy greens for better vitamin K intake.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroIndicator(String label, int grams, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${grams}g',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal, int index) {
    final colors = [AppColors.neonOrange, AppColors.neonCyan, AppColors.neonGreen, AppColors.neonPurple];
    final icons = [Icons.wb_sunny, Icons.wb_cloudy, Icons.cookie, Icons.nights_stay];
    final color = colors[index % colors.length];
    final icon = icons[index % icons.length];

    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      meal['type'],
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      meal['time'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  meal['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meal['calories']} calories',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
