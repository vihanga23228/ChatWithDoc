import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config.dart';
import '../models/models.dart';
import 'api_client.dart';

enum RealtimeEventType { messageCreated, consultationUpdated, messagesRead, typing }

/// One push from the server on `/user/queue/events` (see the backend README, "Real-time").
class RealtimeEvent {
  final RealtimeEventType type;
  final String consultationId;
  final Map<String, dynamic> data;

  const RealtimeEvent(this.type, this.consultationId, this.data);

  ChatMessage get message => ChatMessage.fromJson(data);
  Consultation get consultation => Consultation.fromJson(data);

  static RealtimeEvent? tryParse(String? body) {
    if (body == null) return null;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final type = switch (json['type']) {
        'MESSAGE_CREATED' => RealtimeEventType.messageCreated,
        'CONSULTATION_UPDATED' => RealtimeEventType.consultationUpdated,
        'MESSAGES_READ' => RealtimeEventType.messagesRead,
        'TYPING' => RealtimeEventType.typing,
        _ => null,
      };
      if (type == null) return null;
      return RealtimeEvent(
        type,
        json['consultationId'],
        Map<String, dynamic>.from(json['data'] as Map),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The STOMP connection. Screens listen to [events]; after a reconnect [reconnected] fires so they can
/// fetch whatever they missed while offline. The client reconnects on its own every few seconds.
class RealtimeService {
  final ApiClient _api;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// Shared with the STOMP client and updated before every (re)connect, so it always carries a fresh token.
  final Map<String, String> _connectHeaders = {};
  final ValueNotifier<bool> connected = ValueNotifier(false);

  StompClient? _client;
  bool _hasConnectedBefore = false;

  RealtimeService(this._api);

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<void> get reconnected => _reconnected.stream;

  Stream<RealtimeEvent> eventsFor(String consultationId) =>
      events.where((e) => e.consultationId == consultationId);

  void connect() {
    if (_client != null) return;
    _hasConnectedBefore = false;
    _client = StompClient(
      config: StompConfig(
        url: AppConfig.webSocketUrl,
        stompConnectHeaders: _connectHeaders,
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 3),
        beforeConnect: () async {
          final token = await _api.validAccessToken();
          _connectHeaders['Authorization'] = 'Bearer ${token ?? ''}';
        },
        onConnect: _onConnect,
        onDisconnect: (_) => connected.value = false,
        onWebSocketDone: () => connected.value = false,
        onWebSocketError: (error) {
          connected.value = false;
          debugPrint('[realtime] websocket error: $error');
        },
        onStompError: (frame) {
          connected.value = false;
          // Usually an expired token: refresh so the automatic reconnect succeeds.
          debugPrint('[realtime] stomp error: ${frame.headers['message']}');
          _api.refreshTokens();
        },
      ),
    )..activate();
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    connected.value = false;
  }

  /// Reconnects with the newest access token (called after login or a token refresh).
  void restart() {
    if (_client == null) return;
    disconnect();
    connect();
  }

  void sendTyping(String consultationId, bool typing) {
    final client = _client;
    if (client == null || !client.connected) return;
    client.send(
      destination: '/app/consultations/$consultationId/typing',
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'typing': typing}),
    );
  }

  void _onConnect(StompFrame frame) {
    connected.value = true;
    _client?.subscribe(
      destination: '/user/queue/events',
      callback: (frame) {
        final event = RealtimeEvent.tryParse(frame.body);
        if (event != null) _events.add(event);
      },
    );
    _client?.subscribe(
      destination: '/user/queue/errors',
      callback: (frame) => debugPrint('[realtime] server error: ${frame.body}'),
    );
    if (_hasConnectedBefore) _reconnected.add(null);
    _hasConnectedBefore = true;
  }
}
