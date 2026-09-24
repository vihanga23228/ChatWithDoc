import 'package:flutter/material.dart';

import '../models/models.dart';
import '../navigation.dart';
import '../services/services.dart';
import '../utils/format.dart';

/// Admin: review doctor registrations (approve / reject with a reason).
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  DoctorStatus _status = DoctorStatus.pending;
  late Future<List<DoctorProfile>> _doctors;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _doctors = Services.backend.doctorsByStatus(_status));
  }

  Future<void> _approve(DoctorProfile doctor) async {
    try {
      await Services.backend.approveDoctor(doctor.id);
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reject(DoctorProfile doctor) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reject ${doctor.name}?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLength: 255,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await Services.backend.rejectDoctor(doctor.id, reason);
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor approvals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<DoctorStatus>(
              segments: const [
                ButtonSegment(value: DoctorStatus.pending, label: Text('Pending')),
                ButtonSegment(value: DoctorStatus.approved, label: Text('Approved')),
                ButtonSegment(value: DoctorStatus.rejected, label: Text('Rejected')),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                _status = selection.first;
                _load();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DoctorProfile>>(
              future: _doctors,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doctors = snapshot.data ?? const [];
                if (doctors.isEmpty) {
                  return const Center(child: Text('Nothing here.'));
                }
                return ListView.builder(
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final d = doctors[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(d.name),
                        subtitle: Text(
                          '${d.specialization}\nSLMC ${d.slmcNumber} · ${d.email}\n'
                          'Fee ${formatMoney(d.consultationFee)}'
                          '${d.rejectionReason == null ? '' : '\nReason: ${d.rejectionReason}'}',
                        ),
                        isThreeLine: true,
                        trailing: _status == DoctorStatus.approved
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    onPressed: () => _approve(d),
                                  ),
                                  if (_status == DoctorStatus.pending)
                                    IconButton(
                                      tooltip: 'Reject',
                                      icon: const Icon(Icons.cancel, color: Colors.red),
                                      onPressed: () => _reject(d),
                                    ),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
