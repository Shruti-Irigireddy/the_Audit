import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_state.dart';
import 'package:the_audit/features/auth/presentation/login.dart';
import 'package:the_audit/features/dashboard/presentation/home.dart';

class AuthGate extends StatelessWidget {
  final AppDatabase database;
    final AuthCubit authCubit; const AuthGate({
    super.key,
    required this.database,
    required this.authCubit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: authCubit,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state.viewStatus == AuthViewStatus.loading || state.viewStatus == AuthViewStatus.initial) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
          if (state.isAuthenticated) {
            return HomePage(
              database: database,
              authCubit: authCubit,
            );
}
          return LoginPage(
            database: database,
            authCubit: authCubit,
          );
        },
      ),
    );
  }
}
