import 'package:flutter/material.dart';

import '../../pages/login_page.dart';
import 'package:chat_with_doc_core/chat_with_doc_core.dart';
import 'pages/chat_home_page.dart';
import 'pages/doctor_dashboard_page.dart';
import 'services/services.dart';

/// Used to leave the current screen from outside the widget tree (e.g. when the session expires).
final navigatorKey = GlobalKey<NavigatorState>();

Widget homeFor(AppUser user) => switch (user.role) {
  Role.patient => const ChatHomePage(),
  Role.doctor => const DoctorDashboardPage(),
  Role.admin || Role.superAdmin => const _UseDesktopAppPage(),
};

/// Admins work in the ChatWithDoc Admin desktop app, not on the phone.
class _UseDesktopAppPage extends StatelessWidget {
  const _UseDesktopAppPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_windows_outlined, size: 64, color: Colors.blue.shade700),
              const SizedBox(height: 16),
              const Text(
                'Admin accounts use the ChatWithDoc Admin desktop app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// After login / registration: open the realtime connection and replace the whole stack with the home screen.
void goHome(BuildContext context, AppUser user) {
  Services.realtime.connect();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => homeFor(user)),
    (_) => false,
  );
}

Future<void> logout(BuildContext context) async {
  Services.realtime.disconnect();
  await Services.auth.logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (_) => false,
  );
}

/// Called by the API client when the refresh token is rejected.
void handleSessionExpired() {
  if (Services.auth.user == null) return;
  Services.realtime.disconnect();
  Services.auth.clearSession();
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (_) => false,
  );
  ScaffoldMessenger.of(navigator.context).showSnackBar(
    const SnackBar(content: Text('Your session has expired. Please log in again.')),
  );
}

/// Shows an error from the API (or anything else) as a snackbar.
void showError(BuildContext context, Object error) {
  final message = error is ApiException
      ? error.details
      : 'Something went wrong. Please try again.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
