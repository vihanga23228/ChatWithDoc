import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../utils/format.dart';
import 'user_avatar.dart';

/// A doctor's public profile with their latest reviews.
class ConsultantProfileSheet extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onStartChat;
  final String buttonLabel;

  const ConsultantProfileSheet({
    super.key,
    required this.doctor,
    this.onStartChat,
    this.buttonLabel = 'Start Chat',
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              _Header(doctor: doctor),
              if (doctor.about != null)
                _Section(
                  title: 'About',
                  child: Text(
                    doctor.about!,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                  ),
                ),
              const Divider(),
              _Section(
                title: 'Details',
                child: Column(
                  children: [
                    _DetailItem(
                      icon: Icons.badge_outlined,
                      label: 'SLMC Registration',
                      value: doctor.slmcNumber,
                    ),
                    if (doctor.hospital != null)
                      _DetailItem(
                        icon: Icons.location_on,
                        label: 'Current Hospital',
                        value: doctor.hospital!,
                      ),
                    _DetailItem(
                      icon: Icons.work_history,
                      label: 'Experience',
                      value: '${doctor.experienceYears} years',
                    ),
                    if (doctor.degree != null)
                      _DetailItem(
                        icon: Icons.school,
                        label: 'Education',
                        value: doctor.university == null
                            ? doctor.degree!
                            : '${doctor.degree} from ${doctor.university}',
                      ),
                    _DetailItem(
                      icon: Icons.language,
                      label: 'Languages',
                      value: doctor.languages.join(', '),
                    ),
                    _DetailItem(
                      icon: Icons.payments_outlined,
                      label: 'Consultation Fee',
                      value: formatMoney(doctor.consultationFee),
                      valueColor: Colors.blue.shade700,
                    ),
                  ],
                ),
              ),
              const Divider(),
              _Section(
                title: 'Patient Reviews',
                child: _Reviews(doctorId: doctor.id),
              ),
              if (onStartChat != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: onStartChat,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Doctor doctor;

  const _Header({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          UserAvatar(name: doctor.name, imageUrl: doctor.avatarUrl, radius: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.specialization,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      doctor.totalReviews == 0
                          ? 'No reviews yet'
                          : '${doctor.rating.toStringAsFixed(1)} (${doctor.totalReviews} reviews)',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  final String doctorId;

  const _Reviews({required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: Services.backend.doctorReviews(doctorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) {
          return Text(
            'No reviews yet.',
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return Column(
          children: reviews.take(5).map((review) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star,
                    size: 14,
                    color: i < review.rating
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                ),
              ),
              title: Text(review.comment ?? 'No comment'),
              subtitle: Text(
                '${review.patientName} · ${formatRelative(review.createdAt)}',
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
