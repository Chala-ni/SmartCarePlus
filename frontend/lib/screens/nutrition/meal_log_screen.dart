/// SMARTCARE+ Meal Log Screen
///
/// Owner: Dilshan
/// Manual meal logging with food search

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../core/services/api_service.dart';
import '../../providers/nutrition_provider.dart';

class MealLogScreen extends ConsumerStatefulWidget {
  const MealLogScreen({super.key});

  @override
  ConsumerState<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends ConsumerState<MealLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMealType = 'Lunch';
  final List<Map<String, dynamic>> _selectedFoods = [];
  
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  
  List<Map<String, dynamic>> _recentFoods = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _debounce;

  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  int get _totalCalories => _selectedFoods.fold(0, (sum, food) => sum + _parseNum(food['calories']).toInt());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentFoods();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentFoods() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/api/nutrition/recent-foods');
      if (response.success && response.data != null && response.data['foods'] != null) {
        setState(() {
          _recentFoods = List<Map<String, dynamic>>.from(response.data['foods']);
        });
      }
    } catch (e) {
      // Fall back to empty list on error
      debugPrint('Error loading recent foods: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchFoods(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/api/nutrition/search', queryParams: {'query': query});
      if (response.success && response.data != null && response.data['results'] != null) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(
            (response.data['results'] as List).map((item) => {
              'name': item['description'] ?? item['name'] ?? 'Unknown',
              'calories': _parseNum(item['calories'] ?? item['foodNutrients']?[0]?['value'] ?? 0),
              'serving': item['servingSize'] ?? item['serving'] ?? '100g',
              'protein': _parseNum(item['protein'] ?? 0),
              'carbs': _parseNum(item['carbs'] ?? 0),
              'fat': _parseNum(item['fat'] ?? 0),
              'fdc_id': item['fdcId'] ?? item['fdc_id'],
            }),
          );
        });
      }
    } catch (e) {
      debugPrint('Error searching foods: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _saveMeal() async {
    if (_selectedFoods.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/api/nutrition/log-meal', body: {
        'user_id': 'current_user',
        'meal_type': _selectedMealType.toLowerCase(),
        'foods': _selectedFoods.map((food) => {
          'name': food['name'],
          'calories': _parseNum(food['calories']),
          'protein': _parseNum(food['protein'] ?? 0),
          'carbs': _parseNum(food['carbs'] ?? 0),
          'fat': _parseNum(food['fat'] ?? 0),
          'serving_size': food['serving'] ?? '1 serving',
        }).toList(),
      });

      if (response.success) {
        // Refresh nutrition data
        ref.read(nutritionProvider.notifier).loadDailySummary('current_user');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedMealType} logged successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save meal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchFoods(query);
    });
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
                    onChanged: _onSearchChanged,
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
                    if (_isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_isLoading && _searchController.text.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      Text(
                        _searchController.text.isNotEmpty ? 'Search Results' : 'Recent Foods',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      if ((_searchController.text.isNotEmpty ? _searchResults : _recentFoods).isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty 
                                      ? 'No foods found for "${_searchController.text}"'
                                      : 'No recent foods',
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...((_searchController.text.isNotEmpty ? _searchResults : _recentFoods)
                            .map((food) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildFoodItem(food),
                                ))),
                    ],
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
                      onPressed: _isSaving ? null : _saveMeal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
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
