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
}
