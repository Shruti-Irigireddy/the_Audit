import 'package:drift/drift.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/data/user_directory.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_state.dart';

/// Thrown when an action needs a signed-in user and there is none.
class NotSignedInException implements Exception {
  @override
  String toString() => 'Sign in again to save changes.';
}

/// Who is doing an action, for every `createdBy` / `performedBy` /
/// `decisionBy` the app writes.
///
/// Always the signed-in Firebase user's uid (never an email or a made-up
/// id), and always a row in the local `users` table, so records point at a
/// real user.
class CurrentUserRepository {
  static const _log = AppLogger('CurrentUserRepository');

  final AppDatabase _db;

  const CurrentUserRepository(this._db);

  /// The signed-in user's id, adding them to the local users table first if
  /// they aren't there yet (e.g. first sign-in while offline).
  Future<String> resolvePerformedBy(AuthState auth) async {
    final uid = auth.uid?.trim();
    if (uid == null || uid.isEmpty) {
      _log.w('no signed-in user');
      throw NotSignedInException();
    }

    final existing = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(uid))).getSingleOrNull();
    if (existing != null) return uid;

    // Another local user may already hold this email; emails are unique, so
    // fall back to a placeholder address for this row.
    final email = auth.email?.trim();
    final emailTaken =
        email != null &&
        email.isNotEmpty &&
        await (_db.select(
              _db.users,
            )..where((u) => u.email.equals(email))).getSingleOrNull() !=
            null;
    final rowEmail = email == null || email.isEmpty || emailTaken
        ? '$uid@local.the-audit'
        : email;

    _log.i('adding signed-in user ${AppLogger.mask(email)} to local users');
    await _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            id: uid,
            name: UserDirectory.displayName(null, email ?? rowEmail),
            role: 'CREW',
            email: rowEmail,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return uid;
  }
}
