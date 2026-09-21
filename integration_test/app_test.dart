import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:mahwar/main.dart' as app;

const String kPhone = '01554775966';
const String kPassword = '123456';
const String kFullName = 'محمد أحمد محمود';

/// ينظر دورياً (بمضخة حقيقية على جهاز حقيقي) حتى تظهر أي من العناصر المطلوبة
/// على الشاشة. يعيد true لو ظهر أحدها، و false عند انتهاء المهلة.
Future<bool> _waitForAny(
  PatrolIntegrationTester $,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      await $.pump(const Duration(milliseconds: 250));
    } catch (_) {}
    for (final f in finders) {
      try {
        if (f.hitTestable().evaluate().isNotEmpty) return true;
      } catch (_) {}
    }
  }
  return false;
}

Future<void> _expectVisible(
  PatrolIntegrationTester $,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final ok = await _waitForAny($, finders, timeout: timeout);
  if (!ok) {
    await _dumpVisibleTexts($);
    throw StateError('_expectVisible فشل: $reason');
  }
}

/// يطبع كل النصوص الموجودة حقيقة على الشاشة الحالية لمساعدتنا في التشخيص.
Future<void> _dumpVisibleTexts(PatrolIntegrationTester $) async {
  try {
    await $.pump(const Duration(milliseconds: 500));
  } catch (_) {}
  final texts = <String>[];
  try {
    for (final w in $.tester.widgetList<Text>(find.byType(Text))) {
      texts.add('"${w.data ?? w.textSpan?.toPlainText()}"');
    }
  } catch (_) {}
  debugPrint('DIAGNOSTIC-ON-SCREEN (${texts.length}): ${texts.join(' , ')}');
}

/// ضغطة بلا pumpAndSettle نهائي (بعض الشاشات تعرض مؤشرات تحميل لا نهائية).
Future<void> _tap(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration? timeout,
}) async {
  await $.tap(
    finder,
    visibleTimeout: timeout ?? const Duration(seconds: 20),
    settlePolicy: SettlePolicy.noSettle,
  );
}

Future<void> _enterText(
  PatrolIntegrationTester $,
  Finder finder,
  String text, {
  Duration? timeout,
}) async {
  await $.enterText(
    finder,
    text,
    hideKeyboard: true,
    visibleTimeout: timeout ?? const Duration(seconds: 20),
    settlePolicy: SettlePolicy.noSettle,
  );
}

/// يفتح DropdownButtonFormField ثم يختار عنصراً منه، مع محاولة تمرير
/// إذا كان العنصر خارج منطقة العرض.
Future<void> _selectDropdownItem(
  PatrolIntegrationTester $,
  String fieldLabel,
  String itemText,
) async {
  await _tap($, find.text(fieldLabel));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  try {
    await $.scrollUntilVisible(
      finder: find.text(itemText).last,
      view: find.byType(Scrollable).last,
      maxScrolls: 15,
      delta: 250,
      settleBetweenScrollsTimeout: const Duration(milliseconds: 400),
    );
  } catch (_) {}
  await _tap($, find.text(itemText).last);
}

