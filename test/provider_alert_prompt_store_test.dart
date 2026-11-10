import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mahwar/features/request_tracking/provider_alert_prompt_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('طلب لم يُعرض من قبل → false ثم true بعد markShown', () async {
    final store = ProviderAlertPromptStore.instance;

    expect(await store.wasShown('order-1'), isFalse);

    await store.markShown('order-1');

    expect(await store.wasShown('order-1'), isTrue);
    expect(await store.wasShown('order-2'), isFalse);
  });

  test('markShown مكرر لا يكرر العضو', () async {
    final store = ProviderAlertPromptStore.instance;

    await store.markShown('order-1');
    await store.markShown('order-1');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('provider_alert_prompt_shown_v1'),
      ['order-1'],
    );
  });

  test('السجل محصور بآخر 100 طلب (الأقدم يُسقط)', () async {
    final store = ProviderAlertPromptStore.instance;

    for (var i = 0; i < 105; i++) {
      await store.markShown('order-$i');
    }

    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getStringList('provider_alert_prompt_shown_v1')!;

    expect(shown.length, 100);
    expect(shown.contains('order-0'), isFalse);
    expect(shown.contains('order-104'), isTrue);
  });
}
