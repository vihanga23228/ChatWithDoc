import 'package:flutter/material.dart';

import '../models/models.dart';
import '../navigation.dart';
import '../services/services.dart';
import '../utils/format.dart';

/// Balance, points and history. Patients can top up (card) and buy points (card or wallet);
/// doctors see their earnings read-only.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Wallet? _wallet;
  List<WalletTransaction> _transactions = const [];
  bool _loading = true;
  bool _busy = false;

  bool get _isPatient => Services.auth.user?.role == Role.patient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Services.backend.wallet(),
        Services.backend.walletTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as Wallet;
        _transactions = results[1] as List<WalletTransaction>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _run(Future<Wallet> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _topUp() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => const _TopUpDialog(),
    );
    if (amount == null) return;
    await _run(
      () => Services.backend.topUp(amount),
      '${formatMoney(amount)} added to your wallet',
    );
  }

  Future<void> _buyPoints() async {
    final wallet = _wallet;
    if (wallet == null) return;
    final choice = await showModalBottomSheet<(int, String)>(
      context: context,
      builder: (_) => _BuyPointsSheet(wallet: wallet),
    );
    if (choice == null) return;
    final (points, method) = choice;
    await _run(
      () => Services.backend.buyPoints(points, method),
      '$points points added',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (wallet != null)
                    Row(
                      children: [
                        Expanded(
                          child: _BalanceCard(
                            label: 'Balance',
                            value: formatMoney(wallet.balance),
                            icon: Icons.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BalanceCard(
                            label: 'Points',
                            value: '${wallet.points}',
                            icon: Icons.stars,
                          ),
                        ),
                      ],
                    ),
                  if (wallet != null && _isPatient) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${formatMoney(wallet.pricePerPoint * 100)} = 100 points · '
                      'a points consultation costs ${wallet.consultationPointsCost} points',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _topUp,
                            icon: const Icon(Icons.add_card),
                            label: const Text('Top up'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _buyPoints,
                            icon: const Icon(Icons.stars_outlined),
                            label: const Text('Buy points'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No transactions yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ..._transactions.map(_TransactionTile.new),
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _BalanceCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue.shade700),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;

  const _TransactionTile(this.tx);

  @override
  Widget build(BuildContext context) {
    final changes = [
      if (tx.amount != 0)
        '${tx.amount > 0 ? '+' : '-'}${formatMoney(tx.amount.abs())}',
      if (tx.points != 0) '${tx.points > 0 ? '+' : ''}${tx.points} pts',
    ].join('  ');
    final positive = tx.amount > 0 || (tx.amount == 0 && tx.points > 0);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: positive ? Colors.green.shade50 : Colors.red.shade50,
        child: Icon(
          positive ? Icons.south_west : Icons.north_east,
          color: positive ? Colors.green.shade700 : Colors.red.shade700,
          size: 18,
        ),
      ),
      title: Text(tx.description),
      subtitle: Text(formatRelative(tx.createdAt)),
      trailing: Text(
        changes,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: positive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

class _TopUpDialog extends StatefulWidget {
  const _TopUpDialog();

  @override
  State<_TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<_TopUpDialog> {
  final _controller = TextEditingController(text: '1000');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount < 100 || amount > 100000) {
      setState(() => _error = 'Enter an amount between Rs 100 and Rs 100,000');
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Top up by card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: 'Rs ',
              labelText: 'Amount',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [500, 1000, 2500, 5000]
                .map(
                  (v) => ActionChip(
                    label: Text('Rs $v'),
                    onPressed: () => _controller.text = '$v',
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Card payments are simulated in this version.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Pay')),
      ],
    );
  }
}

/// Pops with (points, "CARD" | "WALLET").
class _BuyPointsSheet extends StatefulWidget {
  final Wallet wallet;

  const _BuyPointsSheet({required this.wallet});

  @override
  State<_BuyPointsSheet> createState() => _BuyPointsSheetState();
}

class _BuyPointsSheetState extends State<_BuyPointsSheet> {
  static const _packages = [100, 200, 500, 1000];
  int _points = 100;
  String _method = 'CARD';

  @override
  Widget build(BuildContext context) {
    final price = widget.wallet.pricePerPoint * _points;
    final canUseWallet = widget.wallet.balance >= price;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buy points',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _packages
                  .map(
                    (p) => ChoiceChip(
                      label: Text('$p pts'),
                      selected: _points == p,
                      onSelected: (_) => setState(() => _points = p),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _method,
              onChanged: (value) => setState(() => _method = value!),
              child: Column(
                children: [
                  const RadioListTile<String>(
                    value: 'CARD',
                    title: Text('Card'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    value: 'WALLET',
                    enabled: canUseWallet,
                    title: Text(
                      'Wallet (balance ${formatMoney(widget.wallet.balance)})',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _method == 'WALLET' && !canUseWallet
                    ? null
                    : () => Navigator.of(context).pop((_points, _method)),
                child: Text('Pay ${formatMoney(price)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
