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
  /// **'أدخل رمز التحقيق المكون من 5 أرقام'**
  String get otpSubTitle;

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
