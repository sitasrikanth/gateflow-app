import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/guard/guard_home_screen.dart';
import 'screens/resident/resident_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GateFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
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
            return const ResidentHomeScreen();
        }
      },
    );
  }
}

Future<Map<String, String>> _getSession() async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final role = prefs.getString('session_role') ?? '';
  return {
    'is_logged_in': isLoggedIn.toString(),
    'role': role,
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
