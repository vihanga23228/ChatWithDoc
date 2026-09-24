import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config.dart';

/// An error returned by the backend (or a network failure). [message] is always safe to show to the user.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, String> fieldErrors;

  const ApiException(
    this.statusCode,
    this.message, [
    this.fieldErrors = const {},
  ]);

  bool get isNetworkError => statusCode == 0;

  /// Validation errors joined into one line, e.g. for a snackbar.
  String get details => fieldErrors.isEmpty
      ? message
      : '$message: ${fieldErrors.values.join(', ')}';

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

/// Access + refresh tokens, kept in the platform's secure storage (Keychain / Keystore).
class TokenStore {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// False keeps tokens in memory only (tests, where the secure-storage plugin is unavailable).
  final bool persist;
  String? _accessToken;
  String? _refreshToken;

  TokenStore({this.persist = true});

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _refreshToken != null;

  Future<void> load() async {
    if (!persist) return;
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
  }

  Future<void> save(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (!persist) return;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    if (!persist) return;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  /// True if the access token is missing or expires within [margin] (read from the JWT's `exp` claim).
  bool accessTokenExpiresSoon([Duration margin = const Duration(seconds: 60)]) {
    final token = _accessToken;
    if (token == null) return true;
    try {
      final payload = token.split('.')[1];
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (claims['exp'] as int) * 1000,
      );
      return DateTime.now().add(margin).isAfter(expiry);
    } catch (_) {
      return true;
    }
  }
}

/// Talks to the REST API. Adds the access token to every request and, when the server answers 401,
/// refreshes the token pair once and retries. If the refresh fails the session is over and
/// [onSessionExpired] is called (the app then shows the login screen).
class ApiClient {
  final TokenStore tokens;
  final http.Client _http = http.Client();

  /// Called when the refresh token is no longer valid.
  void Function()? onSessionExpired;

  /// Called whenever a new token pair is stored (the realtime connection uses the newest token).
  void Function()? onTokensChanged;

  Future<bool>? _refreshing;

  ApiClient(this.tokens);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send((headers) => _http.get(_uri(path, query), headers: headers));

  Future<dynamic> post(String path, [Object? body, bool authenticated = true]) =>
      _send(
        (headers) => _http.post(
          _uri(path),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        authenticated: authenticated,
      );

  Future<dynamic> put(String path, Object body) => _send(
    (headers) => _http.put(_uri(path), headers: headers, body: jsonEncode(body)),
  );

  /// Raw bytes of a protected file (chat photos).
  Future<Uint8List> getBytes(String path) async {
    final response = await _sendRaw(
      (headers) => _http.get(_uri(path), headers: headers),
    );
    return response.bodyBytes;
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
  }) {
    return _send((headers) async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(headers..remove('Content-Type'))
        ..fields.addAll(fields)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        );
      return http.Response.fromStream(await _http.send(request));
    });
  }

  /// Returns a fresh access token, refreshing first if it is about to expire.
  Future<String?> validAccessToken() async {
    if (tokens.hasSession && tokens.accessTokenExpiresSoon()) {
      await refreshTokens();
    }
    return tokens.accessToken;
  }

  /// Exchanges the refresh token for a new pair. Concurrent callers share one request.
  Future<bool> refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _http.post(
        _uri('/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode != 200) {
        await tokens.clear();
        onSessionExpired?.call();
        return false;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await tokens.save(json['accessToken'], json['refreshToken']);
      onTokensChanged?.call();
      return true;
    } catch (_) {
      // Network problem: keep the session, the next request will try again.
      return false;
    }
  }

  Future<dynamic> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    bool authenticated = true,
  }) async {
    final response = await _sendRaw(request, authenticated: authenticated);
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<http.Response> _sendRaw(
    Future<http.Response> Function(Map<String, String> headers) request, {
    bool authenticated = true,
  }) async {
    try {
      var response = await request(_headers(authenticated));
      if (authenticated && response.statusCode == 401 && tokens.hasSession) {
        if (await refreshTokens()) {
          response = await request(_headers(authenticated));
        }
      }
      if (response.statusCode >= 400) throw _toException(response);
      return response;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(0, 'The server took too long to answer.');
    } catch (_) {
      throw ApiException(
        0,
        'Cannot reach the server at ${AppConfig.apiBaseUrl}. Is the backend running?',
      );
    }
  }

  Map<String, String> _headers(bool authenticated) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (authenticated && tokens.accessToken != null)
      'Authorization': 'Bearer ${tokens.accessToken}',
  };

  ApiException _toException(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return ApiException(
        response.statusCode,
        json['message'] ?? 'Request failed (${response.statusCode})',
        Map<String, String>.from(json['fieldErrors'] ?? const {}),
      );
    } catch (_) {
      return ApiException(
        response.statusCode,
        'Request failed (${response.statusCode})',
      );
    }
  }
}
