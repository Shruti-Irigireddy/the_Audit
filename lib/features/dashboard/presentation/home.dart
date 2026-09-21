import 'package:flutter/material.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/features/pre_field/presentation/pre-field.dart';
import 'package:the_audit/features/profile/presentation/profile_page.dart';

class HomePage extends StatelessWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  const HomePage({
    super.key,
    required this.database,
    required this.authCubit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CreateSessionPage(
                database: database,
                authCubit: authCubit,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      appBar: NavBar(
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfilePage(
                database: database,
                authCubit: authCubit,
              ),
            ),
          );
        },
      ),
    );
  }
}
