/// User Model
/// 
/// Represents authenticated user data

import 'dart:convert';

class UserModel {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final bool isActive;
  final bool isVerified;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? phone;
  final bool phoneVerified;

  UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.isActive = true,
    this.isVerified = false,
    this.isAdmin = false,
    required this.createdAt,
    this.updatedAt,
    this.phone,
    this.phoneVerified = false,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get displayName => fullName.isNotEmpty ? fullName : email;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'avatar_url': avatarUrl,
    'is_active': isActive,
    'is_verified': isVerified,
    'is_admin': isAdmin,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'phone': phone,
    'phone_verified': phoneVerified,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    email: json['email'],
    firstName: json['first_name'],
    lastName: json['last_name'],
    avatarUrl: json['avatar_url'],
    isActive: json['is_active'] ?? true,
    isVerified: json['is_verified'] ?? false,
    isAdmin: json['is_admin'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
    phone: json['phone'],
    phoneVerified: json['phone_verified'] ?? false,
  );

  String toRawJson() => jsonEncode(toJson());
  factory UserModel.fromRawJson(String str) => UserModel.fromJson(jsonDecode(str));

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    bool? isActive,
    bool? isVerified,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? phone,
    bool? phoneVerified,
  }) => UserModel(
    id: id ?? this.id,
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isActive: isActive ?? this.isActive,
    isVerified: isVerified ?? this.isVerified,
    isAdmin: isAdmin ?? this.isAdmin,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    phone: phone ?? this.phone,
    phoneVerified: phoneVerified ?? this.phoneVerified,
  );
}

/// Authentication Tokens
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime obtainedAt;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    required this.expiresIn,
    DateTime? obtainedAt,
  }) : obtainedAt = obtainedAt ?? DateTime.now();

  DateTime get expiresAt => obtainedAt.add(Duration(seconds: expiresIn));
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get needsRefresh {
    final refreshThreshold = expiresAt.subtract(const Duration(minutes: 5));
    return DateTime.now().isAfter(refreshThreshold);
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_in': expiresIn,
    'obtained_at': obtainedAt.toIso8601String(),
  };

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'],
    refreshToken: json['refresh_token'],
    tokenType: json['token_type'] ?? 'bearer',
    expiresIn: json['expires_in'],
    obtainedAt: json['obtained_at'] != null 
        ? DateTime.parse(json['obtained_at'])
        : DateTime.now(),
  );
}

/// Device Information for authentication
class DeviceInfo {
  final String? deviceName;
  final String? deviceType;
  final String? osVersion;
  final String? appVersion;
  final String? deviceFingerprint;

  DeviceInfo({
    this.deviceName,
    this.deviceType,
    this.osVersion,
    this.appVersion,
    this.deviceFingerprint,
  });

  Map<String, dynamic> toJson() => {
    'device_name': deviceName,
    'device_type': deviceType,
    'os_version': osVersion,
    'app_version': appVersion,
    'device_fingerprint': deviceFingerprint,
  };
}
