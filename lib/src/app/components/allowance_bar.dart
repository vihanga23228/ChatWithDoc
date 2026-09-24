import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/format.dart';

/// What the patient can still send in a points consultation: words, photos, voice and video time.
class AllowanceBar extends StatelessWidget {
  final Allowance allowance;

  const AllowanceBar({super.key, required this.allowance});

  @override
  Widget build(BuildContext context) {
    final remaining = allowance.remaining;
    final allowed = allowance.allowed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Item(
            icon: Icons.short_text,
            label: '${remaining.textWords}/${allowed.textWords} words',
            empty: remaining.textWords <= 0,
          ),
          _Item(
            icon: Icons.photo_outlined,
            label: '${remaining.photos}/${allowed.photos}',
            empty: remaining.photos <= 0,
          ),
          _Item(
            icon: Icons.mic_none,
            label: formatDuration(remaining.voiceSeconds),
            empty: remaining.voiceSeconds <= 0,
          ),
          _Item(
            icon: Icons.videocam_outlined,
            label: formatDuration(remaining.videoSeconds),
            empty: remaining.videoSeconds <= 0,
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool empty;

  const _Item({required this.icon, required this.label, required this.empty});

  @override
  Widget build(BuildContext context) {
    final color = empty ? Colors.red.shade400 : Colors.blue.shade800;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
