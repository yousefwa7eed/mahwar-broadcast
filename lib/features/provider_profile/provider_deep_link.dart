/// روابط QR الخارجية للمزوّد: `mahwar://provider?id=<uuid>`.
///
/// الرابط يفتح الملف العام للمزوّد فقط (عرض الورشة والتقييمات). لا يحمل أي
/// رمز دخول ولا معرّف عميل، ولا يسمح بأي إجراء كتابة — لذلك يمكن طباعته على
/// واجهة المحل بأمان. التقييم يظل من الطلبات المكتملة فقط.
library;

const String providerDeepLinkScheme = 'mahwar';
const String providerDeepLinkHost = 'provider';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// الرابط الكامل الذي يُرمَّز داخل صورة QR.
String buildProviderProfileLink(String providerId) => Uri(
  scheme: providerDeepLinkScheme,
  host: providerDeepLinkHost,
  queryParameters: {'id': providerId},
).toString();

/// هل هذا URI وصل عبر مخطط التطبيق ومسار المزوّد؟ (قبل التحقق من المعرّف)
bool isProviderDeepLink(Uri uri) =>
    uri.scheme.toLowerCase() == providerDeepLinkScheme &&
    uri.host.toLowerCase() == providerDeepLinkHost;

/// يحوّل `mahwar://provider?id=<uuid>` إلى مسار داخلي، أو null إن كان
/// المعرّف غائبًا/غير صالح — عندها لا نفتح ملفًا لأي مزوّد.
String? providerProfileTargetFromUri(Uri uri) {
  if (!isProviderDeepLink(uri)) return null;
  final id = uri.queryParameters['id']?.trim() ?? '';
  if (!_uuidPattern.hasMatch(id)) return null;
  return '/provider/profile?providerId=${Uri.encodeQueryComponent(id)}';
}
