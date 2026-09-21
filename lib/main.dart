import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/data/auth_storage.dart';
import 'package:the_audit/features/auth/presentation/auth_gate.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
    return MaterialApp(
      title: 'The Audit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(
        database: _database,
        authCubit: _authCubit,
      ),       
    );
  }
}

