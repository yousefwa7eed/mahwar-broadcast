import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
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
import '../../features/orders_history/orders_history_screen.dart';
import '../../features/provider_selection/nearby_providers_screen.dart';
import '../../features/provider_selection/provider_details_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_personal_info_screen.dart';
import '../../features/profile/edit_workshop_screen.dart';
import '../../features/profile/edit_specializations_screen.dart';
import '../../features/profile/manage_cars_screen.dart';
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
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'car_owner';
        return LoginScreen(role: role);
      },
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'car_owner';
        if (role == 'provider') {
          return const SignupProviderScreen();
        }
        return const SignupOwnerScreen();
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
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        final serviceId = state.uri.queryParameters['serviceId'] ?? 'crane';
        final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ?? 0;
        final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ?? 0;
        return NearbyProvidersScreen(
          orderId: orderId,
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
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        final providerId = state.uri.queryParameters['providerId'] ?? '';
        return ProviderDetailsScreen(orderId: orderId, providerId: providerId);
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
