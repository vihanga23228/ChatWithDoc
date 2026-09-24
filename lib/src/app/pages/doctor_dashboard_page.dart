import 'package:flutter/material.dart';

import '../components/consultation_list.dart';
import '../components/user_avatar.dart';
import '../models/models.dart';
import '../navigation.dart';
import '../services/services.dart';
import '../utils/format.dart';
import 'wallet_page.dart';

/// The doctor's home: approval status, earnings, and patient chats (live).
class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final _searchController = TextEditingController();
  DoctorProfile? _profile;
  int _activeCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await Services.backend.myDoctorProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _onConsultationsChanged(List<Consultation> consultations) {
    setState(() {
      _activeCount = consultations.where((c) => c.isActive).length;
      _unreadCount = consultations.fold(0, (sum, c) => sum + c.unreadCount);
    });
    // New earnings arrive with new consultations.
    _loadProfile();
  }

  Future<void> _openWallet() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WalletPage()));
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Wallet',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: _openWallet,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (profile == null)
              const LinearProgressIndicator()
            else ...[
              _ProfileCard(profile: profile),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Earnings',
                      value: formatMoney(profile.walletBalance),
                      detail: '${profile.points} points',
                      onTap: _openWallet,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Active chats',
                      value: '$_activeCount',
                      detail: _unreadCount == 0
                          ? 'All read'
                          : '$_unreadCount unread',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patient chats',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFEFF6FF),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LiveConsultationList(
                doctorView: true,
                filter: _searchController.text,
                onChanged: _onConsultationsChanged,
                emptyView: Text(
                  profile?.status == DoctorStatus.approved
                      ? 'No consultations yet. Patients will appear here as soon as they start a chat.'
                      : 'Patients can book you once your registration is approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DoctorProfile profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (profile.status) {
      DoctorStatus.approved => ('Verified', Colors.green),
      DoctorStatus.pending => ('Pending review', Colors.orange),
      DoctorStatus.rejected => ('Rejected', Colors.red),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(name: profile.name, radius: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${profile.specialization} · SLMC ${profile.slmcNumber}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: color,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      if (profile.totalReviews > 0) ...[
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(
                          ' ${profile.rating.toStringAsFixed(1)} (${profile.totalReviews})',
                        ),
                      ],
                    ],
                  ),
                  if (profile.status == DoctorStatus.rejected &&
                      profile.rejectionReason != null)
                    Text(
                      'Reason: ${profile.rejectionReason}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.detail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                detail,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
