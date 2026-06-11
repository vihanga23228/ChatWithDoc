import 'package:flutter/material.dart';
import 'package:chat_with_doc/src/app/services/app_storage.dart';
import '../models/users.dart';
import '../components/consultant_profile_sheet.dart';

class ChatPage extends StatefulWidget {
  final ConsultantUser consultant;
  final String patientEmail;
  final bool initialPaid;

  const ChatPage({
    super.key,
    required this.consultant,
    required this.patientEmail,
    this.initialPaid = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _paid = widget.initialPaid;
    _loadMessages();
  }

  void _loadMessages() {
    final session = AppStorage.getChatSession(
      widget.patientEmail,
      widget.consultant.id,
    );
    if (session != null) {
      _messages.addAll(
        session.messages.map(
          (message) =>
              _ChatMessage(text: message.text, fromUser: message.fromUser),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _messages.add(
        _ChatMessage(
          text: 'Thanks for your message. I will review and respond shortly.',
          fromUser: false,
        ),
      );
      _controller.clear();
    });

    AppStorage.addChatMessage(
      widget.patientEmail,
      widget.consultant.id,
      widget.consultant.name,
      widget.consultant.specialization,
      widget.consultant.avatarUrl,
      text,
      true,
    );

    AppStorage.addChatMessage(
      widget.patientEmail,
      widget.consultant.id,
      widget.consultant.name,
      widget.consultant.specialization,
      widget.consultant.avatarUrl,
      'Thanks for your message. I will review and respond shortly.',
      false,
    );
  }

  void _showConsultantProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConsultantProfileSheet(
        consultant: widget.consultant,
        buttonLabel: 'Close',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: widget.consultant.avatarUrl != null
                  ? NetworkImage(widget.consultant.avatarUrl!)
                  : null,
              child: widget.consultant.avatarUrl == null
                  ? Text(
                      widget.consultant.name[0],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.consultant.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    widget.consultant.specialization,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'View Profile',
            onPressed: _showConsultantProfile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_paid)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Limited access chat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pay now to start your consultation and send messages.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _paid = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Payment successful. You can now chat.',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                        ),
                        child: const Text('Pay & Start Chat'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        _paid
                            ? 'Send the first message to begin your consultation.'
                            : 'Complete payment to unlock chat access.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.fromUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.fromUser
                                ? Colors.blue.shade700
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: message.fromUser
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_paid)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 18,
                        ),
                      ),
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromUser;

  _ChatMessage({required this.text, required this.fromUser});
}
