/// SMARTCARE+ Meal Log Screen
///
/// Owner: Dilshan
/// Manual meal logging with food search

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class MealLogScreen extends StatefulWidget {
  const MealLogScreen({super.key});

  @override
  State<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends State<MealLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMealType = 'Lunch';
  final List<Map<String, dynamic>> _selectedFoods = [];
  
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  
  final List<Map<String, dynamic>> _recentFoods = [
    {'name': 'Oatmeal', 'calories': 150, 'serving': '1 cup'},
    {'name': 'Banana', 'calories': 105, 'serving': '1 medium'},
    {'name': 'Grilled Chicken', 'calories': 165, 'serving': '100g'},
    {'name': 'Brown Rice', 'calories': 215, 'serving': '1 cup'},
    {'name': 'Greek Yogurt', 'calories': 100, 'serving': '170g'},
  ];
  
  final List<Map<String, dynamic>> _searchResults = [
    {'name': 'Apple', 'calories': 95, 'serving': '1 medium', 'protein': 0.5, 'carbs': 25, 'fat': 0.3},
    {'name': 'Almonds', 'calories': 164, 'serving': '1 oz (28g)', 'protein': 6, 'carbs': 6, 'fat': 14},
    {'name': 'Avocado', 'calories': 240, 'serving': '1 whole', 'protein': 3, 'carbs': 12, 'fat': 22},
    {'name': 'Salmon', 'calories': 208, 'serving': '100g', 'protein': 20, 'carbs': 0, 'fat': 13},
    {'name': 'Spinach Salad', 'calories': 23, 'serving': '1 cup', 'protein': 3, 'carbs': 4, 'fat': 0.4},
  ];

  int get _totalCalories => _selectedFoods.fold(0, (sum, food) => sum + (food['calories'] as int));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                      child: Text(
                        'Log Meal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Meal Type Selector
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _mealTypes.length,
                  itemBuilder: (context, index) {
                    final mealType = _mealTypes[index];
                    final isSelected = _selectedMealType == mealType;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMealType = mealType),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.neonGreen.withOpacity(0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.neonGreen : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            mealType,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? AppColors.neonGreen : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search food...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Food List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Selected Foods
                    if (_selectedFoods.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Selected Foods',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '$_totalCalories cal',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neonGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_selectedFoods.length, (index) {
                        final food = _selectedFoods[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildSelectedFoodItem(food, index),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    
                    // Search Results or Recent Foods
                    Text(
                      _searchController.text.isNotEmpty ? 'Search Results' : 'Recent Foods',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    ...((_searchController.text.isNotEmpty ? _searchResults : _recentFoods)
                        .map((food) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildFoodItem(food),
                            ))),
                  ],
                ),
              ),
              
              // Save Button
              if (_selectedFoods.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Save meal to backend
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Save $_selectedMealType • $_totalCalories cal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildFoodItem(Map<String, dynamic> food) {
    final isSelected = _selectedFoods.any((f) => f['name'] == food['name']);
    
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedFoods.add(food));
        }
      },
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant, color: AppColors.neonGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    food['serving'],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${food['calories']} cal',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.neonOrange,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected ? Icons.check_circle : Icons.add_circle_outline,
              color: isSelected ? AppColors.neonGreen : AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFoodItem(Map<String, dynamic> food, int index) {
    return GlassmorphicCard(
      glowColor: AppColors.neonGreen,
      glowIntensity: 0.08,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check, color: AppColors.neonGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  food['serving'],
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${food['calories']} cal',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neonGreen,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _selectedFoods.removeAt(index)),
            child: const Icon(Icons.remove_circle, color: AppColors.neonRed, size: 22),
          ),
        ],
      ),
    );
  }
}
