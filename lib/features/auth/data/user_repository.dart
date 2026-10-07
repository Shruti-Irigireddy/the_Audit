import 'package:drift/drift.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';

/// Reads the local users table (filled from the Firestore directory) for
/// screens that show people.
class UserRepository {
  static const _log = AppLogger('UserRepository');

  final AppDatabase _db;

  const UserRepository(this._db);

  /// The local row for a signed-in account: by uid, else by email (any
  /// case).
  Future<User?> findUser({required String uid, String? email}) async {
    final byUid = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(uid))).getSingleOrNull();
    if (byUid != null) return byUid;

    final normalized = email?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    _log.d('no user for uid; looking up ${AppLogger.mask(normalized)}');
    return (_db.select(
      _db.users,
    )..where((u) => u.email.lower().equals(normalized))).getSingleOrNull();
  }

  /// Every user's name by id.
  Future<Map<String, String>> getUserNames() async {
    final users = await _db.select(_db.users).get();
    return {for (final user in users) user.id: user.name};
  }
}
