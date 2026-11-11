import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mahwar/core/auth/install_login_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('نسخة جديدة (تخزين فارغ): الرقم غير محقَّق', () async {
    expect(await InstallLoginStore.instance.isVerified('01012345678'), isFalse);
  });

  test('التحقق يُخزَّن ويُطبَّع من صيغتي +20 و20', () async {
    await InstallLoginStore.instance.markVerified('+201012345678');

    expect(await InstallLoginStore.instance.isVerified('01012345678'), isTrue);
    expect(await InstallLoginStore.instance.isVerified('201012345678'), isTrue);
    expect(await InstallLoginStore.instance.isVerified('01099999999'), isFalse);
  });

  test('التسجيل مكرر لا يكرر الرقم في التخزين', () async {
    await InstallLoginStore.instance.markVerified('01012345678');
    await InstallLoginStore.instance.markVerified('+201012345678');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('install_verified_phones_v1'), <String>[
      '01012345678',
    ]);
  });

  test('علامة الانتظار تُسجَّل ويزيلها التحقق الناجح', () async {
    await InstallLoginStore.instance.markPending('01012345678');
    expect(await InstallLoginStore.instance.isPending('01012345678'), isTrue);
    expect(await InstallLoginStore.instance.isVerified('01012345678'), isFalse);

    await InstallLoginStore.instance.markVerified('+201012345678');
    expect(await InstallLoginStore.instance.isPending('01012345678'), isFalse);
    expect(await InstallLoginStore.instance.isVerified('01012345678'), isTrue);
  });

  test('رقم غير صالح لا يُسجَّل', () async {
    await InstallLoginStore.instance.markVerified('123');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('install_verified_phones_v1'), isNull);
  });

  test('قيم تالفة في التخزين تُتجاهَل ولا تحجب المستخدم', () async {
    SharedPreferences.setMockInitialValues({
      'install_verified_phones_v1': <String>['bad', '01012345678'],
    });

    expect(await InstallLoginStore.instance.isVerified('01012345678'), isTrue);
    expect(await InstallLoginStore.instance.isVerified('01111111111'), isFalse);
  });
}
