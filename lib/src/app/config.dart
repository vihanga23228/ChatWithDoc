import 'package:flutter/foundation.dart';

/// Where the backend runs. Override with
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8055` (e.g. a phone on the same Wi-Fi).
class AppConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// The Android emulator reaches the host machine's localhost at 10.0.2.2.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8055';
    }
    return 'http://localhost:8055';
  }

  static String get webSocketUrl =>
      '${apiBaseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws';
}
