import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:sagada_tour_planner/screens/gradient_background.dart';
import 'otp_verified.dart';

class OTPVerificationScreen extends StatelessWidget {
  final String email;

  const OTPVerificationScreen({super.key, required this.email});

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
                  // Logo and App Name
                  Image.asset('assets/images/logo.jpg', width: 80, height: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Sagada Tour Planner',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    'Verify Email',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'A verification code has been sent to $email',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter the code sent to your email',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  // OTP Field (6-digit)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: OtpTextField(
                      numberOfFields: 6,
                      borderColor: Colors.red, // Sets default border color
                      focusedBorderColor:
                          Colors.black, // Sets focused border color
                      showFieldAsBox: true,
                      fieldWidth: 45, // Optional: adjust width if needed
                      borderRadius: BorderRadius.circular(
                        10,
                      ), // Increased corner radius
                      onCodeChanged: (String code) {
                        // Handle real-time code change if needed
                      },
                      onSubmit: (String verificationCode) {
                        print("Entered Code: $verificationCode");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    EmailVerifiedScreen(userEmail: email),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Resend Option
                  GestureDetector(
                    onTap: () {
                      // Your resend code logic here
                    },
                    child: const Text(
                      'Did not receive code? Resend.',
                      style: TextStyle(fontSize: 14, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
