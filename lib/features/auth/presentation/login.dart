import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';

const _log = AppLogger('Login');

class LoginPage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  const LoginPage({super.key, required this.database, required this.authCubit});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  /// Only a remembered login is restored automatically on the next launch.
  bool _rememberMe = false;
  String? _errorMessage;

  Future<bool> _login() => _log.trace('login', () async {
    _log.i('login attempt ${AppLogger.mask(_emailController.text.trim())}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth
          .instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final firebase_auth.User? user = userCredential.user;
      if (user == null) {
        _log.w('login returned no user');
        setState(() {
          _errorMessage = "Login failed. User not found.";
        });
        return false;
      }

      await widget.authCubit.saveSession(
        remember: _rememberMe,
        uid: user.uid,
        email: user.email ?? _emailController.text.trim(),
      );
      _log.i('login succeeded ${AppLogger.mask(user.email)}');
      return true;
    } on firebase_auth.FirebaseAuthException catch (e, stackTrace) {
      _log.w('login failed: ${e.code}', e, stackTrace);
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
  });
  Future<void> _forgotPassword() async {
    _log.d('forgot password opened');
    final TextEditingController forgotPasswordEmailController =
        TextEditingController();
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
                _log.i(
                  'password reset requested ${AppLogger.mask(forgotPasswordEmailController.text)}',
                );
                try {
                  await firebase_auth.FirebaseAuth.instance
                      .sendPasswordResetEmail(
                        email: forgotPasswordEmailController.text,
                      );
                  _log.i('password reset email sent');
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent.')),
                  );
                } on firebase_auth.FirebaseAuthException catch (e, stackTrace) {
                  _log.w('password reset failed: ${e.code}', e, stackTrace);
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
                _log.d('forgot password cancelled');
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
  void initState() {
    super.initState();
    _log.t('initState');
  }

  @override
  void dispose() {
    _log.t('dispose');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppAuthTheme.fieldLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppAuthTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _LoginLayout.from(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              );
              const shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppSizes.cardRadius),
                ),
                side: BorderSide(color: AppAuthTheme.cardBorder),
              );

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.pageGutter,
                        vertical: 16,
                      ),
                      child: SizedBox(
                        width: layout.cardWidth,
                        child: DecoratedBox(
                          decoration: const ShapeDecoration(
                            shape: shape,
                            color: AppAuthTheme.cardFill,
                            shadows: [AppAuthTheme.cardShadow],
                          ),
                          child: ClipPath(
                            clipper: ShapeBorderClipper(shape: shape),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: layout.horizontalPadding,
                                vertical: layout.verticalPadding,
                              ),
                              child: _buildForm(layout),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(_LoginLayout layout) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('THE AUDIT', style: AppAuthTheme.title(layout.titleSize)),
        const SizedBox(height: 28),
        _fieldLabel('Email'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          cursorColor: AppAuthTheme.cursorColor,
          style: AppAuthTheme.fieldText,
          decoration: AppAuthTheme.field('Enter email'),
        ),
        const SizedBox(height: 18),
        _fieldLabel('Password'),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          cursorColor: AppAuthTheme.cursorColor,
          style: AppAuthTheme.fieldText,
          decoration: AppAuthTheme.field('Enter password').copyWith(
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              color: AppAuthTheme.iconColor,
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) =>
                    setState(() => _rememberMe = value ?? false),
                side: const BorderSide(color: AppAuthTheme.iconColor),
                activeColor: AppAuthTheme.checkboxFill,
                checkColor: AppColors.darkNavy,
              ),
              const Text('Remember me', style: AppAuthTheme.fieldLabel),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_errorMessage != null)
          Text(_errorMessage!, style: AppAuthTheme.error),
        const SizedBox(height: 16),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    await _login();
                  },
            style: AppAuthTheme.loginButton,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.snowWhite,
                    ),
                  )
                : const Text('Login  →'),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _forgotPassword,
            style: AppAuthTheme.forgotPasswordButton,
            child: const Text('Forgot Password?'),
          ),
        ),
      ],
    );
  }
}

/// Breakpoint maths for the login card (Material 3 window-size classes).
class _LoginLayout {
  const _LoginLayout({
    required this.cardWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.pageGutter,
    required this.titleSize,
  });

  final double cardWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final double pageGutter;
  final double titleSize;

  factory _LoginLayout.from({required double width, required double height}) {
    final isLandscapePhone = height < 500;

    if (width < 600) {
      const gutter = 16.0;
      final cardWidth = width - 2 * gutter;
      return _LoginLayout(
        cardWidth: cardWidth,
        horizontalPadding: 24,
        verticalPadding: isLandscapePhone ? 24 : 44,
        pageGutter: gutter,
        titleSize: 28,
      );
    }

    if (width < 840) {
      const gutter = 24.0;
      final cardWidth = (width - 2 * gutter).clamp(0.0, 520.0);
      return _LoginLayout(
        cardWidth: cardWidth,
        horizontalPadding: 40,
        verticalPadding: isLandscapePhone ? 24 : 60,
        pageGutter: gutter,
        titleSize: 34,
      );
    }

    const cardWidth = 580.0;
    return _LoginLayout(
      cardWidth: cardWidth,
      horizontalPadding: 48,
      verticalPadding: isLandscapePhone ? 24 : 60,
      pageGutter: 24,
      titleSize: 34,
    );
  }
}
