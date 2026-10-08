import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';

/// The team's user list, kept in Firestore (`users/{uid}`: name, email) and
/// mirrored into the local `users` table so pickers work offline.
///
/// Everyone who signs in adds/updates their own profile; Create session pulls
/// the whole list.
class UserDirectory {
  static const _log = AppLogger('UserDirectory');
  static const collection = 'users';

  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  UserDirectory(this._db, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Saves the signed-in user locally right away and to Firestore in the
  /// background. Never blocks or fails sign-in: Firestore queues the write
  /// while offline.
  Future<void> registerSignedInUser(firebase_auth.User user) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      _log.w('signed-in user has no email; not added to the directory');
      return;
    }
    final name = displayName(user.displayName, email);

    await _saveLocal(id: user.uid, name: name, email: email);

    unawaited(
      _firestore
          .collection(collection)
          .doc(user.uid)
          .set({
            'name': name,
            'email': email,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .then((_) => _log.i('profile saved for ${AppLogger.mask(email)}'))
          .catchError((Object error, StackTrace stackTrace) {
            _log.w('profile save failed', error, stackTrace);
          }),
    );
  }

  /// Copies every Firestore profile into the local users table. Throws if
  /// Firestore can't be reached in time; the local list is then still usable.
  Future<int> syncToLocal() {
    return _log.trace('syncToLocal', () async {
      final snapshot = await _firestore
          .collection(collection)
          .get()
          .timeout(const Duration(seconds: 10));

      var saved = 0;
      // One transaction: far fewer disk writes than one per user.
      await _db.transaction(() async {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final email = (data['email'] as String?)?.trim();
          if (email == null || email.isEmpty) continue;
          final name = displayName(data['name'] as String?, email);
          if (await _saveLocal(id: doc.id, name: name, email: email)) saved++;
        }
      });
      _log.i('synced $saved / ${snapshot.docs.length} users from Firestore');
      return saved;
    });
  }

  /// Inserts or updates one user by id, keeping its role. Skips (returns
  /// false) when a different local user already has this email, since user
  /// ids are referenced by sessions and can't be changed.
  Future<bool> _saveLocal({
    required String id,
    required String name,
    required String email,
  }) async {
    final byId = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    final byEmail = await (_db.select(
      _db.users,
    )..where((u) => u.email.equals(email))).getSingleOrNull();

    if (byEmail != null && byEmail.id != id) {
      _log.w('local user ${byEmail.id} already uses ${AppLogger.mask(email)}');
      return false;
    }

    if (byId == null) {
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: id,
              name: name,
              role: 'CREW',
              email: email,
            ),
          );
    } else if (byId.name != name || byId.email != email) {
      await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
        UsersCompanion(
          name: Value(name),
          email: Value(email),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    return true;
  }

  /// "shruti.k@example.com" -> "Shruti.k" when there's no display name.
  static String displayName(String? name, String email) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final local = email.split('@').first;
    return local.isEmpty ? email : local[0].toUpperCase() + local.substring(1);
  }
}
