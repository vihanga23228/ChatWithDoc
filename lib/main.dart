import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'src/app/navigation.dart';
import 'src/app/services/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Services.api.onSessionExpired = handleSessionExpired;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Micro Consultation',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const StartupPage(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Restores the saved session (if any) and opens the right home screen, otherwise the login screen.
class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final user = await Services.auth.restoreSession();
    if (!mounted) return;
    if (user != null) {
      goHome(context, user);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
