import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  const LoginPage({
    super.key,
    required this.database,
    required this.authCubit,
  });

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
      final firebase_auth.UserCredential userCredential =
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final firebase_auth.User? user = userCredential.user;
      if (user == null) {
      setState(() {
        _errorMessage = "Login failed. User not found.";
      });
      return false;
      }

      await widget.authCubit.saveSession(
        uid: user.uid,
        email: user.email ?? _emailController.text.trim(),
      );
      return true;

    } on firebase_auth.FirebaseAuthException catch (e) {
      if (mounted) {
      setState(() {
        _errorMessage = e.message;
      });
      }
      return false;
    } finally {
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  }
  Future<void> _forgotPassword() async {
    final TextEditingController forgotPasswordEmailController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: forgotPasswordEmailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(
                    email: forgotPasswordEmailController.text,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent.')),
                  );
                } on firebase_auth.FirebaseAuthException catch (e) {
                  if (!mounted || !dialogContext.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'An error occurred.')),
                  );
                }
              },
              child: const Text('Send'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    forgotPasswordEmailController.dispose();
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
                              onPressed: _isLoading ? null : () async { await _login();
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
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.snowWhite,
                        ),
                        child: const Text('Forgot Password?'),
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
