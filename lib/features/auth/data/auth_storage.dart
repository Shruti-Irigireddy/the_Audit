import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String isLoggedInKey = 'isLoggedIn';
  static const String uidkey = 'uid';
  static const String emailKey = 'email';

  Future<void> saveSession(String uid, String email) async {
    await _storage.write(key: isLoggedInKey, value: 'true');
    await _storage.write(key: uidkey, value: uid);
    await _storage.write(key: emailKey, value: email);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: isLoggedInKey);
    await _storage.delete(key: uidkey);
    await _storage.delete(key: emailKey);
  }

  Future<bool> isLoggedIn() async {
    String? isLoggedInValue = await _storage.read(key: isLoggedInKey);
    return isLoggedInValue == 'true';
  }

  Future<String?> getUid() async {
    return await _storage.read(key: uidkey);
  }
  
  Future<String?> getEmail() async {
    return await _storage.read(key: emailKey);
  }
}