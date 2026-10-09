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
  String get sharePhoneTitle => 'Share my phone number with the provider';

  @override
  String get sharePhoneSubtitle =>
      'Lets the provider see your number and call you directly (optional)';

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
}
