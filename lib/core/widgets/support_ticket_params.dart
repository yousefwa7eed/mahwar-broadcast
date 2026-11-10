/// معاملات دوال صندوق الدعم (RPC) وحدود الحقول المشتركة.
///
/// التوقيع الحي (مُطبَّق في القاعدة بعد migration 20261110183820):
/// - `submit_support_ticket(p_kind text, p_category text default null,
///   p_subject text default null, p_body text default null,
///   p_contact_name text default null, p_contact_phone text default null,
///   p_attachment_path text default null) returns uuid`
/// - `get_my_support_tickets(p_limit integer default 20,
///   p_offset integer default 0)`
///
/// الخادم يعيد التحقق من كل الحدود بنفسه؛ القيم هنا للتحقق المحلي وتثبيت
/// مفاتيح الخريطة باختبار حتى لا ينزلق أي اسم معامل عند التعديل.
library;

const int supportSubjectMinLength = 3;
const int supportSubjectMaxLength = 120;
const int supportBodyMinLength = 10;
const int supportBodyMaxLength = 4000;
const int supportContactNameMinLength = 2;
const int supportContactNameMaxLength = 80;
const int supportAttachmentMaxBytes = 10 * 1024 * 1024;
const int supportTicketsPageSize = 20;

Map<String, dynamic> buildSubmitSupportTicketParams({
  required String kind,
  String? category,
  required String subject,
  required String body,
  String? contactName,
  String? contactPhone,
  String? attachmentPath,
}) {
  return {
    'p_kind': kind,
    'p_category': category,
    'p_subject': subject,
    'p_body': body,
    'p_contact_name': contactName,
    'p_contact_phone': contactPhone,
    'p_attachment_path': attachmentPath,
  };
}

Map<String, dynamic> buildMySupportTicketsParams({
  int limit = supportTicketsPageSize,
  int offset = 0,
}) {
  return {
    'p_limit': limit,
    'p_offset': offset,
  };
}
