import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/signup_error_mapper.dart';

void main() {
  test('رسالة فارغة تعطي الخطأ العام', () {
    expect(mapSignupError('   ', null), 'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى');
  });

  test('رمز غير معروف يعطي الخطأ العام', () {
    expect(
      mapSignupError('SOMETHING_ELSE: boom', null),
      'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى',
    );
  });

  test('الرموز القديمة للتكرار ما زالت مدعومة (المُهاجرة معلّقة)', () {
    expect(mapSignupError('DUPLICATE_PHONE: ...', null), 'رقم الهاتف مسجّل بالفعل');
    expect(
      mapSignupError('DUPLICATE_NATIONAL_ID: ...', null),
      'الرقم القومي مسجّل بالفعل',
    );
  });

  test('الرمز القديم مع بادئة GoTrue يُلتقط بالمسح الاحتياطي', () {
    expect(
      mapSignupError('Database error saving new user: DUPLICATE_PHONE: ...', null),
      'رقم الهاتف مسجّل بالفعل',
    );
  });

  test('NATIONAL_ID_EXISTS bare يعطي رسالة الرقم القومي', () {
    expect(
      mapSignupError(
        'NATIONAL_ID_EXISTS: national ID is already registered',
        null,
      ),
      'الرقم القومي مسجّل بالفعل',
    );
  });

  test('NATIONAL_ID_EXISTS مع بادئة GoTrue يُلتقط', () {
    expect(
      mapSignupError(
        'Database error saving new user: NATIONAL_ID_EXISTS: national ID is already registered',
        null,
      ),
      'الرقم القومي مسجّل بالفعل',
    );
  });

  test('انتهاك قيد التفرّد (23505/duplicate key) يعطي رسالة تكرار', () {
    expect(
      mapSignupError(
        'Database error saving new user: duplicate key value violates '
        'unique constraint "profiles_phone_number_canonical_key"',
        null,
      ),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل',
    );
    expect(
      mapSignupError('23505: duplicate key value violates unique constraint', null),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل',
    );
  });

  test('ACCOUNT_EXISTS_AS:car_owner يوجّه لصفحة دخول العميل', () {
    expect(
      mapSignupError('ACCOUNT_EXISTS_AS:car_owner', null),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب عميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.',
    );
  });

  test('ACCOUNT_EXISTS_AS:provider يوجّه لصفحة دخول المزوّد', () {
    expect(
      mapSignupError('ACCOUNT_EXISTS_AS:provider', null),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب مزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.',
    );
  });

  test('ACCOUNT_EXISTS_AS مع بادئة GoTrue يُلتقط', () {
    expect(
      mapSignupError(
        'Database error saving new user: ACCOUNT_EXISTS_AS:provider',
        null,
      ),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب مزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.',
    );
  });

  test('ACCOUNT_EXISTS_AS بدور غير معروف يعطي رسالة عامة للتكرار', () {
    expect(
      mapSignupError('ACCOUNT_EXISTS_AS:admin', null),
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود.',
    );
  });

  group('أكواد سيارة المالك الجديدة', () {
    test('MISSING_VEHICLE تطالب باختيار سيارة', () {
      expect(
        mapSignupError('MISSING_VEHICLE: a vehicle is required', null),
        'يرجى اختيار سيارتك لإكمال التسجيل',
      );
    });

    test('MISSING_VEHICLE_YEAR و MISSING_VEHICLE_COLOR برسائل مستقلة', () {
      expect(
        mapSignupError('MISSING_VEHICLE_YEAR: required', null),
        'يرجى اختيار سنة صنع السيارة',
      );
      expect(
        mapSignupError('MISSING_VEHICLE_COLOR: required', null),
        'يرجى اختيار لون السيارة',
      );
    });

    test('أخطاء الكتالوج تُختصر لرسالة بيانات سيارة غير صحيحة', () {
      for (final code in [
        'VEHICLE_TRIM_NOT_FOUND',
        'INVALID_MODEL_YEAR',
        'VEHICLE_COLOR_NOT_FOUND',
        'INVALID_PLATE',
      ]) {
        expect(
          mapSignupError('$code: invalid', null),
          'بيانات السيارة المختارة غير صحيحة، يرجى اختيارها مرة أخرى',
        );
      }
    });

    test('رمز السيارة مع بادئة GoTrue يُلتقط', () {
      expect(
        mapSignupError(
          'Database error saving new user: MISSING_VEHICLE: a vehicle is required',
          null,
        ),
        'يرجى اختيار سيارتك لإكمال التسجيل',
      );
    });
  });
}
