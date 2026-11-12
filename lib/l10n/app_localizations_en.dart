// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mahwar';

  @override
  String get version => 'Version 1.0.0';

  @override
  String get carOwner => 'Car Owner';

  @override
  String get carOwnerDesc =>
      'Request nearby emergency roadside assistance easily';

  @override
  String get serviceProvider => 'Service Provider';

  @override
  String get serviceProviderDesc =>
      'Receive emergency requests and provide services';

  @override
  String get selectUserType => 'Select User Type';

  @override
  String get login => 'Login';

  @override
  String get signup => 'Create Account';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get termsAndConditions => 'Terms & Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get phoneOrEmail => 'Phone or Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get email => 'Email (Optional)';

  @override
  String get nationalId => 'National ID';

  @override
  String get nationalIdOptionalHint =>
      'Optional on registration, required for orders';

  @override
  String get nationalIdRequiredHint =>
      'National ID is required to create service orders';

  @override
  String get carMake => 'Car Make';

  @override
  String get carModel => 'Model';

  @override
  String get carYear => 'Year';

  @override
  String get agreeToTerms => 'I agree to Terms & Conditions and Privacy Policy';

  @override
  String get workshopName => 'Workshop / Agency Name';

  @override
  String get address => 'Address';

  @override
  String get specialization => 'Specialization';

  @override
  String get supportScope => 'Support Scope';

  @override
  String get hasVehicle => 'Do you have a service vehicle?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get vehicleSpecs => 'Vehicle Specifications';

  @override
  String get loginMethod => 'Login Method';

  @override
  String get phoneTab => 'Phone';

  @override
  String get emailTab => 'Email';

  @override
  String get emailLabel => 'Email';

  @override
  String get enterPhonePrompt => 'Please enter your phone number';

  @override
  String get enterEmailPrompt => 'Please enter your email';

  @override
  String get invalidPhoneShort =>
      'Invalid Egyptian phone number (e.g. 01012345678)';

  @override
  String get invalidEmailFormat => 'Invalid email format';

  @override
  String get enterPasswordPrompt => 'Please enter your password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get loginWithOtp => 'Sign in with a verification code';

  @override
  String get returnToAccount => 'Back to your account';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get loginHeaderTitle => 'Login';

  @override
  String get loginWelcome =>
      'Welcome back! Please enter your account credentials to continue.';

  @override
  String get specTowTruck => 'Tow Truck Crane S.O.S';

  @override
  String get specTire => 'Tire Services';

  @override
  String get specBattery => 'Battery & Electrical';

  @override
  String get specFuel => 'Fuel Delivery';

  @override
  String get specMechanical => 'Emergency Mechanic';

  @override
  String get signupFullNameLabel => 'Full Name (Required)';

  @override
  String get signupFullNameRequired => 'Please enter your full name';

  @override
  String get signupPhoneLabel => 'Phone Number (Required)';

  @override
  String get signupInvalidPhone =>
      'Invalid Egyptian phone number (e.g. 01012345678)';

  @override
  String get signupEmailLabel => 'Email Address (Optional)';

  @override
  String get signupNationalIdLabel => 'National ID (Optional)';

  @override
  String get signupNationalIdHint =>
      'Optional at registration, required to complete a service request';

  @override
  String get signupInvalidNationalId => 'Invalid national ID (14 digits)';

  @override
  String get signupPasswordMismatch => 'Passwords do not match';

  @override
  String get signupAgreeTerms =>
      'I agree to the Terms of Use and Privacy Policy';

  @override
  String get signupAgreeTermsRequired =>
      'You must agree to the Terms of Use and Privacy Policy to continue';

  @override
  String get providerEnableLocationService =>
      'Please enable location services (GPS)';

  @override
  String get providerLocationDenied => 'Location permission denied';

  @override
  String get providerLocationDeniedForever =>
      'Location permission permanently denied, please enable it in app settings';

  @override
  String get providerLocationFilled =>
      'Location pinned and address filled, you can edit it';

  @override
  String get providerLocationDetectFailed =>
      'Could not determine current location';

  @override
  String get providerSelectSpecPrompt => 'يرجى اختيار تخصص واحد على الأقل';

  @override
  String get providerAgreeTermsPrompt =>
      'يجب الموافقة على الشروط والأحكام وميثاق الخدمة';

  @override
  String get providerFullNameRequired => 'Please enter full name';

  @override
  String get providerNameAtLeast3 => 'Please enter at least 3 names';

  @override
  String get providerEnterPhone => 'Please enter phone number';

  @override
  String get providerInvalidPhone =>
      'Invalid Egyptian phone number (11 digits)';

  @override
  String get providerNationalIdHint => '14 رقم قومي مدون في البطاقة';

  @override
  String get providerNationalIdHelper =>
      'Mandatory for service providers for security verification';

  @override
  String get providerNationalIdRequired => 'National ID is mandatory';

  @override
  String get providerWorkshopSectionTitle => 'Workshop & Service Details';

  @override
  String get providerWorkshopRequired => 'Please enter workshop name';

  @override
  String get providerAddressHint => 'Use auto-location or type your address';

  @override
  String get providerLocateTooltip => 'Use my current location';

  @override
  String get providerAddressRequired => 'Please enter detailed address';

  @override
  String get providerAutoFillHint =>
      'Tap the location icon to auto-fill the address, then edit if needed';

  @override
  String get providerScopeRoadside => 'Roadside';

  @override
  String get providerScopeOnSite => 'On-site';

  @override
  String get providerVehicleMakeLabel => 'Vehicle Make';

  @override
  String get providerVehicleMakeHint => 'e.g. Toyota';

  @override
  String get providerVehicleMakeRequired => 'Please enter vehicle make';

  @override
  String get providerVehicleModelLabel => 'Vehicle Model';

  @override
  String get providerVehicleModelHint => 'e.g. Corolla';

  @override
  String get providerVehicleModelRequired => 'Please enter vehicle model';

  @override
  String get providerVehicleYearLabel => 'Year';

  @override
  String get providerVehicleYearRequired => 'Required';

  @override
  String get providerVehicleColorLabel => 'Color';

  @override
  String get providerVehicleColorHint => 'White';

  @override
  String get providerVehiclePlateLabel => 'Plate Number';

  @override
  String get providerVehiclePlateRequired => 'Please enter plate number';

  @override
  String get providerVehiclePlateHint => 'A B C 1234';

  @override
  String get providerVehicleSpecsHint => 'e.g. Hydraulic crane';

  @override
  String get providerEnterPassword => 'Please enter password';

  @override
  String get providerPasswordTooShort =>
      'Password must be at least 6 characters';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get setNewPasswordTitle => 'Set a New Password';

  @override
  String get setNewPasswordSubtitle =>
      'Enter a new password for your account (min 6 characters).';

  @override
  String get setNewPasswordFieldLabel => 'New password';

  @override
  String get setNewPasswordConfirmLabel => 'Confirm password';

  @override
  String get setNewPasswordConfirmPrompt => 'Please confirm your password';

  @override
  String get setNewPasswordSuccess =>
      'Password changed successfully. Log in with your new password.';

  @override
  String get setNewPasswordInvalidLink => 'Invalid or expired link';

  @override
  String get setNewPasswordInvalidLinkHint =>
      'Request a fresh reset link via \"Forgot password?\" on the login screen.';

  @override
  String get setNewPasswordBackToLogin => 'Back to Login';

  @override
  String get setNewPasswordLinkExpired =>
      'انتهت صلاحية رابط استعادة كلمة المرور. يرجى طلب رابط جديد.';

  @override
  String get setNewPasswordFailed =>
      'حدث خطأ في تعيين كلمة المرور. حاول مرة أخرى.';

  @override
  String get otpTitle => 'Verify Phone Number';

  @override
  String get otpLoginTitle => 'Sign in with a verification code';

  @override
  String get otpLoginSubtitle =>
      'Enter the phone number registered with your account and we\'ll text you a sign-in code';

  @override
  String get otpSubTitle => 'Enter the 6-digit verification code';

  @override
  String otpCodeSentTo(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String resendCodeIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get useAnotherNumber => 'Use another number';

  @override
  String get didNotReceiveCode => 'Didn\'t receive the code?';

  @override
  String get changeNumberTitle => 'Change phone number';

  @override
  String get changeNumberSubTitle =>
      'Enter the new number and we\'ll send a verification code to it';

  @override
  String get phoneChangeRequiresOtp =>
      'Changing your phone number requires SMS verification. Use the Change number button.';

  @override
  String get sendCode => 'Send code';

  @override
  String get verify => 'Verify';

  @override
  String get home => 'Home';

  @override
  String get services => 'Services';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsPermissionDenied =>
      'System notifications are off — enable them in app settings to receive order alerts';

  @override
  String get settings => 'Settings';

  @override
  String get history => 'Order History';

  @override
  String get aboutApp => 'About App';

  @override
  String get crane => 'Tow Truck Crane';

  @override
  String get tire => 'Tire Repair';

  @override
  String get fuel => 'Fuel Delivery';

  @override
  String get battery => 'Battery & Electrical';

  @override
  String get mechanical => 'Emergency Mechanic';

  @override
  String get requestService => 'Request Service';

  @override
  String get offerPrice => 'Offer Price';

  @override
  String get acceptPrice => 'Accept Price';

  @override
  String get rejectPrice => 'Reject Price';

  @override
  String get cancelOrder => 'Cancel Order';

  @override
  String get priceOffered => 'Offered Price';

  @override
  String get egp => 'EGP';

  @override
  String get nearestProviders => 'Nearest Available Providers';

  @override
  String get km => 'km';

  @override
  String get orderStatusPending => 'Sending to provider';

  @override
  String get orderStatusPriced => 'Price quoted';

  @override
  String get orderStatusConfirmed => 'Order Confirmed';

  @override
  String get orderStatusRejectedProvider => 'Rejected by provider';

  @override
  String get orderStatusRejectedOwner => 'Quote rejected by owner';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get switchToEnglish => 'Switch to English';

  @override
  String get switchToArabic => 'Switch to Arabic';

  @override
  String get policyPlaceholder =>
      'The full content will be shown on a dedicated screen soon.';

  @override
  String get profile => 'Profile';

  @override
  String get editPersonalInfo => 'Edit Personal Info';

  @override
  String get manageCars => 'Manage Cars';

  @override
  String get addCar => 'Add a car';

  @override
  String get profilePhoto => 'Profile photo';

  @override
  String get languageLabel => 'Language';

  @override
  String get currentLanguage => 'English';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get logout => 'Logout';

  @override
  String get logoutFailedMessage =>
      'Couldn\'t log out. Check your connection and try again.';

  @override
  String get retry => 'Retry';

  @override
  String get profileLoadFailed => 'Couldn\'t load your profile';

  @override
  String get carDataRequired => 'Car Details (Required)';

  @override
  String get selectMakeFirst => 'Select car make first';

  @override
  String get selectModelFirst => 'Select model first';

  @override
  String get carMakeRequired => 'Please select car make';

  @override
  String get carModelRequired => 'Please select car model';

  @override
  String get carYearRequired => 'Please select year';

  @override
  String get myAccount => 'My Account';

  @override
  String get orders => 'Orders';

  @override
  String get noNewNotifications => 'No new notifications';

  @override
  String get welcomeUser => 'Hello,';

  @override
  String get setLocation => 'Set location...';

  @override
  String get sosEmergency => 'S.O.S Emergency';

  @override
  String get sosTapForHelp => 'Tap for immediate assistance';

  @override
  String get emergencyServices => 'Emergency Services';

  @override
  String get providerLabel => 'Provider:';

  @override
  String get orderHistory => 'Order History';

  @override
  String get noOrdersCurrently => 'No orders yet';

  @override
  String get faultLocation => 'Breakdown Location';

  @override
  String get faultDescription => 'Breakdown description / notes';

  @override
  String get faultHint => 'Write a brief description of the fault...';

  @override
  String get sendRequest => 'Send Request';

  @override
  String get selectLocationOnMap => 'Please select car location on the map';

  @override
  String get tapMapToSetLocation => 'Tap the map to set location';

  @override
  String get brokenDownCar => 'Broken-down Car';

  @override
  String get noCarAdded =>
      'You haven\'t added a car yet. Add one from your profile first.';

  @override
  String get selectCar => 'Select Car';

  @override
  String get trackOrder => 'Track Order';

  @override
  String get searchingProvider => 'Searching for nearest available provider...';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get searchingProviderTitle => 'Searching for provider...';

  @override
  String get orderSentToProviderTitle =>
      'Your request was sent to the provider';

  @override
  String get orderSentToProviderSub =>
      'The provider is reviewing your request and will reply with a price offer — you\'ll be notified as soon as they respond.';

  @override
  String get selectedProviderLabel => 'Selected provider';

  @override
  String get priceOfferReceived => 'Price offer received!';

  @override
  String get orderConfirmed => 'Order Confirmed';

  @override
  String get rejectedByProvider => 'Rejected by provider';

  @override
  String get priceRejected => 'Price rejected';

  @override
  String get orderCancelled => 'Order Cancelled';

  @override
  String get searchingProviderSub =>
      'Looking for nearest available provider to help you';

  @override
  String get reviewPriceOfferSub =>
      'You can review the price offer and accept or reject';

  @override
  String get providerOnWaySub => 'The provider is on their way to you now';

  @override
  String get resendOrChooseOther =>
      'You can resend the request or choose another provider';

  @override
  String get orderCancelledSub => 'This order has been cancelled';

  @override
  String get priceOfferLabel => 'Price Offer';

  @override
  String get reject => 'Reject';

  @override
  String get call => 'Call';

  @override
  String get message => 'Message';

  @override
  String get confirmedLabel => 'Confirmed';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noOrders => 'No orders';

  @override
  String get allTab => 'All';

  @override
  String get activeTab => 'Active';

  @override
  String get completedTab => 'Completed';

  @override
  String get cancelledTab => 'Cancelled';

  @override
  String get serviceLabel => 'Service:';

  @override
  String get orderDetails => 'Order details';

  @override
  String get orderDetailsLoadFailed => 'Couldn\'t load order details';

  @override
  String get customerRating => 'Customer rating';

  @override
  String get customerRatingEmpty => 'The customer hasn\'t rated this order yet';

  @override
  String get carLabel => 'Car:';

  @override
  String get addressLabel => 'Address:';

  @override
  String get notesLabel => 'Notes:';

  @override
  String get notificationLoadFailed => 'Couldn\'t load the notification';

  @override
  String get notificationNotFound => 'Notification not found';

  @override
  String get orderConfirmedShort => 'Confirmed';

  @override
  String get pendingLabel => 'Pending';

  @override
  String get offerReceivedLabel => 'Offer received';

  @override
  String get cancelledShortLabel => 'Cancelled';

  @override
  String get min => 'min';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get notificationDetails => 'Notification details';

  @override
  String get notificationSentAt => 'Sent at';

  @override
  String get notificationBroadcast => 'Broadcast';

  @override
  String get nearbyRequests => 'Nearby Requests';

  @override
  String get offlineMessage => 'You are currently offline';

  @override
  String get offlineHint => 'Enable availability to receive requests';

  @override
  String get noNearbyRequests => 'No nearby requests at the moment';

  @override
  String get workshopInfo => 'Workshop Info';

  @override
  String get mySpecializations => 'My Specializations';

  @override
  String get attachImages => 'Attach Images (Optional)';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to permanently delete your account? This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get savedSuccessfully => 'Saved Successfully';

  @override
  String get autoCancelTitle => 'Auto-cancel order after 5 minutes';

  @override
  String get autoCancelSubtitle =>
      'If your request is not completed within 5 minutes it will be cancelled automatically (enabled by default)';

  @override
  String get workingHours => 'Working Hours';

  @override
  String get workingHoursHint =>
      'Set your working hours — outside these hours you won\'t appear in the available providers list';

  @override
  String get closed => 'Closed';

  @override
  String get openAt => 'Opens at';

  @override
  String get closeAt => 'Closes at';

  @override
  String get workingHoursSetTimes => 'Please set both open and close times';

  @override
  String get workingHoursInvalidRange => 'Open time must be before close time';

  @override
  String get searchProviderHint => 'Search provider by name';

  @override
  String get noProvidersMatch => 'No providers match your search';

  @override
  String get nationalIdInvalid =>
      'Invalid national ID. Make sure it is 14 digits matching your ID card.';

  @override
  String get nationalIdValid => 'National ID is valid';

  @override
  String get nationalIdRequiredToOrderTitle => 'National ID required';

  @override
  String get nationalIdRequiredToOrderBody =>
      'To submit a service request, add your valid national ID in your personal info first.';

  @override
  String get goToPersonalInfo => 'Go to personal info';

  @override
  String get sharePhoneConsent =>
      'Your phone will be shared with the provider until the request ends.';

  @override
  String get m => 'm';

  @override
  String get locationAccuracyLabel => 'Location accuracy';

  @override
  String get approximateLocationWarning =>
      'Approximate location, may not be precise';

  @override
  String get refineLocation => 'Refine location';

  @override
  String get providerListUpdateFailed => 'Couldn\'t refresh the list';

  @override
  String providerLastSeen(String time) {
    return 'Last seen: $time';
  }

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordSubtitle =>
      'Enter your current password then choose a new one (at least 6 characters).';

  @override
  String get currentPasswordLabel => 'Current Password';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmNewPasswordLabel => 'Confirm New Password';

  @override
  String get passwordChangedSuccess => 'Password changed successfully';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get enterCurrentPassword => 'Please enter your current password';

  @override
  String get enterNewPassword => 'Please enter a new password';

  @override
  String get enterConfirmPassword => 'Please confirm your new password';

  @override
  String get currentPasswordIncorrect => 'Current password is incorrect';

  @override
  String get newPasswordSameAsCurrent =>
      'New password must be different from the current one';

  @override
  String get reauthenticationRequired =>
      'For your security, please sign in again before changing your password';

  @override
  String get changePasswordNoEmail =>
      'Cannot change the password because no email is linked to this account';

  @override
  String get changePasswordFailed =>
      'Could not change your password. Please try again.';

  @override
  String get deleteAccountOtpPrompt =>
      'To confirm deletion we\'ll send a verification code to your registered phone number.';

  @override
  String get deleteAccountSendOtp => 'Send verification code';

  @override
  String deleteAccountOtpSentTo(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get deleteAccountOtpLabel => 'Verification code';

  @override
  String get deleteAccountOtpIncomplete =>
      'Enter the 6-digit verification code';

  @override
  String get deleteAccountInvalidOtp =>
      'The verification code is incorrect or expired. Request a new one.';

  @override
  String get deleteAccountRateLimited =>
      'Too many attempts in a short time. Try again shortly.';

  @override
  String get deleteAccountPhoneMissing =>
      'No phone number is linked to this account. Contact support to delete it.';

  @override
  String get deleteAccountFailed =>
      'Could not delete your account. Please try again.';

  @override
  String get changePasswordRateLimited =>
      'Too many attempts, try again shortly';

  @override
  String get delete => 'Delete';

  @override
  String get notificationTitleNewOrder => 'New order';

  @override
  String get notificationTitlePriceOffer => 'New price offer';

  @override
  String get notificationTitleOrderConfirmed => 'Order confirmed';

  @override
  String get notificationTitleOrderRejected => 'Order rejected';

  @override
  String get notificationTitleOrderRejectedForProvider =>
      'Your offer was rejected';

  @override
  String get notificationTitleOrderCancelled => 'Order cancelled';

  @override
  String get notificationTitleOrderCompleted => 'Order completed';

  @override
  String get notificationTitleShiftStarted => 'Work hours started';

  @override
  String get notificationTitleShiftEnded => 'Work hours ended';

  @override
  String get notificationTitleRatingReceived => 'New rating';

  @override
  String get notificationTitleNewMessage => 'New message';

  @override
  String get notificationTitleBroadcast => 'Notification';

  @override
  String get notificationTitleDefault => 'New notification';

  @override
  String notificationBodyNewOrderWithService(String service) {
    return 'You have a new order: $service';
  }

  @override
  String get notificationBodyNewOrder => 'You have a new order';

  @override
  String notificationBodyPriceOfferWithService(
    String provider,
    String price,
    String currency,
    String service,
  ) {
    return '$provider offered a price of $price $currency for $service';
  }

  @override
  String notificationBodyPriceOffer(
    String provider,
    String price,
    String currency,
  ) {
    return '$provider offered a price of $price $currency';
  }

  @override
  String get notificationBodyPriceOfferReceived =>
      'A new price offer was received';

  @override
  String get notificationBodyOrderConfirmedForProvider =>
      'The customer accepted your offer — you can start the job';

  @override
  String notificationBodyOrderRejectedWithProvider(String provider) {
    return 'The order was rejected by $provider';
  }

  @override
  String get notificationBodyOrderRejected => 'The order was rejected';

  @override
  String get notificationBodyOrderRejectedForProvider =>
      'The customer rejected your offer';

  @override
  String get notificationBodyOrderCancelled => 'This order was cancelled';

  @override
  String get notificationBodyOrderCancelledForProvider =>
      'The customer cancelled the order';

  @override
  String get notificationBodyOrderCompleted =>
      'The order service was completed successfully';

  @override
  String get notificationBodyShiftStarted =>
      'Your working hours have started — you are now available to customers';

  @override
  String get notificationBodyShiftEnded =>
      'Your working hours have ended — you are now unavailable';

  @override
  String notificationBodyRatingWithValue(String rating) {
    return 'You received a rating of $rating out of 5';
  }

  @override
  String get notificationBodyRating => 'You received a new rating';

  @override
  String get notificationBodyNewMessage => 'You received a new message';

  @override
  String get notificationBodyDefault => 'There is a new update for Mahwar';

  @override
  String get notificationTitlePriceChangeRequest => 'Price change request';

  @override
  String notificationBodyPriceChangeRequest(
    String oldPrice,
    String newPrice,
    String currency,
  ) {
    return 'The provider asked to change the price from $oldPrice $currency to $newPrice $currency. Review the reason and decide within 10 minutes.';
  }

  @override
  String get notificationTitlePriceChangeApproved => 'Price change approved';

  @override
  String notificationBodyPriceChangeApproved(String newPrice, String currency) {
    return 'The customer approved the new price of $newPrice $currency — continue the job';
  }

  @override
  String get notificationTitlePriceChangeRejected => 'Price change rejected';

  @override
  String notificationBodyPriceChangeRejected(String newPrice, String currency) {
    return 'The customer rejected the new price of $newPrice $currency. Choose: continue at the original price or withdraw.';
  }

  @override
  String get notificationTitlePriceChangeContinued => 'Provider will continue';

  @override
  String notificationBodyPriceChangeContinued(String price, String currency) {
    return 'The provider confirmed they will continue at the original price of $price $currency';
  }

  @override
  String get notificationTitlePriceChangeExpired => 'Price change expired';

  @override
  String get notificationBodyPriceChangeExpired =>
      'The response window for the price change expired — the provider can continue at the original price or withdraw.';

  @override
  String get notificationTitleOrderWithdrawnAfterInspection =>
      'Provider withdrew';

  @override
  String get notificationBodyOrderWithdrawnAfterInspection =>
      'The provider withdrew after inspecting the problem. You can choose another provider to complete the order.';

  @override
  String get priceChangeRequestTitle => 'Price change request';

  @override
  String priceChangeCurrentPrice(String price, String currency) {
    return 'Current price: $price $currency';
  }

  @override
  String get priceChangeNewPriceLabel => 'New price';

  @override
  String get priceChangeReasonLabel => 'Reason for the change';

  @override
  String get priceChangeReasonHint =>
      'Example: the problem is bigger than described and needs extra parts';

  @override
  String get priceChangePhotosHint =>
      'Add photos of the problem (optional, up to 5)';

  @override
  String get priceChangeSubmit => 'Send change request';

  @override
  String get priceChangeSent =>
      'Change request sent — waiting for the customer';

  @override
  String get priceChangeOnlyOnce =>
      'A change request already exists for this order; a second one is not allowed.';

  @override
  String get priceChangeInvalidNewPrice =>
      'Enter a valid price that differs from the current one.';

  @override
  String get priceChangePendingHint =>
      'You requested a price change — waiting for the customer';

  @override
  String get priceChangeRejectedTitle => 'The customer rejected the new price';

  @override
  String get priceChangeContinueOriginal => 'Continue at the original price';

  @override
  String get priceChangeWithdraw => 'Withdraw from the order';

  @override
  String get priceChangeWithdrawConfirmTitle => 'Withdraw from the order?';

  @override
  String get priceChangeWithdrawConfirmBody =>
      'The order will be closed and the customer will choose another provider. This cannot be undone.';

  @override
  String get priceChangeWithdrawConfirmLabel => 'Yes, withdraw';

  @override
  String get priceChangeContinuedToast =>
      'Done — the order continues at the original price';

  @override
  String get priceChangeWithdrawnToast => 'You withdrew from the order';

  @override
  String get priceChangeRequest => 'Request a price change';

  @override
  String get priceRevisionPendingTitle =>
      'The provider requested a price change';

  @override
  String priceRevisionFromTo(
    String oldPrice,
    String newPrice,
    String currency,
  ) {
    return 'From $oldPrice $currency to $newPrice $currency';
  }

  @override
  String get priceRevisionReasonLabel => 'Reason';

  @override
  String get priceRevisionApprove => 'Approve the new price';

  @override
  String get priceRevisionReject => 'Reject the new price';

  @override
  String priceRevisionTimeLeft(String time) {
    return 'Response window left: $time';
  }

  @override
  String get priceRevisionExpiredHint =>
      'The response window expired — the change is treated as rejected and the provider decides.';

  @override
  String get priceRevisionApprovedHint =>
      'You approved the new price. The order continues.';

  @override
  String get priceRevisionRejectedHint =>
      'You rejected the new price — the provider chooses between continuing at the original price or withdrawing.';

  @override
  String get priceRevisionAwaitProvider =>
      'Waiting for the provider\'s decision.';

  @override
  String get priceRevisionContinued =>
      'The provider will continue at the original price.';

  @override
  String get chooseAnotherProvider => 'Choose another provider';

  @override
  String get notificationTimeNow => 'Just now';

  @override
  String notificationTimeMinutes(int count) {
    return '$count minutes ago';
  }

  @override
  String notificationTimeHours(int count) {
    return '$count hours ago';
  }

  @override
  String notificationTimeDays(int count) {
    return '$count days ago';
  }

  @override
  String get notificationRatingLabel => 'Rating';

  @override
  String notificationRatingOfFive(String rating) {
    return '$rating out of 5';
  }

  @override
  String get notificationFromCustomer => 'From customer';

  @override
  String get notificationCustomerFallback => 'Customer';

  @override
  String get notificationRatingDate => 'Rating date';

  @override
  String get notificationCommentLabel => 'Comment';

  @override
  String get viewTransactionDetails => 'View transaction details';

  @override
  String get availabilityOnlineTitle => 'I\'m available now';

  @override
  String get availabilityOfflineTitle => 'Currently unavailable';

  @override
  String get availabilityOnlineHint =>
      'You\'ll receive requests near your location';

  @override
  String get availabilityOfflineHint =>
      'You won\'t receive any requests right now';

  @override
  String get stepAssigned => 'Assigned';

  @override
  String get stepPriceOffer => 'Price offer';

  @override
  String get stepConfirmation => 'Confirmation';

  @override
  String get stepCompletion => 'Completion';

  @override
  String get ownerStepSent => 'Sent';

  @override
  String get ownerStepProviderResponse => 'Provider response';

  @override
  String get acceptOffer => 'Accept offer';

  @override
  String get rejectOffer => 'Reject offer';

  @override
  String get providerRespondedWithOffer =>
      'The provider responded to your request with a price';

  @override
  String get agreedPrice => 'Agreed price';

  @override
  String get completeOrder => 'Complete order';

  @override
  String get acceptOrder => 'Accept request';

  @override
  String get waitingYourResponse => 'Waiting for your response to the request';

  @override
  String get waitingCustomerConfirmation =>
      'Waiting for the customer to confirm the offer';

  @override
  String get locationUnavailable => 'Location unavailable';

  @override
  String autoCancelCountdown(String time) {
    return 'Provider response window — the order auto-cancels in $time';
  }

  @override
  String get tapToViewFullMap => 'Tap to view the full map';

  @override
  String get orderStatusCompletedTitle => 'Order completed';

  @override
  String get orderStatusCompletedSubtitle =>
      'Service completed successfully, we hope you had a good experience';

  @override
  String get imagePickError => 'An error occurred while picking the image';

  @override
  String get orderLoadFailed => 'Couldn\'t load order data';

  @override
  String get orderNoLongerAvailable =>
      'Sorry, this request is no longer available (it may have expired)';

  @override
  String get enterPrice => 'Please enter the proposed price';

  @override
  String get enterValidPrice => 'Please enter a valid price';

  @override
  String get offerSentSuccess => 'Price offer sent successfully';

  @override
  String get rejectOrder => 'Reject request';

  @override
  String get rejectOrderConfirm =>
      'Are you sure you want to reject this request?';

  @override
  String get orderRejectedToast => 'Request rejected';

  @override
  String get customerPhotos => 'Photos from customer';

  @override
  String get customerLocationMap => 'Customer location map';

  @override
  String get proposedPriceEgp => 'Proposed price (EGP)';

  @override
  String get priceHintExample => 'e.g. 350';

  @override
  String get etaMinutesLabel => 'Estimated time of arrival (min)';

  @override
  String get etaHintExample => 'e.g. 15';

  @override
  String get notesToOwnerOptional => 'Notes to the owner (optional)';

  @override
  String get notesHint => 'Write any extra details about the service...';

  @override
  String yourAttachedPhotos(int count) {
    return 'Photos attached by you ($count)';
  }

  @override
  String get submitOffer => 'Submit offer';

  @override
  String get cancelOrderConfirmTitle => 'Cancel request?';

  @override
  String get cancelOrderConfirmBody =>
      'The current request will be cancelled and the provider will be notified (if assigned).';

  @override
  String get goBack => 'Go back';

  @override
  String get providerPhoneUnavailable => 'Provider\'s number is unavailable';

  @override
  String get selectRatingPrompt => 'Please select a rating from 1 to 5';

  @override
  String get ratingSubmittedThanks =>
      'Thank you! Your rating has been submitted';

  @override
  String get providerRated => 'Provider rated';

  @override
  String get ratingExperiencePrompt =>
      'How was your experience with the provider?';

  @override
  String get addCommentOptionalHint => 'Add a comment (optional)...';

  @override
  String get submitRating => 'Submit rating';

  @override
  String get providerRejectOrderConfirmTitle => 'Reject request?';

  @override
  String get providerRejectOrderConfirmBody =>
      'The customer will be notified and this request will be cancelled.';

  @override
  String get providerRejectOrderConfirmLabel => 'Yes, reject request';

  @override
  String get providerOrderNoLongerAvailable =>
      'This request is no longer available (it may have expired)';

  @override
  String get completeOrderTitle => 'Complete request?';

  @override
  String get completeOrderConfirmBody =>
      'The service will be marked complete and the customer will be able to rate you afterwards.';

  @override
  String get orderCompletedToast => 'Request completed successfully';

  @override
  String get currentOrdersTitle => 'Your current requests';

  @override
  String get providerNewOrderBadge => 'New order';

  @override
  String get providerViewOrder => 'View order';

  @override
  String get providePriceOffer => 'Make a price offer';

  @override
  String get locatingLocation => 'Locating...';

  @override
  String get providerDataUnavailable => 'Provider data unavailable';

  @override
  String providerLoadFailed(String error) {
    return 'Couldn\'t load provider data: $error';
  }

  @override
  String get mustLoginToSend => 'You must log in to send the request';

  @override
  String get requestDataNotFound =>
      'Couldn\'t find the request data, please re-enter it';

  @override
  String get phoneUnavailable => 'Phone number unavailable';

  @override
  String get cannotCallNumber => 'Cannot call this number';

  @override
  String get providerDetailsTitle => 'Provider details';

  @override
  String get hasServiceVehicle => 'Has a service vehicle';

  @override
  String get noServiceVehicle => 'No service vehicle';

  @override
  String get availableNow => 'Available now';

  @override
  String get sendRequestToProvider => 'Send request to this provider';

  @override
  String get sendRequestNote =>
      'The request goes only to this provider, who has a short window to respond before it auto-cancels.';

  @override
  String providersLoadFailed(String error) {
    return 'Couldn\'t load providers: $error';
  }

  @override
  String get selectProvider => 'Select provider';

  @override
  String get noNearbyProviders => 'No providers available nearby';

  @override
  String get nearbyMapEntryTitle => 'Providers around you on the map';

  @override
  String get nearbyMapEntrySubtitle =>
      'See the workshops and providers available around your location';

  @override
  String get ownerMapPreviewHint => 'Tap to see the services around you';

  @override
  String get comingSoonMoreServices => 'More services coming soon';

  @override
  String get homeHowItWorksTitle => 'How Mahwar works';

  @override
  String get homeHowItWorksStep1Title => 'Request your service';

  @override
  String get homeHowItWorksStep1Body =>
      'Tell us what you need, where you are, and pick your provider';

  @override
  String get homeHowItWorksStep2Title => 'Get the price and approve';

  @override
  String get homeHowItWorksStep2Body =>
      'The provider sends a price — you accept or reject freely';

  @override
  String get homeHowItWorksStep3Title => 'Track and rate';

  @override
  String get homeHowItWorksStep3Body =>
      'Follow the provider\'s arrival, then rate the service';

  @override
  String get homeSupportTitle => 'Need help?';

  @override
  String get homeSupportSubtitle =>
      'Our support team is ready whenever you need';

  @override
  String get currentLocationLabel => 'Your current location';

  @override
  String get faultLocationOnMap => 'The fault location is shown on the map';

  @override
  String get providersMapTitle => 'Providers around you';

  @override
  String providersMapCount(int count) {
    return 'Available now: $count providers';
  }

  @override
  String get providersMapEmpty =>
      'No providers are available right now — try refreshing the map in a moment';

  @override
  String get providersMapLocationFailed =>
      'Could not determine your location. Enable location services and try again.';

  @override
  String get providersMapLoadFailed => 'Could not load providers on the map.';

  @override
  String get providersMapRefresh => 'Refresh';

  @override
  String get providersMapRecenter => 'Back to my location';

  @override
  String get providersMapViewProfile => 'View profile';

  @override
  String get providersMapDirections => 'Directions';

  @override
  String get providersMapFilterAll => 'All';

  @override
  String mapLoadFailed(String error) {
    return 'Couldn\'t load map data: $error';
  }

  @override
  String get noMapAppsAvailable => 'No map apps available on your device';

  @override
  String get navigateToCustomerTitle =>
      'The customer approved the price — head to them now';

  @override
  String get navigateToCustomerAction => 'Navigate to customer';

  @override
  String get enableLocationService =>
      'Please enable location services (GPS) in your device settings';

  @override
  String get locationPermissionDenied =>
      'Location access permission was denied';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission is permanently denied, please enable it from the app settings';

  @override
  String get locationDetectFailed => 'Couldn\'t determine the current location';

  @override
  String get accessMapTitle => 'Access map';

  @override
  String get customerLocationLabel => 'Customer location';

  @override
  String get yourLocationLabel => 'Your location';

  @override
  String approxDistanceToCustomer(String distance) {
    return 'Approximate distance to customer: $distance';
  }

  @override
  String approxDistance(String distance) {
    return 'Approximate distance: $distance';
  }

  @override
  String get openRouteInMaps => 'Open route in maps';

  @override
  String get locateCurrentPositionTooltip => 'Locate my current position';

  @override
  String get orderStatusCompleted => 'Completed';

  @override
  String get noRatingsYet => 'No ratings yet';

  @override
  String ratingSummary(String avg, int count) {
    return '$avg ($count ratings)';
  }

  @override
  String get supportScopeEmergency => 'Roadside emergency';

  @override
  String get supportScopeOnSite => 'At the workshop';

  @override
  String get supportScopeBoth => 'Both';

  @override
  String get supportScopeBothDetailed => 'In the workshop and on the road';

  @override
  String get transactionSummaryTitle => 'Transaction summary';

  @override
  String get transactionDateLabel => 'Transaction date';

  @override
  String get transactionClosedDateLabel => 'Completion date';

  @override
  String get transactionProviderLabel => 'Provider';

  @override
  String get transactionPathTitle => 'Transaction path';

  @override
  String get transactionSucceeded => 'Transaction completed successfully';

  @override
  String get transactionFailed => 'Transaction not completed';

  @override
  String get transactionEventOrderSent => 'Order sent';

  @override
  String get transactionEventProviderReceived => 'Provider received the order';

  @override
  String transactionEventOfferWithPrice(String price, String currency) {
    return 'Provider submitted a price offer ($price $currency)';
  }

  @override
  String get transactionEventOfferConfirmed => 'Offer confirmed';

  @override
  String transactionEventPriceChangeRequested(
    String oldPrice,
    String newPrice,
    String currency,
  ) {
    return 'Provider requested a price change after inspection ($oldPrice → $newPrice $currency)';
  }

  @override
  String get transactionEventPriceChangeAwaitingOwner =>
      'Waiting for the response to the new price';

  @override
  String get transactionEventPriceChangeApproved => 'New price approved';

  @override
  String get transactionEventPriceChangeRejected => 'New price rejected';

  @override
  String get transactionEventPriceChangeExpired =>
      'Response window expired — the new price is treated as rejected';

  @override
  String get transactionEventPriceChangeAwaitingProvider =>
      'Waiting for the provider to continue at the original price or withdraw';

  @override
  String transactionEventPriceChangeContinued(String price, String currency) {
    return 'Provider chose to continue at the original price ($price $currency)';
  }

  @override
  String get transactionEventPriceChangeWithdrawn =>
      'Provider withdrew after the new price was rejected';

  @override
  String get transactionEventCompleted => 'Transaction completed';

  @override
  String get transactionEventRejectedByProvider =>
      'Provider rejected the transaction';

  @override
  String get transactionEventRejectedByOwner =>
      'Customer rejected the price offer';

  @override
  String get transactionEventCancelledTimeout =>
      'Order cancelled (response timeout)';

  @override
  String get transactionFailureProvider => 'Rejected by the provider';

  @override
  String get transactionFailureProviderWithdrawn =>
      'Provider withdrew after the new price was rejected';

  @override
  String get transactionFailureOwner => 'Rejected by the customer';

  @override
  String get transactionFailureAutoCancel =>
      'Auto-cancelled (response timeout)';

  @override
  String get orderTimelineTitle => 'Order timeline';

  @override
  String get apply => 'Apply';

  @override
  String orderHistoryLoadFailed(String error) {
    return 'Failed to load history: $error';
  }

  @override
  String get selectTransactionDate => 'Select transaction date';

  @override
  String get filterByDateAllDays => 'Filter by date: all days';

  @override
  String get ratingExperienceTitle => 'Rate your experience with the provider';

  @override
  String get ratingQualityPrompt => 'How was the service quality?';

  @override
  String ratingProviderPrompt(String name) {
    return 'How was the service from \"$name\"?';
  }

  @override
  String get rateLater => 'Rate later';

  @override
  String get rpcErrorOrderNotFound => 'This request no longer exists.';

  @override
  String get rpcErrorNotOwner =>
      'You do not have permission to perform this action on this request.';

  @override
  String get rpcErrorOrderNotPending =>
      'This request is no longer available; it may have been processed or cancelled.';

  @override
  String get rpcErrorNotAssigned =>
      'This request has not been assigned to a provider yet.';

  @override
  String get rpcErrorNotProvider =>
      'You do not have permission to handle this request.';

  @override
  String get rpcErrorInvalidPrice =>
      'Invalid price. Enter an amount greater than zero.';

  @override
  String get rpcErrorNotPricedOrNotOwner =>
      'There is no valid quote for this request, or you are not its owner.';

  @override
  String get rpcErrorNotConfirmedOrNotProvider =>
      'The request is not confirmed, or you are not the assigned provider.';

  @override
  String get rpcErrorInvalidRating =>
      'Invalid rating value (must be between 1 and 5).';

  @override
  String get rpcErrorOrderNotCompleted =>
      'You can only rate a request after it is completed.';

  @override
  String get rpcErrorAlreadyRated => 'This request has already been rated.';

  @override
  String get rpcErrorOrderNotFoundOrForbidden =>
      'The request does not exist, or you do not have access to it.';

  @override
  String get rpcErrorOwnerNationalIdMissing =>
      'A valid national ID is required to complete the request. Please update your profile.';

  @override
  String get rpcErrorOwnerNationalIdInvalid =>
      'The national ID on your account is invalid. Please update it in your profile.';

  @override
  String get rpcErrorDuplicatePendingOrder =>
      'You already have a pending request. Cancel it or wait for it before creating a new one.';

  @override
  String get rpcErrorProviderUnavailable =>
      'This provider is no longer available for this request. Please try another provider.';

  @override
  String get rpcErrorTooManyAttachments => 'Too many photos (maximum is 10).';

  @override
  String get rpcErrorInvalidAttachmentUrl =>
      'One of the attached photos could not be verified. Please try again.';

  @override
  String get rpcErrorNotAuthenticated =>
      'Your session has expired. Please sign in again.';

  @override
  String get rpcErrorPhoneNotVerified =>
      'Please verify your phone number first to complete this action.';

  @override
  String get rpcErrorPhoneChangeRequiresOtp =>
      'Changing your phone number requires SMS verification. Use the Change number button.';

  @override
  String get rpcErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get otpErrorExpired =>
      'The code is incorrect or has expired. Try again.';

  @override
  String get otpErrorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get otpErrorSendFailed =>
      'We couldn\'t send the code. Try again later.';

  @override
  String get otpErrorPhoneExists =>
      'This phone number is already registered to another account.';

  @override
  String get otpErrorPhoneNotConfirmed =>
      'The phone number is not confirmed. Try the code again.';

  @override
  String get otpErrorReauth => 'Please sign in again to continue.';

  @override
  String get otpErrorUserNotFound =>
      'We couldn\'t send a code. Check the phone number and try again.';

  @override
  String get otpErrorGeneric =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get recoveryNeutralError =>
      'We couldn\'t send a code. Check the phone number and try again.';

  @override
  String get changePhoneThrottleError =>
      'Too many attempts. Please try again later.';

  @override
  String get changePhoneLookupFailed =>
      'Couldn\'t verify the phone number. Please try again.';

  @override
  String get signupGenericError =>
      'Something went wrong while creating your account. Please try again.';

  @override
  String get signupMissingWorkshopName => 'Please enter the workshop name.';

  @override
  String get signupMissingNationalId => 'Please enter your national ID.';

  @override
  String get signupMissingAddress => 'Please enter the address.';

  @override
  String get signupMissingLocation => 'Please set your location on the map.';

  @override
  String get signupMissingSpecialization =>
      'Please choose at least one specialization.';

  @override
  String get signupInvalidRole =>
      'There was an error with the account type. Please try signing up again.';

  @override
  String get signupDuplicatePhone => 'This phone number is already registered.';

  @override
  String get signupDuplicateNationalId =>
      'This national ID is already registered.';

  @override
  String get signupUniqueViolation =>
      'The phone number or national ID is already registered.';

  @override
  String get signupAccountExistsCustomer =>
      'The phone number or national ID is already registered to a customer account. Please sign in from the customer login page.';

  @override
  String get signupAccountExistsProvider =>
      'The phone number or national ID is already registered to a provider account. Please sign in from the provider login page.';

  @override
  String get signupAccountExistsUnknown =>
      'The phone number or national ID is already registered to another account. Please sign in with the existing account.';

  @override
  String get roleMismatchProvider =>
      'This account is registered as a provider. Please sign in from the provider login page.';

  @override
  String get roleMismatchCustomer =>
      'This account is registered as a customer. Please sign in from the customer login page.';

  @override
  String get roleUnresolved =>
      'Could not determine the account type after signing in. Please try again.';

  @override
  String get signOutSuccess => 'Signed out';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get cancelAction => 'Back';

  @override
  String get errorTitle => 'Error';

  @override
  String get okButton => 'OK';

  @override
  String get errPhoneDuplicate =>
      'This phone number is already registered to another account. Please use a different number or sign in to the existing account.';

  @override
  String get errNationalIdDuplicate =>
      'This national ID is already registered to another account. If you already have an account, please sign in to it.';

  @override
  String get errEmailDuplicate =>
      'This email is already registered to another account. Please sign in to the existing account or use a different email.';

  @override
  String get errInvalidCredentials =>
      'Incorrect email or password. Please check your details and try again.';

  @override
  String get errUserBanned =>
      'You have been banned from using Mahwar. If you believe this is a mistake, please contact support.';

  @override
  String get errEmailNotConfirmed =>
      'Your email has not been confirmed yet. Please check your inbox and click the confirmation link.';

  @override
  String get errTooManyRequests =>
      'You have exceeded the allowed number of attempts. Please wait a moment and try again.';

  @override
  String get errUserNotFound =>
      'No account is linked to this email. Please sign up first.';

  @override
  String get errInvalidPassword => 'Incorrect password. Please try again.';

  @override
  String get authErrorUnexpected =>
      'An unexpected error occurred. Please try again.';

  @override
  String get authErrorNoAccount =>
      'No account is linked to this number or email.';

  @override
  String get authErrorNetwork =>
      'No internet connection. Check your connection and try again.';

  @override
  String get authErrorSignOut => 'An error occurred while signing out.';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get forgotPhoneEntrySubtitle =>
      'Enter the phone number linked to your account and we will send a verification code to it';

  @override
  String get enterValidEgyptianPhone => 'Enter a valid Egyptian phone number';

  @override
  String get phoneAlreadyRegistered =>
      'This phone number is already registered to another user';

  @override
  String get changePhoneSameNumber =>
      'This is already your current number. Enter a different number.';

  @override
  String get rejectOfferConfirmTitle => 'Reject the price offer?';

  @override
  String get rejectOfferConfirmBody =>
      'The provider offer will be rejected and this order will be closed.';

  @override
  String get rejectOfferConfirmLabel => 'Yes, reject offer';

  @override
  String get signupOwnerTitle => 'New Car Owner Account';

  @override
  String get signupOwnerSubtitle =>
      'Register your details and car to request emergency services';

  @override
  String get signupProviderTitle => 'Join Mahwar Provider Network';

  @override
  String get signupProviderSubtitle =>
      'Register your workshop or service details to receive roadside emergency requests in your area';

  @override
  String get forgotPasswordSubtitle =>
      'Enter the phone number linked to your account. We will send a verification code via SMS.';

  @override
  String get sendVerificationCode => 'Send Code';

  @override
  String errorWithDetail(String error) {
    return 'Error: $error';
  }

  @override
  String errorSaving(String error) {
    return 'Error saving: $error';
  }

  @override
  String get saveFailedRetry =>
      'Couldn\'t save your changes. Please try again.';

  @override
  String get chooseAvatarTitle => 'Choose your avatar';

  @override
  String get chooseAvatarSubtitle =>
      'This will appear on your profile and orders';

  @override
  String get saving => 'Saving...';

  @override
  String get saveAvatar => 'Save Avatar';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get phoneRequired => 'Phone number is required';

  @override
  String get enterValidEgyptianPhoneNumber =>
      'Enter a valid Egyptian phone number (01xxxxxxxxx)';

  @override
  String get selectSpecialtiesDesc =>
      'Select the specialties your workshop offers. They appear to car owners when searching for services.';

  @override
  String get noSpecialtiesAvailable => 'No specialties available right now';

  @override
  String get workshopNameRequired => 'Workshop name is required';

  @override
  String get workshopAddressRequired => 'Please enter workshop address';

  @override
  String get vehicleSpecsHintEquipped =>
      'e.g. Hydraulic crane, equipped vehicle';

  @override
  String get deleteCarConfirm => 'Are you sure you want to delete this car?';

  @override
  String get noCarsRegistered => 'No cars registered';

  @override
  String get tapToAddCar => 'Tap + to add a car';

  @override
  String get addNewCar => 'Add New Car';

  @override
  String get selectCarMakeModelYear =>
      'Please select car make, model, and year';

  @override
  String get add => 'Add';

  @override
  String get appliedToAllDays => 'Applied to all days';

  @override
  String get dailyExceptions => 'Daily exceptions';

  @override
  String get dailyExceptionsHint =>
      'Turn a day off or edit its time — the rest follow the unified schedule';

  @override
  String get oneScheduleForAllDays => 'One schedule for all days';

  @override
  String get oneScheduleForAllDaysHint =>
      'Set a single time and apply it to every day, then adjust exceptions below';

  @override
  String get applyToAllDays => 'Apply to all days';

  @override
  String get today => 'Today';

  @override
  String get customLabel => 'Custom';

  @override
  String get dayOff => 'Day off';

  @override
  String get available => 'Available';

  @override
  String get restoreUnifiedTime => 'Restore unified time';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get welcomeToMahwar => 'Welcome to Mahwar';

  @override
  String get chooseAccountTypeSubtitle =>
      'Choose your account type to start using the app and exploring available services';

  @override
  String get needUrgentRoadsideHelp => 'Need urgent roadside help?';

  @override
  String get supportTeamReady24_7 =>
      'Our support team is ready to assist you 24 hours';

  @override
  String get mahwarHotlineAvailable =>
      'Mahwar hotline: 19xxx available in all governorates';

  @override
  String get callNow => 'Call Now';

  @override
  String get highlightLiveTracking => 'Live GPS tracking';

  @override
  String get highlightTransparentPricing => '100% transparent pricing';

  @override
  String get highlightFastResponse => 'Fast response 24/7';

  @override
  String get topRoadsideAssistance => 'The leading roadside emergency network';

  @override
  String get fastSafeRoadside24_7 => 'Fast and safe service on all roads 24/7';

  @override
  String get bannerHeadline => 'We\'ve paved your way!';

  @override
  String get betaVersionNotice => 'Beta version — more coming soon';

  @override
  String get betaBadge => 'Beta';

  @override
  String get backLabel => 'Back';

  @override
  String get viewAll => 'View all';

  @override
  String get unknownServiceType =>
      'Unknown service type, please update the app';

  @override
  String get preparingYourRequest => 'Preparing your request...';

  @override
  String get pleaseWaitDontClose => 'Please wait, don\'t close the app';

  @override
  String get additionalOptions => 'Additional options';

  @override
  String get locationTimeoutRetry =>
      'Couldn\'t locate you within 30 seconds, make sure GPS is available and try again';

  @override
  String get onboardingTitle1 => 'Fastest roadside emergency help';

  @override
  String get onboardingDesc1 =>
      'Mahwar connects you to the nearest tow trucks and roadside technicians by location in seconds.';

  @override
  String get onboardingTitle2 => 'Transparent, hassle-free pricing';

  @override
  String get onboardingDesc2 =>
      'Receive a direct price offer from the provider and accept or reject with one tap.';

  @override
  String get onboardingTitle3 => 'All-in-one breakdown service';

  @override
  String get onboardingDesc3 =>
      'Whether you need a tow truck, tire change, fuel, battery, or an emergency mechanic.';

  @override
  String get legalLastUpdated => 'Last Updated: November 2026';

  @override
  String get legalContactTitle => 'Contact Us';

  @override
  String get legalContactBody =>
      'If you have any questions or complaints, please contact us at:\nsupport@mahwar.app';

  @override
  String get legalTermsIntro =>
      'Welcome to Mahwar, a marketplace connecting car owners with roadside-assistance providers. These Terms govern your relationship with the Mahwar platform, its app and its website. The full text is published at mahwar.app/terms, and the Arabic version is authoritative. By using the Platform you agree to these Terms and the Privacy Policy.';

  @override
  String get legalTermsSection1Title => 'Acceptance & Eligibility';

  @override
  String get legalTermsSection1Body =>
      'By using the Platform or creating an account you confirm that you have read and understood these Terms and the Privacy Policy and agree to them. The Platform is for persons who are at least eighteen (18) and legally able to contract under the laws of Egypt, and operates inside Egypt only. If you do not agree, do not use the Platform.';

  @override
  String get legalTermsSection2Title => 'Nature of the Service';

  @override
  String get legalTermsSection2Body =>
      'Mahwar is a digital marketplace connecting a Car Owner with geographically nearby Service Providers. It enables posting a Request, receiving Offers, accepting one, tracking the Request and rating the Service. Mahwar is not a service provider and not a party to the contract between the Car Owner and the Service Provider, and does not guarantee provider availability, any arrival time or any price; a displayed arrival time is an estimate, not a commitment.';

  @override
  String get legalTermsSection3Title => 'Account & Registration';

  @override
  String get legalTermsSection3Body =>
      'Registration and sign-in use an Egyptian mobile number verified by a one-time code (OTP) sent by SMS; there is no password. You are responsible for the accuracy of your number and data — including your name, national ID and vehicle data — and for protecting your device and verification code. One account per person in the role chosen at registration; creating multiple accounts to evade a ban or usage limits is prohibited. Report any unauthorised use of your account immediately.';

  @override
  String get legalTermsSection4Title => 'Obligations of Both Parties';

  @override
  String get legalTermsSection4Body =>
      'A Car Owner must describe the fault and Service accurately, attach genuine photos, provide an accurate location, cooperate with the provider and pay the agreed price after performance. A Service Provider acts as an independent contractor responsible for tools, licences, insurance and tax obligations, submits honest Offers without raising the price after acceptance, and performs the Service safely. A Service Provider may not use Car Owner data — location or the phone number revealed after confirmation — for anything other than performing the Request, nor store, share or use it for marketing.';

  @override
  String get legalTermsSection5Title => 'Pricing, Payment & Cancellation';

  @override
  String get legalTermsSection5Body =>
      'The Service Provider sets the price and the Car Owner approves it before work begins; it may not change after approval except with the express consent of both parties in the app. Payment is made directly between the parties outside the app (cash or any method they agree); Mahwar collects no amount or commission and does not handle collection or refunds. A Request may be cancelled before an Offer is accepted; after acceptance it is binding on both parties. A Request may be cancelled automatically at the in-app deadline, and repeated cancellations or non-response may lower account priority or lead to suspension after a warning.';

  @override
  String get legalTermsSection6Title => 'Contact Data & Public Content';

  @override
  String get legalTermsSection6Body =>
      'The Car Owner\'s phone number is shown to the Service Provider only after the Request is confirmed and solely to perform it. Ratings and comments are public on the provider\'s profile, and users remain responsible for their content. Abusive, defamatory, privacy-violating, advertising or misleading content is prohibited. You may report any abusive content or behaviour via the in-app support button or support@mahwar.app; Mahwar reviews reports and takes appropriate action — up to removing content or suspending the account — within a period not exceeding 72 hours, and may hide abusive content and prevent its author from appearing to you.';

  @override
  String get legalTermsSection7Title => 'Suspension & Liability';

  @override
  String get legalTermsSection7Body =>
      'Mahwar may suspend or terminate an account for breach of these Terms, abusive behaviour, suspected fraud or danger to other users, notifying the user of the reason where possible. The Platform is provided \"as is\" and subject to availability; Mahwar does not certify Service Providers professionally or guarantee the quality of their work, but verifies identity and reviews ratings and reports. Roadside assistance can involve risk, and users must follow safety instructions. Mahwar\'s total liability shall not exceed the amount you actually paid to use the Platform in the twelve months preceding the claim, to the extent permitted by law.';

  @override
  String get legalTermsSection8Title => 'Governing Law, Changes & Contact';

  @override
  String get legalTermsSection8Body =>
      'These Terms are governed by the laws of Egypt. We will first seek amicable resolution of any dispute within 30 days of notice; failing that, the courts of Cairo have jurisdiction, without prejudice to your mandatory consumer rights. We may amend these Terms for operational or legal reasons, publish the updated version in the app and at mahwar.app/terms with the update date, and give reasonable notice of material changes before they take effect. Contact: support@mahwar.app.';

  @override
  String get legalPrivacyIntro =>
      'At Mahwar we collect the minimum data needed to operate a roadside-assistance service, and we do not sell it or use it for advertising or tracking. This Policy explains what we collect, why, how we store it and your rights of control. It is directed at persons aged 18 or over in Egypt; the full text is published at mahwar.app/privacy.';

  @override
  String get legalPrivacySection1Title => 'Data We Collect';

  @override
  String get legalPrivacySection1Body =>
      'Data you provide: Egyptian phone number (mandatory for OTP authentication), name, email (optional), national ID (mandatory before sending a Request, for identity verification), vehicle data, vehicle location, fault description and photos when creating a Request, support-ticket image and text, and ratings and comments. Data collected automatically: Request details, status and price, Service Provider location during an active Request only, FCM notification token, device identifier and notification text, screen name and dwell time to improve the app, SMS send logs, and basic technical data for security. We never collect payment data (no in-app payments), contacts, SMS messages or call logs, audio or video, background location, or the advertising identifier.';

  @override
  String get legalPrivacySection2Title => 'Why We Use Your Data';

  @override
  String get legalPrivacySection2Body =>
      'We use your data to create and authenticate accounts; operate the marketplace (posting Requests, finding the nearest provider, offers, tracking, ratings); verify identity and prevent fraud; secure the Platform; send operational notifications; improve the app; handle support tickets; and comply with lawful requests. We do not use your data for advertising, do not sell it, and do not make automated decisions with legal effects on you without human intervention.';

  @override
  String get legalPrivacySection3Title => 'Who Sees Your Data';

  @override
  String get legalPrivacySection3Body =>
      'The other party to a Request sees what is needed to perform it: the Service Provider sees the description, location, photos and the Car Owner\'s name, while the Car Owner\'s phone number is revealed only after the Request is confirmed. Your ratings and comments are public on the provider\'s profile without phone numbers or national IDs. We use processors acting on our behalf only to operate the service: Supabase (data, authentication, storage), Google Firebase (notifications), ZADX (SMS), Resend (support email), Cloudflare (DNS and email routing) and OpenStreetMap (map tiles). We may disclose data under a binding legal request or to protect our rights and users\' safety to the minimum extent necessary, and data may transfer to a successor on a business sale under the same obligations.';

  @override
  String get legalPrivacySection4Title => 'Location, Camera & Notifications';

  @override
  String get legalPrivacySection4Body =>
      'We use vehicle location to find nearby providers and track the Request; we do not follow your location outside an active Request, in the background, or after it ends. We request camera access to capture a fault photo or support-ticket image, and photo-library access to choose an existing photo, and we upload nothing without your explicit selection. We send operational notifications about Requests and your account, adjustable in your device settings, and do not use your data to send third-party advertising.';

  @override
  String get legalPrivacySection5Title => 'Where Data Is Stored & Retention';

  @override
  String get legalPrivacySection5Body =>
      'Data is stored on Supabase cloud infrastructure and may be outside Egypt under appropriate contractual and technical safeguards, protected in transit by encryption and by row-level security (RLS) policies preventing any user from reading another user\'s data. Account data is kept for the life of the account and deleted when it is closed. Limited anonymised information may remain after deletion for service records, abuse prevention and legal obligations: public ratings and comments, support tickets and SMS send logs — unlinkable to you once your identifiers are removed. Request and support photos and attachments are deleted on deletion or when the purpose ends.';

  @override
  String get legalPrivacySection6Title => 'Deleting Your Account';

  @override
  String get legalPrivacySection6Body =>
      'You can delete your account at any time from the in-app settings or via mahwar.app/delete-account without installing the app. To confirm you own the account we ask for a code sent to your registered phone number — the same sign-in mechanism — and never for a password. On deletion we remove your profile and vehicle data, your Requests and their details, your notifications and device tokens, your preferences, your stored attachments, and permanently remove your account from authentication. We may temporarily delay deletion if an active Request, a dispute or a legal obligation applies, explaining the reason and delay. Deletion is usually permanent and cannot be undone.';

  @override
  String get legalPrivacySection7Title => 'Your Rights';

  @override
  String get legalPrivacySection7Body =>
      'Under Egypt\'s Personal Data Protection Law No. 151 of 2020 and applicable regulations you may access your data, rectify it, delete it and close your account, restrict or object to processing for reasons specific to you, withdraw consent where processing is based on it without retroactive effect, port data you provided where applicable, and complain to us and then to the competent authority. We usually respond within 30 days and may ask for proof of identity before acting, and we do not treat users differently for exercising their rights.';

  @override
  String get legalPrivacySection8Title => 'Security, Policy Updates & Contact';

  @override
  String get legalPrivacySection8Body =>
      'We use encryption in transit, strict access policies, least privilege, multi-factor authentication for administrator accounts and audit logs for sensitive actions; no one can guarantee absolute security, and if a breach affects your data we notify you and the competent authority as required by law. We may update this Policy for service or legal changes, publish the updated version in the app and at mahwar.app/privacy with the update date, and give reasonable notice of material changes before they take effect. Contact: privacy@mahwar.app or support@mahwar.app.';

  @override
  String get signOut => 'Sign out';

  @override
  String get providerLogoutLastSessionTitle => 'Sign out';

  @override
  String get providerLogoutLastSessionBody =>
      'Your activity will stop after 2 hours. Sign in again to reactivate it.';

  @override
  String get providerOfflineAlertTitle => 'Provider is offline';

  @override
  String get providerOfflineAlertBody =>
      'The provider just signed out. Send them a text alert?';

  @override
  String get providerOfflineAlertMonthlyUsed =>
      'The monthly alert for this provider has already been used.';

  @override
  String get providerOfflineAlertDailyCap =>
      'No more alerts can be sent right now. Try again later.';

  @override
  String get sendProviderAlertSms => 'Send text alert';

  @override
  String get providerAlertSmsSent => 'Alert sent';

  @override
  String get providerAlertSmsSentBody =>
      'We\'ll notify the provider by text message.';

  @override
  String get providerAlertSmsAlreadySent =>
      'An alert was already sent for this order.';

  @override
  String get providerAlertSmsFailed =>
      'Couldn\'t send the alert. Please try again.';

  @override
  String get connectionError => 'Connection error, please try again.';

  @override
  String get noInternetTitle => 'No internet connection';

  @override
  String get noInternetBody => 'Check your network connection and try again';

  @override
  String get notificationsLoadFailed => 'Couldn\'t load notifications';

  @override
  String get ordersLoadFailed => 'Couldn\'t load orders';

  @override
  String get needNationalIdFirst =>
      'To submit a service request, you must add your valid national ID to your personal data first.';

  @override
  String get locationServiceDisabled =>
      'Please enable location services (GPS) from your device settings';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permission is permanently denied, please enable it from app settings';

  @override
  String serviceRequestErrorWithDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String get locationTimeoutDelayed =>
      'Could not locate you within 30 seconds, make sure GPS is available and try again';

  @override
  String get selectVehicleTitle => 'Select vehicle';

  @override
  String get vehiclePopularBrands => 'Popular brands';

  @override
  String get vehicleAllBrands => 'All brands';

  @override
  String get vehicleSearchBrand => 'Search brands';

  @override
  String get vehicleSearchModel => 'Search models';

  @override
  String get vehicleNoResults => 'No matching results';

  @override
  String get vehicleStepBrand => 'Brand';

  @override
  String get vehicleStepModel => 'Model';

  @override
  String get vehicleStepYear => 'Model year';

  @override
  String get vehicleStepTrim => 'Trim';

  @override
  String get vehicleStepColor => 'Color';

  @override
  String get vehicleStepPlate => 'Plate';

  @override
  String get vehicleStepReview => 'Review';

  @override
  String get vehicleReviewTitle => 'Review your car';

  @override
  String get vehicleReviewHint =>
      'Check the details — you can edit any item before saving.';

  @override
  String get vehicleReviewAction => 'Review details';

  @override
  String get vehicleEdit => 'Edit';

  @override
  String get vehiclePlateNone => 'Not added (optional)';

  @override
  String get vehicleYearHint =>
      'Pick the model year — we\'ll match the generation for you';

  @override
  String get vehicleTrimHint =>
      'A trim is the engine and equipment level. Pick \"Not sure\" if you don\'t know.';

  @override
  String get vehicleTrimUnknown => 'Not sure';

  @override
  String get vehicleTrimUnknownHint =>
      'We\'ll pick the base trim — you can change it later';

  @override
  String vehicleMatchedGeneration(String range) {
    return 'Matched generation: $range';
  }

  @override
  String vehicleHorsepower(int count) {
    return '$count hp';
  }

  @override
  String vehicleSeatsCount(int count) {
    return '$count seats';
  }

  @override
  String get vehicleBodySedan => 'Sedan';

  @override
  String get vehicleBodyHatchback => 'Hatchback';

  @override
  String get vehicleBodySuv => 'SUV';

  @override
  String get vehicleBodyCrossover => 'Crossover';

  @override
  String get vehicleBodyPickup => 'Pickup';

  @override
  String get vehicleBodyVan => 'Van';

  @override
  String get vehicleBodyMpv => 'MPV';

  @override
  String get vehicleBodyCoupe => 'Coupe';

  @override
  String get vehicleBodyWagon => 'Wagon';

  @override
  String get vehicleFuelPetrol => 'Petrol';

  @override
  String get vehicleFuelDiesel => 'Diesel';

  @override
  String get vehicleFuelHybrid => 'Hybrid';

  @override
  String get vehicleFuelElectric => 'Electric';

  @override
  String get vehicleFuelCng => 'CNG';

  @override
  String get vehicleTransmissionManual => 'Manual';

  @override
  String get vehicleTransmissionAutomatic => 'Automatic';

  @override
  String get vehicleTransmissionCvt => 'CVT';

  @override
  String get vehicleTransmissionDct => 'DCT';

  @override
  String get vehiclePlateOptionalTitle => 'Plate number (optional)';

  @override
  String get vehiclePlateOptionalHint =>
      'Adding the plate helps the provider identify your car';

  @override
  String get vehiclePlateEditableHint =>
      'Type the digits on the plate, then pick the letters in order — first letter on the right. Repeats are fine and the count is not fixed';

  @override
  String get vehiclePlateSequenceHint =>
      'The first letter you tap appears on the right of the plate';

  @override
  String get vehiclePlateBackspace => 'Delete last letter';

  @override
  String get vehiclePlateLetters => 'Letters';

  @override
  String get vehiclePlateDigitsHint => 'Digits';

  @override
  String get vehiclePlatePreview => 'Plate preview';

  @override
  String get vehiclePlateClear => 'Clear';

  @override
  String get vehiclePlateInvalid =>
      'Enter both letters and digits (up to 5 letters and 7 digits), or clear the plate';

  @override
  String get vehicleSave => 'Save vehicle';

  @override
  String get vehicleCatalogLoadFailed =>
      'Could not load the vehicle catalog. Check your connection and try again.';

  @override
  String get signupVehicleSection => 'Your car';

  @override
  String get signupVehicleRequired => 'Please select your car to continue';

  @override
  String get defaultVehicle => 'Default vehicle';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get editVehicle => 'Edit vehicle';

  @override
  String get deleteCarTitle => 'Delete vehicle';

  @override
  String get vehicleSaved => 'Vehicle saved';

  @override
  String get vehicleDeleted => 'Vehicle deleted';

  @override
  String get vehicleDefaultSet => 'Default vehicle updated';

  @override
  String get selectCarFirst => 'Please select your car first';

  @override
  String get signupVehicleYearRequired => 'Please select your car model year';

  @override
  String get signupVehicleColorRequired => 'Please select your car color';

  @override
  String get signupInvalidVehicleData =>
      'The selected vehicle data is invalid, please pick it again';

  @override
  String get rpcErrorVehicleNotFound =>
      'The selected vehicle was not found. Pick another car.';

  @override
  String get rpcErrorVehicleTrimNotFound =>
      'The selected trim is unavailable. Please pick the car again.';

  @override
  String get rpcErrorInvalidModelYear =>
      'The model year does not match the selected generation. Check the car details.';

  @override
  String get rpcErrorVehicleColorNotFound =>
      'The selected color is unavailable. Please pick the color again.';

  @override
  String get rpcErrorInvalidPlate =>
      'Invalid plate details. Use 3 letters and 3 or 4 digits.';

  @override
  String get providerPublicProfileTitle => 'Provider profile';

  @override
  String get viewProviderProfileAndReviews => 'Profile & reviews';

  @override
  String providerCompletedOrdersCount(int count) {
    return '$count completed orders';
  }

  @override
  String get providerReviewsTitle => 'Customer reviews';

  @override
  String get providerReviewsEmpty => 'No reviews yet';

  @override
  String get providerReviewsLoadMore => 'Show more';

  @override
  String get providerReviewAnonymous => 'Mahwar customer';

  @override
  String get providerProfileLoadFailed => 'Could not load the provider profile';

  @override
  String get providerPublicProfileMenu => 'My public profile';

  @override
  String get providerQrTitle => 'My QR code';

  @override
  String get providerQrBody =>
      'Print this code so customers can open your public profile and rate you.';

  @override
  String get providerQrShare => 'Share / save image';

  @override
  String get providerQrShareFailed => 'Could not share the image';

  @override
  String get providerQrScanHint =>
      'Scan the code to open the workshop profile and reviews';

  @override
  String get supportInboxSubtitle =>
      'Your message reaches our support team inside the app, and you can follow the reply from \"My tickets\".';

  @override
  String get supportLink => 'Support';

  @override
  String get supportNewMessage => 'New message';

  @override
  String get supportMyTickets => 'My tickets';

  @override
  String get supportTicketsEmpty => 'No previous messages yet';

  @override
  String get supportTicketsLoadFailed =>
      'Could not load your previous messages';

  @override
  String get supportSendButton => 'Send message';

  @override
  String get supportSendSuccess => 'Your message was sent';

  @override
  String supportTicketNumber(String id) {
    return 'Ticket number: $id';
  }

  @override
  String get supportFollowReplyHint =>
      'You can follow the support team\'s reply from \"My tickets\" at any time.';

  @override
  String get supportSendAnother => 'Send another message';

  @override
  String get supportAttachmentNeedsLogin =>
      'Sign in to attach an image. You can still send the message without an attachment now.';

  @override
  String get supportAttachmentUploadFailed =>
      'Could not upload the attached image. Try another image or send without an attachment.';

  @override
  String get supportAttachmentTooLarge => 'The image is larger than 10 MB.';

  @override
  String get supportAttachmentUnsupported =>
      'Unsupported image format. Use JPG, PNG, or WebP.';

  @override
  String get supportStatusOpen => 'Under review';

  @override
  String get supportStatusReplied => 'Replied';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportReplyLabel => 'Support team reply';

  @override
  String get rpcErrorSupportInvalidKind => 'Invalid message type.';

  @override
  String get rpcErrorSupportInvalidSubject =>
      'The subject must be between 3 and 120 characters.';

  @override
  String get rpcErrorSupportInvalidBody =>
      'The message must be between 10 and 4000 characters.';

  @override
  String get rpcErrorSupportInvalidCategory =>
      'The selected category is too long.';

  @override
  String get rpcErrorSupportInvalidContact =>
      'Check the name and phone number (11 digits starting with 01).';

  @override
  String get rpcErrorSupportInvalidAttachment =>
      'Could not verify the attached image. Upload it again and retry.';

  @override
  String get rpcErrorSupportRateLimited =>
      'You reached today\'s message limit. Try again later.';

  @override
  String get rpcErrorPriceRevisionExists =>
      'A price change request was already sent for this order and a second one is not allowed.';

  @override
  String get rpcErrorPriceRevisionNotAllowed =>
      'The price cannot be changed in the order\'s current state.';

  @override
  String get rpcErrorPriceRevisionPending =>
      'The order cannot be completed while a price change request is pending.';

  @override
  String get rpcErrorInvalidRevisionReason =>
      'Write a clear reason for the change (at least 3 characters).';

  @override
  String get rpcErrorRevisionNotFoundOrForbidden =>
      'The price change request was not found, or you cannot access it.';

  @override
  String get rpcErrorRevisionAlreadyDecided =>
      'This price change request was already decided.';

  @override
  String get rpcErrorInvalidRevisionChoice =>
      'Invalid choice. Select continue at the original price or withdraw.';

  @override
  String get rpcErrorUnauthenticated => 'Sign in to view your messages.';
}
