import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/provider_logout_service.dart';

void main() {
  group('parseLogoutPreview — استجابة provider_logout_preview', () {
    test('صف واحد is_last_session=true → آخر جلسة', () {
      expect(
        parseLogoutPreview([
          {'is_last_session': true, 'active_sessions': 1},
        ]),
        isTrue,
      );
    });

    test('صف واحد is_last_session=false → توجد جلسة أخرى', () {
      expect(
        parseLogoutPreview([
          {'is_last_session': false, 'active_sessions': 2},
        ]),
        isFalse,
      );
    });

    test('قائمة فارغة أو null أو شكل غير متوقع → ليست الأخيرة (بلا تحذير خاطئ)', () {
      expect(parseLogoutPreview(const []), isFalse);
      expect(parseLogoutPreview(null), isFalse);
      expect(parseLogoutPreview('unexpected'), isFalse);
      expect(parseLogoutPreview([41]), isFalse);
    });

    test('map مفرد (PostgREST قد يرجعه لبعض الحالات) يُقرأ كذلك', () {
      expect(parseLogoutPreview({'is_last_session': true}), isTrue);
    });

    test('القيمة غير المنطقية true النصية لا تُعامل كصحيح', () {
      expect(parseLogoutPreview({'is_last_session': 'true'}), isFalse);
    });
  });
}
