import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_owner_screen.dart';
import '../../features/splash_onboarding/onboarding_screen.dart';
import '../../features/splash_onboarding/select_user_type_screen.dart';
import '../../features/splash_onboarding/splash_screen.dart';

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
          return const Scaffold(
            body: Center(child: Text('Provider Signup Screen Placeholder')),
          );
        }
        return const SignupOwnerScreen();
      },
    ),
  ],
);
