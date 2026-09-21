// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'محور';

  @override
  String get version => 'إصدار 1.0.0';

  @override
  String get carOwner => 'مالك السيارة';

  @override
  String get carOwnerDesc => 'اطلب أقرب خدمات الطوارئ لسيارتك بكل سهولة';

  @override
  String get serviceProvider => 'مقدم الخدمة';

  @override
  String get serviceProviderDesc => 'استقبل طلبات الطوارئ وقدم خدماتك للعملاء';

  @override
  String get selectUserType => 'اختر نوع المستخدم';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get signup => 'إنشاء حساب جديد';

  @override
  String get skip => 'تخطي';

  @override
  String get next => 'التالي';

  @override
  String get termsAndConditions => 'الشروط والأحكام';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get phoneOrEmail => 'رقم الهاتف أو البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get fullName => 'الاسم رباعي';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get email => 'البريد الإلكتروني (اختياري)';

  @override
  String get nationalId => 'الرقم القومي';

  @override
  String get nationalIdOptionalHint => 'اختياري عند التسجيل، مطلوب للطلب';

  @override
  String get nationalIdRequiredHint => 'الرقم القومي مطلوب لإجراء طلبات الخدمة';

  @override
  String get carMake => 'نوع السيارة';

  @override
  String get carModel => 'الموديل';

  @override
  String get carYear => 'سنة الصنع';

  @override
  String get agreeToTerms => 'أوافق على الشروط والأحكام وسياسة الخصوصية';

  @override
  String get workshopName => 'اسم التوكيل / الورشة';

  @override
  String get address => 'العنوان';

  @override
  String get specialization => 'التخصص';

  @override
  String get supportScope => 'نطاق الدعم';

  @override
  String get hasVehicle => 'هل لديك سيارة خدمة؟';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get vehicleSpecs => 'مواصفات السيارة';

  @override
  String get otpTitle => 'تأكيد رقم الهاتف';

  @override
  String get otpSubTitle => 'أدخل رمز التحقق المكوّن من 6 أرقام';

  @override
  String otpCodeSentTo(String phone) {
    return 'أدخل رمز التحقق المكوّن من 6 أرقام الذي أُرسل إلى $phone';
  }

  @override
  String get resendCode => 'إعادة إرسال الرمز';

  @override
  String resendCodeIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String get useAnotherNumber => 'استخدام رقم آخر';

  @override
  String get didNotReceiveCode => 'لم يصلك الرمز؟';

  @override
  String get changeNumberTitle => 'تغيير رقم الهاتف';

  @override
  String get changeNumberSubTitle =>
      'أدخل رقم الهاتف الجديد وسنرسل إليه رمز التحقق';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get verify => 'تأكيد';

  @override
  String get home => 'الرئيسية';

  @override
  String get services => 'الخدمات';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get history => 'سجل الطلبات';

  @override
  String get aboutApp => 'عن التطبيق';

  @override
  String get crane => 'ونش s.o.s';

  @override
  String get tire => 'خدمات الإطارات';

  @override
  String get fuel => 'تزويد بنزين';

  @override
  String get battery => 'بطاريات/كهرباء';

  @override
  String get mechanical => 'ميكانيكي طوارئ';

  @override
  String get requestService => 'اطلب خدمة';

  @override
  String get offerPrice => 'تقديم عرض سعر';

  @override
  String get acceptPrice => 'قبول السعر';

  @override
  String get rejectPrice => 'رفض السعر';

  @override
  String get cancelOrder => 'إلغاء الطلب';

  @override
  String get priceOffered => 'السعر المعروض';

  @override
  String get egp => 'ج.م';

  @override
  String get nearestProviders => 'أقرب المذودين المتاحين';

  @override
  String get km => 'كم';

  @override
  String get orderStatusPending => 'قيد الإرسال للمذود';

  @override
  String get orderStatusPriced => 'تم تقديم عرض سعر';

  @override
  String get orderStatusConfirmed => 'تم تأكيد الطلب';

  @override
  String get orderStatusRejectedProvider => 'تم رفض الطلب من المذود';

  @override
  String get orderStatusRejectedOwner => 'تم رفض السعر من العميل';

  @override
  String get orderStatusCancelled => 'ملغى';

  @override
  String get lightTheme => 'الوضع الفاتح';

  @override
  String get darkTheme => 'الوضع الداكن';

  @override
  String get switchToEnglish => 'التبديل إلى الإنجليزية';

  @override
  String get switchToArabic => 'التبديل إلى العربية';

  @override
  String get policyPlaceholder =>
      'سيتم عرض المحتوى الكامل في شاشة مخصصة قريباً.';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get editPersonalInfo => 'تعديل البيانات الشخصية';

  @override
  String get manageCars => 'إدارة السيارات';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get currentLanguage => 'العربية';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get termsOfUse => 'شروط الاستخدام';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutFailedMessage =>
      'لم نتمكن من تسجيل الخروج. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get carDataRequired => 'بيانات السيارة (إجباري)';

  @override
  String get selectMakeFirst => 'اختر ماركة السيارة أولاً';

  @override
  String get selectModelFirst => 'اختر الموديل أولاً';

  @override
  String get carMakeRequired => 'يرجى اختيار ماركة السيارة';

  @override
  String get carModelRequired => 'يرجى اختيار موديل السيارة';

  @override
  String get carYearRequired => 'يرجى اختيار سنة الصنع';

  @override
  String get myAccount => 'حسابي';

  @override
  String get orders => 'الطلبات';

  @override
  String get noNewNotifications => 'لا توجد إشعارات جديدة';

  @override
  String get welcomeUser => 'مرحباً،';

  @override
  String get setLocation => 'تحديد الموقع...';

  @override
  String get sosEmergency => 'S.O.S طوارئ';

  @override
  String get sosTapForHelp => 'اضغط للحصول على نجدة فورية';

  @override
  String get emergencyServices => 'خدمات الطوارئ';

  @override
  String get providerLabel => 'المزود:';

  @override
  String get orderHistory => 'سجل الطلبات';

  @override
  String get noOrdersCurrently => 'لا توجد طلبات حالياً';

  @override
  String get faultLocation => 'موقع العطل';

  @override
  String get faultDescription => 'وصف العطل / ملاحظات';

  @override
  String get faultHint => 'اكتب وصفاً مختصراً للعطل...';

  @override
  String get sendRequest => 'إرسال الطلب';

  @override
  String get selectLocationOnMap => 'يرجى تحديد موقع السيارة على الخريطة';

  @override
  String get tapMapToSetLocation => 'اضغط على الخريطة لتحديد الموقع';

  @override
  String get brokenDownCar => 'السيارة المتعطلة';

  @override
  String get noCarAdded =>
      'لم تقم بإضافة سيارة بعد. أضف سيارة من الملف الشخصي أولاً.';

  @override
  String get selectCar => 'اختر السيارة';

  @override
  String get trackOrder => 'تتبع الطلب';

  @override
  String get searchingProvider => 'جاري البحث عن أقرب مزود متاح...';

  @override
  String get backToHome => 'العودة للرئيسية';

  @override
  String get searchingProviderTitle => 'جاري البحث عن مزود...';

  @override
  String get priceOfferReceived => 'تم استلام عرض سعر!';

  @override
  String get orderConfirmed => 'تم تأكيد الطلب';

  @override
  String get rejectedByProvider => 'تم رفض الطلب من المزود';

  @override
  String get priceRejected => 'تم رفض عرض السعر';

  @override
  String get orderCancelled => 'تم إلغاء الطلب';

  @override
  String get searchingProviderSub => 'نبحث عن أقرب مزود خدمة متاح لمساعدتك';

  @override
  String get reviewPriceOfferSub => 'يمكنك مراجعة عرض السعر والقبول أو الرفض';

  @override
  String get providerOnWaySub => 'المزود في طريقه إليك الآن';

  @override
  String get resendOrChooseOther =>
      'يمكنك إعادة إرسال الطلب أو اختيار مزود آخر';

  @override
  String get orderCancelledSub => 'تم إلغاء هذا الطلب';

  @override
  String get priceOfferLabel => 'عرض السعر';

  @override
  String get reject => 'رفض';

  @override
  String get call => 'اتصال';

  @override
  String get message => 'رسالة';

  @override
  String get confirmedLabel => 'مؤكد';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get noOrders => 'لا توجد طلبات';

  @override
  String get allTab => 'الكل';

  @override
  String get activeTab => 'النشطة';

  @override
  String get completedTab => 'المكتملة';

  @override
  String get cancelledTab => 'الملغاة';

  @override
  String get serviceLabel => 'خدمة:';

  @override
  String get orderConfirmedShort => 'مؤكد';

  @override
  String get pendingLabel => 'قيد الإرسال';

  @override
  String get offerReceivedLabel => 'تم تقديم عرض';

  @override
  String get cancelledShortLabel => 'ملغي';

  @override
  String get min => 'دقيقة';

  @override
  String get markAllRead => 'قراءة الكل';

  @override
  String get notificationDetails => 'تفاصيل الإشعار';

  @override
  String get notificationSentAt => 'أُرسل في';

  @override
  String get notificationBroadcast => 'إشعار عام';

  @override
  String get nearbyRequests => 'الطلبات القريبة';

  @override
  String get offlineMessage => 'أنت غير متاح حالياً';

  @override
  String get offlineHint => 'فعّل وضع التوفر لاستقبال الطلبات';

  @override
  String get noNearbyRequests => 'لا توجد طلبات قريبة حالياً';

  @override
  String get workshopInfo => 'بيانات الورشة';

  @override
  String get mySpecializations => 'تخصصاتي';

  @override
  String get attachImages => 'إرفاق صور (اختياري)';

  @override
  String get camera => 'الكاميرا';

  @override
  String get gallery => 'المعرض';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountConfirm =>
      'هل أنت متأكد من حذف حسابك نهائياً؟ لن تتمكن من استعادته.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get savedSuccessfully => 'تم الحفظ بنجاح';

  @override
  String get autoCancelTitle => 'إلغاء الطلب تلقائياً بعد 5 دقائق';

  @override
  String get autoCancelSubtitle =>
      'إذا لم يكتمل طلبك خلال 5 دقائق سيُلغى تلقائياً (مفعّل افتراضياً)';

  @override
  String get sharePhoneTitle => 'مشاركة رقم هاتفي مع المزوّد';

  @override
  String get sharePhoneSubtitle =>
      'سيتيح للمزوّد رؤية رقمك والاتصال بك مباشرة (اختياري)';

  @override
  String get workingHours => 'ساعات العمل';

  @override
  String get workingHoursHint =>
      'حدد ساعات عملك — خارج هذه الساعات لن تظهر في قائمة المزودين المتاحين';

  @override
  String get closed => 'مغلق';

  @override
  String get openAt => 'بداية العمل';

  @override
  String get closeAt => 'نهاية العمل';

  @override
  String get workingHoursSetTimes => 'يرجى تحديد وقت بداية ونهاية العمل';

  @override
  String get workingHoursInvalidRange =>
      'يجب أن يكون وقت البداية قبل وقت النهاية';

  @override
  String get searchProviderHint => 'ابحث عن مزوّد بالاسم';

  @override
  String get noProvidersMatch => 'لا يوجد مزوّدون مطابقون للبحث';
}
