/// API Client
/// 
/// HTTP client for communicating with the LYRR backend API

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../../core/config.dart';
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
    // Always validate TLS certificates. Self-signed certs should be handled
    // by installing the CA, never by disabling verification in app code.
    final ioClient = HttpClient();
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

  /// Extract host from URL for error messages
  String _extractHost(String path) {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
      return uri.host;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Handle SocketException with descriptive message
  Never _throwSocketError(SocketException e, {String path = '', String method = ''}) {
    final host = _extractHost(path);
    final osError = e.osError?.message ?? '';
    
    if (e.message.contains('Connection refused') || osError.contains('Connection refused')) {
      throw ApiException(
        'Cannot connect to server at $host. Make sure the backend is running.',
        statusCode: 0,
      );
    }
    if (e.message.contains('Connection timed out') || osError.contains('timed out')) {
      throw ApiException(
        'Connection to server at $host timed out. Check your network or server status.',
        statusCode: 0,
      );
    }
    if (e.message.contains('No address') || osError.contains('No address')) {
      throw ApiException(
        'Could not resolve server address: $host. Check the API URL in settings.',
        statusCode: 0,
      );
    }
    if (e.message.contains('reset by peer') || osError.contains('reset')) {
      throw ApiException(
        'Connection to server was interrupted. The server may have restarted.',
        statusCode: 0,
      );
    }
    
    throw ApiException(
      'Network error: ${e.message}. Server: $host. $osError',
      statusCode: 0,
    );
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
      _throwSocketError(e, path: path, method: 'GET');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out after ${AppConfig.apiTimeout.inSeconds}s. '
        'Server: ${_extractHost(path)}. Check that the backend is running and accessible.',
        statusCode: 0,
      );
    } on FormatException catch (e) {
      throw ApiException(
        'Received unexpected data from server. ${e.message}',
        statusCode: 0,
      );
    } on HttpException catch (e) {
      throw ApiException(
        'HTTP error: ${e.message}',
        statusCode: 0,
      );
    } catch (e) {
      throw ApiException(
        'Unexpected error: ${e.runtimeType}. ${e.toString().length > 200 ? e.toString().substring(0, 200) : e}',
        statusCode: 0,
      );
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
      _throwSocketError(e, path: path, method: 'POST');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out after ${AppConfig.apiTimeout.inSeconds}s. '
        'Server: ${_extractHost(path)}. Check that the backend is running and accessible.',
        statusCode: 0,
      );
    } on FormatException catch (e) {
      throw ApiException('Received unexpected data from server. ${e.message}', statusCode: 0);
    } on HttpException catch (e) {
      throw ApiException('HTTP error: ${e.message}', statusCode: 0);
    } catch (e) {
      throw ApiException(
        'Unexpected error: ${e.runtimeType}. ${e.toString().length > 200 ? e.toString().substring(0, 200) : e}',
        statusCode: 0,
      );
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
      _throwSocketError(e, path: path, method: 'PUT');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out after ${AppConfig.apiTimeout.inSeconds}s. '
        'Server: ${_extractHost(path)}. Check that the backend is running and accessible.',
        statusCode: 0,
      );
    } on FormatException catch (e) {
      throw ApiException('Received unexpected data from server. ${e.message}', statusCode: 0);
    } on HttpException catch (e) {
      throw ApiException('HTTP error: ${e.message}', statusCode: 0);
    } catch (e) {
      throw ApiException(
        'Unexpected error: ${e.runtimeType}. ${e.toString().length > 200 ? e.toString().substring(0, 200) : e}',
        statusCode: 0,
      );
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
      _throwSocketError(e, path: path, method: 'DELETE');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out after ${AppConfig.apiTimeout.inSeconds}s. '
        'Server: ${_extractHost(path)}. Check that the backend is running and accessible.',
        statusCode: 0,
      );
    } on FormatException catch (e) {
      throw ApiException('Received unexpected data from server. ${e.message}', statusCode: 0);
    } on HttpException catch (e) {
      throw ApiException('HTTP error: ${e.message}', statusCode: 0);
    } catch (e) {
      throw ApiException(
        'Unexpected error: ${e.runtimeType}. ${e.toString().length > 200 ? e.toString().substring(0, 200) : e}',
        statusCode: 0,
      );
    }
  }

  /// Handle HTTP response
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? parser,
  ) {
    final statusCode = response.statusCode;
    
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return ApiResponse.success(null as T, statusCode: statusCode);
      }
      
      final data = jsonDecode(response.body);
      if (data == null) {
        return ApiResponse.success(null as T, statusCode: statusCode);
      }
      final parsedData = parser != null ? parser(data) : (data is T ? data : data as T);
      return ApiResponse.success(parsedData, statusCode: statusCode);
    } else if (statusCode == 401) {
      final error = _parseError(response.body);
      final msg = error['detail'] ?? error['message'] ?? 'Session expired. Please login again.';
      throw ApiException(msg, statusCode: 401);
    } else if (statusCode == 403) {
      final error = _parseError(response.body);
      throw ApiException(
        error['detail'] ?? error['message'] ?? 'Access denied',
        statusCode: 403,
      );
    } else if (statusCode == 404) {
      final error = _parseError(response.body);
      throw ApiException(
        error['detail'] ?? error['message'] ?? 'Resource not found',
        statusCode: 404,
      );
    } else if (statusCode == 422) {
      final error = _parseError(response.body);
      final detail = error['detail'];
      // Append field-level errors
      String msg;
      if (detail is List) {
        final fieldErrors = detail.take(2).map((e) {
          final field = e['field'] ?? e['loc']?.join('.') ?? 'unknown';
          final message = e['message'] ?? e['msg'] ?? 'invalid';
          return '$field: $message';
        }).join('; ');
        msg = 'Validation failed: $fieldErrors';
      } else {
        msg = error['detail'] ?? 'Invalid data submitted';
      }
      throw ApiException(msg, statusCode: 422, errors: error['errors']);
    } else if (statusCode >= 400 && statusCode < 500) {
      final error = _parseError(response.body);
      throw ApiException(
        error['detail'] ?? error['message'] ?? 'Request failed',
        statusCode: statusCode,
        errors: error['errors'],
      );
    } else if (statusCode >= 500) {
      final error = _parseError(response.body);
      throw ApiException(
        error['detail'] ?? 'Server error. Please try again later.',
        statusCode: statusCode,
      );
    } else {
      throw ApiException('Unexpected response (status: $statusCode)', statusCode: statusCode);
    }
  }

  /// Parse error response
  Map<String, dynamic> _parseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) return data as Map<String, dynamic>;
      return {'message': body};
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

  // Payments (FRS §10)
  static const String subscriptions = '/payments/subscriptions';
  static const String paymentMethods = '/payments/methods';
  static const String paymentCheckout = '/payments/checkout';
  static const String paymentHistory = '/payments/history';
  static String payment(String id) => '/payments/$id';
  static String paymentConfirm(String id) => '/payments/$id/confirm';

  // Verification (FRS §4)
  static const String verifyRequest = '/auth/verify/request';
  static const String verifyConfirm = '/auth/verify/confirm';
}
