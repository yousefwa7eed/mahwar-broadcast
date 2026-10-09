import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/signup_error_mapper.dart';

void main() {
  test('رسالة فارغة تعطي الخطأ العام', () {
    expect(mapSignupError('   '), 'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى');
  });

  test('رمز غير معروف يعطي الخطأ العام', () {
    expect(
      mapSignupError('SOMETHING_ELSE: boom'),
      'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى',
    );
  });

  test('الرموز القديمة للتكرار ما زالت مدعومة (المُهاجرة معلّقة)', () {
    expect(mapSignupError('DUPLICATE_PHONE: ...'), 'رقم الهاتف مسجّل بالفعل');
    expect(
      mapSignupError('DUPLICATE_NATIONAL_ID: ...'),
      'الرقم القومي مسجّل بالفعل',
    );
  });

  test('الرمز القديم مع بادئة GoTrue يُلتقط بالمسح الاحتياطي', () {
    expect(
      mapSignupError('Database error saving new user: DUPLICATE_PHONE: ...'),
      'رقم الهاتف مسجّل بالفعل',
    );
  });

  test('ACCOUNT_EXISTS_AS:car_owner يوجّه لصفحة دخول العميل', () {
    expect(
      mapSignupError('ACCOUNT_EXISTS_AS:car_owner'),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب عميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.',
    );
  });

  test('ACCOUNT_EXISTS_AS:provider يوجّه لصفحة دخول المزوّد', () {
    expect(
      mapSignupError('ACCOUNT_EXISTS_AS:provider'),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب مزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.',
    );
  });

  test('ACCOUNT_EXISTS_AS مع بادئة GoTrue يُلتقط', () {
    expect(
      mapSignupError('Database error saving new user: ACCOUNT_EXISTS_AS:provider'),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب مزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.',
    );
  });

  test('ACCOUNT_EXISTS_AS بدور غير معروف يعطي رسالة عامة للتكرار', () {
    expect(
      mapSignupError('ACCOUNT_EXISTS_AS:admin'),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود.',
    );
  });
}
