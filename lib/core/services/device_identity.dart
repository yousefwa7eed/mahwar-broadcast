import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentity {
  DeviceIdentity._();

  static final DeviceIdentity instance = DeviceIdentity._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'mahwar_device_id';

  String? _cached;

  Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    String? id;
    try {
      id = await _storage.read(key: _key);
    } catch (_) {}

    id = (id == null || id.isEmpty) ? _generateUuid() : id;
    _cached = id;

    try {
      await _storage.write(key: _key, value: id);
    } catch (_) {}

    return id;
  }

  static String _generateUuid() {
    final rng = Random.secure();
    final bytes =
        Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256)));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex[0]}${hex[1]}${hex[2]}${hex[3]}-${hex[4]}${hex[5]}-'
        '${hex[6]}${hex[7]}-${hex[8]}${hex[9]}-'
        '${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}';
  }
}