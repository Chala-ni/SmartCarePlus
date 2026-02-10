/// SMARTCARE+ Meal Plan Screen
///
/// Owner: Dilshan
/// RDA-based meal plan with dietary preferences, budget, and restrictions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> with WidgetsBindingObserver {
  Map<String, List<Map<String, dynamic>>> _mealPlan = {};
  Map<String, dynamic> _dailyTargets = {};
  List<String> _weekDays = [];
  int _selectedDayIndex = 0;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;
  
  // Track which individual foods have been logged (key: "day_mealType_mealIndex_foodIndex")
  final Set<String> _loggedFoods = {};

  // Preferences
  List<String> _selectedRestrictions = [];
  String _budgetLevel = 'medium';
  int _calorieTarget = 1800;
  List<String> _foodDislikes = [];
  List<String> _allergies = [];
  List<String> _medicalConditions = [];
  List<String> _medications = [];
  final TextEditingController _dislikeController = TextEditingController();
  final TextEditingController _allergyController = TextEditingController();
  final TextEditingController _medicalController = TextEditingController();
  final TextEditingController _medicationController = TextEditingController();

  // Available restrictions
  final List<Map<String, dynamic>> _allRestrictions = [
    {'id': 'diabetic', 'label': 'Diabetic', 'icon': Icons.monitor_heart},
    {'id': 'low_sodium', 'label': 'Low Sodium', 'icon': Icons.no_food},
    {'id': 'heart_healthy', 'label': 'Heart Healthy', 'icon': Icons.favorite},
    {'id': 'vegetarian', 'label': 'Vegetarian', 'icon': Icons.eco},
    {'id': 'gluten_free', 'label': 'Gluten Free', 'icon': Icons.grain},
    {'id': 'lactose_free', 'label': 'Lactose Free', 'icon': Icons.no_drinks},
    {'id': 'low_fat', 'label': 'Low Fat', 'icon': Icons.fitness_center},
    {'id': 'high_fiber', 'label': 'High Fiber', 'icon': Icons.grass},
    {'id': 'kidney_friendly', 'label': 'Kidney Friendly', 'icon': Icons.health_and_safety},
    {'id': 'soft_foods', 'label': 'Soft Foods', 'icon': Icons.soup_kitchen},
  ];

  String get _userId => ref.read(currentUserProvider)?.uid ?? 'demo_user';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generateWeekDays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences().then((_) => _loadMealPlan());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dislikeController.dispose();
    _allergyController.dispose();
    _medicalController.dispose();
    _medicationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app resumes
      _loadMealPlan();
    }
  }

  void _generateWeekDays() {
    final now = DateTime.now();
    _weekDays = List.generate(7, (index) {
      final day = now.add(Duration(days: index));
      return DateFormat('EEE, MMM d').format(day);
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/api/nutrition/nutrition-preferences/$_userId');
      if (response.success && response.data != null) {
        final prefs = response.data['preferences'] as Map<String, dynamic>? ?? {};
        setState(() {
          _selectedRestrictions = List<String>.from(prefs['dietary_restrictions'] ?? []);
          _budgetLevel = prefs['budget_level'] ?? 'medium';
          _calorieTarget = prefs['calorie_target'] ?? 1800;
          _foodDislikes = List<String>.from(prefs['food_dislikes'] ?? []);
          _allergies = List<String>.from(prefs['allergies'] ?? []);
          _medicalConditions = List<String>.from(prefs['medical_conditions'] ?? []);
          _medications = List<String>.from(prefs['medications'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/api/nutrition/nutrition-preferences', body: {
        'user_id': _userId,
        'dietary_restrictions': _selectedRestrictions,
        'food_dislikes': _foodDislikes,
        'allergies': _allergies,
        'medical_conditions': _medicalConditions,
        'medications': _medications,
        'budget_level': _budgetLevel,
        'calorie_target': _calorieTarget,
      });
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  Future<void> _loadMealPlan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/api/nutrition/meal-plan/$_userId');

      if (response.success && response.data != null && response.data['meal_plan'] != null) {
        final rawPlan = response.data['meal_plan'] as Map<String, dynamic>;
        _mealPlan = {};
        rawPlan.forEach((day, meals) {
          if (meals is List) {
            _mealPlan[day] = meals.map((m) => Map<String, dynamic>.from(m as Map)).toList();
          }
        });
        if (response.data['daily_targets'] != null) {
          _dailyTargets = Map<String, dynamic>.from(response.data['daily_targets']);
        }
        // Sync checkmarks with actually logged meals
        await _syncLoggedFoods();
      } else {
        _mealPlan = {};
      }
    } catch (e) {
      _error = 'Failed to load meal plan: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Cross-reference meal plan foods with today's logged meals to restore checkmarks
  Future<void> _syncLoggedFoods() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/api/nutrition/daily-summary/$_userId');
      if (!response.success || response.data == null) return;

      final loggedMeals = response.data['meals'] as List<dynamic>? ?? [];
      if (loggedMeals.isEmpty) return;

      // Build a set of logged food names (lowercased) grouped by meal type
      final Map<String, Set<String>> loggedByType = {};
      for (final meal in loggedMeals) {
        final mealType = ((meal['meal_type'] ?? meal['type'] ?? '') as String).toLowerCase();
        final foods = meal['foods'] as List<dynamic>? ?? [];
        for (final food in foods) {
          final name = ((food is Map ? food['name'] : food.toString()) ?? '').toString().toLowerCase().trim();
          if (name.isNotEmpty) {
            loggedByType.putIfAbsent(mealType, () => {}).add(name);
          }
        }
        // Also check top-level meal name (when meal itself is the food)
        final mealName = (meal['name'] ?? '').toString().toLowerCase().trim();
        if (mealName.isNotEmpty) {
          loggedByType.putIfAbsent(mealType, () => {}).add(mealName);
        }
      }

      // For each day in the plan, match foods against logged meals
      // Only day 0 = today matters for syncing
      final dayKey = 'day_0';
      final dayMeals = _mealPlan[dayKey] ?? [];

      final newLoggedFoods = <String>{};
      // Preserve existing logged foods for other days
      for (final key in _loggedFoods) {
        if (!key.startsWith('day_0_')) {
          newLoggedFoods.add(key);
        }
      }

      for (int mealIndex = 0; mealIndex < dayMeals.length; mealIndex++) {
        final meal = dayMeals[mealIndex];
        final mealType = ((meal['meal_type'] ?? meal['type'] ?? '') as String).toLowerCase();
        final foods = meal['foods'] as List<dynamic>? ?? [];
        final loggedNames = loggedByType[mealType] ?? {};

        for (int foodIndex = 0; foodIndex < foods.length; foodIndex++) {
          final food = foods[foodIndex];
          final foodName = (food is Map ? (food['name'] ?? food['food_name'] ?? '') : food.toString()).toString().toLowerCase().trim();
          if (foodName.isNotEmpty && loggedNames.contains(foodName)) {
            newLoggedFoods.add('day_0_${mealType}_${mealIndex}_$foodIndex');
          }
        }
      }

      if (mounted) {
        setState(() {
          _loggedFoods.clear();
          _loggedFoods.addAll(newLoggedFoods);
        });
      }
    } catch (e) {
      debugPrint('Error syncing logged foods: $e');
    }
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    // Save preferences first
    await _savePreferences();

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/api/nutrition/generate-plan', body: {
        'user_id': _userId,
        'duration_days': 7,
        'restrictions': _selectedRestrictions,
        'calorie_target': _calorieTarget,
        'budget_level': _budgetLevel,
        'food_dislikes': _foodDislikes,
      });

      if (response.success && response.data != null) {
        // Also save to Firestore via save-meal-plan
        try {
          await api.post('/api/nutrition/save-meal-plan', body: {
            'user_id': _userId,
            'duration_days': 7,
            'restrictions': _selectedRestrictions,
            'calorie_target': _calorieTarget,
            'budget_level': _budgetLevel,
            'food_dislikes': _foodDislikes,
          });
        } catch (_) {}

        await _loadMealPlan();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal plan generated successfully!'),
              backgroundColor: AppColors.neonGreen,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to generate meal plan: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showPreferencesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Meal Plan Preferences',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Calorie Target
                      const Text(
                        'Daily Calorie Target',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _calorieTarget.toDouble(),
                              min: 1200,
                              max: 2500,
                              divisions: 13,
                              activeColor: AppColors.neonGreen,
                              inactiveColor: AppColors.glassBorder,
                              label: '$_calorieTarget cal',
                              onChanged: (v) {
                                setState(() => _calorieTarget = v.toInt());
                                setSheetState(() {});
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.neonGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_calorieTarget',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neonGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Budget Level
                      const Text(
                        'Budget Level',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['low', 'medium', 'high'].map((level) {
                          final isSelected = _budgetLevel == level;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _budgetLevel = level);
                                  setSheetState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.neonGreen.withOpacity(0.15) : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppColors.neonGreen : AppColors.glassBorder,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      level[0].toUpperCase() + level.substring(1),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected ? AppColors.neonGreen : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Dietary Restrictions
                      const Text(
                        'Dietary Restrictions',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allRestrictions.map((r) {
                          final isSelected = _selectedRestrictions.contains(r['id']);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedRestrictions.remove(r['id']);
                                } else {
                                  _selectedRestrictions.add(r['id']);
                                }
                              });
                              setSheetState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.neonGreen.withOpacity(0.15) : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.neonGreen : AppColors.glassBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    r['icon'] as IconData,
                                    size: 16,
                                    color: isSelected ? AppColors.neonGreen : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    r['label'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? AppColors.neonGreen : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Food Dislikes
                      const Text(
                        'Foods You Dislike',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dislikeController,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. fish, mushroom',
                                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final text = _dislikeController.text.trim();
                              if (text.isNotEmpty && !_foodDislikes.contains(text.toLowerCase())) {
                                setState(() => _foodDislikes.add(text.toLowerCase()));
                                setSheetState(() {});
                                _dislikeController.clear();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.neonGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add, color: AppColors.neonGreen),
                            ),
                          ),
                        ],
                      ),
                      if (_foodDislikes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _foodDislikes.map((d) {
                            return Chip(
                              label: Text(d, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              backgroundColor: AppColors.surfaceLight,
                              deleteIconColor: AppColors.neonRed,
                              onDeleted: () {
                                setState(() => _foodDislikes.remove(d));
                                setSheetState(() {});
                              },
                              side: const BorderSide(color: AppColors.glassBorder),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Allergies
                      const Text(
                        'Allergies',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _allergyController,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. peanuts, shellfish',
                                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final text = _allergyController.text.trim();
                              if (text.isNotEmpty && !_allergies.contains(text.toLowerCase())) {
                                setState(() => _allergies.add(text.toLowerCase()));
                                setSheetState(() {});
                                _allergyController.clear();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.neonOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add, color: AppColors.neonOrange),
                            ),
                          ),
                        ],
                      ),
                      if (_allergies.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _allergies.map((a) {
                            return Chip(
                              label: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              backgroundColor: AppColors.neonOrange.withOpacity(0.1),
                              deleteIconColor: AppColors.neonRed,
                              onDeleted: () {
                                setState(() => _allergies.remove(a));
                                setSheetState(() {});
                              },
                              side: BorderSide(color: AppColors.neonOrange.withOpacity(0.3)),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Medical Conditions
                      const Text(
                        'Medical Conditions',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _medicalController,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. diabetes, hypertension',
                                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final text = _medicalController.text.trim();
                              if (text.isNotEmpty && !_medicalConditions.contains(text.toLowerCase())) {
                                setState(() => _medicalConditions.add(text.toLowerCase()));
                                setSheetState(() {});
                                _medicalController.clear();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.neonPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add, color: AppColors.neonPurple),
                            ),
                          ),
                        ],
                      ),
                      if (_medicalConditions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _medicalConditions.map((m) {
                            return Chip(
                              label: Text(m, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              backgroundColor: AppColors.neonPurple.withOpacity(0.1),
                              deleteIconColor: AppColors.neonRed,
                              onDeleted: () {
                                setState(() => _medicalConditions.remove(m));
                                setSheetState(() {});
                              },
                              side: BorderSide(color: AppColors.neonPurple.withOpacity(0.3)),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Medications
                      const Text(
                        'Current Medications',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _medicationController,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. metformin, aspirin',
                                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.glassBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final text = _medicationController.text.trim();
                              if (text.isNotEmpty && !_medications.contains(text.toLowerCase())) {
                                setState(() => _medications.add(text.toLowerCase()));
                                setSheetState(() {});
                                _medicationController.clear();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.neonCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add, color: AppColors.neonCyan),
                            ),
                          ),
                        ],
                      ),
                      if (_medications.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _medications.map((med) {
                            return Chip(
                              label: Text(med, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              backgroundColor: AppColors.neonCyan.withOpacity(0.1),
                              deleteIconColor: AppColors.neonRed,
                              onDeleted: () {
                                setState(() => _medications.remove(med));
                                setSheetState(() {});
                              },
                              side: BorderSide(color: AppColors.neonCyan.withOpacity(0.3)),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isGenerating
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _generateMealPlan();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome),
                              SizedBox(width: 8),
                              Text(
                                'Generate Meal Plan',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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
                        'Meal Plan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showPreferencesSheet,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune, color: AppColors.neonGreen),
                      ),
                    ),
                  ],
                ),
              ),

              // Active filters summary
              if (_selectedRestrictions.isNotEmpty || _budgetLevel != 'medium') ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('${_calorieTarget} cal', AppColors.neonOrange),
                        if (_budgetLevel != 'medium')
                          _buildFilterChip(_budgetLevel.toUpperCase(), AppColors.neonCyan),
                        ..._selectedRestrictions.map((r) => _buildFilterChip(
                          r.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                          AppColors.neonPurple,
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Day selector
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _weekDays.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedDayIndex;
                    final parts = _weekDays[index].split(', ');
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDayIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.neonGreen.withOpacity(0.15) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.neonGreen : AppColors.glassBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              parts[0],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.neonGreen : AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              parts.length > 1 ? parts[1] : '',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? AppColors.neonGreen.withOpacity(0.7) : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorState()
                        : _mealPlan.isEmpty
                            ? _buildEmptyState()
                            : _buildMealsForDay(),
              ),

              // Bottom button bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.glassBorder.withOpacity(0.3))),
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: _isGenerating ? null : _showPreferencesSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isGenerating ? AppColors.surfaceLight : AppColors.neonCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isGenerating
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonCyan),
                              ),
                              const SizedBox(width: 12),
                              const Text('Generating Plan...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.black),
                              SizedBox(width: 8),
                              Text('Generate Meal Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
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

  Widget _buildFilterChip(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.neonRed),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadMealPlan,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonCyan, foregroundColor: Colors.black),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 72, color: Colors.grey[600]),
            const SizedBox(height: 20),
            const Text(
              'No Meal Plan Yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Generate a personalized meal plan based on your dietary preferences and health needs.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showPreferencesSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Set Preferences & Generate', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsForDay() {
    final dayKey = 'day_$_selectedDayIndex';
    final meals = _mealPlan[dayKey] ?? [];

    if (meals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_meals, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            const Text('No meals planned for this day', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    // Group by meal type
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final meal in meals) {
      final type = (meal['meal_type'] as String?) ?? 'other';
      grouped.putIfAbsent(type, () => []).add(meal);
    }

    return RefreshIndicator(
      onRefresh: _loadMealPlan,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Daily target summary
          if (_dailyTargets.isNotEmpty)
            GlassmorphicCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTargetItem('Calories', '${(_dailyTargets['calories'] ?? 1800).toInt()}', 'kcal', AppColors.neonOrange),
                  _buildTargetItem('Protein', '${(_dailyTargets['protein'] ?? 60).toInt()}', 'g', AppColors.neonCyan),
                  _buildTargetItem('Carbs', '${(_dailyTargets['carbohydrates'] ?? 220).toInt()}', 'g', AppColors.neonPurple),
                  _buildTargetItem('Fat', '${(_dailyTargets['fat'] ?? 60).toInt()}', 'g', AppColors.neonGreen),
                ],
              ),
            ),
          const SizedBox(height: 16),

          for (final entry in grouped.entries) ...[
            _buildMealTypeHeader(entry.key),
            ...entry.value.asMap().entries.map((mealEntry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMealCard(mealEntry.value, entry.key, mealEntry.key),
            )),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTargetItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(unit, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildMealTypeHeader(String mealType) {
    IconData icon;
    Color color;
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        icon = Icons.wb_sunny;
        color = AppColors.neonOrange;
        break;
      case 'lunch':
        icon = Icons.wb_cloudy;
        color = AppColors.neonCyan;
        break;
      case 'dinner':
        icon = Icons.nights_stay;
        color = AppColors.neonPurple;
        break;
      case 'morning_snack':
      case 'afternoon_snack':
      case 'evening_snack':
      case 'snack':
        icon = Icons.cookie;
        color = AppColors.neonGreen;
        break;
      default:
        icon = Icons.restaurant;
        color = AppColors.neonGreen;
    }

    final displayName = mealType.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal, String mealType, int mealIndex) {
    final name = meal['name'] ?? 'Meal';
    final calories = (meal['calories'] as num?)?.toInt() ?? 0;
    final time = meal['time'] ?? '';
    final foods = meal['foods'] as List<dynamic>? ?? [];

    // Check if all foods in this meal have been logged (include mealType in key)
    final allLogged = foods.isNotEmpty && foods.asMap().entries.every(
      (e) => _loggedFoods.contains('day_${_selectedDayIndex}_${mealType}_${mealIndex}_${e.key}'),
    );

    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: allLogged ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: allLogged ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (time.isNotEmpty)
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.neonOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$calories cal',
                  style: const TextStyle(fontSize: 11, color: AppColors.neonOrange, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (foods.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: 8),
            // Individual foods list
            ...foods.asMap().entries.map((entry) {
              final idx = entry.key;
              final food = entry.value;
              final foodName = food is Map ? (food['name'] ?? food['food_name'] ?? 'Item') : food.toString();
              final foodCal = food is Map ? ((food['calories'] as num?)?.toInt() ?? 0) : 0;
              final foodKey = 'day_${_selectedDayIndex}_${mealType}_${mealIndex}_$idx';
              final isLogged = _loggedFoods.contains(foodKey);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      isLogged ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isLogged ? AppColors.neonGreen : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        foodName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isLogged ? AppColors.textSecondary : AppColors.textPrimary,
                          decoration: isLogged ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (foodCal > 0)
                      Text(
                        '$foodCal cal',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLogged ? AppColors.textSecondary.withOpacity(0.5) : AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (!isLogged)
                      GestureDetector(
                        onTap: () => _logSingleFood(foodKey, foodName, foodCal, meal['meal_type'] ?? meal['type'] ?? mealType),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.neonGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, size: 16, color: AppColors.neonGreen),
                        ),
                      )
                    else
                      const Icon(Icons.check, size: 16, color: AppColors.neonGreen),
                  ],
                ),
              );
            }),
            // Log entire meal button
            if (!allLogged) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _logEntireMeal(meal, mealType, mealIndex),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.neonCyan.withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Text(
                      'Log Entire Meal',
                      style: TextStyle(fontSize: 12, color: AppColors.neonCyan, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '✓ Meal Logged',
                    style: TextStyle(fontSize: 12, color: AppColors.neonGreen, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ] else ...[
            // No individual foods — simple log button
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: () => _logEntireMeal(meal, mealType, mealIndex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neonGreen.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: AppColors.neonGreen),
                        SizedBox(width: 4),
                        Text('Log', style: TextStyle(fontSize: 11, color: AppColors.neonGreen, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _logSingleFood(String foodKey, String foodName, int calories, String mealType) async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/api/nutrition/log-meal', body: {
        'user_id': _userId,
        'meal_type': mealType.isNotEmpty ? mealType : 'lunch',
        'foods': [{'name': foodName, 'calories': calories, 'portion': 1.0}],
        'notes': 'Logged from meal plan',
      });
      setState(() => _loggedFoods.add(foodKey));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged $foodName'),
            backgroundColor: AppColors.neonGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _logEntireMeal(Map<String, dynamic> meal, String mealType, int mealIndex) async {
    final foods = meal['foods'] as List<dynamic>? ?? [];
    final mealTypeValue = meal['meal_type'] ?? meal['type'] ?? mealType;
    final api = ref.read(apiServiceProvider);

    final foodEntries = foods.isNotEmpty
        ? foods.map((f) {
            if (f is Map) {
              return {
                'name': f['name'] ?? f['food_name'] ?? 'Item',
                'calories': (f['calories'] as num?)?.toInt() ?? 0,
                'portion': 1.0,
              };
            }
            return {'name': f.toString(), 'calories': 0, 'portion': 1.0};
          }).toList()
        : [{'name': meal['name'] ?? 'Meal', 'calories': (meal['calories'] as num?)?.toInt() ?? 0, 'portion': 1.0}];

    try {
      await api.post('/api/nutrition/log-meal', body: {
        'user_id': _userId,
        'meal_type': mealTypeValue,
        'foods': foodEntries,
        'notes': 'Logged entire meal from meal plan',
      });
      setState(() {
        for (int i = 0; i < foods.length; i++) {
          _loggedFoods.add('day_${_selectedDayIndex}_${mealType}_${mealIndex}_$i');
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${meal['name'] ?? 'meal'}'),
            backgroundColor: AppColors.neonGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log meal: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
