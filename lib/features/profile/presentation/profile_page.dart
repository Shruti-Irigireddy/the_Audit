import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';

const _log = AppLogger('Profile');

class ProfilePage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;

  const ProfilePage({
    super.key,
    required this.database,
    required this.authCubit,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<User?> _user;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _log.t('initState');
    _user = _loadUser();
  }

  @override
  void dispose() {
    _log.t('dispose');
    super.dispose();
  }

  Future<User?> _loadUser() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _log.w('no firebase user');
      return null;
    }

    final userByUid = await (widget.database.select(
      widget.database.users,
    )..where((row) => row.id.equals(firebaseUser.uid))).getSingleOrNull();

    if (userByUid != null) {
      _log.d('local user found by uid');
      return userByUid;
    }

    final email = firebaseUser.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      _log.w('no local user and no email');
      return null;
    }
    _log.d('looking up local user by ${AppLogger.mask(email)}');

    return (widget.database.select(
      widget.database.users,
    )..where((row) => row.email.lower().equals(email))).getSingleOrNull();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    _log.i('logout tapped');

    await _log.trace('logout', () async {
      setState(() => _isLoggingOut = true);

      try {
        await firebase_auth.FirebaseAuth.instance.signOut();
        await widget.authCubit.clearSession();
        _log.i('logged out');

        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (error, stackTrace) {
        _log.e('logout failed', error, stackTrace);
        if (!mounted) return;
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not log out: $error')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: const NavBar(
        title: 'Profile',
        showBackButton: true,
        showProfileButton: false,
      ),
      body: SafeArea(
        child: FutureBuilder<User?>(
          future: _user,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = snapshot.data;
            final name = user?.name ?? 'User';
            final email = user?.email ?? firebaseUser?.email ?? 'No email';
            final role = user?.role ?? 'Role not assigned';

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.deepBlue,
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: AppColors.snowWhite,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 28),
                _ProfileDetail(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                ),
                const SizedBox(height: 12),
                _ProfileDetail(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: role,
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'The local user profile could not be loaded.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.error,
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isLoggingOut ? null : _logout,
                  icon: _isLoggingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      tileColor: AppColors.snowWhite,
    );
  }
}
