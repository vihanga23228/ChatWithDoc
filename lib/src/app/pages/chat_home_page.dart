import 'package:flutter/material.dart';

import '../components/consultation_list.dart';
import '../models/models.dart';
import '../navigation.dart';
import '../services/services.dart';
import '../utils/format.dart';
import 'consultant_list_page.dart';
import 'wallet_page.dart';

/// The patient's home: their consultations (live), wallet shortcut, and a button to start a new chat.
class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final _listKey = GlobalKey<LiveConsultationListState>();
  Wallet? _wallet;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await Services.backend.wallet();
      if (mounted) setState(() => _wallet = wallet);
    } catch (_) {
      // The chip just stays hidden.
    }
  }

  Future<void> _openDoctors() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ConsultantListPage()));
    _listKey.currentState?.reload();
    _loadWallet();
  }

  Future<void> _openWallet() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WalletPage()));
    _loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final user = Services.auth.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          if (_wallet != null)
            TextButton.icon(
              onPressed: _openWallet,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.stars, size: 18),
              label: Text('${_wallet!.points} pts'),
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.blue.shade700),
                accountName: Text(user?.name ?? ''),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    initialsOf(user?.name ?? '?'),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Chats'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.person_search),
                title: const Text('Find a doctor'),
                onTap: () {
                  Navigator.pop(context);
                  _openDoctors();
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Wallet & points'),
                subtitle: _wallet == null
                    ? null
                    : Text(
                        '${formatMoney(_wallet!.balance)} · ${_wallet!.points} points',
                      ),
                onTap: () {
                  Navigator.pop(context);
                  _openWallet();
                },
              ),
              const Spacer(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () => logout(context),
              ),
            ],
          ),
        ),
      ),
      body: LiveConsultationList(
        key: _listKey,
        doctorView: false,
        emptyView: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new consultation with a specialist',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openDoctors,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New chat'),
      ),
    );
  }
}
