import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../pages/chat_page.dart';
import '../services/realtime_service.dart';
import '../services/services.dart';
import '../utils/format.dart';
import 'user_avatar.dart';

/// The user's consultations, newest activity first. Updates live: new chats, previews and unread counts
/// arrive as CONSULTATION_UPDATED events.
class LiveConsultationList extends StatefulWidget {
  /// Doctors see the patient's name; patients see the doctor's.
  final bool doctorView;

  /// Case-insensitive filter on the other person's name and the last message.
  final String filter;
  final Widget emptyView;

  /// Called whenever the list changes (e.g. to update counters on the dashboard).
  final ValueChanged<List<Consultation>>? onChanged;

  const LiveConsultationList({
    super.key,
    required this.doctorView,
    required this.emptyView,
    this.filter = '',
    this.onChanged,
  });

  @override
  State<LiveConsultationList> createState() => LiveConsultationListState();
}

class LiveConsultationListState extends State<LiveConsultationList> {
  final Map<String, Consultation> _items = {};
  final List<StreamSubscription> _subscriptions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      Services.realtime.events
          .where((e) => e.type == RealtimeEventType.consultationUpdated)
          .listen((e) => _upsert(e.consultation)),
    );
    _subscriptions.add(Services.realtime.reconnected.listen((_) => reload()));
    reload();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final list = await Services.backend.consultations();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addEntries(list.map((c) => MapEntry(c.id, c)));
        _loading = false;
        _error = null;
      });
      widget.onChanged?.call(_sorted);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _upsert(Consultation consultation) {
    if (!mounted) return;
    setState(() => _items[consultation.id] = consultation);
    widget.onChanged?.call(_sorted);
  }

  List<Consultation> get _sorted => _items.values.toList()
    ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

  Future<void> _open(Consultation consultation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatPage(consultation: consultation)),
    );
    reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load your consultations.'),
            TextButton(onPressed: reload, child: const Text('Retry')),
          ],
        ),
      );
    }

    final query = widget.filter.trim().toLowerCase();
    final items = _sorted.where((c) {
      if (query.isEmpty) return true;
      final name = widget.doctorView ? c.patientName : c.doctorName;
      return name.toLowerCase().contains(query) ||
          (c.lastMessagePreview ?? '').toLowerCase().contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: reload,
      child: items.isEmpty
          ? ListView(children: [const SizedBox(height: 80), widget.emptyView])
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _ConsultationTile(
                consultation: items[index],
                doctorView: widget.doctorView,
                onTap: () => _open(items[index]),
              ),
            ),
    );
  }
}

class _ConsultationTile extends StatelessWidget {
  final Consultation consultation;
  final bool doctorView;
  final VoidCallback onTap;

  const _ConsultationTile({
    required this.consultation,
    required this.doctorView,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = consultation;
    final name = doctorView ? c.patientName : c.doctorName;
    final avatar = doctorView ? c.patientAvatarUrl : c.doctorAvatarUrl;
    final subtitleParts = [
      if (!doctorView) c.doctorSpecialization,
      c.type == ConsultationType.points ? 'Points' : 'Paid',
      if (!c.isActive) 'Ended',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: onTap,
      leading: UserAvatar(name: name, imageUrl: avatar, radius: 26),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitleParts.join(' · '),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            c.lastMessagePreview ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.unreadCount > 0 ? Colors.black87 : Colors.grey.shade700,
              fontWeight: c.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatRelative(c.lastActivityAt),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          if (c.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${c.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
