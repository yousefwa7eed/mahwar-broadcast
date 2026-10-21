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

  /// No description provided for @loginMethod.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدخول'**
  String get loginMethod;

  /// No description provided for @phoneTab.
  ///
  /// In ar, this message translates to:
  /// **'هاتف'**
  String get phoneTab;

  /// No description provided for @emailTab.
  ///
  /// In ar, this message translates to:
  /// **'بريد'**
  String get emailTab;

  /// No description provided for @emailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailLabel;

  /// No description provided for @enterPhonePrompt.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الهاتف'**
  String get enterPhonePrompt;

  /// No description provided for @enterEmailPrompt.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال البريد الإلكتروني'**
  String get enterEmailPrompt;

  /// No description provided for @invalidPhoneShort.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتف مصري غير صحيح (مثال: 01012345678)'**
  String get invalidPhoneShort;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In ar, this message translates to:
  /// **'صيغة البريد الإلكتروني غير صحيحة'**
  String get invalidEmailFormat;

  /// No description provided for @enterPasswordPrompt.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال كلمة المرور'**
  String get enterPasswordPrompt;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ '**
  String get dontHaveAccount;

  /// No description provided for @loginHeaderTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل دخول'**
  String get loginHeaderTitle;

  /// No description provided for @loginWelcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بعودتك، يرجى إدخال بيانات حسابك للمتابعة'**
  String get loginWelcome;

  /// No description provided for @specTowTruck.
  ///
  /// In ar, this message translates to:
  /// **'ونش طوارئ S.O.S'**
  String get specTowTruck;

  /// No description provided for @specTire.
  ///
  /// In ar, this message translates to:
  /// **'خدمات الإطارات'**
  String get specTire;

  /// No description provided for @specBattery.
  ///
  /// In ar, this message translates to:
  /// **'بطاريات / كهرباء'**
  String get specBattery;

  /// No description provided for @specFuel.
  ///
  /// In ar, this message translates to:
  /// **'تزويد بنزين'**
  String get specFuel;

  /// No description provided for @specMechanical.
  ///
  /// In ar, this message translates to:
  /// **'ميكانيكي طوارئ'**
  String get specMechanical;

  /// No description provided for @signupFullNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم رباعي (إجباري)'**
  String get signupFullNameLabel;

  /// No description provided for @signupFullNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال الاسم رباعي'**
  String get signupFullNameRequired;

  /// No description provided for @signupPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف (إجباري)'**
  String get signupPhoneLabel;

  /// No description provided for @signupInvalidPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتف مصري غير صحيح (11 رقم مثال: 01012345678)'**
  String get signupInvalidPhone;

  /// No description provided for @signupEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني (اختياري)'**
  String get signupEmailLabel;

  /// No description provided for @signupNationalIdLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي (اختياري)'**
  String get signupNationalIdLabel;

  /// No description provided for @signupNationalIdHint.
  ///
  /// In ar, this message translates to:
  /// **'اختياري عند التسجيل، مطلوب فقط لإتمام طلب خدمة'**
  String get signupNationalIdHint;

  /// No description provided for @signupInvalidNationalId.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي غير صحيح (14 رقم)'**
  String get signupInvalidNationalId;

  /// No description provided for @signupPasswordMismatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور غير متطابقة'**
  String get signupPasswordMismatch;

  /// No description provided for @signupAgreeTerms.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على شروط الاستخدام وسياسة الخصوصية'**
  String get signupAgreeTerms;

  /// No description provided for @signupAgreeTermsRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب الموافقة على شروط الاستخدام وسياسة الخصوصية للمتابعة'**
  String get signupAgreeTermsRequired;

  /// No description provided for @providerEnableLocationService.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك'**
  String get providerEnableLocationService;

  /// No description provided for @providerLocationDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض إذن الوصول للموقع'**
  String get providerLocationDenied;

  /// No description provided for @providerLocationDeniedForever.
  ///
  /// In ar, this message translates to:
  /// **'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق'**
  String get providerLocationDeniedForever;

  /// No description provided for @providerLocationFilled.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد موقعك وكتابة العنوان، يمكنك تعديله يدويًا'**
  String get providerLocationFilled;

  /// No description provided for @providerLocationDetectFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع الحالي'**
  String get providerLocationDetectFailed;

  /// No description provided for @providerSelectSpecPrompt.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار تخصص واحد على الأقل'**
  String get providerSelectSpecPrompt;

  /// No description provided for @providerAgreeTermsPrompt.
  ///
  /// In ar, this message translates to:
  /// **'يجب الموافقة على الشروط والأحكام وميثاق الخدمة'**
  String get providerAgreeTermsPrompt;

  /// No description provided for @providerFullNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال الاسم رباعي'**
  String get providerFullNameRequired;

  /// No description provided for @providerNameAtLeast3.
  ///
  /// In ar, this message translates to:
  /// **'يرجى كتابة الاسم الثلاثي على الأقل'**
  String get providerNameAtLeast3;

  /// No description provided for @providerEnterPhone.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الهاتف'**
  String get providerEnterPhone;

  /// No description provided for @providerInvalidPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتف مصري غير صحيح (11 رقم)'**
  String get providerInvalidPhone;

  /// No description provided for @providerNationalIdHint.
  ///
  /// In ar, this message translates to:
  /// **'14 رقم قومي مدون في البطاقة'**
  String get providerNationalIdHint;

  /// No description provided for @providerNationalIdHelper.
  ///
  /// In ar, this message translates to:
  /// **'إجباري لمزودي الخدمة لتوثيق الحساب والأمان'**
  String get providerNationalIdHelper;

  /// No description provided for @providerNationalIdRequired.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي إجباري لمزودي الخدمة'**
  String get providerNationalIdRequired;

  /// No description provided for @providerWorkshopSectionTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الورشة والخدمة'**
  String get providerWorkshopSectionTitle;

  /// No description provided for @providerWorkshopRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال اسم الورشة أو التوكيل'**
  String get providerWorkshopRequired;

  /// No description provided for @providerAddressHint.
  ///
  /// In ar, this message translates to:
  /// **'حدد موقعك تلقائيًا أو اكتب العنوان يدويًا'**
  String get providerAddressHint;

  /// No description provided for @providerLocateTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تحديد موقعي وكتابة العنوان تلقائيًا'**
  String get providerLocateTooltip;

  /// No description provided for @providerAddressRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال عنوان الورشة/المقر'**
  String get providerAddressRequired;

  /// No description provided for @providerAutoFillHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على أيقونة الموقع لملء العنوان تلقائيًا، ويمكنك تعديله بعد ذلك'**
  String get providerAutoFillHint;

  /// No description provided for @providerScopeRoadside.
  ///
  /// In ar, this message translates to:
  /// **'طوارئ الطريق'**
  String get providerScopeRoadside;

  /// No description provided for @providerScopeOnSite.
  ///
  /// In ar, this message translates to:
  /// **'في الورشة'**
  String get providerScopeOnSite;

  /// No description provided for @providerVehicleMakeLabel.
  ///
  /// In ar, this message translates to:
  /// **'ماركة السيارة'**
  String get providerVehicleMakeLabel;

  /// No description provided for @providerVehicleMakeHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: تويوتا'**
  String get providerVehicleMakeHint;

  /// No description provided for @providerVehicleMakeRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال ماركة السيارة'**
  String get providerVehicleMakeRequired;

  /// No description provided for @providerVehicleModelLabel.
  ///
  /// In ar, this message translates to:
  /// **'موديل السيارة'**
  String get providerVehicleModelLabel;

  /// No description provided for @providerVehicleModelHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: كورولا'**
  String get providerVehicleModelHint;

  /// No description provided for @providerVehicleModelRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال موديل السيارة'**
  String get providerVehicleModelRequired;

  /// No description provided for @providerVehicleYearLabel.
  ///
  /// In ar, this message translates to:
  /// **'السنة'**
  String get providerVehicleYearLabel;

  /// No description provided for @providerVehicleYearRequired.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get providerVehicleYearRequired;

  /// No description provided for @providerVehicleColorLabel.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get providerVehicleColorLabel;

  /// No description provided for @providerVehicleColorHint.
  ///
  /// In ar, this message translates to:
  /// **'أبيض'**
  String get providerVehicleColorHint;

  /// No description provided for @providerVehiclePlateLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة'**
  String get providerVehiclePlateLabel;

  /// No description provided for @providerVehiclePlateRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم اللوحة'**
  String get providerVehiclePlateRequired;

  /// No description provided for @providerVehiclePlateHint.
  ///
  /// In ar, this message translates to:
  /// **'أ ب ج 1234'**
  String get providerVehiclePlateHint;

  /// No description provided for @providerVehicleSpecsHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: ونش هيدروليك'**
  String get providerVehicleSpecsHint;

  /// No description provided for @providerEnterPassword.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال كلمة المرور'**
  String get providerEnterPassword;

  /// No description provided for @providerPasswordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن لا تقل عن 6 خانات'**
  String get providerPasswordTooShort;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟'**
  String get alreadyHaveAccount;

  /// No description provided for @setNewPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كلمة مرور جديدة'**
  String get setNewPasswordTitle;

  /// No description provided for @setNewPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة مرور جديدة لحسابك (6 أحرف على الأقل).'**
  String get setNewPasswordSubtitle;

  /// No description provided for @setNewPasswordFieldLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get setNewPasswordFieldLabel;

  /// No description provided for @setNewPasswordConfirmLabel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get setNewPasswordConfirmLabel;

  /// No description provided for @setNewPasswordConfirmPrompt.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تأكيد كلمة المرور'**
  String get setNewPasswordConfirmPrompt;

  /// No description provided for @setNewPasswordSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور بنجاح. سجّل الدخول بكلمة المرور الجديدة.'**
  String get setNewPasswordSuccess;

  /// No description provided for @setNewPasswordInvalidLink.
  ///
  /// In ar, this message translates to:
  /// **'الرابط غير صالح أو منتهي'**
  String get setNewPasswordInvalidLink;

  /// No description provided for @setNewPasswordInvalidLinkHint.
  ///
  /// In ar, this message translates to:
  /// **'اطلب رابط استعادة جديدًا من شاشة \"نسيت كلمة المرور\" بالضغط على \"نسيت كلمة المرور؟\" في شاشة تسجيل الدخول.'**
  String get setNewPasswordInvalidLinkHint;

  /// No description provided for @setNewPasswordBackToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة لتسجيل الدخول'**
  String get setNewPasswordBackToLogin;

  /// No description provided for @setNewPasswordLinkExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية رابط استعادة كلمة المرور. يرجى طلب رابط جديد.'**
  String get setNewPasswordLinkExpired;

  /// No description provided for @setNewPasswordFailed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في تعيين كلمة المرور. حاول مرة أخرى.'**
  String get setNewPasswordFailed;

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

  /// No description provided for @availabilityOnlineTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنا متاح للخدمة الآن'**
  String get availabilityOnlineTitle;

  /// No description provided for @availabilityOfflineTitle.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح حالياً'**
  String get availabilityOfflineTitle;

  /// No description provided for @availabilityOnlineHint.
  ///
  /// In ar, this message translates to:
  /// **'ستتلقى الطلبات القريبة من موقعك'**
  String get availabilityOnlineHint;

  /// No description provided for @availabilityOfflineHint.
  ///
  /// In ar, this message translates to:
  /// **'لن تتلقى أي طلبات حالياً'**
  String get availabilityOfflineHint;

  /// No description provided for @stepAssigned.
  ///
  /// In ar, this message translates to:
  /// **'الاسناد'**
  String get stepAssigned;

  /// No description provided for @stepPriceOffer.
  ///
  /// In ar, this message translates to:
  /// **'عرض السعر'**
  String get stepPriceOffer;

  /// No description provided for @stepConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'التأكيد'**
  String get stepConfirmation;

  /// No description provided for @stepCompletion.
  ///
  /// In ar, this message translates to:
  /// **'الإتمام'**
  String get stepCompletion;

  /// No description provided for @ownerStepSent.
  ///
  /// In ar, this message translates to:
  /// **'تم الإرسال'**
  String get ownerStepSent;

  /// No description provided for @ownerStepProviderResponse.
  ///
  /// In ar, this message translates to:
  /// **'استجابة المزوّد'**
  String get ownerStepProviderResponse;

  /// No description provided for @acceptOffer.
  ///
  /// In ar, this message translates to:
  /// **'قبول العرض'**
  String get acceptOffer;

  /// No description provided for @rejectOffer.
  ///
  /// In ar, this message translates to:
  /// **'رفض العرض'**
  String get rejectOffer;

  /// No description provided for @providerRespondedWithOffer.
  ///
  /// In ar, this message translates to:
  /// **'ردّ المزوّد على طلبك بعرض سعر'**
  String get providerRespondedWithOffer;

  /// No description provided for @agreedPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر المُتفق عليه'**
  String get agreedPrice;

  /// No description provided for @completeOrder.
  ///
  /// In ar, this message translates to:
  /// **'إتمام الطلب'**
  String get completeOrder;

  /// No description provided for @acceptOrder.
  ///
  /// In ar, this message translates to:
  /// **'قبول الطلب'**
  String get acceptOrder;

  /// No description provided for @waitingYourResponse.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار ردّك على الطلب'**
  String get waitingYourResponse;

  /// No description provided for @waitingCustomerConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار تأكيد العميل للعرض'**
  String get waitingCustomerConfirmation;

  /// No description provided for @locationUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الموقع غير متاح'**
  String get locationUnavailable;

  /// No description provided for @autoCancelCountdown.
  ///
  /// In ar, this message translates to:
  /// **'سيُلغى الطلب تلقائياً خلال 5 دقائق — متبقي {time}'**
  String autoCancelCountdown(String time);

  /// No description provided for @tapToViewFullMap.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لعرض الخريطة الكاملة'**
  String get tapToViewFullMap;

  /// No description provided for @orderStatusCompletedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم إتمام الطلب'**
  String get orderStatusCompletedTitle;

  /// No description provided for @orderStatusCompletedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تمت الخدمة بنجاح، نأمل أن تكون تجربتك جيدة'**
  String get orderStatusCompletedSubtitle;

  /// No description provided for @imagePickError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء اختيار الصورة'**
  String get imagePickError;

  /// No description provided for @orderLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات الطلب'**
  String get orderLoadFailed;

  /// No description provided for @orderNoLongerAvailable.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، هذا الطلب لم يعد متاحاً (ربما انتهت مدته)'**
  String get orderNoLongerAvailable;

  /// No description provided for @enterPrice.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال السعر المقترح'**
  String get enterPrice;

  /// No description provided for @enterValidPrice.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال سعر صحيح'**
  String get enterValidPrice;

  /// No description provided for @offerSentSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال عرض السعر بنجاح'**
  String get offerSentSuccess;

  /// No description provided for @rejectOrder.
  ///
  /// In ar, this message translates to:
  /// **'رفض الطلب'**
  String get rejectOrder;

  /// No description provided for @rejectOrderConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رفض هذا الطلب؟'**
  String get rejectOrderConfirm;

  /// No description provided for @orderRejectedToast.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب'**
  String get orderRejectedToast;

  /// No description provided for @customerPhotos.
  ///
  /// In ar, this message translates to:
  /// **'صور من العميل'**
  String get customerPhotos;

  /// No description provided for @customerLocationMap.
  ///
  /// In ar, this message translates to:
  /// **'خريطة موقع العميل'**
  String get customerLocationMap;

  /// No description provided for @proposedPriceEgp.
  ///
  /// In ar, this message translates to:
  /// **'السعر المقترح (ج.م)'**
  String get proposedPriceEgp;

  /// No description provided for @priceHintExample.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 350'**
  String get priceHintExample;

  /// No description provided for @etaMinutesLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتوقع للوصول (دقيقة)'**
  String get etaMinutesLabel;

  /// No description provided for @etaHintExample.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 15'**
  String get etaHintExample;

  /// No description provided for @notesToOwnerOptional.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات للمالك (اختياري)'**
  String get notesToOwnerOptional;

  /// No description provided for @notesHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب أي تفاصيل إضافية عن الخدمة...'**
  String get notesHint;

  /// No description provided for @yourAttachedPhotos.
  ///
  /// In ar, this message translates to:
  /// **'صور مرفقة منك ({count})'**
  String yourAttachedPhotos(int count);

  /// No description provided for @submitOffer.
  ///
  /// In ar, this message translates to:
  /// **'تقديم العرض'**
  String get submitOffer;

  /// No description provided for @cancelOrderConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب؟'**
  String get cancelOrderConfirmTitle;

  /// No description provided for @cancelOrderConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إلغاء الطلب الحالي وإخطار المزوّد (إن تم إسناده).'**
  String get cancelOrderConfirmBody;

  /// No description provided for @goBack.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get goBack;

  /// No description provided for @providerPhoneUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'رقم المزوّد غير متاح'**
  String get providerPhoneUnavailable;

  /// No description provided for @selectRatingPrompt.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار تقييم من 1 إلى 5'**
  String get selectRatingPrompt;

  /// No description provided for @ratingSubmittedThanks.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لك! تم إرسال تقييمك'**
  String get ratingSubmittedThanks;

  /// No description provided for @providerRated.
  ///
  /// In ar, this message translates to:
  /// **'تم تقييم المزوّد'**
  String get providerRated;

  /// No description provided for @ratingExperiencePrompt.
  ///
  /// In ar, this message translates to:
  /// **'كيف كانت تجربتك مع المزوّد؟'**
  String get ratingExperiencePrompt;

  /// No description provided for @addCommentOptionalHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف تعليقاً (اختياري)...'**
  String get addCommentOptionalHint;

  /// No description provided for @submitRating.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get submitRating;

  /// No description provided for @providerRejectOrderConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفض الطلب؟'**
  String get providerRejectOrderConfirmTitle;

  /// No description provided for @providerRejectOrderConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إخطار العميل وإلغاء هذا الطلب.'**
  String get providerRejectOrderConfirmBody;

  /// No description provided for @providerRejectOrderConfirmLabel.
  ///
  /// In ar, this message translates to:
  /// **'نعم، رفض الطلب'**
  String get providerRejectOrderConfirmLabel;

  /// No description provided for @providerOrderNoLongerAvailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا الطلب لم يعد متاحاً (ربما انتهت مدته)'**
  String get providerOrderNoLongerAvailable;

  /// No description provided for @completeOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'إتمام الطلب؟'**
  String get completeOrderTitle;

  /// No description provided for @completeOrderConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ستُعتبر الخدمة مكتملة وسيتمكّن العميل من تقييمك بعدها.'**
  String get completeOrderConfirmBody;

  /// No description provided for @orderCompletedToast.
  ///
  /// In ar, this message translates to:
  /// **'تم إتمام الطلب بنجاح'**
  String get orderCompletedToast;

  /// No description provided for @currentOrdersTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلباتك الحالية'**
  String get currentOrdersTitle;

  /// No description provided for @providePriceOffer.
  ///
  /// In ar, this message translates to:
  /// **'تقديم عرض سعر'**
  String get providePriceOffer;

  /// No description provided for @locatingLocation.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد الموقع...'**
  String get locatingLocation;

  /// No description provided for @providerDataUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'بيانات المزوّد غير متاحة'**
  String get providerDataUnavailable;

  /// No description provided for @providerLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات المزوّد: {error}'**
  String providerLoadFailed(String error);

  /// No description provided for @mustLoginToSend.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول لإرسال الطلب'**
  String get mustLoginToSend;

  /// No description provided for @requestDataNotFound.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر العثور على بيانات الطلب، يرجى إعادة إدخاله من جديد'**
  String get requestDataNotFound;

  /// No description provided for @phoneUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير متاح'**
  String get phoneUnavailable;

  /// No description provided for @cannotCallNumber.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن الاتصال بهذا الرقم'**
  String get cannotCallNumber;

  /// No description provided for @providerDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات المزوّد'**
  String get providerDetailsTitle;

  /// No description provided for @hasServiceVehicle.
  ///
  /// In ar, this message translates to:
  /// **'لديه سيارة خدمة'**
  String get hasServiceVehicle;

  /// No description provided for @noServiceVehicle.
  ///
  /// In ar, this message translates to:
  /// **'بدون سيارة خدمة'**
  String get noServiceVehicle;

  /// No description provided for @availableNow.
  ///
  /// In ar, this message translates to:
  /// **'متاح الآن'**
  String get availableNow;

  /// No description provided for @sendRequestToProvider.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب لهذا المزوّد'**
  String get sendRequestToProvider;

  /// No description provided for @providersLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المزودين: {error}'**
  String providersLoadFailed(String error);

  /// No description provided for @selectProvider.
  ///
  /// In ar, this message translates to:
  /// **'اختر المزوّد'**
  String get selectProvider;

  /// No description provided for @noNearbyProviders.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مزودون متاحون قريباً'**
  String get noNearbyProviders;

  /// No description provided for @mapLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات الخريطة: {error}'**
  String mapLoadFailed(String error);

  /// No description provided for @noMapAppsAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تطبيقات خرائط متاحة على جهازك'**
  String get noMapAppsAvailable;

  /// No description provided for @enableLocationService.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك'**
  String get enableLocationService;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض إذن الوصول للموقع'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In ar, this message translates to:
  /// **'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق'**
  String get locationPermissionDeniedForever;

  /// No description provided for @locationDetectFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع الحالي'**
  String get locationDetectFailed;

  /// No description provided for @accessMapTitle.
  ///
  /// In ar, this message translates to:
  /// **'خريطة الوصول'**
  String get accessMapTitle;

  /// No description provided for @customerLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'موقع العميل'**
  String get customerLocationLabel;

  /// No description provided for @yourLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'موقعك'**
  String get yourLocationLabel;

  /// No description provided for @approxDistanceToCustomer.
  ///
  /// In ar, this message translates to:
  /// **'المسافة التقريبية عن العميل: {distance}'**
  String approxDistanceToCustomer(String distance);

  /// No description provided for @approxDistance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة التقريبية: {distance}'**
  String approxDistance(String distance);

  /// No description provided for @openRouteInMaps.
  ///
  /// In ar, this message translates to:
  /// **'فتح مسار في الخرائط'**
  String get openRouteInMaps;

  /// No description provided for @locateCurrentPositionTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تحديد موقعي الحالي'**
  String get locateCurrentPositionTooltip;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get orderStatusCompleted;

  /// No description provided for @noRatingsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تقييمات بعد'**
  String get noRatingsYet;

  /// No description provided for @ratingSummary.
  ///
  /// In ar, this message translates to:
  /// **'{avg}م ({count} تقييم)'**
  String ratingSummary(String avg, int count);

  /// No description provided for @supportScopeEmergency.
  ///
  /// In ar, this message translates to:
  /// **'طوارئ الطريق'**
  String get supportScopeEmergency;

  /// No description provided for @supportScopeOnSite.
  ///
  /// In ar, this message translates to:
  /// **'في الورشة'**
  String get supportScopeOnSite;

  /// No description provided for @supportScopeBoth.
  ///
  /// In ar, this message translates to:
  /// **'كلاهما'**
  String get supportScopeBoth;

  /// No description provided for @supportScopeBothDetailed.
  ///
  /// In ar, this message translates to:
  /// **'بداخل الورشة وعلى الطريق'**
  String get supportScopeBothDetailed;

  /// No description provided for @transactionSummaryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخّص المعاملة'**
  String get transactionSummaryTitle;

  /// No description provided for @transactionDateLabel.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ المعاملة'**
  String get transactionDateLabel;

  /// No description provided for @transactionClosedDateLabel.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإنهاء'**
  String get transactionClosedDateLabel;

  /// No description provided for @transactionProviderLabel.
  ///
  /// In ar, this message translates to:
  /// **'المزوّد'**
  String get transactionProviderLabel;

  /// No description provided for @transactionPathTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسار المعاملة'**
  String get transactionPathTitle;

  /// No description provided for @transactionSucceeded.
  ///
  /// In ar, this message translates to:
  /// **'تمت المعاملة بنجاح'**
  String get transactionSucceeded;

  /// No description provided for @transactionFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم تُنجز المعاملة'**
  String get transactionFailed;

  /// No description provided for @transactionEventOrderSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الطلب'**
  String get transactionEventOrderSent;

  /// No description provided for @transactionEventProviderReceived.
  ///
  /// In ar, this message translates to:
  /// **'استلم المزوّد الطلب'**
  String get transactionEventProviderReceived;

  /// No description provided for @transactionEventOfferWithPrice.
  ///
  /// In ar, this message translates to:
  /// **'قدّم المزوّد عرض السعر ({price} {currency})'**
  String transactionEventOfferWithPrice(String price, String currency);

  /// No description provided for @transactionEventOfferConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد العرض'**
  String get transactionEventOfferConfirmed;

  /// No description provided for @transactionEventCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تم إتمام المعاملة'**
  String get transactionEventCompleted;

  /// No description provided for @transactionEventRejectedByProvider.
  ///
  /// In ar, this message translates to:
  /// **'رفض المزوّد المعاملة'**
  String get transactionEventRejectedByProvider;

  /// No description provided for @transactionEventRejectedByOwner.
  ///
  /// In ar, this message translates to:
  /// **'رفض العميل عرض السعر'**
  String get transactionEventRejectedByOwner;

  /// No description provided for @transactionEventCancelledTimeout.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الطلب (انتهت مهلة الاستجابة)'**
  String get transactionEventCancelledTimeout;

  /// No description provided for @transactionFailureProvider.
  ///
  /// In ar, this message translates to:
  /// **'رفض من جهة المزوّد'**
  String get transactionFailureProvider;

  /// No description provided for @transactionFailureOwner.
  ///
  /// In ar, this message translates to:
  /// **'رفض من جهة العميل'**
  String get transactionFailureOwner;

  /// No description provided for @transactionFailureAutoCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء تلقائي (انتهت مهلة الاستجابة)'**
  String get transactionFailureAutoCancel;

  /// No description provided for @apply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get apply;

  /// No description provided for @orderHistoryLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل السجل: {error}'**
  String orderHistoryLoadFailed(String error);

  /// No description provided for @selectTransactionDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخ المعاملة'**
  String get selectTransactionDate;

  /// No description provided for @filterByDateAllDays.
  ///
  /// In ar, this message translates to:
  /// **'فلترة بحث بالتاريخ: كل الأيام'**
  String get filterByDateAllDays;

  /// No description provided for @ratingExperienceTitle.
  ///
  /// In ar, this message translates to:
  /// **'قيّم تجربتك مع المزوّد'**
  String get ratingExperienceTitle;

  /// No description provided for @ratingQualityPrompt.
  ///
  /// In ar, this message translates to:
  /// **'كيف كانت جودة الخدمة؟'**
  String get ratingQualityPrompt;

  /// No description provided for @ratingProviderPrompt.
  ///
  /// In ar, this message translates to:
  /// **'كيف كانت خدمة «{name}»؟'**
  String ratingProviderPrompt(String name);

  /// No description provided for @rateLater.
  ///
  /// In ar, this message translates to:
  /// **'التقييم لاحقاً'**
  String get rateLater;

  /// No description provided for @rpcErrorOrderNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الطلب غير موجود أو تم حذفه.'**
  String get rpcErrorOrderNotFound;

  /// No description provided for @rpcErrorNotOwner.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية للقيام بهذا الإجراء على هذا الطلب.'**
  String get rpcErrorNotOwner;

  /// No description provided for @rpcErrorOrderNotPending.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد الطلب متاحاً، ربما تمت معالجته أو إلغاؤه.'**
  String get rpcErrorOrderNotPending;

  /// No description provided for @rpcErrorNotAssigned.
  ///
  /// In ar, this message translates to:
  /// **'الطلب لم يُسنَد لأي مزوّد بعد.'**
  String get rpcErrorNotAssigned;

  /// No description provided for @rpcErrorNotProvider.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية للتعامل مع هذا الطلب.'**
  String get rpcErrorNotProvider;

  /// No description provided for @rpcErrorInvalidPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر المُدخل غير صالح، تأكد من إدخال مبلغ صحيح أكبر من صفر.'**
  String get rpcErrorInvalidPrice;

  /// No description provided for @rpcErrorNotPricedOrNotOwner.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عرض سعر سارٍ لهذا الطلب، أو أنك لست صاحب الطلب.'**
  String get rpcErrorNotPricedOrNotOwner;

  /// No description provided for @rpcErrorNotConfirmedOrNotProvider.
  ///
  /// In ar, this message translates to:
  /// **'الطلب غير مؤكد، أو أنك لست المزوّد المسند للمهمة.'**
  String get rpcErrorNotConfirmedOrNotProvider;

  /// No description provided for @rpcErrorInvalidRating.
  ///
  /// In ar, this message translates to:
  /// **'قيمة التقييم غير صالحة (يجب أن تكون بين 1 و5).'**
  String get rpcErrorInvalidRating;

  /// No description provided for @rpcErrorOrderNotCompleted.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تقييم الطلب قبل اكتماله.'**
  String get rpcErrorOrderNotCompleted;

  /// No description provided for @rpcErrorAlreadyRated.
  ///
  /// In ar, this message translates to:
  /// **'تم تقييم هذا الطلب من قبل.'**
  String get rpcErrorAlreadyRated;

  /// No description provided for @rpcErrorOrderNotFoundOrForbidden.
  ///
  /// In ar, this message translates to:
  /// **'الطلب غير موجود، أو ليس لك صلاحية للوصول إليه.'**
  String get rpcErrorOrderNotFoundOrForbidden;

  /// No description provided for @rpcErrorOwnerNationalIdMissing.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب إضافة رقم قومي صحيح لإتمام الطلب. يرجى تحديث بياناتك الشخصية.'**
  String get rpcErrorOwnerNationalIdMissing;

  /// No description provided for @rpcErrorOwnerNationalIdInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي المسجّل في حسابك غير صحيح. يرجى تحديثه من البيانات الشخصية.'**
  String get rpcErrorOwnerNationalIdInvalid;

  /// No description provided for @rpcErrorDuplicatePendingOrder.
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب قيد الانتظار بالفعل. يمكنك إلغاؤه أو انتظاره قبل إنشاء طلب جديد.'**
  String get rpcErrorDuplicatePendingOrder;

  /// No description provided for @rpcErrorProviderUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا المزوّد متاحاً لاستقبال الطلب. جرّب مزوّداً آخر.'**
  String get rpcErrorProviderUnavailable;

  /// No description provided for @rpcErrorTooManyAttachments.
  ///
  /// In ar, this message translates to:
  /// **'عدد الصور كبير جداً (الحد الأقصى 10 صور).'**
  String get rpcErrorTooManyAttachments;

  /// No description provided for @rpcErrorInvalidAttachmentUrl.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من إحدى الصور المرفقة. يرجى المحاولة مرة أخرى.'**
  String get rpcErrorInvalidAttachmentUrl;

  /// No description provided for @rpcErrorNotAuthenticated.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة، يرجى تسجيل الدخول من جديد.'**
  String get rpcErrorNotAuthenticated;

  /// No description provided for @rpcErrorPhoneNotVerified.
  ///
  /// In ar, this message translates to:
  /// **'يجب تأكيد رقم هاتفك أولًا لإتمام هذا الإجراء.'**
  String get rpcErrorPhoneNotVerified;

  /// No description provided for @rpcErrorPhoneChangeRequiresOtp.
  ///
  /// In ar, this message translates to:
  /// **'لتغيير رقم الهاتف يجب التحقق منه برمز SMS. استخدم زر تغيير الرقم.'**
  String get rpcErrorPhoneChangeRequiresOtp;

  /// No description provided for @rpcErrorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الاتصال، حاول مرة أخرى.'**
  String get rpcErrorGeneric;

  /// No description provided for @otpErrorExpired.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح أو منتهي الصلاحية. حاول مرة أخرى.'**
  String get otpErrorExpired;

  /// No description provided for @otpErrorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز عدد المحاولات. يرجى الانتظار قليلاً ثم إعادة المحاولة.'**
  String get otpErrorRateLimited;

  /// No description provided for @otpErrorSendFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال الرمز. حاول مرة أخرى لاحقاً.'**
  String get otpErrorSendFailed;

  /// No description provided for @otpErrorPhoneExists.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مسجّل بالفعل في حساب آخر.'**
  String get otpErrorPhoneExists;

  /// No description provided for @otpErrorPhoneNotConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تأكيد رقم الهاتف بعد. حاول إدخال الرمز مرة أخرى.'**
  String get otpErrorPhoneNotConfirmed;

  /// No description provided for @otpErrorReauth.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تسجيل الدخول مرة أخرى للمتابعة.'**
  String get otpErrorReauth;

  /// No description provided for @otpErrorUserNotFound.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.'**
  String get otpErrorUserNotFound;

  /// No description provided for @otpErrorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما. تحقق من اتصالك وحاول مرة أخرى.'**
  String get otpErrorGeneric;

  /// No description provided for @recoveryNeutralError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.'**
  String get recoveryNeutralError;

  /// No description provided for @changePhoneThrottleError.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز عدد المحاولات. حاول مرة أخرى لاحقاً.'**
  String get changePhoneThrottleError;

  /// No description provided for @changePhoneLookupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من رقم الهاتف. حاول مرة أخرى.'**
  String get changePhoneLookupFailed;

  /// No description provided for @signupGenericError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى'**
  String get signupGenericError;

  /// No description provided for @signupMissingWorkshopName.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل اسم الورشة'**
  String get signupMissingWorkshopName;

  /// No description provided for @signupMissingNationalId.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل الرقم القومي'**
  String get signupMissingNationalId;

  /// No description provided for @signupMissingAddress.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل العنوان'**
  String get signupMissingAddress;

  /// No description provided for @signupMissingLocation.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك حدد موقعك على الخريطة'**
  String get signupMissingLocation;

  /// No description provided for @signupMissingSpecialization.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك اختر تخصص واحد على الأقل'**
  String get signupMissingSpecialization;

  /// No description provided for @signupInvalidRole.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في نوع الحساب، حاول التسجيل مرة أخرى'**
  String get signupInvalidRole;

  /// No description provided for @signupDuplicatePhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مسجّل بالفعل'**
  String get signupDuplicatePhone;

  /// No description provided for @signupDuplicateNationalId.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي مسجّل بالفعل'**
  String get signupDuplicateNationalId;

  /// No description provided for @signupUniqueViolation.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو الرقم القومي مسجّل بالفعل'**
  String get signupUniqueViolation;

  /// No description provided for @signupAccountExistsCustomer.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب عميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.'**
  String get signupAccountExistsCustomer;

  /// No description provided for @signupAccountExistsProvider.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب مزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.'**
  String get signupAccountExistsProvider;

  /// No description provided for @signupAccountExistsUnknown.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود.'**
  String get signupAccountExistsUnknown;

  /// No description provided for @roleMismatchProvider.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب مسجّل كمزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.'**
  String get roleMismatchProvider;

  /// No description provided for @roleMismatchCustomer.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب مسجّل كعميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.'**
  String get roleMismatchCustomer;

  /// No description provided for @roleUnresolved.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد نوع الحساب بعد تسجيل الدخول. يرجى المحاولة مرة أخرى.'**
  String get roleUnresolved;

  /// No description provided for @signOutSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الخروج'**
  String get signOutSuccess;

  /// No description provided for @confirmAction.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirmAction;

  /// No description provided for @cancelAction.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get cancelAction;

  /// No description provided for @errorTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get errorTitle;

  /// No description provided for @okButton.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get okButton;

  /// No description provided for @errPhoneDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مسجل بالفعل في حساب آخر. يرجى استخدام رقم هاتف مختلف أو تسجيل الدخول بالحساب الموجود.'**
  String get errPhoneDuplicate;

  /// No description provided for @errNationalIdDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي مسجل بالفعل في حساب آخر. إذا كنت تملك حساباً سابقاً، يرجى تسجيل الدخول إليه.'**
  String get errNationalIdDuplicate;

  /// No description provided for @errEmailDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني مسجل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود أو استخدام بريد إلكتروني مختلف.'**
  String get errEmailDuplicate;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى التحقق من البيانات والمحاولة مرة أخرى.'**
  String get errInvalidCredentials;

  /// No description provided for @errUserBanned.
  ///
  /// In ar, this message translates to:
  /// **'تم حظرك من استخدام تطبيق محور. إذا كنت تعتقد أن هذا خطأ، يرجى التواصل مع الدعم الفني.'**
  String get errUserBanned;

  /// No description provided for @errEmailNotConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تأكيد البريد الإلكتروني بعد. يرجى التحقق من بريدك الإلكتروني والضغط على رابط التأكيد.'**
  String get errEmailNotConfirmed;

  /// No description provided for @errTooManyRequests.
  ///
  /// In ar, this message translates to:
  /// **'لقد تجاوزت عدد المحاولات المسموح. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.'**
  String get errTooManyRequests;

  /// No description provided for @errUserNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مرتبط بهذا البريد الإلكتروني. يرجى التسجيل أولاً.'**
  String get errUserNotFound;

  /// No description provided for @errInvalidPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.'**
  String get errInvalidPassword;

  /// No description provided for @authErrorUnexpected.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع، حاول مرة أخرى.'**
  String get authErrorUnexpected;

  /// No description provided for @authErrorNoAccount.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مرتبط بهذا الرقم أو البريد الإلكتروني'**
  String get authErrorNoAccount;

  /// No description provided for @authErrorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت، تحقق من اتصالك وحاول مجددًا'**
  String get authErrorNetwork;

  /// No description provided for @authErrorSignOut.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تسجيل الخروج'**
  String get authErrorSignOut;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة كلمة المرور'**
  String get resetPasswordTitle;

  /// No description provided for @forgotPhoneEntrySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الهاتف المرتبط بحسابك وسنرسل إليه رمز تحقق'**
  String get forgotPhoneEntrySubtitle;

  /// No description provided for @enterValidEgyptianPhone.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتف مصري صحيح'**
  String get enterValidEgyptianPhone;

  /// No description provided for @phoneAlreadyRegistered.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مسجل بالفعل لدى مستخدم آخر'**
  String get phoneAlreadyRegistered;

  /// No description provided for @rejectOfferConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفض عرض السعر؟'**
  String get rejectOfferConfirmTitle;

  /// No description provided for @rejectOfferConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم رفض عرض المزوّد وإنهاء هذا الطلب.'**
  String get rejectOfferConfirmBody;

  /// No description provided for @rejectOfferConfirmLabel.
  ///
  /// In ar, this message translates to:
  /// **'نعم، رفض العرض'**
  String get rejectOfferConfirmLabel;

  /// No description provided for @signupOwnerTitle.
  ///
  /// In ar, this message translates to:
  /// **'حساب مالك سيارة جديد'**
  String get signupOwnerTitle;

  /// No description provided for @signupOwnerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل بياناتك وسيارتك لتتمكن من طلب خدمات الطوارئ'**
  String get signupOwnerSubtitle;

  /// No description provided for @signupProviderTitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم لشبكة مزودي خدمة محور'**
  String get signupProviderTitle;

  /// No description provided for @signupProviderSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل بيانات ورشتك أو خدماتك لتلقي طلبات طوارئ الطرق في نطاقك المباشر'**
  String get signupProviderSubtitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الهاتف المرتبط بحسابك. سنرسل إليه رمز تحقق عبر رسالة نصية (SMS).'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendVerificationCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز التحقق'**
  String get sendVerificationCode;

  /// No description provided for @errorWithDetail.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ: {error}'**
  String errorWithDetail(String error);

  /// No description provided for @errorSaving.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء الحفظ: {error}'**
  String errorSaving(String error);

  /// No description provided for @chooseAvatarTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر صورتك الرمزية'**
  String get chooseAvatarTitle;

  /// No description provided for @chooseAvatarSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هذه الصورة في ملفك الشخصي وطلباتك'**
  String get chooseAvatarSubtitle;

  /// No description provided for @saving.
  ///
  /// In ar, this message translates to:
  /// **'جاري الحفظ...'**
  String get saving;

  /// No description provided for @saveAvatar.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الصورة الرمزية'**
  String get saveAvatar;

  /// No description provided for @nameRequired.
  ///
  /// In ar, this message translates to:
  /// **'الاسم مطلوب'**
  String get nameRequired;

  /// No description provided for @phoneRequired.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مطلوب'**
  String get phoneRequired;

  /// No description provided for @enterValidEgyptianPhoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتف مصري صحيح (01xxxxxxxxx)'**
  String get enterValidEgyptianPhoneNumber;

  /// No description provided for @selectSpecialtiesDesc.
  ///
  /// In ar, this message translates to:
  /// **'اختر التخصصات التي تقدمها ورشتك، وستظهر لمالكي السيارات عند البحث عن الخدمات'**
  String get selectSpecialtiesDesc;

  /// No description provided for @noSpecialtiesAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تخصصات متاحة حالياً'**
  String get noSpecialtiesAvailable;

  /// No description provided for @workshopNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اسم الورشة مطلوب'**
  String get workshopNameRequired;

  /// No description provided for @workshopAddressRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال عنوان الورشة'**
  String get workshopAddressRequired;

  /// No description provided for @vehicleSpecsHintEquipped.
  ///
  /// In ar, this message translates to:
  /// **'مثال: ونش هيدروليك، سيارة مجهزة'**
  String get vehicleSpecsHintEquipped;

  /// No description provided for @deleteCarConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف هذه السيارة؟'**
  String get deleteCarConfirm;

  /// No description provided for @noCarsRegistered.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سيارات مسجلة'**
  String get noCarsRegistered;

  /// No description provided for @tapToAddCar.
  ///
  /// In ar, this message translates to:
  /// **'اضغط + لإضافة سيارة'**
  String get tapToAddCar;

  /// No description provided for @addNewCar.
  ///
  /// In ar, this message translates to:
  /// **'إضافة سيارة جديدة'**
  String get addNewCar;

  /// No description provided for @selectCarMakeModelYear.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار ماركة وموديل وسنة السيارة'**
  String get selectCarMakeModelYear;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get add;

  /// No description provided for @appliedToAllDays.
  ///
  /// In ar, this message translates to:
  /// **'تم تطبيق الجدول على جميع الأيام'**
  String get appliedToAllDays;

  /// No description provided for @dailyExceptions.
  ///
  /// In ar, this message translates to:
  /// **'الأيام الاستثنائية'**
  String get dailyExceptions;

  /// No description provided for @dailyExceptionsHint.
  ///
  /// In ar, this message translates to:
  /// **'عطّل يوماً أو عدّل وقته — باقي الأيام تتبع الجدول الموحّد'**
  String get dailyExceptionsHint;

  /// No description provided for @oneScheduleForAllDays.
  ///
  /// In ar, this message translates to:
  /// **'الجدول الموحّد لجميع الأيام'**
  String get oneScheduleForAllDays;

  /// No description provided for @oneScheduleForAllDaysHint.
  ///
  /// In ar, this message translates to:
  /// **'حدّد موعداً واحداً وطبّقه على كل أيام الأسبوع، ثم استثنِ بعدها ما تريد'**
  String get oneScheduleForAllDaysHint;

  /// No description provided for @applyToAllDays.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق على جميع الأيام'**
  String get applyToAllDays;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @customLabel.
  ///
  /// In ar, this message translates to:
  /// **'خاص'**
  String get customLabel;

  /// No description provided for @dayOff.
  ///
  /// In ar, this message translates to:
  /// **'إجازة'**
  String get dayOff;

  /// No description provided for @available.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get available;

  /// No description provided for @restoreUnifiedTime.
  ///
  /// In ar, this message translates to:
  /// **'استعادة الجدول الموحّد'**
  String get restoreUnifiedTime;

  /// No description provided for @weekdaySunday.
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get weekdaySunday;

  /// No description provided for @weekdayMonday.
  ///
  /// In ar, this message translates to:
  /// **'الاثنين'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In ar, this message translates to:
  /// **'الثلاثاء'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In ar, this message translates to:
  /// **'الأربعاء'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get weekdaySaturday;

  /// No description provided for @welcomeToMahwar.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في محور'**
  String get welcomeToMahwar;

  /// No description provided for @chooseAccountTypeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع حسابك للبدء في استخدام التطبيق واستكشاف الخدمات المتاحة'**
  String get chooseAccountTypeSubtitle;

  /// No description provided for @needUrgentRoadsideHelp.
  ///
  /// In ar, this message translates to:
  /// **'هل تحتاج مساعدة عاجلة في الطريق؟'**
  String get needUrgentRoadsideHelp;

  /// No description provided for @supportTeamReady24_7.
  ///
  /// In ar, this message translates to:
  /// **'فريق الدعم الفني جاهز لمساعدتك 24 ساعة'**
  String get supportTeamReady24_7;

  /// No description provided for @mahwarHotlineAvailable.
  ///
  /// In ar, this message translates to:
  /// **'خط طوارئ محور: 19xxx جاهز في جميع المحافظات'**
  String get mahwarHotlineAvailable;

  /// No description provided for @callNow.
  ///
  /// In ar, this message translates to:
  /// **'اتصل الآن'**
  String get callNow;

  /// No description provided for @highlightLiveTracking.
  ///
  /// In ar, this message translates to:
  /// **'تتبع جغرافي حي'**
  String get highlightLiveTracking;

  /// No description provided for @highlightTransparentPricing.
  ///
  /// In ar, this message translates to:
  /// **'تسعير شفاف 100%'**
  String get highlightTransparentPricing;

  /// No description provided for @highlightFastResponse.
  ///
  /// In ar, this message translates to:
  /// **'نجدة سريعة 24/7'**
  String get highlightFastResponse;

  /// No description provided for @topRoadsideAssistance.
  ///
  /// In ar, this message translates to:
  /// **'شبكة طوارئ السيارات الأولى'**
  String get topRoadsideAssistance;

  /// No description provided for @fastSafeRoadside24_7.
  ///
  /// In ar, this message translates to:
  /// **'خدمة سريعة وآمنة على كافة الطرق 24/7'**
  String get fastSafeRoadside24_7;

  /// No description provided for @viewAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get viewAll;

  /// No description provided for @unknownServiceType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الخدمة غير معروف، يرجى تحديث التطبيق'**
  String get unknownServiceType;

  /// No description provided for @preparingYourRequest.
  ///
  /// In ar, this message translates to:
  /// **'جاري تجهيز طلبك...'**
  String get preparingYourRequest;

  /// No description provided for @pleaseWaitDontClose.
  ///
  /// In ar, this message translates to:
  /// **'يرجى الانتظار، لا تغلق التطبيق'**
  String get pleaseWaitDontClose;

  /// No description provided for @additionalOptions.
  ///
  /// In ar, this message translates to:
  /// **'خيارات إضافية'**
  String get additionalOptions;

  /// No description provided for @locationTimeoutRetry.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد موقعك خلال 30 ثانية، تأكد من توافر GPS ثم أعد المحاولة'**
  String get locationTimeoutRetry;

  /// No description provided for @onboardingTitle1.
  ///
  /// In ar, this message translates to:
  /// **'أسرع نجدة لطوارئ السيارات'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In ar, this message translates to:
  /// **'محور يربطك بأقرب أونياش وفنيي طوارئ الطرق جغرافياً في ثوانٍ معدودة.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In ar, this message translates to:
  /// **'تسعير شفاف وبدون تعقيد'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In ar, this message translates to:
  /// **'استلم عرض السعر المباشر من مقدم الخدمة واقبل أو ارفض بضغطة زر.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In ar, this message translates to:
  /// **'خدمة شاملة لكافة الأعطال'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In ar, this message translates to:
  /// **'سواء احتجت ونش، أو تغير إطار، بنزين، بطارية، أو ميكانيكي طوارئ.'**
  String get onboardingDesc3;

  /// No description provided for @legalLastUpdated.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث: أغسطس 2025'**
  String get legalLastUpdated;

  /// No description provided for @legalContactTitle.
  ///
  /// In ar, this message translates to:
  /// **'للتواصل معنا'**
  String get legalContactTitle;

  /// No description provided for @legalContactBody.
  ///
  /// In ar, this message translates to:
  /// **'إذا كان لديك أي استفسارات حول هذه السياسة، يرجى التواصل معنا على:\nsupport@mahwar.app\nأو الاتصال بخط الدعم: 19000'**
  String get legalContactBody;

  /// No description provided for @legalTermsIntro.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك في تطبيق مِحْوَر لخدمات طوارئ السيارات. باستخدامك لهذا التطبيق، أنت توافق على الشروط والأحكام التالية التي تنظم العلاقة بينك وبين منصة مِحْوَر.'**
  String get legalTermsIntro;

  /// No description provided for @legalTermsSection1Title.
  ///
  /// In ar, this message translates to:
  /// **'قبول الشروط'**
  String get legalTermsSection1Title;

  /// No description provided for @legalTermsSection1Body.
  ///
  /// In ar, this message translates to:
  /// **'باستخدامك لتطبيق مِحْوَر، أنت تُقر بأنك قرأت هذه الشروط وفهمتها وتوافق على الالتزام بها. إذا كنت لا توافق على أي من هذه الشروط، يرجى عدم استخدام التطبيق.'**
  String get legalTermsSection1Body;

  /// No description provided for @legalTermsSection2Title.
  ///
  /// In ar, this message translates to:
  /// **'الاستخدام المقبول'**
  String get legalTermsSection2Title;

  /// No description provided for @legalTermsSection2Body.
  ///
  /// In ar, this message translates to:
  /// **'يُسمح باستخدام التطبيق فقط للأغراض القانونية ووفقاً للقوانين المعمول بها في جمهورية مصر العربية. يُحظر استخدام التطبيق لأي غرض احتيالي أو ضار أو مخالف للآداب العامة.'**
  String get legalTermsSection2Body;

  /// No description provided for @legalTermsSection3Title.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات والمسؤولية'**
  String get legalTermsSection3Title;

  /// No description provided for @legalTermsSection3Body.
  ///
  /// In ar, this message translates to:
  /// **'أنت مسؤول عن الحفاظ على سرية بيانات حسابك وكلمة مرورك. كما أنت مسؤول عن جميع الأنشطة التي تحدث تحت حسابك. يجب إبلاغنا فوراً عن أي استخدام غير مصرح به لحسابك.'**
  String get legalTermsSection3Body;

  /// No description provided for @legalTermsSection4Title.
  ///
  /// In ar, this message translates to:
  /// **'طبيعة خدمات التطبيق'**
  String get legalTermsSection4Title;

  /// No description provided for @legalTermsSection4Body.
  ///
  /// In ar, this message translates to:
  /// **'يوفر تطبيق مِحْوَر منصة رقمية لربط مالكي السيارات بمقدمي خدمات الطوارئ. نحن لسنا طرفاً في الاتفاق بين العميل ومقدم الخدمة، ولا نتحمل المسؤولية عن جودة الخدمات المقدمة.'**
  String get legalTermsSection4Body;

  /// No description provided for @legalTermsSection5Title.
  ///
  /// In ar, this message translates to:
  /// **'التسعير والمدفوعات'**
  String get legalTermsSection5Title;

  /// No description provided for @legalTermsSection5Body.
  ///
  /// In ar, this message translates to:
  /// **'جميع المدفوعات تتم مباشرةً بين مالك السيارة ومقدم الخدمة. يتيح التطبيق عملية التفاوض على السعر والموافقة عليه. التطبيق لا يتحصل على عمولة أو رسوم مالية من المعاملات.'**
  String get legalTermsSection5Body;

  /// No description provided for @legalTermsSection6Title.
  ///
  /// In ar, this message translates to:
  /// **'الإلغاء والرفض'**
  String get legalTermsSection6Title;

  /// No description provided for @legalTermsSection6Body.
  ///
  /// In ar, this message translates to:
  /// **'يمكن لمالك السيارة إلغاء الطلب في أي وقت قبل قبول السعر. يمكن لمقدم الخدمة رفض الطلب قبل تقديم عرض السعر. بعد قبول السعر من قبل العميل، يُعتبر الطلب مُلزِماً.'**
  String get legalTermsSection6Body;

  /// No description provided for @legalTermsSection7Title.
  ///
  /// In ar, this message translates to:
  /// **'الملكية الفكرية'**
  String get legalTermsSection7Title;

  /// No description provided for @legalTermsSection7Body.
  ///
  /// In ar, this message translates to:
  /// **'جميع حقوق الملكية الفكرية للتطبيق بما في ذلك التصاميم والشعارات والمحتوى محفوظة لشركة مِحْوَر. لا يُسمح بإعادة إنتاج أي جزء من التطبيق أو استخدامه تجارياً دون إذن مسبق.'**
  String get legalTermsSection7Body;

  /// No description provided for @legalTermsSection8Title.
  ///
  /// In ar, this message translates to:
  /// **'التعديلات على الشروط'**
  String get legalTermsSection8Title;

  /// No description provided for @legalTermsSection8Body.
  ///
  /// In ar, this message translates to:
  /// **'نحتفظ بحقنا في تعديل هذه الشروط والأحكام في أي وقت. سيتم إشعار المستخدمين بأي تغييرات جوهرية من خلال التطبيق. استمرارك في استخدام التطبيق بعد التعديلات يُعدّ قبولاً لها.'**
  String get legalTermsSection8Body;

  /// No description provided for @legalPrivacyIntro.
  ///
  /// In ar, this message translates to:
  /// **'نحن في تطبيق مِحْوَر نُقدّر ثقتك ونلتزم التزاماً تاماً بحماية بياناتك الشخصية. توضح هذه السياسة كيفية جمع البيانات واستخدامها وحمايتها.'**
  String get legalPrivacyIntro;

  /// No description provided for @legalPrivacySection1Title.
  ///
  /// In ar, this message translates to:
  /// **'البيانات التي نجمعها'**
  String get legalPrivacySection1Title;

  /// No description provided for @legalPrivacySection1Body.
  ///
  /// In ar, this message translates to:
  /// **'نجمع البيانات الضرورية لتقديم خدماتنا، وتشمل: الاسم الكامل، رقم الهاتف، البريد الإلكتروني، الموقع الجغرافي الحي، الرقم القومي (لمقدمي الخدمة)، وبيانات السيارة (الماركة، الموديل، السنة). لا نجمع أي بيانات غير ضرورية.'**
  String get legalPrivacySection1Body;

  /// No description provided for @legalPrivacySection2Title.
  ///
  /// In ar, this message translates to:
  /// **'كيفية استخدام بياناتك'**
  String get legalPrivacySection2Title;

  /// No description provided for @legalPrivacySection2Body.
  ///
  /// In ar, this message translates to:
  /// **'نستخدم بياناتك للأغراض التالية: تقديم خدمات الطوارئ، ربطك بأقرب مقدمي الخدمة جغرافياً، إرسال الإشعارات ذات الصلة بطلباتك، تحسين جودة التطبيق وتجربة المستخدم، وضمان أمان المنصة.'**
  String get legalPrivacySection2Body;

  /// No description provided for @legalPrivacySection3Title.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة البيانات'**
  String get legalPrivacySection3Title;

  /// No description provided for @legalPrivacySection3Body.
  ///
  /// In ar, this message translates to:
  /// **'لا نشارك بياناتك مع أطراف ثالثة إلا في الحالات التالية: عند ضرورة تقديم الخدمة (مشاركة موقعك مع مقدم الخدمة المختار)، أو عند الإلزام القانوني من الجهات الحكومية المختصة، أو بموافقتك الصريحة.'**
  String get legalPrivacySection3Body;

  /// No description provided for @legalPrivacySection4Title.
  ///
  /// In ar, this message translates to:
  /// **'أمان البيانات'**
  String get legalPrivacySection4Title;

  /// No description provided for @legalPrivacySection4Body.
  ///
  /// In ar, this message translates to:
  /// **'نستخدم أحدث تقنيات التشفير والأمان لحماية بياناتك. نعتمد على Supabase كبنية تحتية آمنة مع تشفير SSL/TLS لجميع الاتصالات. يتم تطبيق سياسات Row Level Security (RLS) لضمان عدم الوصول غير المصرح به لبياناتك.'**
  String get legalPrivacySection4Body;

  /// No description provided for @legalPrivacySection5Title.
  ///
  /// In ar, this message translates to:
  /// **'حقوقك على بياناتك'**
  String get legalPrivacySection5Title;

  /// No description provided for @legalPrivacySection5Body.
  ///
  /// In ar, this message translates to:
  /// **'لديك الحقوق التالية بشأن بياناتك: حق الوصول والاطلاع على بياناتك المخزنة، حق التصحيح والتعديل، حق حذف حسابك وبياناتك كاملاً، وحق الاعتراض على معالجة بياناتك في حالات معينة.'**
  String get legalPrivacySection5Body;

  /// No description provided for @legalPrivacySection6Title.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الموقع الجغرافي'**
  String get legalPrivacySection6Title;

  /// No description provided for @legalPrivacySection6Body.
  ///
  /// In ar, this message translates to:
  /// **'نستخدم الموقع الجغرافي فقط خلال جلسة الطلب النشطة لإيجاد أقرب مقدمي الخدمة. لا نتتبع موقعك في الخلفية خارج طلبات الخدمة. يمكنك التحكم في صلاحيات الموقع من إعدادات هاتفك في أي وقت.'**
  String get legalPrivacySection6Body;

  /// No description provided for @legalPrivacySection7Title.
  ///
  /// In ar, this message translates to:
  /// **'الاحتفاظ بالبيانات'**
  String get legalPrivacySection7Title;

  /// No description provided for @legalPrivacySection7Body.
  ///
  /// In ar, this message translates to:
  /// **'نحتفظ ببيانات حسابك طالما كان حسابك نشطاً. عند حذف حسابك، يتم حذف جميع بياناتك الشخصية خلال 30 يوماً. قد نحتفظ ببعض البيانات المجهولة للتحليل الإحصائي.'**
  String get legalPrivacySection7Body;

  /// No description provided for @legalPrivacySection8Title.
  ///
  /// In ar, this message translates to:
  /// **'التحديثات على السياسة'**
  String get legalPrivacySection8Title;

  /// No description provided for @legalPrivacySection8Body.
  ///
  /// In ar, this message translates to:
  /// **'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر لتعكس التغييرات في ممارساتنا أو لأسباب تشغيلية أو قانونية. سنُشعرك بأي تغييرات جوهرية عبر إشعار داخل التطبيق قبل دخول التغييرات حيز التنفيذ.'**
  String get legalPrivacySection8Body;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @connectionError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الاتصال، حاول مرة أخرى.'**
  String get connectionError;

  /// No description provided for @needNationalIdFirst.
  ///
  /// In ar, this message translates to:
  /// **'لإرسال طلب خدمة يجب إضافة رقمك القومي الصحيح أولاً في بياناتك الشخصية.'**
  String get needNationalIdFirst;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك'**
  String get locationServiceDisabled;

  /// No description provided for @locationPermissionPermanentlyDenied.
  ///
  /// In ar, this message translates to:
  /// **'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق'**
  String get locationPermissionPermanentlyDenied;

  /// No description provided for @serviceRequestErrorWithDetail.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ: {detail}'**
  String serviceRequestErrorWithDetail(String detail);

  /// No description provided for @locationTimeoutDelayed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد موقعك خلال 30 ثانية، تأكد من توافر GPS ثم أعد المحاولة'**
  String get locationTimeoutDelayed;
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
