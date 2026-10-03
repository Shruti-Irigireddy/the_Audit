import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:the_audit/core/utils/app_logger.dart';

class AuthStorage {
  static const _log = AppLogger('AuthStorage');

  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String isLoggedInKey = 'isLoggedIn';
  static const String uidkey = 'uid';
  static const String emailKey = 'email';

  Future<void> saveSession(String uid, String email) {
    return _log.trace('saveSession', () async {
      await _storage.write(key: isLoggedInKey, value: 'true');
      await _storage.write(key: uidkey, value: uid);
      await _storage.write(key: emailKey, value: email);
      _log.i('session saved for ${AppLogger.mask(email)}');
    });
  }

  Future<void> clearSession() {
    return _log.trace('clearSession', () async {
      await _storage.delete(key: isLoggedInKey);
      await _storage.delete(key: uidkey);
      await _storage.delete(key: emailKey);
      _log.i('session cleared');
    });
  }

  Future<bool> isLoggedIn() {
    return _log.trace('isLoggedIn', () async {
      String? isLoggedInValue = await _storage.read(key: isLoggedInKey);
      final loggedIn = isLoggedInValue == 'true';
      _log.d('session read: logged in: $loggedIn');
      return loggedIn;
    });
  }

  Future<String?> getUid() {
    return _log.trace('getUid', () async {
      final uid = await _storage.read(key: uidkey);
      _log.d('uid present: ${uid != null}');
      return uid;
    });
  }

  Future<String?> getEmail() {
    return _log.trace('getEmail', () async {
      final email = await _storage.read(key: emailKey);
      _log.d('email read: ${AppLogger.mask(email)}');
      return email;
    });
  }
}
