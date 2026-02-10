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

// ============= Patient Profile Models =============

/// BMI calculation result from backend
class BMIResult {
  final double bmi;
  final String category;
  final String healthRisk;
  final String weightStatus;
  final List<String> recommendations;

  BMIResult({
    required this.bmi,
    required this.category,
    required this.healthRisk,
    required this.weightStatus,
    required this.recommendations,
  });

  factory BMIResult.fromJson(Map<String, dynamic> json) {
    return BMIResult(
      bmi: (json['bmi'] ?? 0).toDouble(),
      category: json['category'] ?? 'unknown',
      healthRisk: json['health_risk'] ?? 'Unknown',
      weightStatus: json['weight_status'] ?? 'Unknown',
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }

  String get displayCategory {
    switch (category) {
      case 'underweight': return 'Underweight';
      case 'normal': return 'Normal';
      case 'overweight': return 'Overweight';
      case 'obese_class_1': return 'Obese I';
      case 'obese_class_2': return 'Obese II';
      case 'obese_class_3': return 'Obese III';
      default: return category;
    }
  }
}

/// Affected joint information
class AffectedJoint {
  final String location;
  final String severity;
  final int painLevel;
  final DateTime? diagnosedDate;

  AffectedJoint({
    required this.location,
    required this.severity,
    this.painLevel = 0,
    this.diagnosedDate,
  });

  factory AffectedJoint.fromJson(Map<String, dynamic> json) {
    return AffectedJoint(
      location: json['location'] ?? '',
      severity: json['severity'] ?? 'none',
      painLevel: json['pain_level'] ?? 0,
      diagnosedDate: json['diagnosed_date'] != null 
          ? DateTime.tryParse(json['diagnosed_date']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'severity': severity,
      'pain_level': painLevel,
    };
  }
}

/// Patient medical history
class MedicalHistory {
  final String arthritisType;
  final String arthritisSeverity;
  final List<AffectedJoint> affectedJoints;
  final bool hasOsteoporosis;
  final bool hasCardiovascularIssues;
  final bool hasBalanceIssues;
  final int fallsLastYear;
  final bool fearOfFalling;
  final List<String> otherConditions;
  final List<String> medications;

  MedicalHistory({
    required this.arthritisType,
    required this.arthritisSeverity,
    required this.affectedJoints,
    this.hasOsteoporosis = false,
    this.hasCardiovascularIssues = false,
    this.hasBalanceIssues = false,
    this.fallsLastYear = 0,
    this.fearOfFalling = false,
    this.otherConditions = const [],
    this.medications = const [],
  });

