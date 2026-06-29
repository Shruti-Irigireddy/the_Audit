import 'package:flutter/material.dart';

import 'auth_storage.dart';
import 'home.dart';
import 'login.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthStorage _authStorage = AuthStorage();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }
  
  Future<void> _checkLoginStatus() async {
    final bool isLoggedIn = await _authStorage.isLoggedIn();

    if(!mounted) return;
    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );  
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}