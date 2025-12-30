/// SMARTCARE+ WebSocket Service
///
/// Real-time connection manager with auto-reconnect for video streaming
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/auth_provider.dart';

/// WebSocket message types (matches backend)
enum WSMessageType {
  ping,
  pong,
  auth,
  authSuccess,
  authFailed,
  error,
  videoFrame,
  frameProcessed,
  gaitUpdate,
  poseUpdate,
  exerciseUpdate,
  fallDetected,
  sosAlert,
  geofenceBreach,
  statusUpdate,
  notification,
  data,
}

/// WebSocket message
class WSMessage {
  final WSMessageType type;
  final dynamic payload;
  final DateTime timestamp;

  WSMessage({
    required this.type,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    return WSMessage(
      type: WSMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => WSMessageType.data,
      ),
      payload: json['payload'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());
}

/// WebSocket connection state
enum WSConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket state
class WebSocketState {
  final WSConnectionState connectionState;
  final String? error;
  final int reconnectAttempts;
  final DateTime? lastConnected;

  const WebSocketState({
    this.connectionState = WSConnectionState.disconnected,
    this.error,
    this.reconnectAttempts = 0,
    this.lastConnected,
  });

  bool get isConnected => connectionState == WSConnectionState.connected;
  bool get isConnecting => connectionState == WSConnectionState.connecting ||
      connectionState == WSConnectionState.reconnecting;

  WebSocketState copyWith({
    WSConnectionState? connectionState,
    String? error,
    int? reconnectAttempts,
    DateTime? lastConnected,
  }) {
    return WebSocketState(
      connectionState: connectionState ?? this.connectionState,
      error: error,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}

/// WebSocket service for real-time communication
class WebSocketService extends StateNotifier<WebSocketState> {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  
  // Configuration
  static const String _baseUrl = 'ws://localhost:8000';
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 10;
  
  // Message handlers
  final Map<WSMessageType, List<void Function(WSMessage)>> _handlers = {};
  
  // Stream controller for all messages
  final _messageController = StreamController<WSMessage>.broadcast();
  Stream<WSMessage> get messages => _messageController.stream;

  WebSocketService(this._ref) : super(const WebSocketState());

  /// Connect to WebSocket endpoint
  Future<bool> connect(String endpoint) async {
    if (state.isConnected) {
      return true;
    }

    state = state.copyWith(connectionState: WSConnectionState.connecting);

    try {
      // Get auth token
      final authState = _ref.read(authProvider);
      final token = await authState.firebaseUser?.getIdToken();
      
      // Build URL with auth
      final url = Uri.parse('$_baseUrl$endpoint');
      
      // Create connection
      _channel = WebSocketChannel.connect(
        url,
        protocols: token != null ? ['Bearer', token] : null,
      );

      // Listen for messages
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Start ping timer
      _startPingTimer();

      state = state.copyWith(
        connectionState: WSConnectionState.connected,
        lastConnected: DateTime.now(),
        reconnectAttempts: 0,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        connectionState: WSConnectionState.error,
        error: 'Connection failed: $e',
      );
      _scheduleReconnect(endpoint);
      return false;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _stopPingTimer();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    state = const WebSocketState();
  }

  /// Send a message
  bool send(WSMessage message) {
    if (!state.isConnected || _channel == null) {
      return false;
    }

    try {
      _channel!.sink.add(message.toJsonString());
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Send failed: $e');
      return false;
    }
  }

  /// Send raw data (for video frames)
  bool sendRaw(dynamic data) {
    if (!state.isConnected || _channel == null) {
      return false;
    }

    try {
      _channel!.sink.add(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Register a message handler
  void on(WSMessageType type, void Function(WSMessage) handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }

  /// Remove a message handler
  void off(WSMessageType type, void Function(WSMessage) handler) {
    _handlers[type]?.remove(handler);
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final message = WSMessage.fromJson(json);
      
      // Handle pong
      if (message.type == WSMessageType.pong) {
        return;
      }

      // Broadcast to stream
      _messageController.add(message);

      // Call registered handlers
      final handlers = _handlers[message.type];
      if (handlers != null) {
        for (final handler in handlers) {
          handler(message);
        }
      }
    } catch (e) {
      // Ignore parse errors for binary data
    }
  }

  void _onError(dynamic error) {
    state = state.copyWith(
      connectionState: WSConnectionState.error,
      error: 'Connection error: $error',
    );
  }

  void _onDone() {
    state = state.copyWith(connectionState: WSConnectionState.disconnected);
    _stopPingTimer();
    
    // Auto-reconnect if was connected before
    if (state.lastConnected != null) {
      // Would need to store the endpoint to reconnect
    }
  }

  void _startPingTimer() {
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      send(WSMessage(type: WSMessageType.ping));
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _scheduleReconnect(String endpoint) {
    if (state.reconnectAttempts >= _maxReconnectAttempts) {
      state = state.copyWith(
        connectionState: WSConnectionState.error,
        error: 'Max reconnect attempts reached',
      );
      return;
    }

    state = state.copyWith(
      connectionState: WSConnectionState.reconnecting,
      reconnectAttempts: state.reconnectAttempts + 1,
    );

    _reconnectTimer = Timer(_reconnectDelay, () {
      connect(endpoint);
    });
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}

/// WebSocket service provider
final webSocketServiceProvider =
    StateNotifierProvider<WebSocketService, WebSocketState>((ref) {
  return WebSocketService(ref);
});

/// Convenience provider for connection state
final wsConnectionStateProvider = Provider<WSConnectionState>((ref) {
  return ref.watch(webSocketServiceProvider).connectionState;
});

/// Convenience provider for checking if connected
final wsIsConnectedProvider = Provider<bool>((ref) {
  return ref.watch(webSocketServiceProvider).isConnected;
});
