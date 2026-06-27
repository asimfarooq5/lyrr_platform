/// Authentication Service
/// 
/// Manages user authentication, tokens, and session state

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import '../../core/constants.dart';

/// Authentication state
enum AuthState {
  uninitialized,
  authenticated,
  unauthenticated,
}

/// Authentication service
class AuthService extends ChangeNotifier {
  final SharedPreferences _prefs;
  AuthState _state = AuthState.uninitialized;
  UserModel? _currentUser;
  AuthTokens? _tokens;
  String? _deviceId;

  AuthService({required SharedPreferences prefs}) : _prefs = prefs {
    _initialize();
  }

  // Getters
  AuthState get state => _state;
  UserModel? get currentUser => _currentUser;
  AuthTokens? get tokens => _tokens;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isInitialized => _state != AuthState.uninitialized;
  String? get deviceId => _deviceId;

  /// Initialize auth state from storage
  Future<void> _initialize() async {
    _deviceId = _prefs.getString(AppConstants.deviceIdKey);
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _prefs.setString(AppConstants.deviceIdKey, _deviceId!);
    }

    final tokenJson = _prefs.getString(AppConstants.authTokenKey);
    final userJson = _prefs.getString(AppConstants.userKey);

    if (tokenJson != null && userJson != null) {
      try {
        _tokens = AuthTokens.fromJson(jsonDecode(tokenJson));
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        
        if (_tokens!.isExpired) {
          // Try to refresh
          final refreshed = await _refreshToken();
          if (!refreshed) {
            await clearTokens();
            _state = AuthState.unauthenticated;
          } else {
            _state = AuthState.authenticated;
          }
        } else {
          _state = AuthState.authenticated;
        }
      } catch (e) {
        await clearTokens();
        _state = AuthState.unauthenticated;
      }
    } else {
      _state = AuthState.unauthenticated;
    }

    notifyListeners();
  }

  /// Register new user
  Future<ApiResponse<UserModel>> register({
    required String email,
    required String password,
    DeviceInfo? deviceInfo,
  }) async {
    try {
      final client = ApiClient(authService: this);
      
      final response = await client.post<Map<String, dynamic>>(
        ApiEndpoints.register,
        body: {
          'email': email,
          'password': password,
          'device_info': (deviceInfo ?? await _getDeviceInfo()).toJson(),
        },
        requiresAuth: false,
      );

      if (response.success && response.data != null) {
        final user = UserModel.fromJson(response.data!);
        return ApiResponse.success(user, statusCode: response.statusCode);
      }

      return ApiResponse.error(
        response.error ?? 'Registration failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Login with email and password
  Future<ApiResponse<UserModel>> login({
    required String email,
    required String password,
    DeviceInfo? deviceInfo,
  }) async {
    try {
      final client = ApiClient(authService: this);
      
      final response = await client.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        body: {
          'username': email,
          'password': password,
          'grant_type': 'password',
        },
        requiresAuth: false,
      );

      if (response.success && response.data != null) {
        // Parse tokens
        _tokens = AuthTokens.fromJson(response.data!);
        await _saveTokens();

        // Get user info
        final userResponse = await client.get<Map<String, dynamic>>(
          ApiEndpoints.me,
          parser: (data) => data,
        );

        if (userResponse.success && userResponse.data != null) {
          _currentUser = UserModel.fromJson(userResponse.data!);
          await _saveUser();
          
          _state = AuthState.authenticated;
          notifyListeners();
          
          return ApiResponse.success(_currentUser!, statusCode: response.statusCode);
        }
      }

      return ApiResponse.error(
        response.error ?? 'Login failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Social login (Google, Apple)
  Future<ApiResponse<UserModel>> socialLogin({
    required String provider,
    required String token,
  }) async {
    try {
      final client = ApiClient(authService: this);
      
      final response = await client.post<Map<String, dynamic>>(
        '${ApiEndpoints.socialLogin}/$provider',
        body: {
          'token': token,
          'device_info': (await _getDeviceInfo()).toJson(),
        },
        requiresAuth: false,
      );

      if (response.success && response.data != null) {
        _tokens = AuthTokens.fromJson(response.data!);
        await _saveTokens();

        _currentUser = UserModel.fromJson(response.data!['user']);
        await _saveUser();

        _state = AuthState.authenticated;
        notifyListeners();

        return ApiResponse.success(_currentUser!, statusCode: response.statusCode);
      }

      return ApiResponse.error(
        response.error ?? 'Social login failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final client = ApiClient(authService: this);
      await client.post(ApiEndpoints.logout, requiresAuth: true);
    } catch (e) {
      // Ignore errors during logout
    } finally {
      await clearTokens();
      _currentUser = null;
      _tokens = null;
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// Refresh access token
  Future<bool> _refreshToken() async {
    if (_tokens == null) return false;

    try {
      final client = ApiClient(authService: this);
      
      final response = await client.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        body: {'refresh_token': _tokens!.refreshToken},
        requiresAuth: false,
      );

      if (response.success && response.data != null) {
        _tokens = AuthTokens.fromJson(response.data!);
        await _saveTokens();
        return true;
      }
    } catch (e) {
      // Refresh failed
    }

    return false;
  }

  /// Get access token (with auto-refresh)
  Future<String?> getAccessToken() async {
    if (_tokens == null) return null;

    if (_tokens!.needsRefresh) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        await logout();
        return null;
      }
    }

    return _tokens?.accessToken;
  }

  /// Clear stored tokens
  Future<void> clearTokens() async {
    await _prefs.remove(AppConstants.authTokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
    await _prefs.remove(AppConstants.userKey);
  }

  /// Save tokens to storage
  Future<void> _saveTokens() async {
    if (_tokens != null) {
      await _prefs.setString(AppConstants.authTokenKey, jsonEncode(_tokens!.toJson()));
    }
  }

  /// Save user to storage
  Future<void> _saveUser() async {
    if (_currentUser != null) {
      await _prefs.setString(AppConstants.userKey, jsonEncode(_currentUser!.toJson()));
    }
  }

  /// Get device info
  Future<DeviceInfo> _getDeviceInfo() async {
    // TODO: Implement platform-specific device info
    return DeviceInfo(
      deviceName: 'Unknown',
      deviceType: 'mobile',
      deviceFingerprint: _deviceId,
    );
  }

  /// Update user profile
  Future<void> updateUser(UserModel user) async {
    _currentUser = user;
    await _saveUser();
    notifyListeners();
  }

  /// Request password reset
  Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      final client = ApiClient(authService: this);
      
      final response = await client.post(
        ApiEndpoints.forgotPassword,
        body: {'email': email},
        requiresAuth: false,
      );

      return response;
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}
