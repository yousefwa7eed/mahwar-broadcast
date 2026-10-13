import 'package:go_router/go_router.dart';
import '../../core/auth/role_gate.dart';
import '../../core/models/notification_model.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/set_new_password_screen.dart';
import '../../features/auth/signup_owner_screen.dart';
import '../../features/auth/signup_provider_screen.dart';
import '../../features/splash_onboarding/onboarding_screen.dart';
import '../../features/select_user_type/select_user_type_screen.dart';
import '../../features/splash_onboarding/splash_screen.dart';
import '../../features/owner_home/owner_home_screen.dart';
import '../../features/service_request/service_request_screen.dart';
import '../../features/request_tracking/request_tracking_screen.dart';
import '../../features/provider_home/provider_home_screen.dart';
import '../../features/provider_offer_price/provider_offer_price_screen.dart';
import '../../features/provider_offer_price/provider_location_map_screen.dart';
import '../../features/orders_history/orders_history_screen.dart';
import '../../features/provider_selection/nearby_providers_screen.dart';
import '../../features/provider_selection/provider_details_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/notifications/notification_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_personal_info_screen.dart';
import '../../features/profile/edit_workshop_screen.dart';
import '../../features/profile/edit_specializations_screen.dart';
import '../../features/profile/working_hours_screen.dart';
import '../../features/profile/manage_cars_screen.dart';
import '../../features/profile/avatar_picker_screen.dart';
import '../../features/legal/screens.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/select-user-type',
      name: 'select-user-type',
      builder: (context, state) => const SelectUserTypeScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      // نقطة دخول مقيّدة بالدور: بدون دور صالح نعيد المستخدم لاختيار النوع
      // بدلاً من افتراض car_owner بصمت.
      redirect: (context, state) => AppRole.tryParse(
                state.uri.queryParameters['role'],
              ) ==
              null
          ? '/select-user-type'
          : null,
      builder: (context, state) {
        final role = AppRole.tryParse(state.uri.queryParameters['role'])!;
        return LoginScreen(role: role.dbValue);
      },
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      redirect: (context, state) => AppRole.tryParse(
                state.uri.queryParameters['role'],
              ) ==
              null
          ? '/select-user-type'
          : null,
      builder: (context, state) {
        final role = AppRole.tryParse(state.uri.queryParameters['role'])!;
        if (role == AppRole.provider) {
          return const SignupProviderScreen();
        }
        return const SignupOwnerScreen();
      },
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      redirect: (context, state) => AppRole.tryParse(
                state.uri.queryParameters['role'],
              ) ==
              null
          ? '/select-user-type'
          : null,
      builder: (context, state) {
        final role = AppRole.tryParse(state.uri.queryParameters['role'])!;
        return ForgotPasswordScreen(role: role.dbValue);
      },
    ),
    GoRoute(
      path: '/set-new-password',
      name: 'set-new-password',
      builder: (context, state) => const SetNewPasswordScreen(),
    ),
    GoRoute(
      path: '/otp-verify',
      name: 'otp-verify',
      builder: (context, state) {
        final modeName = state.uri.queryParameters['mode'] ?? 'signup';
        final phone = state.uri.queryParameters['phone'];
        final role = state.uri.queryParameters['role'];
        return OtpScreen(
          mode: otpModeFromQuery(modeName),
          phone: phone,
          role: role,
        );
      },
    ),
    GoRoute(
      path: '/home/owner',
      name: 'home-owner',
      builder: (context, state) => const OwnerHomeScreen(),
    ),
    GoRoute(
      path: '/home/provider',
      name: 'home-provider',
      builder: (context, state) => const ProviderHomeScreen(),
    ),
    GoRoute(
      path: '/request/create',
      name: 'request-create',
      builder: (context, state) {
        final serviceId = state.uri.queryParameters['serviceId'] ?? 'crane';
        return ServiceRequestScreen(serviceId: serviceId);
      },
    ),
    GoRoute(
      path: '/request/track',
      name: 'request-track',
      builder: (context, state) {
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return RequestTrackingScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/request/providers',
      name: 'request-providers',
      builder: (context, state) {
        final serviceId = state.uri.queryParameters['serviceId'] ?? 'crane';
        final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ?? 0;
        final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ?? 0;
        return NearbyProvidersScreen(
          serviceId: serviceId,
          lat: lat,
          lng: lng,
        );
      },
    ),
    GoRoute(
      path: '/request/provider-details',
      name: 'request-provider-details',
      builder: (context, state) {
        final providerId = state.uri.queryParameters['providerId'] ?? '';
        return ProviderDetailsScreen(providerId: providerId);
      },
    ),
    GoRoute(
      path: '/request/quote',
      name: 'request-quote',
      builder: (context, state) {
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return ProviderOfferPriceScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/request/map',
      name: 'request-map',
      builder: (context, state) {
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return ProviderLocationMapScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/orders/owner',
      name: 'orders-owner',
      builder: (context, state) => const OrdersHistoryScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/notification/detail',
      name: 'notification-detail',
      builder: (context, state) {
        // الإشعار يُمرَّر كاملاً عبر extra (title/body/created_at/image…).
        // إن غاب (مسار مباشر أو حالة قديمة) نعود لقائمة الإشعارات بأمان.
        final notification = state.extra;
        if (notification is NotificationModel) {
          return NotificationDetailScreen(notification: notification);
        }
        return const NotificationsScreen();
      },
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/edit',
      name: 'profile-edit',
      builder: (context, state) => const EditPersonalInfoScreen(),
    ),
    GoRoute(
      path: '/profile/cars',
      name: 'profile-cars',
      builder: (context, state) => const ManageCarsScreen(),
    ),
    GoRoute(
      path: '/provider/workshop',
      name: 'provider-workshop',
      builder: (context, state) => const EditWorkshopScreen(),
    ),
    GoRoute(
      path: '/provider/specialties',
      name: 'provider-specialties',
      builder: (context, state) => const EditSpecializationsScreen(),
    ),
    GoRoute(
      path: '/provider/schedule',
      name: 'provider-schedule',
      builder: (context, state) => const WorkingHoursScreen(),
    ),
    GoRoute(
      path: '/profile/avatar',
      name: 'profile-avatar',
      // دور الصورة يجب أن يكون صريحًا (يأتي من profile)؛ بدون دور صالح نرجع
      // لصفحة الملف الشخصي بدل افتراض car_owner.
      redirect: (context, state) => AppRole.tryParse(
                state.uri.queryParameters['role'],
              ) ==
              null
          ? '/profile'
          : null,
      builder: (context, state) {
        final role = AppRole.tryParse(state.uri.queryParameters['role'])!;
        return AvatarPickerScreen(role: role.dbValue);
      },
    ),
    GoRoute(
      path: '/terms',
      name: 'terms',
      builder: (context, state) => const TermsScreen(),
    ),
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
  ],
);
