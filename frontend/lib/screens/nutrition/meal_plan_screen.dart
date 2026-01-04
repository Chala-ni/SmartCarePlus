import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/nutrition_provider.dart';
import '../../core/services/api_service.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  Map<String, List<Map<String, dynamic>>> _mealPlan = {};
  List<String> _weekDays = [];
  int _selectedDayIndex = 0;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateWeekDays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMealPlan();
    });
  }

  void _generateWeekDays() {
    final now = DateTime.now();
    _weekDays = List.generate(7, (index) {
      final day = now.add(Duration(days: index));
      return DateFormat('EEE, MMM d').format(day);
    });
  }

  Future<void> _loadMealPlan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final userId = 'current_user'; // TODO: Get from auth provider
      final response = await api.get('/api/nutrition/meal-plan/$userId');

      if (response.success && response.data != null && response.data['meal_plan'] != null) {
        final rawPlan = response.data['meal_plan'] as Map<String, dynamic>;
        _mealPlan = {};
        
        rawPlan.forEach((day, meals) {
          if (meals is List) {
            _mealPlan[day] = meals.map((m) => m as Map<String, dynamic>).toList();
          }
        });
      } else {
        _mealPlan = {};
      }
    } catch (e) {
      _error = 'Failed to load meal plan: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/api/nutrition/generate-plan', body: {
        'user_id': 'current_user',
        'preferences': {
          'dietary_restrictions': [],
          'calorie_target': 1800,
        },
      });

      if (response.success && response.data != null) {
        await _loadMealPlan(); // Reload the plan after generation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal plan generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to generate meal plan: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMealPlan,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _mealPlan.isEmpty
                  ? _buildEmptyState()
                  : _buildMealPlanContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _generateMealPlan,
        backgroundColor: Colors.green,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          _isGenerating ? 'Generating...' : 'Generate Plan',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMealPlan,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'No Meal Plan Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Generate a personalized meal plan based on\nyour dietary preferences and health goals.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateMealPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isGenerating ? 'Generating...' : 'Generate My Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlanContent() {
    return Column(
      children: [
        // Day selector
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _weekDays.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedDayIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDayIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekDays[index].split(',')[0],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _weekDays[index].split(',')[1].trim(),
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // Meals list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMealPlan,
            child: _buildMealsForDay(),
          ),
        ),
      ],
    );
  }

  Widget _buildMealsForDay() {
    final dayKey = 'day_$_selectedDayIndex';
    final meals = _mealPlan[dayKey] ?? [];

    if (meals.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.no_meals, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No meals planned for this day',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Group meals by type
    final mealsByType = <String, List<Map<String, dynamic>>>{};
    for (final meal in meals) {
      final type = (meal['meal_type'] as String?) ?? 'Other';
      mealsByType.putIfAbsent(type, () => []).add(meal);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in mealsByType.entries) ...[
          _buildMealTypeHeader(entry.key),
          ...entry.value.map((meal) => _buildMealCard(meal)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildMealTypeHeader(String mealType) {
    IconData icon;
    Color color;
    
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        icon = Icons.wb_sunny;
        color = Colors.orange;
        break;
      case 'lunch':
        icon = Icons.wb_cloudy;
        color = Colors.blue;
        break;
      case 'dinner':
        icon = Icons.nightlight_round;
        color = Colors.indigo;
        break;
      case 'snack':
        icon = Icons.cookie;
        color = Colors.brown;
        break;
      default:
        icon = Icons.restaurant;
        color = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            mealType.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final name = meal['name'] ?? 'Unknown';
    final calories = meal['calories'] ?? 0;
    final description = meal['description'] ?? '';
    final servingSize = meal['serving_size'] ?? '1 serving';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.green[50],
          child: Icon(
            Icons.restaurant_menu,
            color: Colors.green[700],
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildNutritionChip('$calories cal', Icons.local_fire_department, Colors.orange),
                const SizedBox(width: 8),
                _buildNutritionChip(servingSize, Icons.restaurant, Colors.blue),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
          onPressed: () {
            // TODO: Add meal to today's log
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added $name to today\'s log'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNutritionChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
