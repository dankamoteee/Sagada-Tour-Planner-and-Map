import 'package:flutter/material.dart';
import 'dart:async';

class FacebookLoadingScreen extends StatefulWidget {
  const FacebookLoadingScreen({super.key});

  @override
  State<FacebookLoadingScreen> createState() => _FacebookLoadingScreenState();
}

class _FacebookLoadingScreenState extends State<FacebookLoadingScreen> {
  @override
  void initState() {
    super.initState();

    // Simulate Facebook OAuth process
    Future.delayed(const Duration(seconds: 3), () {
      // Navigate to home screen (replace with your route)
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F0FF), Color(0xFFC1C0DF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset('assets/images/logo.jpg', height: 100),
                const SizedBox(height: 16),

                const Text(
                  'Sagada Tour Planner',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // Loading Indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF1877F2), // Facebook blue
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Logging in with Facebook...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 58, 106, 85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
