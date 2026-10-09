import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LocalStorage implementation backed by [FlutterSecureStorage]
/// (Keychain on iOS, Keystore-backed AES-GCM on Android API 23+).
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage({
    this.persistSessionKey = _defaultPersistSessionKey,
  });

  static const _defaultPersistSessionKey = 'sb-trgesfzojaoirutkkfcs-auth-token';

  static const _storage = FlutterSecureStorage();

  final String persistSessionKey;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() =>
      _storage.containsKey(key: persistSessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: persistSessionKey, value: persistSessionString);
}