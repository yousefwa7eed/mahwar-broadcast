import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_home/owner_profiles_resolution.dart';

void main() {
  group('buildGetPublicProfilesParams — عقد التوقيع الحي', () {
    test('مفاتيح المعاملات ثابتة: p_user_ids فقط', () {
      expect(
        buildGetPublicProfilesParams(userIds: ['u1', 'u2']).keys.toList(),
        ['p_user_ids'],
      );
    });

    test('القائمة تمر كما هي بلا تحويلات', () {
      const ids = ['8a1c0000-0000-0000-0000-000000000001', 'other-uuid'];
      expect(
        buildGetPublicProfilesParams(userIds: ids)['p_user_ids'],
        ids,
      );
    });
  });

  group('resolveOwnerProfiles', () {
    test('الصف الموجود يعطي الاسم منقّحًا والصور عند غير الفراغ', () {
      final r = resolveOwnerProfiles(
        rows: [
          {
            'user_id': 'u1',
            'full_name': '  محمود أحمد ',
            'role': 'car_owner',
            'avatar_id': 'a1',
            'avatar_url': '',
          },
        ],
        requestedIds: {'u1'},
        fallbackName: 'العميل',
      );
      expect(r.names, {'u1': 'محمود أحمد'});
      expect(r.avatarIds, {'u1': 'a1'});
      expect(r.avatarUrls, isEmpty);
    });

    test('الغياب أو الاسم الفارغ = البديل الافتراضي (fail-closed بلا كشف)', () {
      final r = resolveOwnerProfiles(
        rows: [
          {'user_id': 'u2', 'full_name': '   ', 'avatar_id': '', 'avatar_url': ''},
        ],
        requestedIds: {'u1', 'u2'},
        fallbackName: 'العميل',
      );
      expect(r.names, {'u1': 'العميل', 'u2': 'العميل'});
      expect(r.avatarIds, isEmpty);
      expect(r.avatarUrls, isEmpty);
    });

    test('صفوف خارج المطلوب تُتجاهل، وصفوف بلا user_id نصي تُتجاهل', () {
      final r = resolveOwnerProfiles(
        rows: [
          {'user_id': 'u9', 'full_name': 'غير مطلوب', 'avatar_id': 'x'},
          {'user_id': null, 'full_name': 'بلا مفتاح'},
        ],
        requestedIds: {'u1'},
        fallbackName: 'العميل',
      );
      expect(r.names, {'u1': 'العميل'});
      expect(r.avatarIds, isEmpty);
    });

    test('null لـ full_name يعطي البديل ولا يسقط الاسم المسند', () {
      final r = resolveOwnerProfiles(
        rows: [
          {'user_id': 'u1', 'full_name': null, 'avatar_url': 'https://cdn/a.png'},
        ],
        requestedIds: {'u1'},
        fallbackName: 'العميل',
      );
      expect(r.names['u1'], 'العميل');
      expect(r.avatarUrls['u1'], 'https://cdn/a.png');
    });
  });

  group('mapBounded', () {
    test('يحافظ على الترتيب وينفّذ الكل مهما تجاوز الدفعة', () async {
      var inFlight = 0;
      var peak = 0;
      final items = List<int>.generate(10, (i) => i);

      final out = await mapBounded<int, int>(items, 3, (i) async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return i * 2;
      });

      expect(out, List<int>.generate(10, (i) => i * 2));
      expect(peak, lessThanOrEqualTo(3));
    });

    test('القائمة الفارغة = بلا عمل', () async {
      var calls = 0;
      final out = await mapBounded<int, int>([], 4, (i) async {
        calls++;
        return i;
      });
      expect(out, isEmpty);
      expect(calls, 0);
    });
  });
}
