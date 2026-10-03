import 'package:flutter/material.dart';
import 'package:the_audit/core/utils/theme.dart';

/// Gradient splash shown at start-up. Matches the native launch screens, then
/// slowly zooms the logo in 10% before the app moves on to login / home.
class SplashScreen extends StatelessWidget {
  /// How long the zoom runs; AuthGate keeps the splash up for this long.
  static const zoomDuration = Duration(milliseconds: 2500);

  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppAuthTheme.backgroundGradient,
        ),
        child: Center(
          child: Semantics(
            label: 'Karta Innovations',
            image: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.1),
              duration: zoomDuration,
              curve: Curves.easeOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Image.asset(
                'assets/images/branding/splash_logo.png',
                width: 300,
                height: 300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
