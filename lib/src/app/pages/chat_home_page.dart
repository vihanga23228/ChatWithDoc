import 'package:flutter/material.dart';
import 'package:chat_with_doc/pages/login_page.dart';
import 'package:chat_with_doc/src/app/components/account_type_selector.dart';
import 'package:chat_with_doc/src/app/pages/consultant_list_page.dart';
import 'package:chat_with_doc/src/app/services/app_storage.dart';
import 'package:chat_with_doc/src/app/pages/chat_page.dart';

class ChatHomePage extends StatefulWidget {
  final AccountType accountType;
  final String userName;

  const ChatHomePage({
    super.key,
    required this.accountType,
    required this.userName,
  });

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  late List<ChatSession> _chatSessions;

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  void _loadChatSessions() {
    final patientEmail = AppStorage.currentPatient?.email ?? '';
    if (patientEmail.isNotEmpty) {
      _chatSessions = AppStorage.getPatientChatHistory(patientEmail)
        ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    } else {
      _chatSessions = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConsultant = widget.accountType == AccountType.consultant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue.shade700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 32, color: Colors.blue),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Micro Consultation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Secure patient chat',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Chats'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.person_search),
                title: const Text('New Chat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ConsultantListPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & feedback'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: isConsultant
            ? _ConsultantChatList()
            : _PatientChatList(
                chatSessions: _chatSessions,
                onRefresh: _loadChatSessions,
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isConsultant
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConsultantListPage(),
                  ),
                );
                // Refresh chats when returning from consultant list
                setState(() {
                  _loadChatSessions();
                });
              },
              backgroundColor: Colors.blue.shade700,
              child: const Icon(Icons.chat_bubble_outline),
            ),
    );
  }
}

class _PatientChatList extends StatelessWidget {
  final List<ChatSession> chatSessions;
  final VoidCallback onRefresh;

  const _PatientChatList({required this.chatSessions, required this.onRefresh});

  String _getTimeString(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (chatSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: chatSessions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final session = chatSessions[index];
        final lastMessage = session.getLastMessage();
        final timeString = _getTimeString(session.lastMessageTime);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.blue.shade200,
            backgroundImage: session.consultantAvatar != null
                ? NetworkImage(session.consultantAvatar!)
                : null,
            child: session.consultantAvatar == null
                ? Text(
                    session.consultantName[0],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  )
                : null,
          ),
          title: Text(
            session.consultantName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                session.consultantSpecialization,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
          trailing: Text(
            timeString,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          onTap: () async {
            final consultant = AppStorage.consultants.firstWhere(
              (c) => c.id == session.consultantId,
            );
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  consultant: consultant,
                  patientEmail: AppStorage.currentPatient?.email ?? '',
                ),
              ),
            );
            onRefresh();
          },
        );
      },
    );
  }
}

class _ConsultantChatList extends StatelessWidget {
  const _ConsultantChatList();

  @override
  Widget build(BuildContext context) {
    final chats = const [
      {
        'name': 'Patient: Sahana',
        'msg': 'Heart palpitations',
        'time': '09:10 AM',
        'unread': 1,
        'image': 'https://i.pravatar.cc/150?img=12',
      },
      {
        'name': 'Patient: Arjun',
        'msg': 'Diet consultation',
        'time': 'Yesterday',
        'unread': 0,
        'image': 'https://i.pravatar.cc/150?img=20',
      },
    ];

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = chats[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.blue.shade200,
            backgroundImage: NetworkImage(c['image'] as String),
          ),
          title: Text(
            c['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            c['msg'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                c['time'] as String,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              if ((c['unread'] as int) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${c['unread']}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          onTap: () {},
        );
      },
    );
  }
}
