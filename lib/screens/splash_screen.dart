import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sagada_tour_planner/screens/gradient_background.dart';
import 'package:sagada_tour_planner/screens/login_screen.dart';
import 'package:sagada_tour_planner/screens/terms_screen.dart';
import 'package:sagada_tour_planner/screens/map_homescreen.dart'; // replace with your actual home screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Show splash for 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('accepted_terms') ?? false;

    if (user == null) {
      // Not logged in → go to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (!accepted) {
      // Logged in but terms not accepted → go to Terms
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TermsAgreementScreen()),
      );
    } else {
      // Logged in + terms accepted → go to Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MapScreen(),
        ), // replace with your actual home
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.jpg', width: 80, height: 80),
              const SizedBox(height: 16),
              const Text(
                'Sagada Tour Planner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
