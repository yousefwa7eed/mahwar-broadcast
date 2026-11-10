import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// RPCs دورة حياة جلسة المزوّد (مطبّقة كـ SECURITY DEFINER على الخادم).
///
/// Live signatures (verified 2026-11-10):
///   provider_logout_preview() returns table(is_last_session boolean, active_sessions int)
///   provider_mark_logged_out() returns boolean
///   provider_mark_active() returns void
///
/// الهوية تُقرأ من `auth.uid()` على الخادم — لا تُرسل أي معرّفات من العميل.
/// `provider_mark_logged_out` تعيد العدّ بنفسها فلا تُكتب `logged_out_at` إن
/// كانت هناك جلسة أخرى نشطة على جهاز ثانٍ.
class ProviderLogoutService {
  final SupabaseClient? _clientOverride;

  ProviderLogoutService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  /// هل الجلسة الحالية هي آخر جلسة حيّة للحساب؟
  Future<bool> isLastSession() async {
    final response = await _client.rpc('provider_logout_preview');
    return parseLogoutPreview(response);
  }

  /// يسجّل وقت الخروج (ساعتان سماح) — يعمل فقط عند آخر جلسة.
  Future<void> markLoggedOut() async {
    await _client.rpc('provider_mark_logged_out');
  }

  /// يلغي وقت الخروج عند عودة المزوّد للنشاط.
  Future<void> markActive() async {
    await _client.rpc('provider_mark_active');
  }
}

/// استجابة `provider_logout_preview` جدول بصف واحد. أي شكل غير متوقع يُعامل
/// كـ«ليست الأخيرة» حتى لا نُظهر تحذيرًا خاطئًا ولا نُخفي مزوّدًا متاحًا.
@visibleForTesting
bool parseLogoutPreview(dynamic response) {
  final rows = response is List
      ? response
      : (response == null ? const <dynamic>[] : <dynamic>[response]);
  if (rows.isEmpty) return false;
  final row = rows.first;
  if (row is! Map) return false;
  return row['is_last_session'] == true;
}
