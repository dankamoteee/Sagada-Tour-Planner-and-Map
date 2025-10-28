import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- 1. ADD FIRESTORE IMPORT
import 'package:sagada_tour_planner/screens/gradient_background.dart';
import 'package:sagada_tour_planner/screens/login_screen.dart';
import 'package:sagada_tour_planner/screens/terms_screen.dart';
import 'package:sagada_tour_planner/screens/map_homescreen.dart';
import 'package:sagada_tour_planner/screens/verification_choice_screen.dart';

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

  // <-- 3. REPLACE YOUR _navigate FUNCTION WITH THIS -->
  Future<void> _navigate() async {
    // Show splash for 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // --- 1. NOT LOGGED IN ---
      // Go to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // --- 2. LOGGED IN ---
      // Now we MUST check if they are verified in Firestore
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!mounted) return;

      final bool isVerified;
      String email = user.email ?? '';
      String phone = '';

      if (userDoc.exists) {
        // Get verification status and user info from their document
        isVerified = userDoc.data()?['isVerified'] ?? false;
        email = userDoc.data()?['email'] ?? email;
        phone = userDoc.data()?['phone'] ?? '';
      } else {
        // This is a rare case (user exists in Auth but not Firestore)
        // Treat them as unverified
        isVerified = false;
      }

      if (!isVerified) {
        // --- 3. LOGGED IN, BUT NOT VERIFIED ---
        // This fixes your bug! Send them to verification.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => VerificationChoiceScreen(email: email, phone: phone),
          ),
        );
      } else {
        // --- 4. LOGGED IN AND VERIFIED ---
        // Now, we can check if they accepted the terms
        final prefs = await SharedPreferences.getInstance();
        final accepted = prefs.getBool('accepted_terms') ?? false;

        if (!accepted) {
          // --- 5. VERIFIED, BUT NOT ACCEPTED TERMS ---
          // Go to Terms
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TermsAgreementScreen()),
          );
        } else {
          // --- 6. VERIFIED AND ACCEPTED TERMS ---
          // Go to Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MapScreen()),
          );
        }
      }
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
                'Sagada Tour Planner and Map',
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
