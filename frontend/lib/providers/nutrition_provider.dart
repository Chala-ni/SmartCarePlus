/// SMARTCARE+ Nutrition Service Provider
///
/// Owner: Dilshan
/// Riverpod state management for nutrition features

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

// ============= Models =============

class Food {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String serving;

  Food({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.serving,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      serving: json['serving'] ?? json['serving_size'] ?? '',
    );
  }
}

class Meal {
  final String type;
  final String name;
  final int calories;
  final String time;
  final List<Food>? foods;

  Meal({
    required this.type,
    required this.name,
    required this.calories,
    required this.time,
    this.foods,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      time: json['time'] ?? '',
    );
  }
}

class NutritionSummary {
  final int caloriesConsumed;
  final int caloriesGoal;
  final double proteinConsumed;
  final double proteinGoal;
  final double carbsConsumed;
  final double carbsGoal;
  final double fatConsumed;
  final double fatGoal;
  final double fiberConsumed;
  final double fiberGoal;
  final List<Meal> meals;

  NutritionSummary({
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatConsumed,
    required this.fatGoal,
    required this.fiberConsumed,
    required this.fiberGoal,
    required this.meals,
  });

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    final calories = json['calories'] ?? {};
    final protein = json['protein'] ?? {};
    final carbs = json['carbohydrates'] ?? {};
    final fat = json['fat'] ?? {};
    final fiber = json['fiber'] ?? {};
    
    return NutritionSummary(
      caloriesConsumed: calories['consumed'] ?? 0,
      caloriesGoal: calories['goal'] ?? 1800,
      proteinConsumed: (protein['consumed'] ?? 0).toDouble(),
      proteinGoal: (protein['goal'] ?? 80).toDouble(),
      carbsConsumed: (carbs['consumed'] ?? 0).toDouble(),
      carbsGoal: (carbs['goal'] ?? 220).toDouble(),
      fatConsumed: (fat['consumed'] ?? 0).toDouble(),
      fatGoal: (fat['goal'] ?? 60).toDouble(),
      fiberConsumed: (fiber['consumed'] ?? 0).toDouble(),
      fiberGoal: (fiber['goal'] ?? 25).toDouble(),
      meals: (json['meals'] as List?)?.map((m) => Meal.fromJson(m)).toList() ?? [],
    );
  }
}

class HydrationData {
  final int glasses;
  final int goalGlasses;
  final int totalMl;
  final int goalMl;
  final List<Map<String, dynamic>> log;

  HydrationData({
    required this.glasses,
    required this.goalGlasses,
    required this.totalMl,
    required this.goalMl,
    required this.log,
  });

  factory HydrationData.fromJson(Map<String, dynamic> json) {
    return HydrationData(
      glasses: json['glasses'] ?? 0,
      goalGlasses: json['goal_glasses'] ?? 8,
      totalMl: json['total_ml'] ?? 0,
      goalMl: json['goal_ml'] ?? 2000,
      log: List<Map<String, dynamic>>.from(json['log'] ?? []),
    );
  }
}

class FoodDetection {
  final String name;
  final double confidence;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;

  FoodDetection({
    required this.name,
    required this.confidence,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
  });

  factory FoodDetection.fromJson(Map<String, dynamic> json) {
    final detected = json['detected'] ?? json;
    return FoodDetection(
      name: detected['name'] ?? '',
      confidence: (detected['confidence'] ?? 0).toDouble(),
      calories: detected['calories'] ?? 0,
      protein: (detected['protein'] ?? 0).toDouble(),
      carbs: (detected['carbs'] ?? 0).toDouble(),
      fat: (detected['fat'] ?? 0).toDouble(),
      servingSize: detected['serving_size'] ?? '',
    );
  }
}

// ============= State =============

class NutritionState {
  final NutritionSummary? summary;
  final HydrationData? hydration;
  final List<Meal> mealPlan;
  final List<Food> searchResults;
  final FoodDetection? lastDetection;
  final bool isLoading;
  final String? error;

  const NutritionState({
    this.summary,
    this.hydration,
    this.mealPlan = const [],
    this.searchResults = const [],
    this.lastDetection,
    this.isLoading = false,
    this.error,
  });

  NutritionState copyWith({
    NutritionSummary? summary,
    HydrationData? hydration,
    List<Meal>? mealPlan,
    List<Food>? searchResults,
    FoodDetection? lastDetection,
    bool? isLoading,
    String? error,
  }) {
    return NutritionState(
      summary: summary ?? this.summary,
      hydration: hydration ?? this.hydration,
      mealPlan: mealPlan ?? this.mealPlan,
      searchResults: searchResults ?? this.searchResults,
      lastDetection: lastDetection ?? this.lastDetection,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ============= Notifier =============

class NutritionNotifier extends StateNotifier<NutritionState> {
  final ApiService _api;

  NutritionNotifier(this._api) : super(const NutritionState());

  Future<void> loadDailySummary(String userId, {String? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = date != null ? {'date': date} : null;
      final response = await _api.get('/api/nutrition/daily-summary/$userId', queryParams: params);
      if (response.success && response.data != null) {
        state = state.copyWith(
          summary: NutritionSummary.fromJson(response.data),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadHydration(String userId, {String? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = date != null ? {'date': date} : null;
      final response = await _api.get('/api/nutrition/hydration/$userId', queryParams: params);
      if (response.success && response.data != null) {
        state = state.copyWith(
          hydration: HydrationData.fromJson(response.data),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMealPlan(String userId, {String? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = date != null ? {'date': date} : null;
      final response = await _api.get('/api/nutrition/meal-plan/$userId', queryParams: params);
      if (response.success && response.data != null) {
        final meals = (response.data['meals'] as List?)?.map((m) => Meal.fromJson(m)).toList() ?? [];
        state = state.copyWith(mealPlan: meals, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> searchFoods(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/api/nutrition/search', queryParams: {'query': query});
      if (response.success && response.data != null) {
        final foods = (response.data['results'] as List).map((f) => Food.fromJson(f)).toList();
        state = state.copyWith(searchResults: foods, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logHydration(String userId, int amountMl, String beverageType) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post('/api/nutrition/hydration/log', body: {
        'user_id': userId,
        'amount_ml': amountMl,
        'beverage_type': beverageType,
      });
      // Reload hydration data
      await loadHydration(userId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============= Providers =============

final nutritionProvider = StateNotifierProvider<NutritionNotifier, NutritionState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return NutritionNotifier(api);
});

final dailySummaryProvider = FutureProvider.family<NutritionSummary?, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/nutrition/daily-summary/$userId');
  if (response.success && response.data != null) {
    return NutritionSummary.fromJson(response.data);
  }
  return null;
});

final hydrationProvider = FutureProvider.family<HydrationData?, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/nutrition/hydration/$userId');
  if (response.success && response.data != null) {
    return HydrationData.fromJson(response.data);
  }
  return null;
});
