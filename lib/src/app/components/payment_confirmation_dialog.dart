import 'package:flutter/material.dart';

import '../models/models.dart';
import '../pages/wallet_page.dart';
import '../services/api_client.dart';
import '../services/services.dart';
import '../utils/format.dart';
import 'user_avatar.dart';

/// Lets the patient choose how to pay (card, wallet or points) and starts the consultation.
/// Pops with the started [Consultation], or null if cancelled.
class PaymentConfirmationDialog extends StatefulWidget {
  final Doctor doctor;

  const PaymentConfirmationDialog({super.key, required this.doctor});

  @override
  State<PaymentConfirmationDialog> createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  PaymentOption _option = PaymentOption.card;
  Wallet? _wallet;
  bool _submitting = false;
  String? _error;
  bool _needsFunds = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await Services.backend.wallet();
      if (mounted) setState(() => _wallet = wallet);
    } on ApiException {
      // The dialog still works without balances.
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
      _needsFunds = false;
    });
    try {
      final consultation = await Services.backend.startConsultation(
        widget.doctor.id,
        _option,
      );
      if (mounted) Navigator.of(context).pop(consultation);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Already chatting with this doctor: open that consultation instead.
        final existing = await _findActiveConsultation();
        if (existing != null && mounted) {
          Navigator.of(context).pop(existing);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.details;
        _needsFunds = e.statusCode == 402;
      });
    }
  }

  Future<Consultation?> _findActiveConsultation() async {
    try {
      final all = await Services.backend.consultations();
      for (final c in all) {
        if (c.doctorId == widget.doctor.id && c.isActive) return c;
      }
    } on ApiException {
      // Fall through to showing the error.
    }
    return null;
  }

  Future<void> _openWallet() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WalletPage()));
    setState(() {
      _error = null;
      _needsFunds = false;
    });
    _loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final wallet = _wallet;
    final pointsCost = wallet?.consultationPointsCost ?? 100;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Start Consultation',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                UserAvatar(name: doctor.name, imageUrl: doctor.avatarUrl),
                const SizedBox(width: 12),
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
                      Text(
                        doctor.specialization,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'How would you like to pay?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              selected: _option == PaymentOption.card,
              icon: Icons.credit_card,
              title: 'Card · ${formatMoney(doctor.consultationFee)}',
              subtitle: 'Unlimited messages',
              onTap: () => setState(() => _option = PaymentOption.card),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              selected: _option == PaymentOption.wallet,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet · ${formatMoney(doctor.consultationFee)}',
              subtitle: wallet == null
                  ? 'Unlimited messages'
                  : 'Unlimited messages · balance ${formatMoney(wallet.balance)}',
              onTap: () => setState(() => _option = PaymentOption.wallet),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              selected: _option == PaymentOption.points,
              icon: Icons.stars_outlined,
              title: 'Points · $pointsCost points',
              subtitle:
                  '100 words, 5 photos, 3 min voice, 1 min video'
                  '${wallet == null ? '' : ' · you have ${wallet.points}'}',
              onTap: () => setState(() => _option = PaymentOption.points),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                    if (_needsFunds)
                      TextButton.icon(
                        onPressed: _openWallet,
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('Top up / buy points'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _confirm,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _option == PaymentOption.points
                                ? 'Use points'
                                : 'Confirm & Pay',
                          ),
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

class _OptionTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue.shade700 : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? Colors.blue.shade50 : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }
}
