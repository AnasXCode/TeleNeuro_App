import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Ye naya import hai
import 'Splash/splash_screen.dart';

void main() async { // 2. Yahan 'async' likha hai
  WidgetsFlutterBinding.ensureInitialized(); // 3. Ye line App ko ready karti hai
  await Firebase.initializeApp(); // 4. Ye line Firebase start karti hai

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}