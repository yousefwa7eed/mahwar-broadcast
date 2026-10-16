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
  String get deleteAccountPasswordPrompt =>
      'Enter your current password to confirm account deletion';

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
  String get notificationBodyOrderConfirmed =>
      'Your order was confirmed successfully';

  @override
  String notificationBodyOrderRejectedWithProvider(String provider) {
    return 'The order was rejected by $provider';
  }

  @override
  String get notificationBodyOrderRejected => 'The order was rejected';

  @override
  String get notificationBodyOrderCancelled => 'This order was cancelled';

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
    return 'The request will be auto-cancelled within 5 minutes — $time left';
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
  String providersLoadFailed(String error) {
    return 'Couldn\'t load providers: $error';
  }

  @override
  String get selectProvider => 'Select provider';

  @override
  String get noNearbyProviders => 'No providers available nearby';

  @override
  String mapLoadFailed(String error) {
    return 'Couldn\'t load map data: $error';
  }

  @override
  String get noMapAppsAvailable => 'No map apps available on your device';

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
  String get transactionFailureOwner => 'Rejected by the customer';

  @override
  String get transactionFailureAutoCancel =>
      'Auto-cancelled (response timeout)';

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
  String get legalLastUpdated => 'Last Updated: August 2025';

  @override
  String get legalContactTitle => 'Contact Us';

  @override
  String get legalContactBody =>
      'If you have any questions about this policy, please contact us at:\nsupport@mahwar.app\nOr call our support line: 19000';

  @override
  String get legalTermsIntro =>
      'Welcome to Mahwar, the roadside emergency services app. By using this application, you agree to the following terms and conditions that govern the relationship between you and the Mahwar platform.';

  @override
  String get legalTermsSection1Title => 'Acceptance of Terms';

  @override
  String get legalTermsSection1Body =>
      'By using the Mahwar app, you acknowledge that you have read, understood, and agree to be bound by these terms. If you do not agree to any of these terms, please do not use the application.';

  @override
  String get legalTermsSection2Title => 'Acceptable Use';

  @override
  String get legalTermsSection2Body =>
      'The application may only be used for lawful purposes and in accordance with applicable laws in Egypt. Use of the application for any fraudulent, harmful, or inappropriate purpose is strictly prohibited.';

  @override
  String get legalTermsSection3Title => 'Accounts & Responsibility';

  @override
  String get legalTermsSection3Body =>
      'You are responsible for maintaining the confidentiality of your account credentials and password, as well as all activities occurring under your account. You must notify us immediately of any unauthorized use of your account.';

  @override
  String get legalTermsSection4Title => 'Nature of App Services';

  @override
  String get legalTermsSection4Body =>
      'Mahwar provides a digital platform connecting car owners with emergency service providers. We are not a party to the agreement between the client and the provider, and we are not responsible for the quality of services rendered.';

  @override
  String get legalTermsSection5Title => 'Pricing & Payments';

  @override
  String get legalTermsSection5Body =>
      'All payments are made directly between the car owner and the service provider. The app facilitates the price negotiation and acceptance process. The application does not collect any commission or fees from transactions.';

  @override
  String get legalTermsSection6Title => 'Cancellation & Rejection';

  @override
  String get legalTermsSection6Body =>
      'Car owners may cancel requests at any time before accepting the price. Service providers may reject requests before submitting a quote. Once the price is accepted by the client, the order is considered binding.';

  @override
  String get legalTermsSection7Title => 'Intellectual Property';

  @override
  String get legalTermsSection7Body =>
      'All intellectual property rights in the app, including designs, logos, and content, are reserved to Mahwar. No part of the application may be reproduced or used commercially without prior permission.';

  @override
  String get legalTermsSection8Title => 'Amendments to Terms';

  @override
  String get legalTermsSection8Body =>
      'We reserve the right to modify these terms and conditions at any time. Users will be notified of any material changes through the application. Continued use of the app after modifications constitutes acceptance of the changes.';

  @override
  String get legalPrivacyIntro =>
      'At Mahwar, we value your trust and are fully committed to protecting your personal data. This policy explains how we collect, use, and protect your information.';

  @override
  String get legalPrivacySection1Title => 'Data We Collect';

  @override
  String get legalPrivacySection1Body =>
      'We collect data necessary for providing our services, including: full name, phone number, email address, live GPS location, national ID (for service providers), and vehicle details (make, model, year). We do not collect any unnecessary data.';

  @override
  String get legalPrivacySection2Title => 'How We Use Your Data';

  @override
  String get legalPrivacySection2Body =>
      'We use your data for the following purposes: providing emergency services, connecting you to the nearest service providers geographically, sending notifications related to your requests, improving app quality and user experience, and ensuring platform security.';

  @override
  String get legalPrivacySection3Title => 'Data Sharing';

  @override
  String get legalPrivacySection3Body =>
      'We do not share your data with third parties except in the following cases: when necessary to provide the service (sharing your location with the selected service provider), legal obligation by competent government authorities, or with your explicit consent.';

  @override
  String get legalPrivacySection4Title => 'Data Security';

  @override
  String get legalPrivacySection4Body =>
      'We use the latest encryption and security technologies to protect your data. We rely on Supabase as a secure infrastructure with SSL/TLS encryption for all communications. Row Level Security (RLS) policies are applied to ensure no unauthorized access to your data.';

  @override
  String get legalPrivacySection5Title => 'Your Data Rights';

  @override
  String get legalPrivacySection5Body =>
      'You have the following rights regarding your data: right to access and view your stored data, right to correction and modification, right to delete your account and all data, and right to object to data processing in certain cases.';

  @override
  String get legalPrivacySection6Title => 'Location Data';

  @override
  String get legalPrivacySection6Body =>
      'We use location data only during active service request sessions to find the nearest providers. We do not track your location in the background outside of service requests. You can control location permissions from your phone settings at any time.';

  @override
  String get legalPrivacySection7Title => 'Data Retention';

  @override
  String get legalPrivacySection7Body =>
      'We retain your account data as long as your account is active. Upon account deletion, all your personal data is deleted within 30 days. We may retain some anonymized data for statistical analysis.';

  @override
  String get legalPrivacySection8Title => 'Policy Updates';

  @override
  String get legalPrivacySection8Body =>
      'We may update this Privacy Policy from time to time to reflect changes in our practices or for operational or legal reasons. We will notify you of any material changes via an in-app notification before the changes take effect.';

  @override
  String get signOut => 'Sign out';

  @override
  String get connectionError => 'Connection error, please try again.';

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
}
