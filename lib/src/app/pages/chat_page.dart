import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/allowance_bar.dart';
import '../components/authenticated_image.dart';
import '../components/user_avatar.dart';
import '../models/models.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';
import '../services/services.dart';
import '../utils/format.dart';

/// One consultation's chat, for both the patient and the doctor.
///
/// Messages are sent over REST; new messages, read receipts, typing and status changes arrive live over the
/// realtime connection. After a reconnect the screen fetches whatever it missed.
class ChatPage extends StatefulWidget {
  final Consultation consultation;

  const ChatPage({super.key, required this.consultation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _typingIdle = Duration(seconds: 3);

  final _controller = TextEditingController();
  final Map<String, ChatMessage> _messages = {};
  final List<StreamSubscription> _subscriptions = [];

  late Consultation _consultation;
  bool _loading = true;
  bool _sending = false;
  bool _otherTyping = false;
  Timer? _otherTypingTimer;
  Timer? _myTypingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isDoctor => Services.auth.user?.role == Role.doctor;
  String get _myId => Services.auth.user?.id ?? '';

  String get _otherName =>
      _isDoctor ? _consultation.patientName : _consultation.doctorName;

  List<ChatMessage> get _sortedMessages =>
      _messages.values.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));

  @override
  void initState() {
    super.initState();
    _consultation = widget.consultation;
    _subscriptions.add(
      Services.realtime.eventsFor(_consultation.id).listen(_onEvent),
    );
    _subscriptions.add(Services.realtime.reconnected.listen((_) => _catchUp()));
    _controller.addListener(_onTextChanged);
    _loadAll();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _otherTypingTimer?.cancel();
    _myTypingTimer?.cancel();
    if (_consultation.isActive) {
      Services.realtime.sendTyping(_consultation.id, false);
    }
    _controller.dispose();
    super.dispose();
  }

