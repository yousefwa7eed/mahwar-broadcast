import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'محور'**
  String get appTitle;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'إصدار 1.0.0'**
  String get version;

  /// No description provided for @carOwner.
  ///
  /// In ar, this message translates to:
  /// **'مالك السيارة'**
  String get carOwner;

  /// No description provided for @carOwnerDesc.
  ///
  /// In ar, this message translates to:
  /// **'اطلب أقرب خدمات الطوارئ لسيارتك بكل سهولة'**
  String get carOwnerDesc;

  /// No description provided for @serviceProvider.
  ///
  /// In ar, this message translates to:
  /// **'مقدم الخدمة'**
  String get serviceProvider;

  /// No description provided for @serviceProviderDesc.
  ///
  /// In ar, this message translates to:
  /// **'استقبل طلبات الطوارئ وقدم خدماتك للعملاء'**
  String get serviceProviderDesc;

  /// No description provided for @selectUserType.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع المستخدم'**
  String get selectUserType;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get signup;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @termsAndConditions.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get termsAndConditions;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @phoneOrEmail.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو البريد الإلكتروني'**
  String get phoneOrEmail;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم رباعي'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني (اختياري)'**
  String get email;

  /// No description provided for @nationalId.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي'**
  String get nationalId;

  /// No description provided for @nationalIdOptionalHint.
  ///
  /// In ar, this message translates to:
  /// **'اختياري عند التسجيل، مطلوب للطلب'**
  String get nationalIdOptionalHint;

  /// No description provided for @nationalIdRequiredHint.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي مطلوب لإجراء طلبات الخدمة'**
  String get nationalIdRequiredHint;

  /// No description provided for @carMake.
  ///
  /// In ar, this message translates to:
  /// **'نوع السيارة'**
  String get carMake;

  /// No description provided for @carModel.
  ///
  /// In ar, this message translates to:
  /// **'الموديل'**
  String get carModel;

  /// No description provided for @carYear.
  ///
  /// In ar, this message translates to:
  /// **'سنة الصنع'**
  String get carYear;

  /// No description provided for @agreeToTerms.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على الشروط والأحكام وسياسة الخصوصية'**
  String get agreeToTerms;

  /// No description provided for @workshopName.
  ///
  /// In ar, this message translates to:
  /// **'اسم التوكيل / الورشة'**
  String get workshopName;

  /// No description provided for @address.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get address;

  /// No description provided for @specialization.
  ///
  /// In ar, this message translates to:
  /// **'التخصص'**
  String get specialization;

  /// No description provided for @supportScope.
  ///
  /// In ar, this message translates to:
  /// **'نطاق الدعم'**
  String get supportScope;

  /// No description provided for @hasVehicle.
  ///
  /// In ar, this message translates to:
  /// **'هل لديك سيارة خدمة؟'**
  String get hasVehicle;

  /// No description provided for @yes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get no;

  /// No description provided for @vehicleSpecs.
  ///
  /// In ar, this message translates to:
  /// **'مواصفات السيارة'**
  String get vehicleSpecs;

  /// No description provided for @otpTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد رقم الهاتف'**
  String get otpTitle;

  /// No description provided for @otpSubTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق المكوّن من 6 أرقام'**
  String get otpSubTitle;

  /// No description provided for @otpCodeSentTo.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق المكوّن من 6 أرقام الذي أُرسل إلى {phone}'**
  String otpCodeSentTo(String phone);

  /// No description provided for @resendCode.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز'**
  String get resendCode;

  /// No description provided for @resendCodeIn.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال بعد {seconds} ثانية'**
  String resendCodeIn(int seconds);

  /// No description provided for @useAnotherNumber.
  ///
  /// In ar, this message translates to:
  /// **'استخدام رقم آخر'**
  String get useAnotherNumber;

  /// No description provided for @didNotReceiveCode.
  ///
  /// In ar, this message translates to:
  /// **'لم يصلك الرمز؟'**
  String get didNotReceiveCode;

  /// No description provided for @changeNumberTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيير رقم الهاتف'**
  String get changeNumberTitle;

  /// No description provided for @changeNumberSubTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الهاتف الجديد وسنرسل إليه رمز التحقق'**
  String get changeNumberSubTitle;

  /// No description provided for @phoneChangeRequiresOtp.
  ///
  /// In ar, this message translates to:
  /// **'لتغيير رقم الهاتف يجب التحقق منه برمز SMS. استخدم زر تغيير الرقم.'**
  String get phoneChangeRequiresOtp;

  /// No description provided for @sendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرمز'**
  String get sendCode;

  /// No description provided for @verify.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get verify;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @services.
  ///
  /// In ar, this message translates to:
  /// **'الخدمات'**
  String get services;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In ar, this message translates to:
  /// **'سجل الطلبات'**
  String get history;

  /// No description provided for @aboutApp.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get aboutApp;

  /// No description provided for @crane.
  ///
  /// In ar, this message translates to:
  /// **'ونش s.o.s'**
  String get crane;

  /// No description provided for @tire.
  ///
  /// In ar, this message translates to:
  /// **'خدمات الإطارات'**
  String get tire;

  /// No description provided for @fuel.
  ///
  /// In ar, this message translates to:
  /// **'تزويد بنزين'**
  String get fuel;

  /// No description provided for @battery.
  ///
  /// In ar, this message translates to:
  /// **'بطاريات/كهرباء'**
  String get battery;

  /// No description provided for @mechanical.
  ///
  /// In ar, this message translates to:
  /// **'ميكانيكي طوارئ'**
  String get mechanical;

  /// No description provided for @requestService.
  ///
  /// In ar, this message translates to:
  /// **'اطلب خدمة'**
  String get requestService;

  /// No description provided for @offerPrice.
  ///
  /// In ar, this message translates to:
  /// **'تقديم عرض سعر'**
  String get offerPrice;

  /// No description provided for @acceptPrice.
  ///
  /// In ar, this message translates to:
  /// **'قبول السعر'**
  String get acceptPrice;

  /// No description provided for @rejectPrice.
  ///
  /// In ar, this message translates to:
  /// **'رفض السعر'**
  String get rejectPrice;

  /// No description provided for @cancelOrder.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelOrder;

  /// No description provided for @priceOffered.
  ///
  /// In ar, this message translates to:
  /// **'السعر المعروض'**
  String get priceOffered;

  /// No description provided for @egp.
  ///
  /// In ar, this message translates to:
  /// **'ج.م'**
  String get egp;

  /// No description provided for @nearestProviders.
  ///
  /// In ar, this message translates to:
  /// **'أقرب المذودين المتاحين'**
  String get nearestProviders;

  /// No description provided for @km.
  ///
  /// In ar, this message translates to:
  /// **'كم'**
  String get km;

  /// No description provided for @orderStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد الإرسال للمذود'**
  String get orderStatusPending;

  /// No description provided for @orderStatusPriced.
  ///
  /// In ar, this message translates to:
  /// **'تم تقديم عرض سعر'**
  String get orderStatusPriced;

  /// No description provided for @orderStatusConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد الطلب'**
  String get orderStatusConfirmed;

  /// No description provided for @orderStatusRejectedProvider.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب من المذود'**
  String get orderStatusRejectedProvider;

  /// No description provided for @orderStatusRejectedOwner.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض السعر من العميل'**
  String get orderStatusRejectedOwner;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get orderStatusCancelled;

  /// No description provided for @lightTheme.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الفاتح'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get darkTheme;

  /// No description provided for @switchToEnglish.
  ///
  /// In ar, this message translates to:
  /// **'التبديل إلى الإنجليزية'**
  String get switchToEnglish;

  /// No description provided for @switchToArabic.
  ///
  /// In ar, this message translates to:
  /// **'التبديل إلى العربية'**
  String get switchToArabic;

  /// No description provided for @policyPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'سيتم عرض المحتوى الكامل في شاشة مخصصة قريباً.'**
  String get policyPlaceholder;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @editPersonalInfo.
  ///
  /// In ar, this message translates to:
  /// **'تعديل البيانات الشخصية'**
  String get editPersonalInfo;

  /// No description provided for @manageCars.
  ///
  /// In ar, this message translates to:
  /// **'إدارة السيارات'**
  String get manageCars;

  /// No description provided for @languageLabel.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get languageLabel;

  /// No description provided for @currentLanguage.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get currentLanguage;

  /// No description provided for @lightMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الفاتح'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get darkMode;

  /// No description provided for @termsOfUse.
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get termsOfUse;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logoutFailedMessage.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من تسجيل الخروج. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.'**
  String get logoutFailedMessage;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @profileLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بياناتك الشخصية'**
  String get profileLoadFailed;

  /// No description provided for @carDataRequired.
  ///
  /// In ar, this message translates to:
  /// **'بيانات السيارة (إجباري)'**
  String get carDataRequired;

  /// No description provided for @selectMakeFirst.
  ///
  /// In ar, this message translates to:
  /// **'اختر ماركة السيارة أولاً'**
  String get selectMakeFirst;

  /// No description provided for @selectModelFirst.
  ///
  /// In ar, this message translates to:
  /// **'اختر الموديل أولاً'**
  String get selectModelFirst;

  /// No description provided for @carMakeRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار ماركة السيارة'**
  String get carMakeRequired;

  /// No description provided for @carModelRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار موديل السيارة'**
  String get carModelRequired;

  /// No description provided for @carYearRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار سنة الصنع'**
  String get carYearRequired;

  /// No description provided for @myAccount.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get myAccount;

  /// No description provided for @orders.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get orders;

  /// No description provided for @noNewNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات جديدة'**
  String get noNewNotifications;

  /// No description provided for @welcomeUser.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً،'**
  String get welcomeUser;

  /// No description provided for @setLocation.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الموقع...'**
  String get setLocation;

  /// No description provided for @sosEmergency.
  ///
  /// In ar, this message translates to:
  /// **'S.O.S طوارئ'**
  String get sosEmergency;

  /// No description provided for @sosTapForHelp.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للحصول على نجدة فورية'**
  String get sosTapForHelp;

  /// No description provided for @emergencyServices.
  ///
  /// In ar, this message translates to:
  /// **'خدمات الطوارئ'**
  String get emergencyServices;

  /// No description provided for @providerLabel.
  ///
  /// In ar, this message translates to:
  /// **'المزود:'**
  String get providerLabel;

  /// No description provided for @orderHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الطلبات'**
  String get orderHistory;

  /// No description provided for @noOrdersCurrently.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات حالياً'**
  String get noOrdersCurrently;

  /// No description provided for @faultLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع العطل'**
  String get faultLocation;

  /// No description provided for @faultDescription.
  ///
  /// In ar, this message translates to:
  /// **'وصف العطل / ملاحظات'**
  String get faultDescription;

  /// No description provided for @faultHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب وصفاً مختصراً للعطل...'**
  String get faultHint;

  /// No description provided for @sendRequest.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get sendRequest;

  /// No description provided for @selectLocationOnMap.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحديد موقع السيارة على الخريطة'**
  String get selectLocationOnMap;

  /// No description provided for @tapMapToSetLocation.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على الخريطة لتحديد الموقع'**
  String get tapMapToSetLocation;

  /// No description provided for @brokenDownCar.
  ///
  /// In ar, this message translates to:
  /// **'السيارة المتعطلة'**
  String get brokenDownCar;

  /// No description provided for @noCarAdded.
  ///
  /// In ar, this message translates to:
  /// **'لم تقم بإضافة سيارة بعد. أضف سيارة من الملف الشخصي أولاً.'**
  String get noCarAdded;

  /// No description provided for @selectCar.
  ///
  /// In ar, this message translates to:
  /// **'اختر السيارة'**
  String get selectCar;

  /// No description provided for @trackOrder.
  ///
  /// In ar, this message translates to:
  /// **'تتبع الطلب'**
  String get trackOrder;

  /// No description provided for @searchingProvider.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث عن أقرب مزود متاح...'**
  String get searchingProvider;

  /// No description provided for @backToHome.
  ///
  /// In ar, this message translates to:
  /// **'العودة للرئيسية'**
  String get backToHome;

  /// No description provided for @searchingProviderTitle.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث عن مزود...'**
  String get searchingProviderTitle;

  /// No description provided for @priceOfferReceived.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام عرض سعر!'**
  String get priceOfferReceived;

  /// No description provided for @orderConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد الطلب'**
  String get orderConfirmed;

  /// No description provided for @rejectedByProvider.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب من المزود'**
  String get rejectedByProvider;

  /// No description provided for @priceRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض عرض السعر'**
  String get priceRejected;

  /// No description provided for @orderCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الطلب'**
  String get orderCancelled;

  /// No description provided for @searchingProviderSub.
  ///
  /// In ar, this message translates to:
  /// **'نبحث عن أقرب مزود خدمة متاح لمساعدتك'**
  String get searchingProviderSub;

  /// No description provided for @reviewPriceOfferSub.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك مراجعة عرض السعر والقبول أو الرفض'**
  String get reviewPriceOfferSub;

  /// No description provided for @providerOnWaySub.
  ///
  /// In ar, this message translates to:
  /// **'المزود في طريقه إليك الآن'**
  String get providerOnWaySub;

  /// No description provided for @resendOrChooseOther.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إعادة إرسال الطلب أو اختيار مزود آخر'**
  String get resendOrChooseOther;

  /// No description provided for @orderCancelledSub.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء هذا الطلب'**
  String get orderCancelledSub;

  /// No description provided for @priceOfferLabel.
  ///
  /// In ar, this message translates to:
  /// **'عرض السعر'**
  String get priceOfferLabel;

  /// No description provided for @reject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get reject;

  /// No description provided for @call.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get call;

  /// No description provided for @message.
  ///
  /// In ar, this message translates to:
  /// **'رسالة'**
  String get message;

  /// No description provided for @confirmedLabel.
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get confirmedLabel;

  /// No description provided for @noNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get noNotifications;

  /// No description provided for @noOrders.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات'**
  String get noOrders;

  /// No description provided for @allTab.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get allTab;

  /// No description provided for @activeTab.
  ///
  /// In ar, this message translates to:
  /// **'النشطة'**
  String get activeTab;

  /// No description provided for @completedTab.
  ///
  /// In ar, this message translates to:
  /// **'المكتملة'**
  String get completedTab;

  /// No description provided for @cancelledTab.
  ///
  /// In ar, this message translates to:
  /// **'الملغاة'**
  String get cancelledTab;

  /// No description provided for @serviceLabel.
  ///
  /// In ar, this message translates to:
  /// **'خدمة:'**
  String get serviceLabel;

  /// No description provided for @orderConfirmedShort.
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get orderConfirmedShort;

  /// No description provided for @pendingLabel.
  ///
  /// In ar, this message translates to:
  /// **'قيد الإرسال'**
  String get pendingLabel;

  /// No description provided for @offerReceivedLabel.
  ///
  /// In ar, this message translates to:
  /// **'تم تقديم عرض'**
  String get offerReceivedLabel;

  /// No description provided for @cancelledShortLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملغي'**
  String get cancelledShortLabel;

  /// No description provided for @min.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get min;

  /// No description provided for @markAllRead.
  ///
  /// In ar, this message translates to:
  /// **'قراءة الكل'**
  String get markAllRead;

  /// No description provided for @notificationDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الإشعار'**
  String get notificationDetails;

  /// No description provided for @notificationSentAt.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل في'**
  String get notificationSentAt;

  /// No description provided for @notificationBroadcast.
  ///
  /// In ar, this message translates to:
  /// **'إشعار عام'**
  String get notificationBroadcast;

  /// No description provided for @nearbyRequests.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات القريبة'**
  String get nearbyRequests;

  /// No description provided for @offlineMessage.
  ///
  /// In ar, this message translates to:
  /// **'أنت غير متاح حالياً'**
  String get offlineMessage;

  /// No description provided for @offlineHint.
  ///
  /// In ar, this message translates to:
  /// **'فعّل وضع التوفر لاستقبال الطلبات'**
  String get offlineHint;

  /// No description provided for @noNearbyRequests.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات قريبة حالياً'**
  String get noNearbyRequests;

  /// No description provided for @workshopInfo.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الورشة'**
  String get workshopInfo;

  /// No description provided for @mySpecializations.
  ///
  /// In ar, this message translates to:
  /// **'تخصصاتي'**
  String get mySpecializations;

  /// No description provided for @attachImages.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق صور (اختياري)'**
  String get attachImages;

  /// No description provided for @camera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In ar, this message translates to:
  /// **'المعرض'**
  String get gallery;

  /// No description provided for @deleteAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف حسابك نهائياً؟ لن تتمكن من استعادته.'**
  String get deleteAccountConfirm;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @savedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ بنجاح'**
  String get savedSuccessfully;

  /// No description provided for @autoCancelTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب تلقائياً بعد 5 دقائق'**
  String get autoCancelTitle;

  /// No description provided for @autoCancelSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'إذا لم يكتمل طلبك خلال 5 دقائق سيُلغى تلقائياً (مفعّل افتراضياً)'**
  String get autoCancelSubtitle;

  /// No description provided for @workingHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات العمل'**
  String get workingHours;

  /// No description provided for @workingHoursHint.
  ///
  /// In ar, this message translates to:
  /// **'حدد ساعات عملك — خارج هذه الساعات لن تظهر في قائمة المزودين المتاحين'**
  String get workingHoursHint;

  /// No description provided for @closed.
  ///
  /// In ar, this message translates to:
  /// **'مغلق'**
  String get closed;

  /// No description provided for @openAt.
  ///
  /// In ar, this message translates to:
  /// **'بداية العمل'**
  String get openAt;

  /// No description provided for @closeAt.
  ///
  /// In ar, this message translates to:
  /// **'نهاية العمل'**
  String get closeAt;

  /// No description provided for @workingHoursSetTimes.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحديد وقت بداية ونهاية العمل'**
  String get workingHoursSetTimes;

  /// No description provided for @workingHoursInvalidRange.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن يكون وقت البداية قبل وقت النهاية'**
  String get workingHoursInvalidRange;

  /// No description provided for @searchProviderHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مزوّد بالاسم'**
  String get searchProviderHint;

  /// No description provided for @noProvidersMatch.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مزوّدون مطابقون للبحث'**
  String get noProvidersMatch;

  /// No description provided for @nationalIdInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي غير صحيح، تأكد من كتابة 14 رقماً مطابقاً للبطاقة'**
  String get nationalIdInvalid;

  /// No description provided for @nationalIdValid.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي صحيح'**
  String get nationalIdValid;

  /// No description provided for @nationalIdRequiredToOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي مطلوب'**
  String get nationalIdRequiredToOrderTitle;

  /// No description provided for @nationalIdRequiredToOrderBody.
  ///
  /// In ar, this message translates to:
  /// **'لإرسال طلب خدمة يجب إضافة رقمك القومي الصحيح أولاً في البيانات الشخصية.'**
  String get nationalIdRequiredToOrderBody;

  /// No description provided for @goToPersonalInfo.
  ///
  /// In ar, this message translates to:
  /// **'الذهاب للبيانات الشخصية'**
  String get goToPersonalInfo;

  /// No description provided for @sharePhoneConsent.
  ///
  /// In ar, this message translates to:
  /// **'سيتم مشاركة رقم هاتفك مع مقدم الخدمة حتى انتهاء الطلب.'**
  String get sharePhoneConsent;

  /// No description provided for @m.
  ///
  /// In ar, this message translates to:
  /// **'م'**
  String get m;

  /// No description provided for @locationAccuracyLabel.
  ///
  /// In ar, this message translates to:
  /// **'دقة الموقع'**
  String get locationAccuracyLabel;

  /// No description provided for @approximateLocationWarning.
  ///
  /// In ar, this message translates to:
  /// **'الموقع تقريبي، قد لا يكون دقيقاً'**
  String get approximateLocationWarning;

  /// No description provided for @refineLocation.
  ///
  /// In ar, this message translates to:
  /// **'تحسين الدقة'**
  String get refineLocation;

  /// No description provided for @providerListUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديث القائمة'**
  String get providerListUpdateFailed;

  /// No description provided for @changePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get changePassword;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور الحالية ثم اختر كلمة مرور جديدة (٦ أحرف على الأقل).'**
  String get changePasswordSubtitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور الجديدة'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور بنجاح'**
  String get passwordChangedSuccess;

  /// No description provided for @passwordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن لا تقل عن 6 أحرف'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get passwordsDoNotMatch;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال كلمة المرور الحالية'**
  String get enterCurrentPassword;

  /// No description provided for @enterNewPassword.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال كلمة المرور الجديدة'**
  String get enterNewPassword;

  /// No description provided for @enterConfirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تأكيد كلمة المرور الجديدة'**
  String get enterConfirmPassword;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية غير صحيحة'**
  String get currentPasswordIncorrect;

  /// No description provided for @newPasswordSameAsCurrent.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة يجب أن تختلف عن الحالية'**
  String get newPasswordSameAsCurrent;

  /// No description provided for @reauthenticationRequired.
  ///
  /// In ar, this message translates to:
  /// **'لأمان حسابك، يرجى تسجيل الدخول من جديد قبل تغيير كلمة المرور'**
  String get reauthenticationRequired;

  /// No description provided for @changePasswordNoEmail.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تغيير كلمة المرور لعدم وجود بريد إلكتروني مرتبط بالحساب'**
  String get changePasswordNoEmail;

  /// No description provided for @changePasswordFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تغيير كلمة المرور. حاول مرة أخرى.'**
  String get changePasswordFailed;

  /// No description provided for @deleteAccountPasswordPrompt.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور الحالية لتأكيد حذف الحساب'**
  String get deleteAccountPasswordPrompt;

  /// No description provided for @changePasswordRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة، حاول بعد قليل'**
  String get changePasswordRateLimited;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @notificationTitleNewOrder.
  ///
  /// In ar, this message translates to:
  /// **'طلب جديد'**
  String get notificationTitleNewOrder;

  /// No description provided for @notificationTitlePriceOffer.
  ///
  /// In ar, this message translates to:
  /// **'عرض سعر جديد'**
  String get notificationTitlePriceOffer;

  /// No description provided for @notificationTitleOrderConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد الطلب'**
  String get notificationTitleOrderConfirmed;

  /// No description provided for @notificationTitleOrderRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب'**
  String get notificationTitleOrderRejected;

  /// No description provided for @notificationTitleOrderCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الطلب'**
  String get notificationTitleOrderCancelled;

  /// No description provided for @notificationTitleOrderCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تم إتمام الطلب'**
  String get notificationTitleOrderCompleted;

  /// No description provided for @notificationTitleShiftStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدء ساعات العمل'**
  String get notificationTitleShiftStarted;

  /// No description provided for @notificationTitleShiftEnded.
  ///
  /// In ar, this message translates to:
  /// **'انتهاء ساعات العمل'**
  String get notificationTitleShiftEnded;

  /// No description provided for @notificationTitleRatingReceived.
  ///
  /// In ar, this message translates to:
  /// **'تقييم جديد'**
  String get notificationTitleRatingReceived;

  /// No description provided for @notificationTitleNewMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة جديدة'**
  String get notificationTitleNewMessage;

  /// No description provided for @notificationTitleBroadcast.
  ///
  /// In ar, this message translates to:
  /// **'إشعار'**
  String get notificationTitleBroadcast;

  /// No description provided for @notificationTitleDefault.
  ///
  /// In ar, this message translates to:
  /// **'إشعار جديد'**
  String get notificationTitleDefault;

  /// No description provided for @notificationBodyNewOrderWithService.
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب جديد: {service}'**
  String notificationBodyNewOrderWithService(String service);

  /// No description provided for @notificationBodyNewOrder.
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب جديد'**
  String get notificationBodyNewOrder;

  /// No description provided for @notificationBodyPriceOfferWithService.
  ///
  /// In ar, this message translates to:
  /// **'{provider} قدم عرض سعر {price} {currency} لطلب {service}'**
  String notificationBodyPriceOfferWithService(
    String provider,
    String price,
    String currency,
    String service,
  );

  /// No description provided for @notificationBodyPriceOffer.
  ///
  /// In ar, this message translates to:
  /// **'{provider} قدم عرض سعر {price} {currency}'**
  String notificationBodyPriceOffer(
    String provider,
    String price,
    String currency,
  );

  /// No description provided for @notificationBodyPriceOfferReceived.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام عرض سعر جديد'**
  String get notificationBodyPriceOfferReceived;

  /// No description provided for @notificationBodyOrderConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد طلبك بنجاح'**
  String get notificationBodyOrderConfirmed;

  /// No description provided for @notificationBodyOrderRejectedWithProvider.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب من {provider}'**
  String notificationBodyOrderRejectedWithProvider(String provider);

  /// No description provided for @notificationBodyOrderRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب'**
  String get notificationBodyOrderRejected;

  /// No description provided for @notificationBodyOrderCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء هذا الطلب'**
  String get notificationBodyOrderCancelled;

  /// No description provided for @notificationBodyOrderCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تم إتمام خدمة الطلب بنجاح'**
  String get notificationBodyOrderCompleted;

  /// No description provided for @notificationBodyShiftStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأت ساعات عملك — أنت الآن متاح أمام العملاء'**
  String get notificationBodyShiftStarted;

  /// No description provided for @notificationBodyShiftEnded.
  ///
  /// In ar, this message translates to:
  /// **'انتهت ساعات عملك — أصبحت الآن غير متاح'**
  String get notificationBodyShiftEnded;

  /// No description provided for @notificationBodyRatingWithValue.
  ///
  /// In ar, this message translates to:
  /// **'حصلت على تقييم {rating} من 5'**
  String notificationBodyRatingWithValue(String rating);

  /// No description provided for @notificationBodyRating.
  ///
  /// In ar, this message translates to:
  /// **'حصلت على تقييم جديد'**
  String get notificationBodyRating;

  /// No description provided for @notificationBodyNewMessage.
  ///
  /// In ar, this message translates to:
  /// **'وصلتك رسالة جديدة'**
  String get notificationBodyNewMessage;

  /// No description provided for @notificationBodyDefault.
  ///
  /// In ar, this message translates to:
  /// **'يوجد تحديث جديد لتطبيق محور'**
  String get notificationBodyDefault;

  /// No description provided for @notificationTimeNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get notificationTimeNow;

  /// No description provided for @notificationTimeMinutes.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} دقيقة'**
  String notificationTimeMinutes(int count);

  /// No description provided for @notificationTimeHours.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} ساعة'**
  String notificationTimeHours(int count);

  /// No description provided for @notificationTimeDays.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} يوم'**
  String notificationTimeDays(int count);

  /// No description provided for @notificationRatingLabel.
  ///
  /// In ar, this message translates to:
  /// **'تقييم'**
  String get notificationRatingLabel;

  /// No description provided for @notificationRatingOfFive.
  ///
  /// In ar, this message translates to:
  /// **'{rating} من 5'**
  String notificationRatingOfFive(String rating);

  /// No description provided for @notificationFromCustomer.
  ///
  /// In ar, this message translates to:
  /// **'من العميل'**
  String get notificationFromCustomer;

  /// No description provided for @notificationCustomerFallback.
  ///
  /// In ar, this message translates to:
  /// **'العميل'**
  String get notificationCustomerFallback;

  /// No description provided for @notificationRatingDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ التقييم'**
  String get notificationRatingDate;

  /// No description provided for @notificationCommentLabel.
  ///
  /// In ar, this message translates to:
  /// **'تعليق'**
  String get notificationCommentLabel;

  /// No description provided for @viewTransactionDetails.
  ///
  /// In ar, this message translates to:
  /// **'عرض تفاصيل المعاملة'**
  String get viewTransactionDetails;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
