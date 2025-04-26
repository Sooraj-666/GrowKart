import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:growkart/screens/splash_screen.dart';
import 'package:growkart/screens/login_screen.dart'; // Import Login Screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GrowKart',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const SplashScreen(), // Splash Screen First
      routes: {
        '/login': (context) => LoginScreen(),
      },
    );
  }
}
