import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Login state. [currentUser] is null when logged out; screens can listen to it.
class AuthService {
  final ApiClient _api;
  final ValueNotifier<AppUser?> currentUser = ValueNotifier(null);

  AuthService(this._api);

  AppUser? get user => currentUser.value;

  /// Restores the previous session on app start. Returns the user, or null if they must log in.
  Future<AppUser?> restoreSession() async {
    await _api.tokens.load();
    if (!_api.tokens.hasSession) return null;
    try {
      final json = await _api.get('/api/auth/me');
      return currentUser.value = AppUser.fromJson(json);
    } on ApiException catch (e) {
      // Offline: keep the tokens so the next start can retry; otherwise the session is gone.
      if (!e.isNetworkError) await _api.tokens.clear();
      return null;
    }
  }

  Future<AppUser> login(String email, String password) => _authenticate(
    '/api/auth/login',
    {'email': email.trim(), 'password': password},
  );

  Future<AppUser> registerPatient({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? healthHistory,
    String? drugAllergies,
  }) => _authenticate('/api/auth/register/patient', {
    'name': name,
    'email': email,
    'password': password,
    'phone': phone,
    'healthHistory': healthHistory,
    'drugAllergies': drugAllergies,
  });

  Future<AppUser> registerDoctor(Map<String, dynamic> request) =>
      _authenticate('/api/auth/register/doctor', request);

  Future<void> logout() async {
    final refreshToken = _api.tokens.refreshToken;
    if (refreshToken != null) {
      try {
        await _api.post('/api/auth/logout', {
          'refreshToken': refreshToken,
        }, false);
      } on ApiException {
        // Logging out locally is what matters.
      }
    }
    await _api.tokens.clear();
    currentUser.value = null;
  }

  /// Local-only sign-out, used when the server has already rejected the session.
  Future<void> clearSession() async {
    await _api.tokens.clear();
    currentUser.value = null;
  }

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _api.put('/api/auth/password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  Future<AppUser> _authenticate(String path, Map<String, dynamic> body) async {
    final json = await _api.post(path, body, false) as Map<String, dynamic>;
    await _api.tokens.save(json['accessToken'], json['refreshToken']);
    _api.onTokensChanged?.call();
    return currentUser.value = AppUser.fromJson(json['user']);
  }
}
