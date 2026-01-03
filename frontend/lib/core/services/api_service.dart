/// SMARTCARE+ API Service
///
/// HTTP client with Firebase auth interceptor for backend communication
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logger.dart';

/// API configuration
class ApiConfig {
  // Platform-specific base URL configuration
  // 
  // FOR PHYSICAL ANDROID DEVICE WITH USB:
  // The video player (ExoPlayer) does NOT work with adb reverse.
  // You MUST use the actual IP address of your laptop.
  // 
  // Steps:
  // 1. Make sure phone and laptop are on same network (or use hotspot)
  // 2. Find laptop IP: Get-NetIPAddress -AddressFamily IPv4
  // 3. Update _serverIp below
  // 4. Run backend with: uvicorn main:app --reload --port 8000 --host 0.0.0.0
  
  // ⚠️ UPDATE THIS TO YOUR LAPTOP'S IP ADDRESS
  static const String _serverIp = '10.154.55.250';
  
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Use actual IP for video streaming to work
      return 'http://$_serverIp:8000';
    }
    return 'http://localhost:8000';
  }
  
  static const Duration timeout = Duration(seconds: 30);
  
  // Endpoints
  static const String health = '/health';
  static const String users = '/api/users';
  static const String physio = '/api/physio';
  static const String nutrition = '/api/nutrition';
  static const String guardian = '/api/guardian';
}

/// API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    required this.statusCode,
  });

  factory ApiResponse.success(T data, int statusCode) {
    return ApiResponse(success: true, data: data, statusCode: statusCode);
  }

  factory ApiResponse.error(String error, int statusCode) {
    return ApiResponse(success: false, error: error, statusCode: statusCode);
  }
}

/// API Service for backend communication
class ApiService {
  final Ref _ref;
  final http.Client _client;
  
  ApiService(this._ref) : _client = http.Client();

  /// Get auth token from Firebase
  Future<String?> _getAuthToken() async {
    final authState = _ref.read(authProvider);
    if (authState.firebaseUser != null) {
      return await authState.firebaseUser!.getIdToken();
    }
    return null;
  }

  /// Build headers with auth token
  Future<Map<String, String>> _buildHeaders({
    bool requireAuth = true,
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extra != null) {
      headers.addAll(extra);
    }

    return headers;
  }

  /// Build full URL
  Uri _buildUrl(String endpoint, {Map<String, dynamic>? queryParams}) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map(
        (key, value) => MapEntry(key, value.toString()),
      ));
    }
    return uri;
  }

  /// Handle response
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJson,
  ) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return ApiResponse.success(null as T, response.statusCode);
        }
        
        final json = jsonDecode(response.body);
        final data = fromJson != null ? fromJson(json) : json as T;
        return ApiResponse.success(data, response.statusCode);
      } else {
        String error = 'Request failed';
        try {
          final json = jsonDecode(response.body);
          error = json['detail'] ?? json['error'] ?? error;
        } catch (_) {}
        return ApiResponse.error(error, response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Failed to parse response: $e', response.statusCode);
    }
  }

  /// GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final url = _buildUrl(endpoint, queryParams: queryParams);
      
      final response = await _client
          .get(url, headers: headers)
          .timeout(ApiConfig.timeout);
      
      return _handleResponse(response, fromJson);
    } on SocketException {
      return ApiResponse.error('No internet connection', 0);
    } on HttpException catch (e) {
      return ApiResponse.error('HTTP error: ${e.message}', 0);
    } catch (e) {
      return ApiResponse.error('Request failed: $e', 0);
    }
  }

  /// POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.api('POST', endpoint);
    
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final url = _buildUrl(endpoint, queryParams: queryParams);
      
      AppLogger.debug('POST $url', tag: 'HTTP');
      
      final response = await _client
          .post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      
      stopwatch.stop();
      AppLogger.api('POST', endpoint, 
          statusCode: response.statusCode, 
          duration: stopwatch.elapsed);
      
      return _handleResponse(response, fromJson);
    } on SocketException catch (e) {
      stopwatch.stop();
      AppLogger.error('POST $endpoint SocketException: $e', tag: 'HTTP');
      return ApiResponse.error('No internet connection', 0);
    } catch (e) {
      stopwatch.stop();
      AppLogger.error('POST $endpoint Exception: $e', tag: 'HTTP');
      return ApiResponse.error('Request failed: $e', 0);
    }
  }

  /// PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic body,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final url = _buildUrl(endpoint);
      
      final response = await _client
          .put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      
      return _handleResponse(response, fromJson);
    } catch (e) {
      return ApiResponse.error('Request failed: $e', 0);
    }
  }

  /// DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final url = _buildUrl(endpoint);
      
      final response = await _client
          .delete(url, headers: headers)
          .timeout(ApiConfig.timeout);
      
      return _handleResponse(response, fromJson);
    } catch (e) {
      return ApiResponse.error('Request failed: $e', 0);
    }
  }

  /// Upload file
  Future<ApiResponse<T>> uploadFile<T>(
    String endpoint,
    String filePath,
    String fieldName, {
    Map<String, String>? fields,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final token = requireAuth ? await _getAuthToken() : null;
      final url = _buildUrl(endpoint);
      
      final request = http.MultipartRequest('POST', url);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5), // Longer timeout for uploads
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response, fromJson);
    } catch (e) {
      return ApiResponse.error('Upload failed: $e', 0);
    }
  }

  /// Check backend health
  Future<bool> checkHealth() async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.health,
      requireAuth: false,
    );
    return response.success && response.data?['status'] == 'healthy';
  }

  /// Dispose client
  void dispose() {
    _client.close();
  }
}

/// API Service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
