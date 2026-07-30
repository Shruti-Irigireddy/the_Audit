import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/data/auth_storage.dart';
import 'package:the_audit/features/dashboard/presentation/home.dart';

final AuthStorage _authStorage = AuthStorage();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<bool> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user == null) {
      setState(() {
        _errorMessage = "Login failed. User not found.";
      });
      return false;
      }

      await _authStorage.saveSession(user.uid, user.email ?? _emailController.text.trim());
      return true;

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _forgotPassword() async {
    final TextEditingController _forgotPasswordEmailController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: _forgotPasswordEmailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: _forgotPasswordEmailController.text,
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent.')),
                  );
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'An error occurred.')),
                  );
                }
              },
              child: const Text('Send'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    _forgotPasswordEmailController.dispose();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.iceBlue,
              AppColors.deepBlue,
              AppColors.darkNavy,
              
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child:ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.pagePadding),  
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Align(
                    //   alignment: Alignment.center,
                    //   child: Image.asset(
                    //     'assets/logo.png',
                    //     width: 100,
                    //     height: 100,
                    //   ),
                    // ),
                    Align(
                      alignment: Alignment.center,
                      child: const Text(
                        'The Audit',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.snowWhite,
                      ),
                    ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        filled: true,
                        fillColor: AppColors.mutedGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(AppSizes.inputRadius)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        filled: true,
                        fillColor: AppColors.mutedGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(AppSizes.inputRadius)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.errorRed),
                      ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: AppSizes.buttonHeight,
                            width: constraints.maxWidth * 0.3,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () async {
                                bool success = await _login();

                                if(!mounted) return;
                                
                                if (success) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const HomePage()),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.buttonHeight / 2),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: AppColors.snowWhite)
                                  : const Text('Login'),
                            ),
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Forgot Password?'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.snowWhite,
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