/// يمنح أي نافذة إذن نظام (من خلال UiAutomator) إن ظهرت:
/// الموقع، والإشعارات...
Future<void> _grantNativePermissionsIfVisible(PatrolIntegrationTester $) async {
  for (var i = 0; i < 12; i++) {
    try {
      final visible = await $.platformAutomator.mobile.isPermissionDialogVisible(
        timeout: const Duration(milliseconds: 2000),
      );
      if (visible) {
        try {
          await $.platformAutomator.mobile.grantPermissionOnlyThisTime();
          await Future<void>.delayed(const Duration(milliseconds: 600));
        } catch (_) {}
      }
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }
}

void main() {
  patrolTest(
    'customer_journey_owner_signup_login_and_screens',
    ($) async {
      app.main();

      // 1) تهيئة الحالة: إما نشاهد Onboarding (حالة نظيفة) أو ظهرت جلسة
      // قديمة مستعادة (Android Backup/Restore قد يعيد جلسة بعد إعادة
      // التثبيت رغم إلغاء التثبيت). لو كانت هناك جلسة، نسجّل الخروج أولاً.
      final atOnboarding = await _waitForAny(
        $,
        [find.text('تخطي')],
        timeout: const Duration(seconds: 25),
      );

      if (!atOnboarding) {
        // جلسة قديمة نشطة: الرئيسية ظاهرة → سجّل الخروج من تبويب "حسابي"
        await _expectVisible(
          $,
          [find.text('ونش S.O.S'), find.text('حسابي')],
          timeout: const Duration(seconds: 25),
          reason: 'الرئيسية بجلسة قديمة مستعادة',
        );
        await _tap($, find.byIcon(Icons.person_outline_rounded));
        await _expectVisible(
          $,
          [find.text('تسجيل الخروج')],
          timeout: const Duration(seconds: 20),
          reason: 'تبويب حسابي → زر تسجيل الخروج',
        );
        await _tap($, find.text('تسجيل الخروج'));
        // بعد الخروج نصل مباشرة إلى شاشة اختيار نوع الحساب
        await _expectVisible(
          $,
          [find.text('مالك السيارة')],
          timeout: const Duration(seconds: 30),
          reason: 'شاشة اختيار نوع الحساب بعد تسجيل الخروج',
        );
      } else {
        // 1a) حالة نظيفة: تجاوز Onboarding
        await _tap($, find.text('تخطي'));

        // 2) اختيار نوع الحساب → مالك السيارة
        await _expectVisible(
          $,
          [find.text('مالك السيارة')],
          reason: 'شاشة اختيار نوع الحساب',
        );
      }

      // لو بدأنا من مرحباً، نضغط على نفس البطاقة أيضاً
      await _tap($, find.text('مالك السيارة'));

      // 3) شاشة الدخول → إنشاء حساب جديد
      await _expectVisible(
        $,
        [find.text('تسجيل الدخول')],
        reason: 'شاشة تسجيل الدخول',
      );
      await _tap($, find.text('إنشاء حساب جديد'));

      // 4) تعبئة نموذج التسجيل (حساب مالك سيارة)
      await _expectVisible(
        $,
        [find.text('الاسم رباعي (إجباري)')],
        reason: 'شاشة التسجيل',
      );

      // انتظار انتهاء تحميل قوائم السيارات (حتى لا يتعارض مؤشر التحميل)
      final t0 = DateTime.now();
      while (DateTime.now().difference(t0) < const Duration(seconds: 20)) {
        if ($.tester.any(find.byType(CircularProgressIndicator))) {
          await $.pump(const Duration(milliseconds: 200));
        } else {
          break;
        }
      }

      await _enterText($, find.text('الاسم رباعي (إجباري)'), kFullName);
      await _enterText($, find.text('رقم الهاتف (إجباري)'), kPhone);

      await _selectDropdownItem($, 'نوع السيارة (الماركة)', 'تويوتا');
      await _selectDropdownItem($, 'موديل السيارة', 'كورولا');
      await _selectDropdownItem($, 'سنة الصنع', '2020');

      await _enterText($, find.text('كلمة المرور'), kPassword);
      await _enterText($, find.text('تأكيد كلمة المرور'), kPassword);

      // التمرير إلى الشروط والموافقة عليها
      try {
        await $.scrollUntilVisible(
          finder: find.text('أوافق على شروط الاستخدام وسياسة الخصوصية'),
          maxScrolls: 10,
          delta: 200,
          settleBetweenScrollsTimeout: const Duration(milliseconds: 300),
        );
      } catch (_) {}
      await _tap($, find.text('أوافق على شروط الاستخدام وسياسة الخصوصية'));

      // التمرير إلى زر الإرسال والضغط عليه
      try {
        await $.scrollUntilVisible(
          finder: find.widgetWithText(ElevatedButton, 'إنشاء حساب جديد'),
          maxScrolls: 6,
          delta: 200,
          settleBetweenScrollsTimeout: const Duration(milliseconds: 300),
        );
      } catch (_) {}
      await _tap($, find.widgetWithText(ElevatedButton, 'إنشاء حساب جديد'));

      // 5) انتظار النجاح (الرئيسية) أو خطأ "الحساب مسجل مسبقاً"
      var loggedIn = await _waitForAny(
        $,
        [find.textContaining('مرحباً'), find.text('ونش S.O.S')],
        timeout: const Duration(seconds: 60),
      );

      if (!loggedIn) {
        // الحساب موجود مسبقاً → أغلق نافذة الخطأ، ارجع، ثم سجّل الدخول
        await _expectVisible(
          $,
          [find.text('حسناً')],
          timeout: const Duration(seconds: 30),
          reason: 'نافذة خطأ التسجيل',
        );
        await _tap($, find.text('حسناً'));

        await _tap($, find.byIcon(Icons.arrow_back_ios_rounded));
        await _expectVisible(
          $,
          [find.text('تسجيل الدخول')],
          reason: 'العودة لشاشة الدخول',
        );

        await _enterText($, find.text('رقم الهاتف أو البريد الإلكتروني'), kPhone);
        await _enterText($, find.text('كلمة المرور'), kPassword);
        await _tap($, find.widgetWithText(ElevatedButton, 'تسجيل الدخول'));

        loggedIn = await _waitForAny(
          $,
          [find.textContaining('مرحباً'), find.text('ونش S.O.S')],
          timeout: const Duration(seconds: 60),
        );
        if (!loggedIn) {
          throw StateError('فشل تسجيل الدخول بالحساب الموجود');
        }
      }

      // منح أي أذونات نظام (الموقع/الإشعارات) قد تظهر تلقائياً
      await _grantNativePermissionsIfVisible($);

      await _expectVisible(
        $,
        [find.text('ونش S.O.S')],
        reason: 'الرئيسية: قائمة خدمات الطوارئ',
      );

      // 6) تبويب الطلبات (آخر الطلبات) ← سجل الطلبات الكامل
      await _tap($, find.byIcon(Icons.receipt_long_outlined));
      await _expectVisible(
        $,
        [find.text('عرض الكل'), find.text('لا توجد طلبات حالياً')],
        reason: 'تبويب الطلبات',
      );
      if (await _waitForAny($, [find.text('عرض الكل')], timeout: const Duration(seconds: 10))) {
        await _tap($, find.text('عرض الكل'));
        await _expectVisible(
          $,
          [find.text('سجل الطلبات')],
          reason: 'شاشة سجل الطلبات',
        );
        await _tap($, find.byIcon(Icons.arrow_back_ios_rounded));
      } else {
        // لا طلبات وليس هناك "عرض الكل" → نواصل
      }

      // 7) تبويب الإشعارات
      await _tap($, find.byIcon(Icons.notifications_outlined));
      await _expectVisible(
        $,
        [find.text('لا توجد إشعارات جديدة'), find.byType(ListView)],
        reason: 'تبويب الإشعارات',
      );

      // 8) تبويب حسابي → الملف الشخصي
      await _tap($, find.byIcon(Icons.person_outline_rounded));
      await _expectVisible(
        $,
        [find.text('تسجيل الخروج'), find.text('الملف الشخصي')],
        reason: 'تبويب حسابي',
      );
      await _tap($, find.text('الملف الشخصي'));

      await _expectVisible(
        $,
        [find.text('تعديل البيانات الشخصية'), find.text('إدارة السيارات')],
        reason: 'شاشة الملف الشخصي',
      );

      // 8.1) تعديل البيانات الشخصية تُعرض بقيمها الحالية
      await _tap($, find.text('تعديل البيانات الشخصية'));
      await _expectVisible(
        $,
        [find.text('الاسم الكامل'), find.text('رقم الهاتف')],
        reason: 'شاشة تعديل البيانات',
      );
      // الهاتف مملوء مسبقاً (لا نعدّله حتى لا نغيير البيانات)
      await _waitForAny(
        $,
        [find.text(kPhone)],
        timeout: const Duration(seconds: 5),
      );
      await _tap($, find.byIcon(Icons.arrow_back_ios_rounded));

      // 8.2) إدارة السيارات
      await _expectVisible(
        $,
        [find.text('إدارة السيارات')],
        reason: 'العودة للملف الشخصي',
      );
      await _tap($, find.text('إدارة السيارات'));
      await _expectVisible(
        $,
        [find.text('لا توجد سيارات مسجلة'), find.byIcon(Icons.delete_outline_rounded)],
        reason: 'شاشة إدارة السيارات',
      );
      await _tap($, find.byIcon(Icons.arrow_back_ios_rounded));
      await _tap($, find.byIcon(Icons.arrow_back_ios_rounded));

      // 9) العودة للتبويب الرئيسي وفتح شاشة طلب الخدمة (بدون إرسال طلب)
      await _tap($, find.byIcon(Icons.home_outlined));
      await _expectVisible(
        $,
        [find.text('ونش S.O.S')],
        reason: 'تبويب الرئيسية',
      );
      await _tap($, find.text('ونش S.O.S'));
      await _expectVisible(
        $,
        [find.text('موقع العطل')],
        timeout: const Duration(seconds: 40),
        reason: 'شاشة طلب الخدمة (الخريطة)',
      );
      await _tap($, find.byIcon(Icons.arrow_back_ios_rounded));

      // 10) نؤكد أننا رجعنا للرئيسية سالمين
      await _expectVisible(
        $,
        [find.text('ونش S.O.S')],
        reason: 'الرئيسية بعد إغلاق طلب الخدمة',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}