  // ---- Loading ----

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        Services.backend.messages(_consultation.id),
        Services.backend.consultation(_consultation.id),
      ]);
      if (!mounted) return;
      setState(() {
        for (final m in results[0] as List<ChatMessage>) {
          _messages[m.id] = m;
        }
        _consultation = results[1] as Consultation;
        _loading = false;
      });
      _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  /// After a reconnect: fetch only the messages we missed.
  Future<void> _catchUp() async {
    final sorted = _sortedMessages;
    try {
      final missed = await Services.backend.messages(
        _consultation.id,
        afterRaw: sorted.isEmpty ? null : sorted.last.sentAtRaw,
      );
      final consultation = await Services.backend.consultation(_consultation.id);
      if (!mounted) return;
      setState(() {
        for (final m in missed) {
          _messages[m.id] = m;
        }
        _consultation = consultation;
      });
      if (missed.any((m) => !m.mine)) _markRead();
    } on ApiException {
      // The next reconnect will try again.
    }
  }

  void _markRead() {
    if (_messages.values.any((m) => !m.mine && m.readAt == null)) {
      Services.backend.markRead(_consultation.id).catchError((_) {});
    }
  }

  // ---- Realtime ----

  void _onEvent(RealtimeEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case RealtimeEventType.messageCreated:
        final message = event.message;
        setState(() {
          _messages[message.id] = message;
          if (!message.mine) _otherTyping = false;
        });
        if (!message.mine) _markRead();
      case RealtimeEventType.consultationUpdated:
        final wasActive = _consultation.isActive;
        setState(() => _consultation = event.consultation);
        if (wasActive && !_consultation.isActive) _onCompleted();
      case RealtimeEventType.messagesRead:
        if (event.data['readerId'] == _myId) return;
        final readAt = DateTime.parse(event.data['readAt']).toLocal();
        setState(() {
          _messages.updateAll((_, m) => m.mine ? m.markRead(readAt) : m);
        });
      case RealtimeEventType.typing:
        if (event.data['userId'] == _myId) return;
        final typing = event.data['typing'] == true;
        _otherTypingTimer?.cancel();
        setState(() => _otherTyping = typing);
        if (typing) {
          // Hide it if the "stopped typing" signal never arrives.
          _otherTypingTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => _otherTyping = false);
          });
        }
    }
  }

  /// Throttled typing signals: at most one "typing" every 3 s, and "stopped" after 3 s idle.
  void _onTextChanged() {
    if (!_consultation.isActive || _controller.text.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) > _typingIdle) {
      _lastTypingSent = now;
      Services.realtime.sendTyping(_consultation.id, true);
    }
    _myTypingTimer?.cancel();
    _myTypingTimer = Timer(_typingIdle, () {
      _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
      Services.realtime.sendTyping(_consultation.id, false);
    });
  }

  // ---- Sending ----

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final allowance = _consultation.allowance;
    if (!_isDoctor && allowance != null) {
      final words = countWords(text);
      if (words > allowance.remaining.textWords) {
        _snack(
          'This message has $words words but you only have '
          '${allowance.remaining.textWords} left. Shorten it or ask the doctor for more.',
        );
        return;
      }
    }

    setState(() => _sending = true);
    try {
      final message = await Services.backend.sendText(_consultation.id, text);
      _myTypingTimer?.cancel();
      Services.realtime.sendTyping(_consultation.id, false);
      if (!mounted) return;
      setState(() {
        _messages[message.id] = message;
        _controller.clear();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto(ImageSource source) async {
    final allowance = _consultation.allowance;
    if (!_isDoctor && allowance != null && allowance.remaining.photos <= 0) {
      _snack('You have used all your photos for this consultation.');
      return;
    }
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      _snack('Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.');
      return;
    }
    if (file == null) return;

    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final message = await Services.backend.sendMedia(
        _consultation.id,
        type: MessageType.image,
        bytes: bytes,
        fileName: file.name,
        contentType: file.mimeType ?? _imageMimeType(file.name),
      );
      if (mounted) setState(() => _messages[message.id] = message);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _imageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _pickPhotoSource() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- Actions ----

  Future<void> _grant(MessageType type) async {
    try {
      final updated = await Services.backend.grantAllowance(_consultation.id, type);
      if (!mounted) return;
      setState(() => _consultation = updated);
      _snack(switch (type) {
        MessageType.text => 'Gave the patient 50 more words',
        MessageType.voice => 'Gave the patient 1 more minute of voice',
        MessageType.image => 'Gave the patient 1 more photo',
        MessageType.video => 'Gave the patient 30 more seconds of video',
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End consultation?'),
        content: const Text(
          'Neither of you will be able to send more messages in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final updated = await Services.backend.completeConsultation(_consultation.id);
      if (!mounted) return;
      setState(() => _consultation = updated);
      _onCompleted();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _onCompleted() {
    if (!_isDoctor && !_consultation.reviewed) _review();
  }

  Future<void> _review() async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _ReviewDialog(doctorName: _consultation.doctorName),
    );
    if (result == null) return;
    try {
      await Services.backend.review(
        _consultation.id,
        result.$1,
        result.$2.isEmpty ? null : result.$2,
      );
      final updated = await Services.backend.consultation(_consultation.id);
      if (!mounted) return;
      setState(() => _consultation = updated);
      _snack('Thank you for your review!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _showPatientProfile() async {
    try {
      final profile = await Services.backend.consultationPatient(_consultation.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(profile.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Health history', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(profile.healthHistory ?? 'Not provided'),
              const SizedBox(height: 12),
              const Text('Drug allergies', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(profile.drugAllergies ?? 'Not provided'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final allowance = _consultation.allowance;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              name: _otherName,
              imageUrl: _isDoctor
                  ? _consultation.patientAvatarUrl
                  : _consultation.doctorAvatarUrl,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_otherName, style: const TextStyle(fontSize: 16)),
                  ValueListenableBuilder<bool>(
                    valueListenable: Services.realtime.connected,
                    builder: (context, connected, _) => Text(
                      !connected
                          ? 'Connecting…'
                          : _otherTyping
                          ? 'typing…'
                          : _isDoctor
                          ? 'Patient'
                          : _consultation.doctorSpecialization,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [_buildMenu()],
      ),
      body: Column(
        children: [
          if (allowance != null && _consultation.isActive)
            AllowanceBar(allowance: allowance),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessages(),
          ),
          if (_consultation.isActive) _buildInput() else _buildCompletedBanner(),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    final canGrant = _isDoctor && _consultation.isActive && _consultation.allowance != null;
    return PopupMenuButton<String>(
      onSelected: (value) => switch (value) {
        'patient' => _showPatientProfile(),
        'grant-text' => _grant(MessageType.text),
        'grant-voice' => _grant(MessageType.voice),
        'grant-photo' => _grant(MessageType.image),
        'grant-video' => _grant(MessageType.video),
        'complete' => _complete(),
        'review' => _review(),
        _ => null,
      },
      itemBuilder: (_) => [
        if (_isDoctor)
          const PopupMenuItem(value: 'patient', child: Text('Patient medical profile')),
        if (canGrant) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'grant-text', child: Text('Give +50 words')),
          const PopupMenuItem(value: 'grant-voice', child: Text('Give +1 min voice')),
          const PopupMenuItem(value: 'grant-photo', child: Text('Give +1 photo')),
          const PopupMenuItem(value: 'grant-video', child: Text('Give +30 s video')),
        ],
        if (_consultation.isActive) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'complete', child: Text('End consultation')),
        ],
        if (!_isDoctor && !_consultation.isActive && !_consultation.reviewed)
          const PopupMenuItem(value: 'review', child: Text('Rate the doctor')),
      ],
    );
  }

  Widget _buildMessages() {
    final messages = _sortedMessages;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _isDoctor
                ? 'No messages yet. Say hello to your patient.'
                : 'Describe your symptoms to begin your consultation.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          _MessageBubble(message: messages[messages.length - 1 - index]),
    );
  }

  Widget _buildInput() {
    final allowance = _consultation.allowance;
    final outOfPhotos = !_isDoctor && allowance != null && allowance.remaining.photos <= 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Send a photo',
              onPressed: _sending || outOfPhotos ? null : _pickPhotoSource,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type your message…',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: _sending ? null : _sendText,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBanner() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade100,
        child: Column(
          children: [
            const Text(
              'This consultation has ended.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!_isDoctor && !_consultation.reviewed)
              TextButton.icon(
                onPressed: _review,
                icon: const Icon(Icons.star_outline),
                label: const Text('Rate the doctor'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final foreground = mine ? Colors.white : Colors.black87;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: mine ? Colors.blue.shade700 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _content(foreground),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatClock(message.sentAt),
                    style: TextStyle(fontSize: 11, color: foreground.withValues(alpha: 0.7)),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.readAt != null ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.readAt != null
                          ? Colors.lightBlueAccent.shade100
                          : foreground.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(Color foreground) {
    switch (message.type) {
      case MessageType.text:
        return Text(message.content ?? '', style: TextStyle(color: foreground, fontSize: 15));
      case MessageType.image:
        return AuthenticatedImage(mediaUrl: message.mediaUrl!);
      case MessageType.voice:
      case MessageType.video:
        final isVoice = message.type == MessageType.voice;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isVoice ? Icons.mic : Icons.videocam, color: foreground),
            const SizedBox(width: 8),
            Text(
              '${isVoice ? 'Voice message' : 'Video'} '
              '(${formatDuration(message.durationSeconds ?? 0)})',
              style: TextStyle(color: foreground),
            ),
          ],
        );
    }
  }
}

/// Pops with (rating 1-5, comment).
class _ReviewDialog extends StatefulWidget {
  final String doctorName;

  const _ReviewDialog({required this.doctorName});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.doctorName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
            ),
          ),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Share your experience (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (_rating, _comment.text.trim())),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
