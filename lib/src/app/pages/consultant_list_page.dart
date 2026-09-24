import 'package:flutter/material.dart';

import '../components/consultant_profile_sheet.dart';
import '../components/payment_confirmation_dialog.dart';
import '../components/user_avatar.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/services.dart';
import '../utils/format.dart';
import 'chat_page.dart';

/// Approved doctors, best rated first. Starting a chat opens the payment dialog, then the chat.
class ConsultantListPage extends StatefulWidget {
  const ConsultantListPage({super.key});

  @override
  State<ConsultantListPage> createState() => _ConsultantListPageState();
}

class _ConsultantListPageState extends State<ConsultantListPage> {
  late Future<List<Doctor>> _doctors;
  String? _specialization;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _doctors = Services.backend.doctors(specialization: _specialization);
    });
  }

  Future<void> _startChat(Doctor doctor) async {
    final consultation = await showDialog<Consultation>(
      context: context,
      builder: (_) => PaymentConfirmationDialog(doctor: doctor),
    );
    if (consultation == null || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatPage(consultation: consultation)),
    );
  }

  void _showProfile(Doctor doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ConsultantProfileSheet(
        doctor: doctor,
        onStartChat: () {
          Navigator.pop(sheetContext);
          _startChat(doctor);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Consultant')),
      body: FutureBuilder<List<Doctor>>(
        future: _doctors,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error!, onRetry: _load);
          }
          final doctors = snapshot.data!;
          final specializations = {
            ...doctors.map((d) => d.specialization),
            ?_specialization,
          }.toList()..sort();

          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _specialization == null,
                        onTap: () {
                          _specialization = null;
                          _load();
                        },
                      ),
                      ...specializations.map(
                        (s) => _FilterChip(
                          label: s,
                          selected: _specialization == s,
                          onTap: () {
                            _specialization = s;
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (doctors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No doctors available right now.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...doctors.map(
                  (doctor) => _DoctorCard(
                    doctor: doctor,
                    onProfile: () => _showProfile(doctor),
                    onStartChat: () => _startChat(doctor),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onProfile;
  final VoidCallback onStartChat;

  const _DoctorCard({
    required this.doctor,
    required this.onProfile,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  name: doctor.name,
                  imageUrl: doctor.avatarUrl,
                  radius: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${doctor.specialization} · ${doctor.experienceYears} yrs',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            doctor.totalReviews == 0
                                ? 'New'
                                : '${doctor.rating.toStringAsFixed(1)} (${doctor.totalReviews})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatMoney(doctor.consultationFee)} / session  ·  or 100 points',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onProfile,
                    icon: const Icon(Icons.person),
                    label: const Text('View Profile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onStartChat,
                    child: const Text('Start Chat'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              error is ApiException
                  ? (error as ApiException).message
                  : 'Could not load doctors.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
