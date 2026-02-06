import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gesport/auth/auth_gate.dart';
import 'firebase_options.dart';

void main() async{
  if(Firebase.apps.isEmpty){
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Gesport',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E5CAD)),
          useMaterial3: true,
        ),
        home: const AuthGate()
    );
  }
}
