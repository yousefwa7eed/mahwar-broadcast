import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mahwar/core/auth/last_account_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('يحفظ آخر حساب ويقرأه ويقنّع الرقم', () async {
    final store = LastAccountStore();
    await store.write(
      const LastAccount(name: 'يوسف', phone: '01012345678', role: 'car_owner'),
    );

    final account = await store.read();
    expect(account, isNotNull);
    expect(account!.name, 'يوسف');
    expect(account.phone, '01012345678');
    expect(account.role, 'car_owner');
    expect(account.maskedPhone, '010••••5678');
  });

  test('يطبّع صيغة +20 عند القراءة', () async {
    SharedPreferences.setMockInitialValues({
      'last_account_v1': jsonEncode({
        'name': 'سارة',
        'phone': '+201012345678',
        'role': 'provider',
      }),
    });

    final account = await LastAccountStore().read();
    expect(account?.phone, '01012345678');
    expect(account?.role, 'provider');
  });

  test('يتجاهل السجل التالف أو برقم غير صالح أو دور مجهول', () async {
    SharedPreferences.setMockInitialValues({
      'last_account_v1': jsonEncode({
        'name': 'يوسف',
        'phone': '12345',
        'role': 'car_owner',
      }),
    });
    expect(await LastAccountStore().read(), isNull);

    SharedPreferences.setMockInitialValues({
      'last_account_v1': jsonEncode({
        'name': 'يوسف',
        'phone': '01012345678',
        'role': 'admin',
      }),
    });
    expect(await LastAccountStore().read(), isNull);

    SharedPreferences.setMockInitialValues({'last_account_v1': 'not json'});
    expect(await LastAccountStore().read(), isNull);
  });

  test('المسح يزيل التلميح نهائيًا', () async {
    final store = LastAccountStore();
    await store.write(
      const LastAccount(name: 'يوسف', phone: '01012345678', role: 'car_owner'),
    );
    expect(await store.read(), isNotNull);

    await store.clear();
    expect(await store.read(), isNull);
  });
}