  factory MedicalHistory.fromJson(Map<String, dynamic> json) {
    return MedicalHistory(
      arthritisType: json['arthritis_type'] ?? 'none',
      arthritisSeverity: json['arthritis_severity'] ?? 'none',
      affectedJoints: (json['affected_joints'] as List?)
          ?.map((j) => AffectedJoint.fromJson(j))
          .toList() ?? [],
      hasOsteoporosis: json['has_osteoporosis'] ?? false,
      hasCardiovascularIssues: json['has_cardiovascular_issues'] ?? false,
      hasBalanceIssues: json['has_balance_issues'] ?? false,
      fallsLastYear: json['falls_last_year'] ?? 0,
      fearOfFalling: json['fear_of_falling'] ?? false,
      otherConditions: List<String>.from(json['other_conditions'] ?? []),
      medications: List<String>.from(json['medications'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'arthritis_type': arthritisType,
      'arthritis_severity': arthritisSeverity,
      'affected_joints': affectedJoints.map((j) => j.toJson()).toList(),
      'has_osteoporosis': hasOsteoporosis,
      'has_cardiovascular_issues': hasCardiovascularIssues,
      'has_balance_issues': hasBalanceIssues,
      'falls_last_year': fallsLastYear,
      'fear_of_falling': fearOfFalling,
    };
  }
}

/// Lifestyle factors for exercise planning
class LifestyleFactors {
  final String activityLevel;
  final String mobilityLevel;
  final bool hasChairForSupport;
  final bool hasWallForSupport;
  final bool livesAlone;

  LifestyleFactors({
    this.activityLevel = 'lightly_active',
    this.mobilityLevel = 'independent',
    this.hasChairForSupport = true,
    this.hasWallForSupport = true,
    this.livesAlone = false,
  });

  factory LifestyleFactors.fromJson(Map<String, dynamic> json) {
    return LifestyleFactors(
      activityLevel: json['activity_level'] ?? 'lightly_active',
      mobilityLevel: json['mobility_level'] ?? 'independent',
      hasChairForSupport: json['has_chair_for_support'] ?? true,
      hasWallForSupport: json['has_wall_for_support'] ?? true,
      livesAlone: json['lives_alone'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activity_level': activityLevel,
      'mobility_level': mobilityLevel,
      'has_chair_for_support': hasChairForSupport,
      'has_wall_for_support': hasWallForSupport,
      'lives_alone': livesAlone,
    };
  }
}

/// Patient profile from backend
class PatientProfile {
  final String? firstName;
  final String? lastName;
  final String? dateOfBirth;
  final int age;
  final String? gender;
  final double heightCm;
  final double weightKg;
  final String mobilityLevel;
  final String activityLevel;
  final MedicalHistory? medicalHistory;
  final LifestyleFactors? lifestyle;
  final String painTolerance;
  final int baselinePainLevel;
  final int baselineFatigueLevel;
  final int baselineMobilityScore;
  final String primaryGoal;
  final List<String> secondaryGoals;
  final bool profileComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PatientProfile({
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    required this.age,
    this.gender,
    required this.heightCm,
    required this.weightKg,
    this.mobilityLevel = 'independent',
    this.activityLevel = 'lightly_active',
    this.medicalHistory,
    this.lifestyle,
    this.painTolerance = 'moderate',
    this.baselinePainLevel = 0,
    this.baselineFatigueLevel = 0,
    this.baselineMobilityScore = 50,
    this.primaryGoal = 'maintain_mobility',
    this.secondaryGoals = const [],
    this.profileComplete = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Helper getter for display name
  String get name => [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      firstName: json['first_name'],
      lastName: json['last_name'],
      dateOfBirth: json['date_of_birth'],
      age: json['age'] ?? 0,
      gender: json['gender'],
      heightCm: (json['height_cm'] ?? 0).toDouble(),
      weightKg: (json['weight_kg'] ?? 0).toDouble(),
      mobilityLevel: json['mobility_level'] ?? 'independent',
      activityLevel: json['activity_level'] ?? 'lightly_active',
      medicalHistory: json['medical_history'] != null
          ? MedicalHistory.fromJson(json['medical_history'])
          : null,
      lifestyle: json['lifestyle'] != null
          ? LifestyleFactors.fromJson(json['lifestyle'])
          : null,
      painTolerance: json['pain_tolerance'] ?? 'moderate',
      baselinePainLevel: json['baseline_pain_level'] ?? 0,
      baselineFatigueLevel: json['baseline_fatigue_level'] ?? 0,
      baselineMobilityScore: json['baseline_mobility_score'] ?? 50,
      primaryGoal: json['primary_goal'] ?? 'maintain_mobility',
      secondaryGoals: List<String>.from(json['secondary_goals'] ?? []),
      profileComplete: json['profile_complete'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (gender != null) 'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'pain_tolerance': painTolerance,
      'baseline_pain_level': baselinePainLevel,
      'baseline_fatigue_level': baselineFatigueLevel,
      'baseline_mobility_score': baselineMobilityScore,
      'primary_goal': primaryGoal,
      if (secondaryGoals.isNotEmpty) 'secondary_goals': secondaryGoals,
      if (medicalHistory != null) 'medical_history': medicalHistory!.toJson(),
      if (lifestyle != null) 'lifestyle': lifestyle!.toJson(),
    };
  }
}

// ============= Exercise Plan Models =============

/// A single exercise in a personalized plan
class PlannedExercise {
  final String exerciseId;
  final String name;
  final String description;
  final String category;
  final String difficulty;
  final int prescribedReps;
  final int prescribedSets;
  final int holdSeconds;
  final int restSeconds;
  final bool requiresChair;
  final bool requiresWall;
  final bool requiresStanding;
  final List<String> instructions;
  final List<String> benefits;
  final String? videoId;
  final String notes;
  final int order;
  final bool adapted;
  final String adaptationReason;

  PlannedExercise({
    required this.exerciseId,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.prescribedReps,
    required this.prescribedSets,
    required this.holdSeconds,
    required this.restSeconds,
    required this.requiresChair,
    required this.requiresWall,
    required this.requiresStanding,
    required this.instructions,
    required this.benefits,
    this.videoId,
    required this.notes,
    required this.order,
    required this.adapted,
    required this.adaptationReason,
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      exerciseId: json['exercise_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? '',
      prescribedReps: json['prescribed_reps'] ?? 10,
      prescribedSets: json['prescribed_sets'] ?? 2,
      holdSeconds: json['hold_seconds'] ?? 0,
      restSeconds: json['rest_seconds'] ?? 30,
      requiresChair: json['requires_chair'] ?? false,
      requiresWall: json['requires_wall'] ?? false,
      requiresStanding: json['requires_standing'] ?? false,
      instructions: List<String>.from(json['instructions'] ?? []),
      benefits: List<String>.from(json['benefits'] ?? []),
      videoId: json['video_id'],
      notes: json['notes'] ?? '',
      order: json['order'] ?? 0,
      adapted: json['adapted'] ?? false,
      adaptationReason: json['adaptation_reason'] ?? '',
    );
  }

  /// Estimated duration for this exercise in minutes
  int get estimatedMinutes {
    int setsTime = (prescribedReps * 3 * prescribedSets); // ~3 sec per rep
    int restTime = (prescribedSets - 1) * restSeconds;
    int holdTime = holdSeconds * prescribedSets;
    return ((setsTime + restTime + holdTime) / 60).ceil();
  }

  /// Display-friendly duration string
  String get durationDisplay {
    final mins = estimatedMinutes;
    return mins <= 1 ? '1 min' : '$mins min';
  }
}

/// Complete daily exercise plan from backend
class DailyExercisePlan {
  final String planId;
  final String userId;
  final DateTime date;
  final DateTime createdAt;
  final List<PlannedExercise> exercises;
  final int exerciseCount;
  final int totalDurationMinutes;
  final String difficultyLevel;
  final List<String> focusAreas;
  final bool basedOnProfile;
  final bool adaptedForPain;
  final String painAdaptationNotes;
  final List<String> additionalNotes;
  final bool completed;
  final DateTime? completedAt;
  final String? completionFeedback;
  final List<String> completedExercises;

  DailyExercisePlan({
    required this.planId,
    required this.userId,
    required this.date,
    required this.createdAt,
    required this.exercises,
    required this.exerciseCount,
    required this.totalDurationMinutes,
    required this.difficultyLevel,
    required this.focusAreas,
    required this.basedOnProfile,
    required this.adaptedForPain,
    required this.painAdaptationNotes,
    required this.additionalNotes,
    required this.completed,
    this.completedAt,
    this.completionFeedback,
    this.completedExercises = const [],
  });

  factory DailyExercisePlan.fromJson(Map<String, dynamic> json) {
    return DailyExercisePlan(
      planId: json['plan_id'] ?? '',
      userId: json['user_id'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      exercises: (json['exercises'] as List?)
          ?.map((e) => PlannedExercise.fromJson(e))
          .toList() ?? [],
      exerciseCount: json['exercise_count'] ?? 0,
      totalDurationMinutes: json['total_duration_minutes'] ?? 0,
      difficultyLevel: json['difficulty_level'] ?? 'easy',
      focusAreas: List<String>.from(json['focus_areas'] ?? []),
      basedOnProfile: json['based_on_profile'] ?? false,
      adaptedForPain: json['adapted_for_pain'] ?? false,
      painAdaptationNotes: json['pain_adaptation_notes'] ?? '',
      additionalNotes: List<String>.from(json['additional_notes'] ?? []),
      completed: json['completed'] ?? false,
      completedAt: json['completed_at'] != null 
          ? DateTime.tryParse(json['completed_at']) 
          : null,
      completionFeedback: json['completion_feedback'],
      completedExercises: List<String>.from(json['completed_exercises'] ?? []),
    );
  }

  /// Get display-friendly difficulty
  String get difficultyDisplay {
    switch (difficultyLevel) {
      case 'very_easy': return 'Very Easy';
      case 'easy': return 'Easy';
      case 'moderate': return 'Moderate';
      case 'challenging': return 'Challenging';
      default: return difficultyLevel;
    }
  }

  /// Check if a specific exercise is completed
  bool isExerciseCompleted(String exerciseId) {
    return completedExercises.contains(exerciseId);
  }

  /// Get completed exercise count
  int get completedExerciseCount {
    return completedExercises.length;
  }

  /// Progress as fraction (0.0 - 1.0)
  double get progress {
    if (exerciseCount == 0) return 0;
    return completedExerciseCount / exerciseCount;
  }

  /// Create a copy with updated completed exercises
  DailyExercisePlan copyWithCompletedExercise(String exerciseId) {
    final updatedList = [...completedExercises];
    if (!updatedList.contains(exerciseId)) {
      updatedList.add(exerciseId);
    }
    final allDone = updatedList.length >= exerciseCount;
    return DailyExercisePlan(
      planId: planId,
      userId: userId,
      date: date,
      createdAt: createdAt,
      exercises: exercises,
      exerciseCount: exerciseCount,
      totalDurationMinutes: totalDurationMinutes,
      difficultyLevel: difficultyLevel,
      focusAreas: focusAreas,
      basedOnProfile: basedOnProfile,
      adaptedForPain: adaptedForPain,
      painAdaptationNotes: painAdaptationNotes,
      additionalNotes: additionalNotes,
      completed: allDone,
      completedAt: allDone ? DateTime.now() : completedAt,
      completionFeedback: completionFeedback,
      completedExercises: updatedList,
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

/// Scheduled exercise with status tracking
class ScheduledExercise {
  final String id;
  final String exerciseId;
  final String name;
  final DateTime scheduledDate;
  final String scheduledTime;
  final String duration;
  final String difficulty;
  final ScheduleStatus status;
  final DateTime? completedAt;

  ScheduledExercise({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.duration,
    required this.difficulty,
    this.status = ScheduleStatus.upcoming,
    this.completedAt,
  });

  factory ScheduledExercise.fromJson(Map<String, dynamic> json) {
    return ScheduledExercise(
      id: json['id'] ?? '',
      exerciseId: json['exercise_id'] ?? '',
      name: json['name'] ?? '',
      scheduledDate: DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now(),
      scheduledTime: json['scheduled_time'] ?? '',
      duration: json['duration'] ?? '',
      difficulty: json['difficulty'] ?? '',
      status: ScheduleStatus.fromString(json['status'] ?? 'upcoming'),
      completedAt: json['completed_at'] != null 
          ? DateTime.tryParse(json['completed_at']) 
          : null,
    );
  }

  ScheduledExercise copyWith({
    ScheduleStatus? status,
    DateTime? completedAt,
  }) {
    return ScheduledExercise(
      id: id,
      exerciseId: exerciseId,
      name: name,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      duration: duration,
      difficulty: difficulty,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

enum ScheduleStatus {
  upcoming,
  inProgress,
  completed,
  missed,
  rescheduled;

  static ScheduleStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
        return ScheduleStatus.completed;
      case 'missed':
        return ScheduleStatus.missed;
      case 'in_progress':
      case 'inprogress':
        return ScheduleStatus.inProgress;
      case 'rescheduled':
        return ScheduleStatus.rescheduled;
      default:
        return ScheduleStatus.upcoming;
    }
  }
}

/// Exercise compliance tracking
class ExerciseCompliance {
  final int totalScheduled;
  final int completed;
  final int missed;
  final double complianceRate;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastExerciseDate;

  ExerciseCompliance({
    required this.totalScheduled,
    required this.completed,
    required this.missed,
    required this.complianceRate,
    required this.currentStreak,
    required this.longestStreak,
    this.lastExerciseDate,
  });

  factory ExerciseCompliance.fromJson(Map<String, dynamic> json) {
    return ExerciseCompliance(
      totalScheduled: json['total_scheduled'] ?? 0,
      completed: json['completed'] ?? 0,
      missed: json['missed'] ?? 0,
      complianceRate: (json['compliance_rate'] ?? 0).toDouble(),
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      lastExerciseDate: json['last_exercise_date'] != null
          ? DateTime.tryParse(json['last_exercise_date'])
          : null,
    );
  }

  /// Create default/mock compliance data
  factory ExerciseCompliance.mock() {
    return ExerciseCompliance(
      totalScheduled: 28,
      completed: 22,
      missed: 4,
      complianceRate: 78.6,
      currentStreak: 3,
      longestStreak: 7,
      lastExerciseDate: DateTime.now().subtract(const Duration(days: 1)),
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
  final List<ScheduledExercise> todaySchedule;
  final ExerciseCompliance? compliance;
  // New fields for patient profile & exercise plans
  final PatientProfile? patientProfile;
  final BMIResult? bmiResult;
  final DailyExercisePlan? todayPlan;
  final bool isLoading;
  final String? error;

  const PhysioState({
    this.exercises = const [],
    this.prescribedExercises = const [],
    this.fallRisk,
    this.gaitMetrics,
    this.sessions = const [],
    this.todaySchedule = const [],
    this.compliance,
    this.patientProfile,
    this.bmiResult,
    this.todayPlan,
    this.isLoading = false,
    this.error,
  });

  /// Get missed exercises from today's schedule
  List<ScheduledExercise> get missedExercises =>
      todaySchedule.where((e) => e.status == ScheduleStatus.missed).toList();

  /// Get upcoming exercises from today's schedule
  List<ScheduledExercise> get upcomingExercises =>
      todaySchedule.where((e) => e.status == ScheduleStatus.upcoming).toList();

  /// Get completed exercises from today's schedule
  List<ScheduledExercise> get completedExercises =>
      todaySchedule.where((e) => e.status == ScheduleStatus.completed).toList();

  PhysioState copyWith({
    List<Exercise>? exercises,
    List<Exercise>? prescribedExercises,
    FallRisk? fallRisk,
    GaitMetrics? gaitMetrics,
    List<PhysioSession>? sessions,
    List<ScheduledExercise>? todaySchedule,
    ExerciseCompliance? compliance,
    PatientProfile? patientProfile,
    BMIResult? bmiResult,
    DailyExercisePlan? todayPlan,
    bool? isLoading,
    String? error,
  }) {
    return PhysioState(
      exercises: exercises ?? this.exercises,
      prescribedExercises: prescribedExercises ?? this.prescribedExercises,
      fallRisk: fallRisk ?? this.fallRisk,
      gaitMetrics: gaitMetrics ?? this.gaitMetrics,
      sessions: sessions ?? this.sessions,
      todaySchedule: todaySchedule ?? this.todaySchedule,
      compliance: compliance ?? this.compliance,
      patientProfile: patientProfile ?? this.patientProfile,
      bmiResult: bmiResult ?? this.bmiResult,
      todayPlan: todayPlan ?? this.todayPlan,
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

  /// Load exercise schedule for a specific date
  Future<void> loadSchedule(String userId, {DateTime? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    final targetDate = date ?? DateTime.now();
    
    try {
      final response = await _api.get('/api/physio/schedule/$userId', 
          queryParams: {'date': targetDate.toIso8601String().split('T')[0]});
      if (response.success && response.data != null) {
        final scheduleList = (response.data['schedule'] as List)
            .map((s) => ScheduledExercise.fromJson(s))
            .toList();
        state = state.copyWith(todaySchedule: scheduleList, isLoading: false);
      } else {
        // Load mock data for demo
        _loadMockSchedule();
      }
    } catch (e) {
      // Load mock data for demo
      _loadMockSchedule();
    }
  }

  /// Load compliance statistics
  Future<void> loadCompliance(String userId) async {
    try {
      final response = await _api.get('/api/physio/compliance/$userId');
      if (response.success && response.data != null) {
        state = state.copyWith(
          compliance: ExerciseCompliance.fromJson(response.data),
        );
      } else {
        // Use mock data for demo
        state = state.copyWith(compliance: ExerciseCompliance.mock());
      }
    } catch (e) {
      // Use mock data for demo
      state = state.copyWith(compliance: ExerciseCompliance.mock());
    }
  }

  /// Mark an exercise as completed
  Future<void> completeExercise(String scheduleId) async {
    try {
      final response = await _api.post('/api/physio/schedule/$scheduleId/complete');
      if (response.success) {
        // Update local state
        final updated = state.todaySchedule.map((e) {
          if (e.id == scheduleId) {
            return e.copyWith(
              status: ScheduleStatus.completed,
              completedAt: DateTime.now(),
            );
          }
          return e;
        }).toList();
        state = state.copyWith(todaySchedule: updated);
      }
    } catch (e) {
      // Still update locally for demo
      final updated = state.todaySchedule.map((e) {
        if (e.id == scheduleId) {
          return e.copyWith(
            status: ScheduleStatus.completed,
            completedAt: DateTime.now(),
          );
        }
        return e;
      }).toList();
      state = state.copyWith(todaySchedule: updated);
    }
  }

  /// Reschedule an exercise
  Future<void> rescheduleExercise(String scheduleId, DateTime newTime) async {
    try {
      await _api.post('/api/physio/schedule/$scheduleId/reschedule', body: {
        'new_time': newTime.toIso8601String(),
      });
      // Update local state
      final updated = state.todaySchedule.map((e) {
        if (e.id == scheduleId) {
          return e.copyWith(status: ScheduleStatus.rescheduled);
        }
        return e;
      }).toList();
      state = state.copyWith(todaySchedule: updated);
    } catch (e) {
      state = state.copyWith(error: 'Failed to reschedule exercise');
    }
  }

  /// Load mock schedule data for demo
  void _loadMockSchedule() {
    final now = DateTime.now();
    final mockSchedule = [
      ScheduledExercise(
        id: '1',
        exerciseId: 'ex1',
        name: 'Morning Stretches',
        scheduledDate: now,
        scheduledTime: '7:00 AM',
        duration: '10 min',
        difficulty: 'Easy',
        status: ScheduleStatus.completed,
        completedAt: now.subtract(const Duration(hours: 5)),
      ),
      ScheduledExercise(
        id: '2',
        exerciseId: 'ex2',
        name: 'Chair Stand Exercise',
        scheduledDate: now,
        scheduledTime: '9:00 AM',
        duration: '15 min',
        difficulty: 'Easy',
        status: ScheduleStatus.missed,
      ),
      ScheduledExercise(
        id: '3',
        exerciseId: 'ex3',
        name: 'Balance Training',
        scheduledDate: now,
        scheduledTime: '11:00 AM',
        duration: '10 min',
        difficulty: 'Medium',
        status: ScheduleStatus.missed,
      ),
      ScheduledExercise(
        id: '4',
        exerciseId: 'ex4',
        name: 'Heel-to-Toe Walk',
        scheduledDate: now,
        scheduledTime: '2:00 PM',
        duration: '10 min',
        difficulty: 'Medium',
        status: ScheduleStatus.upcoming,
      ),
      ScheduledExercise(
        id: '5',
        exerciseId: 'ex5',
        name: 'Evening Stretches',
        scheduledDate: now,
        scheduledTime: '6:00 PM',
        duration: '10 min',
        difficulty: 'Easy',
        status: ScheduleStatus.upcoming,
      ),
    ];
    state = state.copyWith(todaySchedule: mockSchedule, isLoading: false);
  }

  // ============= Patient Profile & Exercise Plan Methods =============

  /// Load patient profile from backend
  Future<void> loadPatientProfile(String userId) async {
    try {
      final response = await _api.get('/api/physio/profile/$userId');
      if (response.success && response.data != null) {
        if (response.data['exists'] == true && response.data['profile'] != null) {
          state = state.copyWith(
            patientProfile: PatientProfile.fromJson(response.data['profile']),
          );
        }
      }
    } catch (e) {
      // Profile not critical for app to work
    }
  }

  /// Create or update patient profile
  Future<bool> updatePatientProfile(String userId, Map<String, dynamic> profileData) async {
    try {
      final response = await _api.post('/api/physio/profile/$userId', body: profileData);
      if (response.success && response.data != null && response.data['profile'] != null) {
        state = state.copyWith(
          patientProfile: PatientProfile.fromJson(response.data['profile']),
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update profile: $e');
      return false;
    }
  }

  /// Load BMI data for user
  Future<void> loadBMI(String userId) async {
    try {
      final response = await _api.get('/api/physio/bmi/$userId');
      if (response.success && response.data != null) {
        state = state.copyWith(
          bmiResult: BMIResult.fromJson(response.data),
        );
      }
    } catch (e) {
      // BMI not critical
    }
  }

  /// Calculate BMI without saving
  Future<BMIResult?> calculateBMI(double weightKg, double heightCm, int age) async {
    try {
      final response = await _api.post('/api/physio/bmi/calculate', body: {
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'age': age,
      });
      if (response.success && response.data != null) {
        return BMIResult.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Load today's exercise plan (creates one if needed)
  Future<void> loadTodayPlan(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/api/physio/plan/today/$userId');
      if (response.success && response.data != null) {
        state = state.copyWith(
          todayPlan: DailyExercisePlan.fromJson(response.data),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load plan: $e');
    }
  }

  /// Generate a new exercise plan (overwrites existing)
  Future<void> generatePlan(String userId, {String? difficulty}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = <String, dynamic>{};
      if (difficulty != null) body['difficulty'] = difficulty;
      
      final response = await _api.post('/api/physio/plan/generate/$userId', body: body);
      if (response.success && response.data != null) {
        state = state.copyWith(
          todayPlan: DailyExercisePlan.fromJson(response.data),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to generate plan: $e');
    }
  }

  /// Mark plan as completed
  Future<void> completePlan(String planId, {String? feedback}) async {
    try {
      final body = feedback != null ? {'feedback': feedback} : null;
      final response = await _api.post('/api/physio/plan/$planId/complete', body: body);
      if (response.success && state.todayPlan?.planId == planId) {
        // Mark all exercises as completed
        final allExerciseIds = state.todayPlan!.exercises
            .map((e) => e.exerciseId)
            .toList();
        // Update local state
        state = state.copyWith(
          todayPlan: DailyExercisePlan(
            planId: state.todayPlan!.planId,
            userId: state.todayPlan!.userId,
            date: state.todayPlan!.date,
            createdAt: state.todayPlan!.createdAt,
            exercises: state.todayPlan!.exercises,
            exerciseCount: state.todayPlan!.exerciseCount,
            totalDurationMinutes: state.todayPlan!.totalDurationMinutes,
            difficultyLevel: state.todayPlan!.difficultyLevel,
            focusAreas: state.todayPlan!.focusAreas,
            basedOnProfile: state.todayPlan!.basedOnProfile,
            adaptedForPain: state.todayPlan!.adaptedForPain,
            painAdaptationNotes: state.todayPlan!.painAdaptationNotes,
            additionalNotes: state.todayPlan!.additionalNotes,
            completed: true,
            completedAt: DateTime.now(),
            completionFeedback: feedback,
            completedExercises: allExerciseIds,
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to complete plan: $e');
    }
  }

  /// Mark a single exercise as completed within the plan
  Future<void> completeExerciseInPlan(String planId, String exerciseId) async {
    try {
      await _api.post('/api/physio/plan/$planId/exercise/$exerciseId/complete');
      // Update local state immediately
      if (state.todayPlan?.planId == planId) {
        state = state.copyWith(
          todayPlan: state.todayPlan!.copyWithCompletedExercise(exerciseId),
        );
      }
    } catch (e) {
      // Still update locally for better UX
      if (state.todayPlan?.planId == planId) {
        state = state.copyWith(
          todayPlan: state.todayPlan!.copyWithCompletedExercise(exerciseId),
        );
      }
    }
  }

  /// Load all data for a user (profile, BMI, today's plan)
  Future<void> loadAllUserData(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        loadPatientProfile(userId),
        loadBMI(userId),
        loadTodayPlan(userId),
        loadCompliance(userId),
      ]);
    } finally {
      state = state.copyWith(isLoading: false);
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

/// Provider for missed exercises - for use in alerts/banners
final missedExercisesProvider = Provider<List<ScheduledExercise>>((ref) {
  final state = ref.watch(physioProvider);
  return state.missedExercises;
});

/// Provider for upcoming exercises  
final upcomingExercisesProvider = Provider<List<ScheduledExercise>>((ref) {
  final state = ref.watch(physioProvider);
  return state.upcomingExercises;
});

/// Provider for compliance statistics
final complianceProvider = Provider<ExerciseCompliance?>((ref) {
  final state = ref.watch(physioProvider);
  return state.compliance;
});

/// Provider for checking if there are any missed exercises
final hasMissedExercisesProvider = Provider<bool>((ref) {
  final missed = ref.watch(missedExercisesProvider);
  return missed.isNotEmpty;
});

// ============= Patient Profile & Plan Providers =============

/// Provider for patient profile from state
final patientProfileProvider = Provider<PatientProfile?>((ref) {
  final state = ref.watch(physioProvider);
  return state.patientProfile;
});

/// Provider for BMI result from state
final bmiResultProvider = Provider<BMIResult?>((ref) {
  final state = ref.watch(physioProvider);
  return state.bmiResult;
});

/// Provider for today's exercise plan from state
final todayPlanProvider = Provider<DailyExercisePlan?>((ref) {
  final state = ref.watch(physioProvider);
  return state.todayPlan;
});

/// Fetch patient profile from API
final fetchPatientProfileProvider = FutureProvider.family<PatientProfile?, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/physio/profile/$userId');
  if (response.success && response.data != null) {
    if (response.data['exists'] == true && response.data['profile'] != null) {
      return PatientProfile.fromJson(response.data['profile']);
    }
  }
  return null;
});

/// Fetch BMI from API
final fetchBMIProvider = FutureProvider.family<BMIResult?, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/physio/bmi/$userId');
  if (response.success && response.data != null) {
    return BMIResult.fromJson(response.data);
  }
  return null;
});

/// Fetch today's exercise plan from API
final fetchTodayPlanProvider = FutureProvider.family<DailyExercisePlan?, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/physio/plan/today/$userId');
  if (response.success && response.data != null) {
    return DailyExercisePlan.fromJson(response.data);
  }
  return null;
});
