import 'package:flutter/material.dart';
import 'package:chat_with_doc/src/app/components/payment_confirmation_dialog.dart';
import 'package:chat_with_doc/src/app/services/app_storage.dart';
import '../models/users.dart';
import '../components/consultant_profile_sheet.dart';
import 'chat_page.dart';

class ConsultantListPage extends StatelessWidget {
  const ConsultantListPage({super.key});

  Future<void> _openPaymentConfirmation(
    BuildContext context,
    ConsultantUser consultant,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PaymentConfirmationDialog(consultant: consultant),
    );

    if (confirmed == true) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatPage(
            consultant: consultant,
            patientEmail: AppStorage.currentPatient?.email ?? '',
            initialPaid: true,
          ),
        ),
      );
    }
  }

  void _showProfileSheet(BuildContext context, ConsultantUser consultant) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ConsultantProfileSheet(
        consultant: consultant,
        onStartChat: () {
          Navigator.pop(sheetContext);
          _openPaymentConfirmation(parentContext, consultant);
        },
        buttonLabel: 'Start Chat',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Consultant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: AppStorage.consultants.length,
          itemBuilder: (context, index) {
            final consultant = AppStorage.consultants[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue.shade700,
                          backgroundImage: consultant.avatarUrl != null
                              ? NetworkImage(consultant.avatarUrl!)
                              : null,
                          child: consultant.avatarUrl == null
                              ? Text(
                                  consultant.name[0],
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                consultant.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                consultant.specialization,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${consultant.rating} (${consultant.totalReviews})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₹${consultant.consultationFee.toInt()} / session',
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
                            onPressed: () {
                              _showProfileSheet(context, consultant);
                            },
                            icon: const Icon(Icons.person),
                            label: const Text('View Profile'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _openPaymentConfirmation(context, consultant);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                            ),
                            child: const Text('Start Chat'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
