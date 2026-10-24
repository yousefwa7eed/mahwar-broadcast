// اختبارات توطين نصوص الإشعارات داخل التطبيق (من ملفات ARB).
//
// الغاية: أن يتطابق ما يعرضه التطبيق مع نص إشعارات الدفع المبني في
// supabase/functions/send-push-notification/notification_text.ts — نفس
// السلاسل العربية والإنجليزية — حتى لا تختلف الواجهة عن الإشعار المدفوع.
//
// لا تحتاج أي plugin (Firebase/Supabase): تُبنى نصوص ARB مباشرة عبر
// AppLocalizationsAr/AppLocalizationsEn.

import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/models/notification_model.dart';
import 'package:mahwar/l10n/app_localizations.dart';
import 'package:mahwar/l10n/app_localizations_ar.dart';
import 'package:mahwar/l10n/app_localizations_en.dart';

NotificationModel notif(
  String type, {
  Map<String, dynamic>? metadata,
  String? createdAt,
}) {
  return NotificationModel.fromJson({
    'id': '00000000-0000-0000-0000-000000000001',
    'user_id': '00000000-0000-0000-0000-000000000002',
    'type': type,
    'metadata': ?metadata,
    'created_at': ?createdAt,
  });
}

void main() {
  final AppLocalizations ar = AppLocalizationsAr();
  final AppLocalizations en = AppLocalizationsEn();

  tearDown(() => NotificationModel.serviceTypeNameResolver = null);

  // [type, arTitle, arBody, enTitle, enBody] — أنواع لا تعتمد على metadata.
  const simple = <List<String>>[
    [
      'order_confirmed',
      'تم تأكيد الطلب',
      'وافق العميل على عرضك — يمكنك بدء التنفيذ',
      'Order confirmed',
      'The customer accepted your offer — you can start the job',
    ],
    [
      'order_cancelled',
      'تم إلغاء الطلب',
      'تم إلغاء هذا الطلب',
      'Order cancelled',
      'This order was cancelled',
    ],
    [
      'order_completed',
      'تم إتمام الطلب',
      'تم إتمام خدمة الطلب بنجاح',
      'Order completed',
      'The order service was completed successfully',
    ],
    [
      'shift_started',
      'بدء ساعات العمل',
      'بدأت ساعات عملك — أنت الآن متاح أمام العملاء',
      'Work hours started',
      'Your working hours have started — you are now available to customers',
    ],
    [
      'shift_ended',
      'انتهاء ساعات العمل',
      'انتهت ساعات عملك — أصبحت الآن غير متاح',
      'Work hours ended',
      'Your working hours have ended — you are now unavailable',
    ],
    [
      'new_message',
      'رسالة جديدة',
      'وصلتك رسالة جديدة',
      'New message',
      'You received a new message',
    ],
    [
      'some_unknown_type',
      'إشعار جديد',
      'يوجد تحديث جديد لتطبيق محور',
      'New notification',
      'There is a new update for Mahwar',
    ],
  ];

  test('الأنواع البسيطة تُعرض بالعربية والإنجليزية (عنوان + نص)', () {
    for (final c in simple) {
      final n = notif(c[0], metadata: const {});
      expect(n.localizedTitle(ar), c[1], reason: 'ar title ${c[0]}');
      expect(n.localizedBody(ar), c[2], reason: 'ar body ${c[0]}');
      expect(n.localizedTitle(en), c[3], reason: 'en title ${c[0]}');
      expect(n.localizedBody(en), c[4], reason: 'en body ${c[0]}');
    }
  });

  test('new_order: اسم الخدمة من service_types ثم metadata ثم حذف اللاحقة', () {
    NotificationModel.serviceTypeNameResolver = (id, isArabic) => id == 'electric'
        ? (isArabic ? 'كهرباء' : 'Electricity')
        : null;

    final dbFirst = notif('new_order', metadata: const {
      'service_type_id': 'electric',
      'service_name': 'سباكة',
    });
    expect(dbFirst.localizedTitle(ar), 'طلب جديد');
    expect(dbFirst.localizedTitle(en), 'New order');
    expect(dbFirst.localizedBody(ar), 'لديك طلب جديد: كهرباء');
    expect(dbFirst.localizedBody(en), 'You have a new order: Electricity');

    final metaOnly = notif('new_order', metadata: const {'service_name': 'سباكة'});
    expect(metaOnly.localizedBody(ar), 'لديك طلب جديد: سباكة');
    // بلا resolver يقع الاسم العربي المحفوظ كما هو.
    expect(metaOnly.localizedBody(en), 'You have a new order: سباكة');

    final none = notif('new_order', metadata: const {});
    expect(none.localizedBody(ar), 'لديك طلب جديد');
    expect(none.localizedBody(en), 'You have a new order');
  });

  test('price_offer: مع مزوّد وسعر وخدمة، باللغتين', () {
    final n = notif('price_offer', metadata: const {
      'provider_name': 'أحمد',
      'price': 150,
      'service_name': 'كهرباء',
    });
    expect(n.localizedTitle(ar), 'عرض سعر جديد');
    expect(n.localizedBody(ar), 'أحمد قدم عرض سعر 150 ج.م لطلب كهرباء');
    expect(n.localizedTitle(en), 'New price offer');
    expect(n.localizedBody(en), 'أحمد offered a price of 150 EGP for كهرباء');

    final noService = notif('price_offer', metadata: const {
      'provider_name': 'أحمد',
      'price': 100,
    });
    expect(noService.localizedBody(ar), 'أحمد قدم عرض سعر 100 ج.م');
    expect(noService.localizedBody(en), 'أحمد offered a price of 100 EGP');

    final noProvider = notif('price_offer', metadata: const {'price': 100});
    expect(noProvider.localizedBody(ar), 'تم استلام عرض سعر جديد');
    expect(noProvider.localizedBody(en), 'A new price offer was received');
  });

  test('order_rejected: مع مزوّد وبدونه', () {
    final withProvider = notif('order_rejected', metadata: const {'provider_name': 'خالد'});
    expect(withProvider.localizedBody(ar), 'تم رفض الطلب من خالد');
    expect(withProvider.localizedBody(en), 'The order was rejected by خالد');

    final without = notif('order_rejected', metadata: const {});
    expect(without.localizedBody(ar), 'تم رفض الطلب');
    expect(without.localizedBody(en), 'The order was rejected');
  });

  test('order_rejected by=owner: نص موجّه للمزوّد', () {
    final n = notif('order_rejected', metadata: const {'by': 'owner'});
    expect(n.localizedTitle(ar), 'تم رفض عرضك');
    expect(n.localizedTitle(en), 'Your offer was rejected');
    expect(n.localizedBody(ar), 'رفض العميل عرضك');
    expect(n.localizedBody(en), 'The customer rejected your offer');

    final fromProvider = notif('order_rejected', metadata: const {'by': 'provider'});
    expect(fromProvider.localizedTitle(ar), 'تم رفض الطلب');
    expect(fromProvider.localizedBody(ar), 'تم رفض الطلب');
  });

  test('order_cancelled by=owner: نص موجّه للمزوّد، وtimeout يبقى عاماً', () {
    final byOwner = notif('order_cancelled', metadata: const {'by': 'owner'});
    expect(byOwner.localizedBody(ar), 'قام العميل بإلغاء الطلب');
    expect(byOwner.localizedBody(en), 'The customer cancelled the order');

    final timeout = notif('order_cancelled', metadata: const {'by': 'timeout'});
    expect(timeout.localizedBody(ar), 'تم إلغاء هذا الطلب');
    expect(timeout.localizedBody(en), 'This order was cancelled');
  });

  test('rating_received: مع قيمة وبدونها (بما فيها 0)', () {
    final four = notif('rating_received', metadata: const {'rating': 4});
    expect(four.localizedTitle(ar), 'تقييم جديد');
    expect(four.localizedBody(ar), 'حصلت على تقييم 4 من 5');
    expect(four.localizedBody(en), 'You received a rating of 4 out of 5');

    final zero = notif('rating_received', metadata: const {'rating': 0});
    expect(zero.localizedBody(ar), 'حصلت على تقييم 0 من 5');

    final none = notif('rating_received', metadata: const {});
    expect(none.localizedBody(ar), 'حصلت على تقييم جديد');
    expect(none.localizedBody(en), 'You received a new rating');
  });

  test('broadcast: العربية من title/body والإنجليزية تفضّل *_en', () {
    final n = notif('broadcast', metadata: const {'title': 'عرض', 'body': 'خصم'});
    expect(n.localizedTitle(ar), 'عرض');
    expect(n.localizedBody(ar), 'خصم');
    expect(n.localizedTitle(en), 'عرض');
    expect(n.localizedBody(en), 'خصم');

    final bilingual = notif('broadcast', metadata: const {
      'title': 'عرض',
      'body': 'خصم',
      'title_en': 'Offer',
      'body_en': 'Discount',
    });
    expect(bilingual.localizedTitle(en), 'Offer');
    expect(bilingual.localizedBody(en), 'Discount');

    final empty = notif('broadcast', metadata: const {});
    expect(empty.localizedTitle(ar), 'إشعار');
    expect(empty.localizedBody(ar), '');
    expect(empty.localizedTitle(en), 'Notification');
    expect(empty.localizedBody(en), '');
  });

  test('timeAgo حسب لغة العارض وضد مرجع asOf', () {
    final n = notif('new_message', createdAt: '2026-09-15T10:30:00+00:00');

    DateTime at(int h, int m, int s) => DateTime.parse(
        '2026-09-15T${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}+00:00');

    expect(n.timeAgo(at(10, 30, 12), ar), 'الآن');
    expect(n.timeAgo(at(10, 30, 12), en), 'Just now');

    expect(n.timeAgo(at(10, 35, 0), ar), 'منذ 5 دقيقة');
    expect(n.timeAgo(at(10, 35, 0), en), '5 minutes ago');

    expect(n.timeAgo(at(11, 30, 0), ar), 'منذ 1 ساعة');
    expect(n.timeAgo(at(11, 30, 0), en), '1 hours ago');

    final twoDays = DateTime.parse('2026-09-17T10:30:00+00:00');
    expect(n.timeAgo(twoDays, ar), 'منذ 2 يوم');
    expect(n.timeAgo(twoDays, en), '2 days ago');
  });

  test('timeAgo بلا l10n يبقى عربيًا (توافق الاختبارات المعزولة)', () {
    final n = notif('new_message', createdAt: '2026-09-15T10:30:00+00:00');
    expect(n.timeAgo(DateTime.parse('2026-09-15T11:30:00+00:00')), 'منذ 1 ساعة');
  });

  test('resolveServiceName: سلسلة الاحتياط مطابقة لدالة الحافة', () {
    expect(NotificationModel.resolveServiceName(const {'service_name': 'ب'}, 'أ'), 'أ');
    expect(NotificationModel.resolveServiceName(const {'service_name': 'ب'}, null), 'ب');
    expect(NotificationModel.resolveServiceName(const {}, null), isNull);
    expect(NotificationModel.resolveServiceName(const {'service_name': '   '}, ''), isNull);
    expect(NotificationModel.resolveServiceName(null, null), isNull);
  });
}
