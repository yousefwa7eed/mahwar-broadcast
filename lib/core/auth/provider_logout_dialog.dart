import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/confirm_dialog.dart';
import 'provider_logout_service.dart';

/// حارس ضد النقر المزدوج أثناء فحص الجلسات (الفحص شبكي قبل الخروج).
bool _checking = false;

/// قبل خروج المزوّد: إن كانت هذه آخر جلسة حيّة يُعرض تحذير توقّف النشاط بعد
/// ساعتين، ويُسجَّل الخروج على الخادم عند التأكيد. تُرجع `true` إن جاز
/// متابعة الخروج. أي فشل في الفحص أو التسجيل لا يمنع الخروج المحلي.
Future<bool> confirmProviderLastSessionLogout(
  BuildContext context, {
  ProviderLogoutService? service,
}) async {
  if (_checking) return false;
  _checking = true;

  final providerSession = service ?? ProviderLogoutService();
  bool lastSession;
  try {
    lastSession = await providerSession.isLastSession();
  } catch (_) {
    lastSession = false;
  } finally {
    _checking = false;
  }

  if (!lastSession) return true;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context);
  final confirmed = await showConfirmDialog(
    context,
    title: l10n?.providerLogoutLastSessionTitle ?? 'تسجيل الخروج',
    message:
        l10n?.providerLogoutLastSessionBody ??
        'نشاطك هيتوقف بعد ساعتين، سجّل دخول تاني عشان يرجع نشاطك',
    confirmLabel: l10n?.confirmAction ?? 'تأكيد',
    cancelLabel: l10n?.cancelAction ?? 'تراجع',
  );
  if (!confirmed) return false;

  try {
    await providerSession.markLoggedOut();
  } catch (_) {
    // أسوأ حالة: يظل المزوّد ظاهرًا ساعتين إضافيتين — لا نمنع خروجه.
  }
  return true;
}
