import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/data/auth_storage.dart';
import 'package:the_audit/features/auth/presentation/auth_gate.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';

import 'firebase_options.dart';

const _log = AppLogger('App');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppLogger.enabled) {
    Bloc.observer = AppBlocObserver();

    // Uncaught Flutter framework errors (build/layout/paint).
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _log.e('Flutter error', details.exception, details.stack);
      previousOnError?.call(details);
    };

    // Uncaught async / platform errors.
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _log.e('Uncaught error', error, stackTrace);
      return false; // keep default handling
    };
  }

  _log.i('Starting The Audit');
  await _log.trace(
    'Firebase.initializeApp',
    () =>
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
  runApp(const TheAuditApp());
}

class TheAuditApp extends StatefulWidget {
  const TheAuditApp({super.key});

  @override
  State<TheAuditApp> createState() => _TheAuditAppState();
}

class _TheAuditAppState extends State<TheAuditApp> {
  late final AppDatabase _database;
  late final AuthCubit _authCubit;

  @override
  void initState() {
    super.initState();

    _database = AppDatabase();
    _authCubit = AuthCubit(AuthStorage());
    _authCubit.loadSession();
  }

  @override
  void dispose() {
    _authCubit.close();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provided above MaterialApp so every route (e.g. the NavBar's profile
    // button on any page) can reach the database and auth state.
    return RepositoryProvider.value(
      value: _database,
      child: BlocProvider.value(
        value: _authCubit,
        child: MaterialApp(
          title: 'The Audit',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [if (AppLogger.enabled) AppRouteLogger()],
          theme: AppTheme.lightTheme,
          home: AuthGate(database: _database, authCubit: _authCubit),
        ),
      ),
    );
  }
}
