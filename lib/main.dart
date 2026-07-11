import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/guard/guard_home_screen.dart';
import 'screens/resident/resident_home_screen.dart';
import 'screens/resident/resident_events_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppTheme.instance.load();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('══════ FLUTTER ERROR STACK TRACE ══════');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString() ?? '(no stack)');
    debugPrint('═══════════════════════════════════════');
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, _) => MaterialApp(
        title: 'GateFlow',
        debugShowCheckedModeBanner: false,
        themeMode: AppTheme.instance.mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.accent),
          scaffoldBackgroundColor: Colors.grey.shade50,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.accent, brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF121212),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getSession(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final session = snap.data ?? {};
        if (session['is_logged_in'] != 'true') return const LoginScreen();

        switch (session['role']) {
          case 'admin':
            return const AdminHomeScreen();
          case 'guard':
            return const GuardHomeScreen();
          default:
            // Admin-configurable in Community Settings — defaults to Home.
            return session['residentLandingScreen'] == 'events'
                ? const ResidentEventsScreen()
                : const ResidentHomeScreen();
        }
      },
    );
  }
}

Future<Map<String, String>> _getSession() async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final role = prefs.getString('session_role') ?? '';

  String residentLandingScreen = 'home';
  if (isLoggedIn && role != 'admin' && role != 'guard') {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get();
      residentLandingScreen =
          (doc.data()?['residentLandingScreen'] as String?) ?? 'home';
    } catch (_) {}
  }

  return {
    'is_logged_in': isLoggedIn.toString(),
    'role': role,
    'residentLandingScreen': residentLandingScreen,
  };
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A73E8),
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
