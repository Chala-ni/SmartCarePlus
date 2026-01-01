/// SMARTCARE+ Nutrition Home Screen
///
/// Owner: Dilshan
/// Main dashboard for nutrition and dietary tracking

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../widgets/common/glassmorphic_card.dart';

class NutritionHomeScreen extends StatelessWidget {
  const NutritionHomeScreen({super.key});

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                            'Nutrition',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Track your meals & hydration',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant, color: AppColors.neonGreen, size: 24),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Daily Summary Card
                GlassmorphicCard(
                  glowColor: AppColors.neonGreen,
                  glowIntensity: 0.15,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Summary",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.neonGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '1,450 / 1,800 cal',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.neonGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildNutrientColumn('Protein', 65, 80, AppColors.neonCyan),
                          _buildNutrientColumn('Carbs', 180, 220, AppColors.neonOrange),
                          _buildNutrientColumn('Fat', 45, 60, AppColors.neonPurple),
                          _buildNutrientColumn('Fiber', 18, 25, AppColors.neonGreen),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        context,
                        icon: Icons.camera_alt,
                        label: 'Scan Food',
                        color: AppColors.neonCyan,
                        onTap: () => Navigator.pushNamed(context, Routes.foodScanner),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        context,
                        icon: Icons.add_circle_outline,
                        label: 'Log Meal',
                        color: AppColors.neonGreen,
                        onTap: () => Navigator.pushNamed(context, Routes.mealLog),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        context,
                        icon: Icons.water_drop,
                        label: 'Hydration',
                        color: AppColors.neonPurple,
                        onTap: () => Navigator.pushNamed(context, Routes.hydration),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Hydration Card
                GlassmorphicCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.neonPurple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.water_drop, color: AppColors.neonPurple, size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Hydration',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            '6 / 8 glasses',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.neonPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: 6 / 8,
                          backgroundColor: AppColors.glassBorder,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonPurple),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(8, (index) {
                          final filled = index < 6;
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: filled 
                                  ? AppColors.neonPurple.withOpacity(0.2)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: filled ? AppColors.neonPurple : AppColors.glassBorder,
                              ),
                            ),
                            child: Icon(
                              Icons.water_drop,
                              size: 16,
                              color: filled ? AppColors.neonPurple : AppColors.textSecondary,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Today's Meals
                const Text(
                  "Today's Meals",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildMealCard(
                  mealType: 'Breakfast',
                  time: '8:00 AM',
                  calories: 420,
                  items: 'Oatmeal, Banana, Coffee',
                  icon: Icons.wb_sunny,
                  color: AppColors.neonOrange,
                ),
                const SizedBox(height: 10),
                _buildMealCard(
                  mealType: 'Lunch',
                  time: '12:30 PM',
                  calories: 650,
                  items: 'Grilled Chicken Salad, Rice',
                  icon: Icons.wb_cloudy,
                  color: AppColors.neonCyan,
                ),
                const SizedBox(height: 10),
                _buildMealCard(
                  mealType: 'Snack',
                  time: '3:00 PM',
                  calories: 180,
                  items: 'Apple, Almonds',
                  icon: Icons.cookie,
                  color: AppColors.neonGreen,
                ),
                const SizedBox(height: 10),
                _buildMealCard(
                  mealType: 'Dinner',
                  time: 'Not logged',
                  calories: 0,
                  items: 'Tap to log dinner',
                  icon: Icons.nights_stay,
                  color: AppColors.textSecondary,
                  isPending: true,
                ),
                
                const SizedBox(height: 24),
                
                // Meal Plan Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.mealPlan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonGreen.withOpacity(0.15),
                      foregroundColor: AppColors.neonGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.neonGreen),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month),
                        SizedBox(width: 8),
                        Text(
                          'View Meal Plan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildNutrientColumn(String label, double current, double goal, Color color) {
    final percentage = (current / goal).clamp(0.0, 1.0);
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: percentage,
                backgroundColor: AppColors.glassBorder,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 5,
              ),
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${current.toInt()}g',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard({
    required String mealType,
    required String time,
    required int calories,
    required String items,
    required IconData icon,
    required Color color,
    bool isPending = false,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isPending ? 0.08 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
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
                      mealType,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isPending ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPending ? AppColors.textSecondary : color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        items,
                        style: TextStyle(
                          fontSize: 12,
                          color: isPending ? AppColors.textSecondary : AppColors.textSecondary,
                          fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isPending)
                      Text(
                        '$calories cal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    if (isPending)
                      const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
