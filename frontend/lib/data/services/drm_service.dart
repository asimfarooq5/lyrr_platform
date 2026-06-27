/// DRM (Digital Rights Management) Service
/// 
/// Handles encrypted media decryption and license management

import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'auth_service.dart';
import 'api_client.dart';

/// DRM License
class DRMLicense {
  final String licenseKey;
  final DateTime? expiresAt;
  final String? downloadUrl;
  final String? encryptionKeyId;

  DRMLicense({
    required this.licenseKey,
    this.expiresAt,
    this.downloadUrl,
    this.encryptionKeyId,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isValid => !isExpired;

  factory DRMLicense.fromJson(Map<String, dynamic> json) => DRMLicense(
    licenseKey: json['license_key'],
    expiresAt: json['expires_at'] != null 
        ? DateTime.parse(json['expires_at']) 
        : null,
    downloadUrl: json['download_url'],
    encryptionKeyId: json['encryption_key_id'],
  );
}

/// DRM Service
class DRMService {
  final AuthService _authService;
  final ApiClient _apiClient;
  final Map<String, DRMLicense> _licenses = {};
  final Map<String, encrypt.Key> _encryptionKeys = {};

  DRMService({
    required AuthService authService,
  })  : _authService = authService,
        _apiClient = ApiClient(authService: authService);

  /// Get or request DRM license for a book
  Future<DRMLicense?> getLicense(String bookId) async {
    // Check cached license
    if (_licenses.containsKey(bookId)) {
      final cached = _licenses[bookId]!;
      if (cached.isValid) {
        return cached;
      }
    }

    // Request new license from server
    final deviceId = _authService.deviceId;
    if (deviceId == null) return null;

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.bookLicense(bookId),
        body: {'device_id': deviceId},
      );

      if (response.success && response.data != null) {
        final license = DRMLicense.fromJson(response.data!);
        _licenses[bookId] = license;
        
        // Derive encryption key from license
        if (license.encryptionKeyId != null) {
          _encryptionKeys[bookId] = _deriveKey(license.licenseKey);
        }
        
        return license;
      }
    } catch (e) {
      // License request failed
    }

    return null;
  }

  /// Decrypt audio chunk
  Future<Uint8List?> decryptAudio(String bookId, Uint8List encryptedData) async {
    final key = _encryptionKeys[bookId];
    if (key == null) return null;

    try {
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      // First 16 bytes are IV
      if (encryptedData.length < 16) return null;
      
      final ivBytes = encryptedData.sublist(0, 16);
      final cipherText = encryptedData.sublist(16);
      
      final ivObj = encrypt.IV(Uint8List.fromList(ivBytes));
      
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(cipherText),
        iv: ivObj,
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      return null;
    }
  }

  /// Encrypt audio chunk (for offline storage)
  Future<Uint8List?> encryptAudio(String bookId, Uint8List plainData) async {
    final key = _encryptionKeys[bookId];
    if (key == null) return null;

    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      final encrypted = encrypter.encryptBytes(plainData, iv: iv);

      // Prepend IV to encrypted data
      final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
      result.setRange(0, iv.bytes.length, iv.bytes);
      result.setRange(iv.bytes.length, result.length, encrypted.bytes);

      return result;
    } catch (e) {
      return null;
    }
  }

  /// Verify license validity
  Future<bool> verifyLicense(String bookId) async {
    final license = await getLicense(bookId);
    return license != null && license.isValid;
  }

  /// Revoke license (e.g., on logout)
  void revokeLicense(String bookId) {
    _licenses.remove(bookId);
    _encryptionKeys.remove(bookId);
  }

  /// Revoke all licenses
  void revokeAllLicenses() {
    _licenses.clear();
    _encryptionKeys.clear();
  }

  /// Derive encryption key from license key
  encrypt.Key _deriveKey(String licenseKey) {
    final bytes = utf8.encode(licenseKey);
    final hash = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// Check if book is licensed
  bool isLicensed(String bookId) {
    final license = _licenses[bookId];
    return license != null && license.isValid;
  }
}
