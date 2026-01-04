/// SMARTCARE+ Nutrition Home Screen
///
/// Owner: Dilshan
/// Main dashboard for nutrition and dietary tracking

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../providers/nutrition_provider.dart';
import '../../core/services/api_service.dart';

class NutritionHomeScreen extends ConsumerStatefulWidget {
  const NutritionHomeScreen({super.key});

  @override
  ConsumerState<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends ConsumerState<NutritionHomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dailySummary = {};
  List<Map<String, dynamic>> _todaysMeals = [];
  int _hydrationGlasses = 0;
  final int _hydrationGoal = 8;

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
      final api = ref.read(apiServiceProvider);
      final userId = 'current_user';

      // Load daily summary
      final summaryResponse = await api.get('/api/nutrition/daily-summary/$userId');
      if (summaryResponse.success && summaryResponse.data != null) {
        _dailySummary = Map<String, dynamic>.from(summaryResponse.data);
      }

      // Load hydration data
      final hydrationResponse = await api.get('/api/nutrition/hydration/$userId');
      if (hydrationResponse.success && hydrationResponse.data != null) {
        _hydrationGlasses = (hydrationResponse.data['glasses'] as num?)?.toInt() ?? 0;
      }

      // Extract meals from summary
      if (_dailySummary['meals'] != null) {
        _todaysMeals = List<Map<String, dynamic>>.from(_dailySummary['meals']);
      }
    } catch (e) {
      debugPrint('Error loading nutrition data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addWaterGlass() async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/api/nutrition/hydration/log', body: {
        'user_id': 'current_user',
        'glasses': 1,
      });
      setState(() {
        _hydrationGlasses = (_hydrationGlasses + 1).clamp(0, _hydrationGoal);
      });
    } catch (e) {
      debugPrint('Error logging hydration: $e');
    }
  }

  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final caloriesConsumed = _parseNum(_dailySummary['total_calories'] ?? 0);
    final caloriesTarget = _parseNum(_dailySummary['target_calories'] ?? 1800);
    final protein = _parseNum(_dailySummary['protein'] ?? 0);
    final proteinTarget = _parseNum(_dailySummary['protein_target'] ?? 80);
    final carbs = _parseNum(_dailySummary['carbs'] ?? 0);
    final carbsTarget = _parseNum(_dailySummary['carbs_target'] ?? 220);
    final fat = _parseNum(_dailySummary['fat'] ?? 0);
    final fatTarget = _parseNum(_dailySummary['fat_target'] ?? 60);
    final fiber = _parseNum(_dailySummary['fiber'] ?? 0);
    final fiberTarget = _parseNum(_dailySummary['fiber_target'] ?? 25);

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
          child: RefreshIndicator(
            onRefresh: _loadNutritionData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                  
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
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
                                child: Text(
                                  '${caloriesConsumed.toInt()} / ${caloriesTarget.toInt()} cal',
                                  style: const TextStyle(
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
                              _buildNutrientColumn('Protein', protein.toDouble(), proteinTarget.toDouble(), AppColors.neonCyan),
                              _buildNutrientColumn('Carbs', carbs.toDouble(), carbsTarget.toDouble(), AppColors.neonOrange),
                              _buildNutrientColumn('Fat', fat.toDouble(), fatTarget.toDouble(), AppColors.neonPurple),
                              _buildNutrientColumn('Fiber', fiber.toDouble(), fiberTarget.toDouble(), AppColors.neonGreen),
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
                            onTap: () => Navigator.pushNamed(context, Routes.foodScanner).then((_) => _loadNutritionData()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.add_circle_outline,
                            label: 'Log Meal',
                            color: AppColors.neonGreen,
                            onTap: () => Navigator.pushNamed(context, Routes.mealLog).then((_) => _loadNutritionData()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.water_drop,
                            label: 'Hydration',
                            color: AppColors.neonPurple,
                            onTap: () => Navigator.pushNamed(context, Routes.hydration).then((_) => _loadNutritionData()),
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
                              Row(
                                children: [
                                  Text(
                                    '$_hydrationGlasses / $_hydrationGoal glasses',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.neonPurple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _addWaterGlass,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.neonPurple.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.add, color: AppColors.neonPurple, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _hydrationGlasses / _hydrationGoal,
                              backgroundColor: AppColors.glassBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonPurple),
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(_hydrationGoal, (index) {
                              final filled = index < _hydrationGlasses;
                              return GestureDetector(
                                onTap: _addWaterGlass,
                                child: Container(
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
                    
                    if (_todaysMeals.isEmpty)
                      GlassmorphicCard(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No meals logged today',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(context, Routes.mealLog),
                                child: const Text('Log your first meal'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._todaysMeals.map((meal) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildMealCard(
                          mealType: (meal['meal_type'] as String?) ?? 'Meal',
                          time: (meal['time'] as String?) ?? '',
                          calories: _parseNum(meal['calories']).toInt(),
                          items: (meal['foods'] as List?)?.map((f) => f['name']).join(', ') ?? '',
                          icon: _getMealIcon((meal['meal_type'] as String?) ?? ''),
                          color: _getMealColor((meal['meal_type'] as String?) ?? ''),
                        ),
                      )),
                    
                    // Show pending meal types
                    ..._getPendingMealTypes().map((mealType) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildMealCard(
                        mealType: mealType,
                        time: 'Not logged',
                        calories: 0,
                        items: 'Tap to log $mealType',
                        icon: _getMealIcon(mealType),
                        color: AppColors.textSecondary,
                        isPending: true,
                      ),
                    )),
                    
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getPendingMealTypes() {
    final loggedTypes = _todaysMeals
        .map((m) => (m['meal_type'] as String?)?.toLowerCase() ?? '')
        .toSet();
    final allTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    return allTypes
        .where((t) => !loggedTypes.contains(t))
        .map((t) => t[0].toUpperCase() + t.substring(1))
        .toList();
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny;
      case 'lunch':
        return Icons.wb_cloudy;
      case 'dinner':
        return Icons.nights_stay;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  Color _getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return AppColors.neonOrange;
      case 'lunch':
        return AppColors.neonCyan;
      case 'dinner':
        return AppColors.neonPurple;
      case 'snack':
        return AppColors.neonGreen;
      default:
        return AppColors.neonGreen;
    }
  }

  Widget _buildNutrientColumn(String label, double current, double goal, Color color) {
    final percentage = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    
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
              '${current.toInt()}g',
              style: TextStyle(
                fontSize: 11,
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
    return GestureDetector(
      onTap: isPending ? () => Navigator.pushNamed(context, Routes.mealLog) : null,
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
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
                          fontSize: 11,
                          color: isPending ? AppColors.textSecondary : color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPending ? AppColors.textSecondary : AppColors.textPrimary.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isPending) ...[
              const SizedBox(width: 12),
              Text(
                '$calories cal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
