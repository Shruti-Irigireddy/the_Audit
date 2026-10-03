import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_state.dart';
import 'package:the_audit/features/auth/presentation/login.dart';
import 'package:the_audit/features/auth/presentation/splash_screen.dart';
import 'package:the_audit/features/dashboard/presentation/home.dart';

const _log = AppLogger('AuthGate');

class AuthGate extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  const AuthGate({super.key, required this.database, required this.authCubit});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Keep the splash up for the full logo zoom, even when the session loads
  /// instantly.
  static const _minimumSplash = SplashScreen.zoomDuration;

  bool _splashElapsed = false;
  Type? _lastPage;

  @override
  void initState() {
    super.initState();
    _log.t('initState');
    Future.delayed(_minimumSplash, () {
      _log.t('minimum splash elapsed');
      if (mounted) setState(() => _splashElapsed = true);
    });
  }

  @override
  void dispose() {
    _log.t('dispose');
    super.dispose();
  }

  void _logPage(Widget page, AuthState state) {
    if (page.runtimeType == _lastPage) return;
    _lastPage = page.runtimeType;
    _log.i(
      'showing ${page.runtimeType} (status: ${state.viewStatus.name}, '
      'authenticated: ${state.isAuthenticated})',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authCubit,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final loading =
              state.viewStatus == AuthViewStatus.loading ||
              state.viewStatus == AuthViewStatus.initial;

          final Widget page;
          if (loading || !_splashElapsed) {
            page = const SplashScreen();
          } else if (state.isAuthenticated) {
            page = HomePage(
              database: widget.database,
              authCubit: widget.authCubit,
            );
          } else {
            page = LoginPage(
              database: widget.database,
              authCubit: widget.authCubit,
            );
          }

          _logPage(page, state);

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
          );
        },
      ),
    );
  }
}
