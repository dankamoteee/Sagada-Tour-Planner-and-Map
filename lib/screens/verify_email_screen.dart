import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sagada_tour_planner/screens/gradient_background.dart';
import 'email_verified_screen.dart'; // Your success screen

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    // 1. Start with the Resend button DISABLED
    canResendEmail = false;

    // 2. Enable it after a 10-second cooldown
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => canResendEmail = true);
      }
    });

    // 3. Start checking for verification every 3 seconds
    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkEmailVerified(),
    );
  }

  @override
  void dispose() {
    timer?.cancel(); // Stop the timer when the screen is closed!
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    // Store context-sensitive objects
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      setState(() => canResendEmail = false);

      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Verification email sent."),
          backgroundColor: Colors.green,
        ),
      );

      // Cooldown before allowing resend
      await Future.delayed(const Duration(seconds: 10));
      if (mounted) setState(() => canResendEmail = true);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Failed to send verification email: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => canResendEmail = true);
      }
    }
  }

  Future<void> _checkEmailVerified() async {
    // Store the navigator before the await
    final navigator = Navigator.of(context);
    final user = FirebaseAuth.instance.currentUser;

    // We must reload the user to get the latest emailVerified status
    await user?.reload();

    if (user != null && user.emailVerified) {
      setState(() => isEmailVerified = true);
      timer?.cancel(); // Stop the timer

      // Update their status in your database
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isVerified': true},
      );

      // Sign out *after* they are verified
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Move to success screen
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const EmailVerifiedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.jpg', width: 80, height: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Sagada Tour Planner',
                    style: TextStyle(
                      height: 1,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),
                  const Text(
                    'Check Your Email',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'A verification email has been sent to:\n${widget.email}\n\nPlease check your inbox (and spam folder).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 58, 106, 85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: canResendEmail ? _sendVerificationEmail : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 58, 106, 85),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      canResendEmail ? 'Resend Email' : 'Wait to Resend',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
