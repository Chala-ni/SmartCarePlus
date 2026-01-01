/// SMARTCARE+ Guardian Service Provider
///
/// Owner: Devin
/// Riverpod state management for guardian monitoring features

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

// ============= Models =============

class ElderlyStatus {
  final String elderlyId;
  final String name;
  final int age;
  final String status;
  final String location;
  final String lastActivity;
  final String lastSeen;
  final Map<String, dynamic>? vitals;

  ElderlyStatus({
    required this.elderlyId,
    required this.name,
    required this.age,
    required this.status,
    required this.location,
    required this.lastActivity,
    required this.lastSeen,
    this.vitals,
  });

  factory ElderlyStatus.fromJson(Map<String, dynamic> json) {
    return ElderlyStatus(
      elderlyId: json['elderly_id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      status: json['status'] ?? 'Unknown',
      location: json['location'] ?? '',
      lastActivity: json['last_activity'] ?? '',
      lastSeen: json['last_seen'] ?? '',
      vitals: json['vitals'],
    );
  }
}

enum AlertSeverity { critical, warning, info }
enum AlertType { fall, inactivity, sos, medication, geofence }

class Alert {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String location;
  final String time;
  final bool resolved;
  final String elderlyId;
  final String elderlyName;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.location,
    required this.time,
    required this.resolved,
    required this.elderlyId,
    required this.elderlyName,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] ?? '',
      type: _parseAlertType(json['type']),
      severity: _parseSeverity(json['severity']),
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      time: json['time'] ?? '',
      resolved: json['resolved'] ?? false,
      elderlyId: json['elderly_id'] ?? '',
      elderlyName: json['elderly_name'] ?? '',
    );
  }

  static AlertType _parseAlertType(String? type) {
    switch (type) {
      case 'fall': return AlertType.fall;
      case 'inactivity': return AlertType.inactivity;
      case 'sos': return AlertType.sos;
      case 'medication': return AlertType.medication;
      case 'geofence': return AlertType.geofence;
      default: return AlertType.inactivity;
    }
  }

  static AlertSeverity _parseSeverity(String? severity) {
    switch (severity) {
      case 'critical': return AlertSeverity.critical;
      case 'warning': return AlertSeverity.warning;
      case 'info': return AlertSeverity.info;
      default: return AlertSeverity.info;
    }
  }
}

class Activity {
  final String time;
  final String event;
  final String location;
  final String type;

