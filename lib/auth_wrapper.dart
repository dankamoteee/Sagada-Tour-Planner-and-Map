import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/map_homescreen.dart';
import 'screens/login_screen.dart';
import 'screens/terms_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  bool _acceptedTerms = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _checkAuthAndTerms();
  }

  Future<void> _checkAuthAndTerms() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('accepted_terms') ?? false;

    setState(() {
      _user = FirebaseAuth.instance.currentUser;
      _acceptedTerms = accepted;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return const LoginScreen(); // Not logged in
    } else if (!_acceptedTerms) {
      return const TermsAgreementScreen(); // Logged in but terms not accepted
    } else {
      return const MapScreen(); // Logged in + terms accepted
    }
  }
}
