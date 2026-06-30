/// API Client
/// 
/// HTTP client for communicating with the LYRR backend API

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../../core/config.dart';
import '../../core/constants.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// API Response wrapper
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

  factory ApiResponse.success(T data, {int statusCode = 200}) => ApiResponse(
    success: true,
    data: data,
    statusCode: statusCode,
  );

  factory ApiResponse.error(String error, {int statusCode = 400}) => ApiResponse(
    success: false,
    error: error,
    statusCode: statusCode,
  );
}

/// Main API Client
class ApiClient {
  late final http.Client _client;
  final AuthService _authService;
  
  ApiClient({required AuthService authService}) : _authService = authService {
    _client = _createClient();
  }

  http.Client _createClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // In production, validate certificates properly
        return !AppConfig.enableDRM; // Only accept bad certs in dev
      };
    return IOClient(ioClient);
  }

  /// Get base headers with authentication
  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Version': '1.0.0',
    };

    if (requiresAuth) {
      final token = await _authService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Make GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
    T Function(dynamic)? parser,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
        queryParameters: queryParams,
      );
      
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConfig.apiTimeout);

      return _handleResponse<T>(response, parser);
    } on SocketException catch (e) {
      throw ApiException('No internet connection', statusCode: 0);
    } on FormatException catch (e) {
      throw ApiException('Invalid response format', statusCode: 0);
    } catch (e) {
      throw ApiException('Request failed: $e', statusCode: 0);
    }
  }

  /// Make POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    T Function(dynamic)? parser,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.apiTimeout);

      return _handleResponse<T>(response, parser);
    } on SocketException catch (e) {
      throw ApiException('No internet connection', statusCode: 0);
    } catch (e) {
      throw ApiException('Request failed: $e', statusCode: 0);
    }
  }

  /// Make PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    T Function(dynamic)? parser,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.apiTimeout);

      return _handleResponse<T>(response, parser);
    } on SocketException catch (e) {
      throw ApiException('No internet connection', statusCode: 0);
    } catch (e) {
      throw ApiException('Request failed: $e', statusCode: 0);
    }
  }

  /// Make DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    bool requiresAuth = true,
    T Function(dynamic)? parser,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      
      final response = await _client
          .delete(uri, headers: headers)
          .timeout(AppConfig.apiTimeout);

      return _handleResponse<T>(response, parser);
    } on SocketException catch (e) {
      throw ApiException('No internet connection', statusCode: 0);
    } catch (e) {
      throw ApiException('Request failed: $e', statusCode: 0);
    }
  }

  /// Handle HTTP response
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? parser,
  ) {
    final statusCode = response.statusCode;
    
    if (statusCode >= 200 && statusCode < 300) {
      // Success
      if (response.body.isEmpty) {
        return ApiResponse.success(null as T, statusCode: statusCode);
      }
      
      final data = jsonDecode(response.body);
      final parsedData = parser != null ? parser(data) : data as T;
      return ApiResponse.success(parsedData, statusCode: statusCode);
    } else if (statusCode == 401) {
      // Get actual error from API
      final error = _parseError(response.body);
      final msg = error['detail'] ?? error['message'] ?? 'Incorrect email or password';
      throw ApiException(msg, statusCode: 401);
    } else if (statusCode >= 400 && statusCode < 500) {
      // Client error
      final error = _parseError(response.body);
      throw ApiException(
        error['message'] ?? 'Request failed',
        statusCode: statusCode,
        errors: error['errors'],
      );
    } else {
      // Server error
      throw ApiException('Server error. Please try again later.', statusCode: statusCode);
    }
  }

  /// Parse error response
  Map<String, dynamic> _parseError(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {'message': body};
    }
  }

  /// Dispose client
  void dispose() {
    _client.close();
  }
}

/// API Endpoints
class ApiEndpoints {
  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String socialLogin = '/auth/social';

  // Books
  static const String books = '/books';
  static String book(String id) => '/books/$id';
  static String bookContent(String id) => '/books/$id/content';
  static String bookSync(String id) => '/books/$id/sync';
  static String bookLicense(String id) => '/books/$id/license';
  static String bookPurchase(String id) => '/books/$id/purchase';
  static String bookDownload(String id) => '/books/$id/download';

  // User Data
  static const String library = '/me/library';
  static const String bookmarks = '/me/bookmarks';
  static String bookmark(String id) => '/me/bookmarks/$id';
  static const String notes = '/me/notes';
  static String note(String id) => '/me/notes/$id';
  static const String progress = '/me/progress';
  static String bookProgress(String bookId) => '/me/progress/$bookId';
  static const String stats = '/me/stats';

  // Sync
  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';
  static const String syncConflicts = '/sync/conflicts';
  static String syncResolve(String id) => '/sync/resolve/$id';
  static const String syncCheckpoint = '/sync/checkpoint';
}
