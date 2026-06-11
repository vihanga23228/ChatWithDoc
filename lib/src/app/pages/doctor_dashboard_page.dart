import 'package:flutter/material.dart';
import 'package:chat_with_doc/pages/login_page.dart';
import 'package:chat_with_doc/src/app/models/users.dart';
import 'package:chat_with_doc/src/app/services/app_storage.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  ConsultantUser? consultant;
  final _searchController = TextEditingController();

  final _patientChats = const [
    _PatientChat(
      name: 'Amir Perera',
      lastMessage:
          'Doctor, I have been experiencing chest pain for the past two days.',
      time: '10:32 AM',
      unread: 2,
      status: 'active',
      messagesLeft: 7,
    ),
    _PatientChat(
      name: 'Nadeesha Silva',
      lastMessage: 'Thank you doctor, I will follow the prescription.',
      time: '9:15 AM',
      unread: 0,
      status: 'completed',
      messagesLeft: 0,
    ),
    _PatientChat(
      name: 'Kasun Fernando',
      lastMessage: 'My blood pressure readings have been fluctuating.',
      time: 'Yesterday',
      unread: 1,
      status: 'active',
      messagesLeft: 4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    consultant = AppStorage.currentConsultant;
    if (consultant == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
    }
  }

  void _handleLogout() {
    AppStorage.currentConsultant = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (consultant == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final initials = consultant!.name
        .split(' ')
        .map((part) => part.isEmpty ? '' : part[0])
        .join()
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue.shade700,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            consultant!.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            consultant!.specialization,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'SLMC: ${consultant!.slmcNumber}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(
                              consultant!.status == 'approved'
                                  ? 'Verified'
                                  : 'Pending Review',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: consultant!.status == 'approved'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wallet Balance',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${consultant!.walletBalance.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consultation Requests',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_patientChats.length}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patient chats',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFEFF6FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredChats().length,
                itemBuilder: (context, index) {
                  final chat = _filteredChats()[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        chat.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            chat.lastMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                chat.time,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (chat.unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${chat.unread} new',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Text(
                        chat.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_PatientChat> _filteredChats() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _patientChats;
    return _patientChats.where((chat) {
      return chat.name.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query);
    }).toList();
  }
}

class _PatientChat {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final String status;
  final int messagesLeft;

  const _PatientChat({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.status,
    required this.messagesLeft,
  });
}
