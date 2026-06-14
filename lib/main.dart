import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pin_entry_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/guard/guard_home_screen.dart';
import 'screens/resident/resident_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Reset session flags on every app launch — forces PIN/code entry each time
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('pin_verified_session', false);

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
    // Always check full user state (handles guard sessions + Firebase Auth)
    return FutureBuilder<_UserState>(
      future: _getUserState(FirebaseAuth.instance.currentUser?.uid),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final state = userSnap.data;
        if (state == null) return const LoginScreen();

        // Guard session (no Firebase Auth needed)
        if (state.isGuardSession) {
          if (!state.pinVerifiedThisSession) return const LoginScreen();
          return const GuardHomeScreen();
        }

        // Not logged in via Firebase Auth
        if (FirebaseAuth.instance.currentUser == null) {
          return const LoginScreen();
        }

        // No profile yet
        if (!state.profileExists) return const LoginScreen();

        // Resident pending approval
        if (state.status == 'pending' || state.status == 'inactive') {
          return const PendingApprovalScreen();
        }

        // PIN not set → set PIN first
        if (!state.pinSet) {
          return const PinSetupScreen();
        }

        // PIN set but not verified this session
        if (!state.pinVerifiedThisSession) {
          return const PinEntryScreen();
        }

        // Route by role
        if (state.role == 'guard') return const GuardHomeScreen();
        if (state.role == 'admin') return const AdminHomeScreen();
        return const ResidentHomeScreen();
      },
    );
  }
}

Future<_UserState> _getUserState(String? uid) async {
  final prefs = await SharedPreferences.getInstance();
  final savedPin = prefs.getString('user_pin') ?? '';
  final pinVerified = prefs.getBool('pin_verified_session') ?? false;
  final pinSet = savedPin.isNotEmpty;
  final isGuardSession = prefs.getBool('is_guard_session') ?? false;

  // Guard session — no Firebase Auth needed
  if (isGuardSession) {
    return _UserState(
      profileExists: true,
      role: 'guard',
      status: 'active',
      pinSet: true,
      pinVerifiedThisSession: pinVerified,
      isGuardSession: true,
    );
  }

  if (uid == null) return _UserState(profileExists: false);

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  if (!userDoc.exists) {
    return _UserState(profileExists: false);
  }

  final data = userDoc.data()!;
  final role = data['role'] ?? 'resident';
  final status = data['status'] ?? 'active';

  return _UserState(
    profileExists: true,
    role: role,
    status: status,
    pinSet: pinSet,
    pinVerifiedThisSession: pinVerified,
  );
}

class _UserState {
  final bool profileExists;
  final String role;
  final String status;
  final bool pinSet;
  final bool pinVerifiedThisSession;
  final bool isGuardSession;

  _UserState({
    this.profileExists = false,
    this.role = 'resident',
    this.status = 'active',
    this.pinSet = false,
    this.pinVerifiedThisSession = false,
    this.isGuardSession = false,
  });
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A73E8),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
