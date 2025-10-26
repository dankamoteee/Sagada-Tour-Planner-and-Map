import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sagada_tour_planner/screens/gradient_background.dart';
import 'package:sagada_tour_planner/screens/verify_email_screen.dart';
import 'verify_otp_screen.dart'; // You will create this file next

class VerificationChoiceScreen extends StatefulWidget {
  final String email;
  final String phone;

  const VerificationChoiceScreen({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  State<VerificationChoiceScreen> createState() =>
      _VerificationChoiceScreenState();
}

class _VerificationChoiceScreenState extends State<VerificationChoiceScreen> {
  bool _isSendingEmail = false;
  bool _isSendingOTP = false;

  // --- Function for Email Verification ---
  Future<void> _sendEmailVerification() async {
    // Disable buttons
    setState(() => _isSendingEmail = true);

    // Store context-sensitive objects
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();

        if (!mounted) return;

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Verification email sent.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to the email verifier screen
        navigator.push(
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(email: widget.email),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Re-enable buttons if mounted
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  // --- Function for Phone Verification ---
  void _goToPhoneVerification() {
    // We don't do any async work here, just navigate
    // The loading state is to prevent double-taps
    setState(() => _isSendingOTP = true);

    // We pass the phone number to the new OTP screen
    Navigator.push(
      context,
      MaterialPageRoute(
        // This is the screen you'll create in Step 4
        builder: (context) => VerifyOTPScreen(phoneNumber: widget.phone),
      ),
    ).then((_) {
      // This 'then' block runs when the user presses "back"
      // from the VerifyOTPScreen, re-enabling the button.
      if (mounted) {
        setState(() => _isSendingOTP = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if either button is loading to disable both
    final isLoading = _isSendingEmail || _isSendingOTP;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/logo.jpg',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sagada Tour Planner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 60),
                    const Text(
                      'Verify Your Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please choose a method to verify your account registered with:\n\nEmail: ${widget.email}\nPhone: ${widget.phone}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- Email Button ---
                    ElevatedButton.icon(
                      icon: const Icon(Icons.email_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          58,
                          106,
                          85,
                        ), // Your app's green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Disable if any button is loading
                      onPressed: isLoading ? null : _sendEmailVerification,
                      label:
                          _isSendingEmail
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : const Text('Verify with Email'),
                    ),

                    const SizedBox(height: 16),

                    // --- Phone Button ---
                    ElevatedButton.icon(
                      icon: const Icon(Icons.phone_android_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3), // Blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Disable if any button is loading
                      onPressed: isLoading ? null : _goToPhoneVerification,
                      label:
                          _isSendingOTP
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : const Text('Verify with Phone (OTP)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
