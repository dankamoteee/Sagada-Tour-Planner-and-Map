import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sagada_tour_planner/screens/gradient_background.dart';
import 'email_verified_screen.dart';

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
    canResendEmail = true; // Start with button enabled
    _sendVerificationEmail();

    // Periodically check if the email is verified
    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkEmailVerified(),
    );
  }

  Future<void> _sendVerificationEmail() async {
    try {
      setState(() => canResendEmail = false);

      User? user = FirebaseAuth.instance.currentUser;

      // Wait for Firebase to populate the user object
      int retries = 0;
      while (user == null && retries < 5) {
        await Future.delayed(const Duration(milliseconds: 300));
        user = FirebaseAuth.instance.currentUser;
        retries++;
      }

      if (user == null) {
        throw Exception("User is not signed in yet.");
      }

      await user.sendEmailVerification();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email sent.")),
        );
      });

      // Cooldown before allowing resend
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) setState(() => canResendEmail = true);
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to send verification email: $e")),
          );
        });
        setState(() => canResendEmail = true);
      }
    }
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if (user != null && user.emailVerified) {
      setState(() => isEmailVerified = true);
      timer?.cancel();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isVerified': true},
      );

      // Sign out after successful verification
      //await FirebaseAuth.instance.signOut();

      // Move to success screen instead of login immediately
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const EmailVerifiedScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    'Verify Email',
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
                      canResendEmail ? 'Resend Email' : 'Sending...',
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
