/// SMARTCARE+ Physio Service Provider
///
/// Owner: Neelaka
/// Riverpod state management for physiotherapy features

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

// ============= Models =============

class Exercise {
  final String id;
  final String name;
  final String category;
  final String duration;
  final String difficulty;
  final String reps;
  final String description;
  final bool isPrescribed;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.duration,
    required this.difficulty,
    required this.reps,
    required this.description,
    this.isPrescribed = false,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      duration: json['duration'] ?? '',
      difficulty: json['difficulty'] ?? '',
      reps: json['reps'] ?? '',
      description: json['description'] ?? '',
      isPrescribed: json['is_prescribed'] ?? false,
    );
  }
}

class FallRisk {
  final double riskScore;
  final String riskLevel;
  final List<String> contributingFactors;
  final String lastAssessment;
  final String trend;

  FallRisk({
    required this.riskScore,
    required this.riskLevel,
    required this.contributingFactors,
    required this.lastAssessment,
    required this.trend,
  });

  factory FallRisk.fromJson(Map<String, dynamic> json) {
    return FallRisk(
      riskScore: (json['risk_score'] ?? 0).toDouble(),
      riskLevel: json['risk_level'] ?? 'Unknown',
      contributingFactors: List<String>.from(json['contributing_factors'] ?? []),
      lastAssessment: json['last_assessment'] ?? '',
      trend: json['trend'] ?? 'stable',
    );
  }
}

class GaitMetrics {
  final double strideLength;
  final double cadence;
  final double speed;
  final double symmetry;
  final double stepWidth;
  final String fallRisk;
  final String gaitQuality;

  GaitMetrics({
    required this.strideLength,
    required this.cadence,
    required this.speed,
    required this.symmetry,
    required this.stepWidth,
    required this.fallRisk,
    required this.gaitQuality,
  });

  factory GaitMetrics.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] ?? {};
    final indicators = json['risk_indicators'] ?? {};
    return GaitMetrics(
      strideLength: (metrics['stride_length'] ?? 0).toDouble(),
      cadence: (metrics['cadence'] ?? 0).toDouble(),
      speed: (metrics['speed'] ?? 0).toDouble(),
      symmetry: (metrics['symmetry'] ?? 0).toDouble(),
      stepWidth: (metrics['step_width'] ?? 0).toDouble(),
      fallRisk: indicators['fall_risk'] ?? 'Unknown',
      gaitQuality: indicators['gait_quality'] ?? 'Unknown',
    );
  }
}

class PhysioSession {
  final String id;
  final String date;
  final String type;
  final int durationMinutes;
  final double score;
  final String status;

  PhysioSession({
    required this.id,
    required this.date,
    required this.type,
    required this.durationMinutes,
    required this.score,
    required this.status,
  });

  factory PhysioSession.fromJson(Map<String, dynamic> json) {
    return PhysioSession(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      type: json['type'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      score: (json['score'] ?? 0).toDouble(),
      status: json['status'] ?? '',
    );
  }
}

// ============= State =============

class PhysioState {
  final List<Exercise> exercises;
  final List<Exercise> prescribedExercises;
  final FallRisk? fallRisk;
  final GaitMetrics? gaitMetrics;
  final List<PhysioSession> sessions;
  final bool isLoading;
  final String? error;

  const PhysioState({
    this.exercises = const [],
    this.prescribedExercises = const [],
    this.fallRisk,
    this.gaitMetrics,
    this.sessions = const [],
    this.isLoading = false,
    this.error,
  });

  PhysioState copyWith({
    List<Exercise>? exercises,
    List<Exercise>? prescribedExercises,
    FallRisk? fallRisk,
    GaitMetrics? gaitMetrics,
    List<PhysioSession>? sessions,
    bool? isLoading,
    String? error,
  }) {
    return PhysioState(
      exercises: exercises ?? this.exercises,
      prescribedExercises: prescribedExercises ?? this.prescribedExercises,
      fallRisk: fallRisk ?? this.fallRisk,
      gaitMetrics: gaitMetrics ?? this.gaitMetrics,
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ============= Notifier =============

class PhysioNotifier extends StateNotifier<PhysioState> {
  final ApiService _api;

  PhysioNotifier(this._api) : super(const PhysioState());

  Future<void> loadExercises({String? category, String? difficulty}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (category != null) params['category'] = category;
      if (difficulty != null) params['difficulty'] = difficulty;
      
      final response = await _api.get('/api/physio/exercises', queryParams: params);
      if (response.success && response.data != null) {
        final exerciseList = (response.data['exercises'] as List)
            .map((e) => Exercise.fromJson(e))
            .toList();
        state = state.copyWith(exercises: exerciseList, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadPrescribedExercises(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/api/physio/exercises/$userId');
      if (response.success && response.data != null) {
        final exerciseList = (response.data['exercises'] as List)
            .map((e) => Exercise.fromJson(e))
            .toList();
        state = state.copyWith(prescribedExercises: exerciseList, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadFallRisk(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/api/physio/fall-risk/$userId');
      if (response.success && response.data != null) {
        state = state.copyWith(
          fallRisk: FallRisk.fromJson(response.data),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadSessions(String userId, {int limit = 5}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/api/physio/sessions/$userId', 
          queryParams: {'limit': limit});
      if (response.success && response.data != null) {
        final sessionList = (response.data['sessions'] as List)
            .map((s) => PhysioSession.fromJson(s))
            .toList();
        state = state.copyWith(sessions: sessionList, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============= Providers =============

final physioProvider = StateNotifierProvider<PhysioNotifier, PhysioState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return PhysioNotifier(api);
});

// Simple providers for individual data
final fallRiskProvider = FutureProvider.family<FallRisk?, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/physio/fall-risk/$userId');
  if (response.success && response.data != null) {
    return FallRisk.fromJson(response.data);
  }
  return null;
});

final exercisesProvider = FutureProvider.family<List<Exercise>, String?>((ref, category) async {
  final api = ref.watch(apiServiceProvider);
  final params = category != null && category != 'All' ? {'category': category} : null;
  final response = await api.get('/api/physio/exercises', queryParams: params);
  if (response.success && response.data != null) {
    return (response.data['exercises'] as List).map((e) => Exercise.fromJson(e)).toList();
  }
  return [];
});
