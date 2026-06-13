import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/guard/guard_home_screen.dart';
import 'screens/resident/resident_home_screen.dart';

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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A73E8),
            body: Center(
                child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        // Not logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // Logged in — check role in Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF1A73E8),
                body: Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              );
            }

            final role = userSnap.data?.get('role') ?? 'resident';

            if (role == 'guard') {
              return const GuardHomeScreen();
            } else if (role == 'admin') {
              // Admin panel coming soon
              return const GuardHomeScreen();
            } else {
              return const ResidentHomeScreen();
            }
          },
        );
      },
    );
  }
}
