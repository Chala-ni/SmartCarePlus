/// SMARTCARE+ Connection Provider
///
/// Manages connections between elderly and guardians/caregivers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

// ============================================
// Models
// ============================================

class ConnectionInfo {
  final String id;
  final String elderlyId;
  final String elderlyName;
  final String linkedUserId;
  final String linkedUserName;
  final String connectionType;
  final String status;
  final String createdAt;

  ConnectionInfo({
    required this.id,
    required this.elderlyId,
    required this.elderlyName,
    required this.linkedUserId,
    required this.linkedUserName,
    required this.connectionType,
    required this.status,
    required this.createdAt,
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      id: json['id'] ?? '',
      elderlyId: json['elderly_id'] ?? '',
      elderlyName: json['elderly_name'] ?? '',
      linkedUserId: json['linked_user_id'] ?? '',
      linkedUserName: json['linked_user_name'] ?? '',
      connectionType: json['connection_type'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class InviteCodeInfo {
  final String code;
  final String expiresAt;
  final String message;

  InviteCodeInfo({
    required this.code,
    required this.expiresAt,
    required this.message,
  });

  factory InviteCodeInfo.fromJson(Map<String, dynamic> json) {
    return InviteCodeInfo(
      code: json['code'] ?? '',
      expiresAt: json['expires_at'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class ElderlyInfo {
  final String id;
  final String name;
  final String connectionType;
  final String connectedAt;

  ElderlyInfo({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.connectedAt,
  });

  factory ElderlyInfo.fromJson(Map<String, dynamic> json) {
    return ElderlyInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      connectionType: json['connection_type'] ?? '',
      connectedAt: json['connected_at'] ?? '',
    );
  }
}

class CaregiverInfo {
  final String id;
  final String name;
  final String connectionType;
  final String connectedAt;

  CaregiverInfo({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.connectedAt,
  });

  factory CaregiverInfo.fromJson(Map<String, dynamic> json) {
    return CaregiverInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      connectionType: json['connection_type'] ?? json['type'] ?? '',
      connectedAt: json['connected_at'] ?? '',
    );
  }
}

// ============================================
// State
// ============================================

class ConnectionServiceState {
  final bool isLoading;
  final String? error;
  final List<ConnectionInfo> connections;
  final List<ElderlyInfo> linkedElderly;
  final List<CaregiverInfo> linkedCaregivers;
  final InviteCodeInfo? activeInviteCode;

  const ConnectionServiceState({
    this.isLoading = false,
    this.error,
    this.connections = const [],
    this.linkedElderly = const [],
    this.linkedCaregivers = const [],
    this.activeInviteCode,
  });
  
  // Convenience getters
  List<ElderlyInfo> get myElderly => linkedElderly;
  List<CaregiverInfo> get myCaregivers => linkedCaregivers;

  ConnectionServiceState copyWith({
    bool? isLoading,
    String? error,
    List<ConnectionInfo>? connections,
    List<ElderlyInfo>? linkedElderly,
    List<CaregiverInfo>? linkedCaregivers,
    InviteCodeInfo? activeInviteCode,
  }) {
    return ConnectionServiceState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      connections: connections ?? this.connections,
      linkedElderly: linkedElderly ?? this.linkedElderly,
      linkedCaregivers: linkedCaregivers ?? this.linkedCaregivers,
      activeInviteCode: activeInviteCode ?? this.activeInviteCode,
    );
  }
}

// ============================================
// Notifier
// ============================================

class ConnectionNotifier extends StateNotifier<ConnectionServiceState> {
  final ApiService _api;
  final UserProfile? _profile;

  ConnectionNotifier(this._api, this._profile) : super(const ConnectionServiceState());

  /// Generate a new invite code
  Future<InviteCodeInfo?> generateInviteCode() async {
    AppLogger.connection('Generating invite code...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      AppLogger.api('POST', '/api/connections/generate-code');
      final response = await _api.post('/api/connections/generate-code', body: {});
      AppLogger.api('POST', '/api/connections/generate-code', 
          statusCode: response.statusCode, 
          data: response.success ? 'success' : response.error);

      if (response.success && response.data != null) {
        final inviteCode = InviteCodeInfo.fromJson(response.data);
        AppLogger.connection('Code generated: ${inviteCode.code}');
        state = state.copyWith(isLoading: false, activeInviteCode: inviteCode);
        return inviteCode;
      } else {
        // If server fails, generate a mock code for demo purposes
        if (response.statusCode == 0) {
          // Network error - use mock data
          AppLogger.warning('Network error (statusCode=0), using mock code', tag: 'CONNECT');
          final mockCode = _generateMockCode();
          final mockInvite = InviteCodeInfo(
            code: mockCode,
            expiresAt: DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
            message: 'Share this code with your caregiver (Demo Mode)',
          );
          state = state.copyWith(isLoading: false, activeInviteCode: mockInvite);
          return mockInvite;
        }
        AppLogger.error('Failed to generate code: ${response.error}', tag: 'CONNECT');
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to generate invite code',
        );
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Exception generating code: $e', tag: 'CONNECT', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Error: $e');
      return null;
    }
  }
  
  String _generateMockCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(random + i * 7) % chars.length];
    }
    return code;
  }

  /// Join using an invite code
  Future<bool> joinWithCode(String code) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.post('/api/connections/join', body: {
        'invite_code': code.toUpperCase().trim(),
      });

      if (response.success) {
        // Refresh connections
        await loadConnections();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to join with invite code',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error: $e');
      return false;
    }
  }

  /// Load all connections
  Future<void> loadConnections() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get('/api/connections/my-connections');

      if (response.success && response.data != null) {
        final connectionsList = (response.data['connections'] as List?)
            ?.map((c) => ConnectionInfo.fromJson(c))
            .toList() ?? [];

        state = state.copyWith(isLoading: false, connections: connectionsList);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error: $e');
    }
  }

  /// Load elderly users (for guardians/caregivers)
  Future<void> loadMyElderly() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get('/api/connections/my-elderly');

      if (response.success && response.data != null) {
        final elderlyList = (response.data['elderly'] as List?)
            ?.map((e) => ElderlyInfo.fromJson(e))
            .toList() ?? [];

        state = state.copyWith(isLoading: false, linkedElderly: elderlyList);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error: $e');
    }
  }

  /// Load caregivers (for elderly users)
  Future<void> loadMyCaregivers() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get('/api/connections/my-caregivers');

      if (response.success && response.data != null) {
        final caregiverList = (response.data['caregivers'] as List?)
            ?.map((c) => CaregiverInfo.fromJson(c))
            .toList() ?? [];

        state = state.copyWith(isLoading: false, linkedCaregivers: caregiverList);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error: $e');
    }
  }

  /// Remove a connection
  Future<bool> removeConnection(String connectionId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.delete('/api/connections/$connectionId');

      if (response.success) {
        // Remove from local state
        final updatedConnections = state.connections
            .where((c) => c.id != connectionId)
            .toList();
        state = state.copyWith(isLoading: false, connections: updatedConnections);
        
        // Reload relevant lists
        if (_profile?.isElderly == true) {
          await loadMyCaregivers();
        } else {
          await loadMyElderly();
        }
        
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to remove connection',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error: $e');
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============================================
// Providers
// ============================================

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionServiceState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final profile = ref.watch(userProfileProvider);
  return ConnectionNotifier(api, profile);
});

/// Convenience provider for linked elderly
final linkedElderlyProvider = Provider<List<ElderlyInfo>>((ref) {
  return ref.watch(connectionProvider).linkedElderly;
});

/// Convenience provider for linked caregivers
final linkedCaregiversProvider = Provider<List<CaregiverInfo>>((ref) {
  return ref.watch(connectionProvider).linkedCaregivers;
});
