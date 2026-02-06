import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gesport/screens/dashboard_screen.dart';
import 'package:gesport/screens/home_screen.dart';
import 'package:gesport/screens/login_screen.dart';
import 'package:gesport/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        return FutureBuilder<String?>(
          future: AuthService().getUserRole(authSnapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF050B14),
                body: Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }

            if (roleSnapshot.hasError || roleSnapshot.data == null) {
              return const HomeScreen();
            }

            if (roleSnapshot.data == 'admin') {
              return const DashboardScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}