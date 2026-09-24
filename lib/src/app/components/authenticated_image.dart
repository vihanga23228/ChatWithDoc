import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/services.dart';

/// Shows a chat photo. Media is protected (medical data), so it is downloaded through the API client with the
/// user's token instead of a plain [Image.network]. Downloads are cached for the app session.
class AuthenticatedImage extends StatefulWidget {
  final String mediaUrl;

  const AuthenticatedImage({super.key, required this.mediaUrl});

  static final Map<String, Future<Uint8List>> _cache = {};

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = AuthenticatedImage._cache.putIfAbsent(
      widget.mediaUrl,
      () => Services.backend.mediaBytes(widget.mediaUrl),
    );
  }

  void _retry() {
    AuthenticatedImage._cache.remove(widget.mediaUrl);
    setState(() {
      _bytes = AuthenticatedImage._cache.putIfAbsent(
        widget.mediaUrl,
        () => Services.backend.mediaBytes(widget.mediaUrl),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () => _openFullScreen(context, snapshot.data!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                width: 220,
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.broken_image_outlined),
            label: const Text('Tap to retry'),
          );
        }
        return const SizedBox(
          width: 220,
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  void _openFullScreen(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
        ),
      ),
    );
  }
}
