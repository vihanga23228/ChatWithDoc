import 'package:flutter/material.dart';

import '../utils/format.dart';

/// A round avatar that shows the photo when there is one, and initials otherwise.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      // No network or a broken URL: keep showing the initials instead of logging an error.
      onForegroundImageError: imageUrl != null ? (_, _) {} : null,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
