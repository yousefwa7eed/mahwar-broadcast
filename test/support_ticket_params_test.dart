import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/widgets/support_ticket_params.dart';

void main() {
  // التوقيع الحي (مُتحقَّق في القاعدة بعد migration 20261110183820):
  //   submit_support_ticket(p_kind text, p_category text, p_subject text,
  //                         p_body text, p_contact_name text,
  //                         p_contact_phone text, p_attachment_path text) returns uuid
  //   get_my_support_tickets(p_limit integer default 20,
  //                          p_offset integer default 0)
  group('buildSubmitSupportTicketParams', () {
    test('يثبّت المفاتيح السبعة فقط', () {
      final params = buildSubmitSupportTicketParams(
        kind: 'complaint',
        subject: 'عنوان الشكوى',
        body: 'تفاصيل كافية عن المشكلة',
        contactName: 'أحمد',
        contactPhone: '01012345678',
      );

      expect(params.keys.toSet(), {
        'p_kind',
        'p_category',
        'p_subject',
        'p_body',
        'p_contact_name',
        'p_contact_phone',
        'p_attachment_path',
      });
      expect(params['p_kind'], 'complaint');
      expect(params['p_subject'], 'عنوان الشكوى');
      expect(params['p_category'], isNull);
      expect(params['p_attachment_path'], isNull);
    });

    test('يمرر التصنيف والمرفق كما هما', () {
      final params = buildSubmitSupportTicketParams(
        kind: 'inquiry',
        category: 'استفسار عام',
        subject: 'سؤال',
        body: 'تفاصيل السؤال بالكامل',
        attachmentPath: 'support/u-1/support_1.png',
      );

      expect(params['p_category'], 'استفسار عام');
      expect(params['p_attachment_path'], 'support/u-1/support_1.png');
    });

    test('المسجل يرسل جهة الاتصال فارغة ليشتقها الخادم من profiles', () {
      final params = buildSubmitSupportTicketParams(
        kind: 'suggestion',
        subject: 'اقتراح',
        body: 'فكرة جديدة للتطبيق',
        contactName: null,
        contactPhone: null,
      );

      expect(params['p_contact_name'], isNull);
      expect(params['p_contact_phone'], isNull);
    });
  });

  group('buildMySupportTicketsParams', () {
    test('يثبّت المفاتيح p_limit و p_offset فقط', () {
      final params = buildMySupportTicketsParams();

      expect(params.keys.toSet(), {'p_limit', 'p_offset'});
      expect(params['p_limit'], supportTicketsPageSize);
      expect(params['p_offset'], 0);
    });

    test('يمرر limit و offset المخصصين كما هما', () {
      final params = buildMySupportTicketsParams(limit: 5, offset: 20);

      expect(params['p_limit'], 5);
      expect(params['p_offset'], 20);
    });

    test('حجم الصفحة الافتراضي 20', () {
      expect(supportTicketsPageSize, 20);
    });
  });

  test('حدود الحقول تطابق تحقق الخادم', () {
    expect(supportSubjectMinLength, 3);
    expect(supportSubjectMaxLength, 120);
    expect(supportBodyMinLength, 10);
    expect(supportBodyMaxLength, 4000);
    expect(supportAttachmentMaxBytes, 10 * 1024 * 1024);
  });
}