  Activity({
    required this.time,
    required this.event,
    required this.location,
    required this.type,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      time: json['time'] ?? '',
      event: json['event'] ?? '',
      location: json['location'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class Camera {
  final String id;
  final String name;
  final String location;
  final String status;
  final String videoFile;

  Camera({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.videoFile,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      status: json['status'] ?? 'offline',
      videoFile: json['video_file'] ?? '',
    );
  }

  bool get isOnline => status == 'online';
}

class ActivitySummary {
  final double activeHours;
  final double restHours;
  final int totalEvents;

  ActivitySummary({
    required this.activeHours,
    required this.restHours,
    required this.totalEvents,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      activeHours: (json['active_hours'] ?? 0).toDouble(),
      restHours: (json['rest_hours'] ?? 0).toDouble(),
      totalEvents: json['total_events'] ?? 0,
    );
  }
}

// ============= State =============

class GuardianState {
  final List<ElderlyStatus> elderlyList;
  final List<Alert> alerts;
  final List<Activity> activities;
  final List<Camera> cameras;
  final ActivitySummary? activitySummary;
  final int activeAlertCount;
  final bool isLoading;
  final String? error;

  const GuardianState({
    this.elderlyList = const [],
    this.alerts = const [],
    this.activities = const [],
    this.cameras = const [],
    this.activitySummary,
    this.activeAlertCount = 0,
    this.isLoading = false,
    this.error,
  });

  GuardianState copyWith({
    List<ElderlyStatus>? elderlyList,
    List<Alert>? alerts,
    List<Activity>? activities,
    List<Camera>? cameras,
    ActivitySummary? activitySummary,
    int? activeAlertCount,
    bool? isLoading,
    String? error,
  }) {
    return GuardianState(
      elderlyList: elderlyList ?? this.elderlyList,
      alerts: alerts ?? this.alerts,
      activities: activities ?? this.activities,
      cameras: cameras ?? this.cameras,
      activitySummary: activitySummary ?? this.activitySummary,
      activeAlertCount: activeAlertCount ?? this.activeAlertCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ============= Notifier =============

class GuardianNotifier extends StateNotifier<GuardianState> {
  final ApiService _api;

  GuardianNotifier(this._api) : super(const GuardianState());

  Future<void> loadElderlyList(String? guardianId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = guardianId != null ? {'guardian_id': guardianId} : null;
      final response = await _api.get('/api/guardian/elderly/list', queryParams: params);
      if (response.success && response.data != null) {
        final list = (response.data['elderly'] as List)
            .map((e) => ElderlyStatus.fromJson(e))
            .toList();
        state = state.copyWith(elderlyList: list, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAlerts(String guardianId, {String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = status != null ? {'status': status} : null;
      final response = await _api.get('/api/guardian/alerts/$guardianId', queryParams: params);
      if (response.success && response.data != null) {
        final alertList = (response.data['alerts'] as List)
            .map((a) => Alert.fromJson(a))
            .toList();
        state = state.copyWith(
          alerts: alertList,
          activeAlertCount: response.data['active_count'] ?? 0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadActivityLog(String elderlyId, {String? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = date != null ? {'date': date} : null;
      final response = await _api.get('/api/guardian/activity-log/$elderlyId', queryParams: params);
      if (response.success && response.data != null) {
        final activityList = (response.data['activities'] as List)
            .map((a) => Activity.fromJson(a))
            .toList();
        state = state.copyWith(
          activities: activityList,
          activitySummary: response.data['summary'] != null
              ? ActivitySummary.fromJson(response.data['summary'])
              : null,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadCameras(String? guardianId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = guardianId != null ? {'guardian_id': guardianId} : null;
      final response = await _api.get('/api/guardian/cameras', queryParams: params);
      if (response.success && response.data != null) {
        final cameraList = (response.data['cameras'] as List)
            .map((c) => Camera.fromJson(c))
            .toList();
        state = state.copyWith(cameras: cameraList, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> acknowledgeAlert(String alertId, String action, {String? notes}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.put('/api/guardian/alerts/$alertId/acknowledge', body: {
        'response_action': action,
        'notes': notes,
      });
      // Update local state
      final updatedAlerts = state.alerts.map((a) {
        if (a.id == alertId) {
          return Alert(
            id: a.id,
            type: a.type,
            severity: a.severity,
            title: a.title,
            location: a.location,
            time: a.time,
            resolved: true,
            elderlyId: a.elderlyId,
            elderlyName: a.elderlyName,
          );
        }
        return a;
      }).toList();
      state = state.copyWith(
        alerts: updatedAlerts,
        activeAlertCount: state.activeAlertCount - 1,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> triggerSOS(String elderlyId, {String? message}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post('/api/guardian/sos', body: {
        'elderly_id': elderlyId,
        'message': message,
      });
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============= Providers =============

final guardianProvider = StateNotifierProvider<GuardianNotifier, GuardianState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return GuardianNotifier(api);
});

final alertsProvider = FutureProvider.family<List<Alert>, String>((ref, guardianId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/guardian/alerts/$guardianId');
  if (response.success && response.data != null) {
    return (response.data['alerts'] as List).map((a) => Alert.fromJson(a)).toList();
  }
  return [];
});

final elderlyStatusProvider = FutureProvider.family<ElderlyStatus?, String>((ref, elderlyId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/guardian/elderly/$elderlyId/status');
  if (response.success && response.data != null) {
    return ElderlyStatus.fromJson(response.data);
  }
  return null;
});

final camerasProvider = FutureProvider<List<Camera>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/api/guardian/cameras');
  if (response.success && response.data != null) {
    return (response.data['cameras'] as List).map((c) => Camera.fromJson(c)).toList();
  }
  return [];
});
