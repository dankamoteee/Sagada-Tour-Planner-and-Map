import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sagada_tour_planner/screens/gradient_background.dart';
import 'package:sagada_tour_planner/screens/email_verified_screen.dart'; // Your success screen

class VerifyOTPScreen extends StatefulWidget {
  final String phoneNumber;

  const VerifyOTPScreen({super.key, required this.phoneNumber});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  int? _resendToken;
  bool _isCodeSent = false;
  bool _isLoading = false;

  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOTP();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        if (mounted) {
          setState(() => _countdown--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOTP() async {
    _startTimer();

    await _auth.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // This is for auto-retrieval (e.g., on Android)
        // We can immediately try to verify
        if (mounted) {
          setState(() => _isLoading = true);
          _otpController.text = credential.smsCode ?? '';
          await _verifyOTP(credential: credential);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        // 🔽 ADD IT HERE INSTEAD 🔽
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (mounted) {
          setState(() => _isLoading = false);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Phone verification failed: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        // This is the main callback
        // Save the verification ID and resend token
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isCodeSent = true; // Show the OTP input field
          });
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Called when auto-retrieval times out
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isCodeSent = true; // Still show the OTP input field
          });
        }
      },
    );
  }

  Future<void> _verifyOTP({PhoneAuthCredential? credential}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Check if form is valid if we're not auto-retrieving
    if (credential == null) {
      if (!_formKey.currentState!.validate()) return;
    }

    if (_verificationId == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try resending the OTP.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create credential if not already provided
      final authCredential =
          credential ??
          PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: _otpController.text.trim(),
          );

      // --- THIS IS THE FIX ---
      User? user = _auth.currentUser;
      if (user == null) {
        // Wait up to 5 seconds for the auth state to restore
        await for (var authUser in _auth.authStateChanges().timeout(
          const Duration(seconds: 5),
        )) {
          if (authUser != null) {
            user = authUser;
            break; // We found the user, stop listening
          }
        }
      }

      // If user is *still* null, then throw the error
      if (user == null) {
        throw Exception(
          "User session expired. Please restart the app and try again.",
        );
      }
      // --- END OF FIX ---

      // --- This is the key step ---
      // Link the phone credential to the existing email account
      await user.linkWithCredential(authCredential);

      if (!mounted) return;

      // Update our custom 'isVerified' flag in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isVerified': true},
      );

      if (!mounted) return;

      // Sign the user out to force a clean login
      await _auth.signOut();

      if (!mounted) return;

      // Navigate to success, clearing the entire auth stack
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmailVerifiedScreen()),
        (route) => false, // This predicate removes all routes
      );
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'invalid-verification-code') {
        message = 'The OTP code is invalid. Please check and try again.';
      } else if (e.code == 'credential-already-in-use') {
        message = 'This phone number is already linked to another account.';
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } on TimeoutException {
      // Handle the case where the user never re-loads
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Could not find user session. Please restart the app."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child:
                  !_isCodeSent
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 24),
                          Text(
                            'Sending OTP to\n${widget.phoneNumber}...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      )
                      : Form(
                        key: _formKey,
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
                              'Enter Verification Code',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'A 6-digit code was sent to\n${widget.phoneNumber}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: '6-Digit OTP Code',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().length != 6) {
                                  return 'Please enter a valid 6-digit code';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  58,
                                  106,
                                  85,
                                ),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _isLoading ? null : _verifyOTP,
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                      : const Text('Verify & Continue'),
                            ),
                            const SizedBox(height: 24),
                            _countdown > 0
                                ? Text(
                                  'Resend code in $_countdown seconds',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                )
                                : TextButton(
                                  onPressed: _sendOTP,
                                  child: const Text(
                                    'Resend OTP Code',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
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
