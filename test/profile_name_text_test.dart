import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/auth/profile_cubit.dart';
import 'package:mahwar/core/widgets/profile_name_text.dart';
import 'package:mahwar/core/widgets/shimmer_box.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('shows a skeleton while the profile is initial/loading',
      (tester) async {
    await tester.pumpWidget(wrap(const ProfileNameText(state: ProfileInitial())));
    expect(find.byType(ShimmerBox), findsOneWidget);

    await tester.pumpWidget(wrap(const ProfileNameText(state: ProfileLoading())));
    expect(find.byType(ShimmerBox), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the real name once the profile is loaded',
      (tester) async {
    await tester.pumpWidget(wrap(
      const ProfileNameText(
        state: ProfileLoaded(ProfileData(fullName: 'أحمد')),
        prefix: 'مرحباً',
      ),
    ));

    expect(find.text('مرحباً أحمد'), findsOneWidget);
    expect(find.byType(ShimmerBox), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows only the fallback when loaded name is empty',
      (tester) async {
    await tester.pumpWidget(wrap(
      const ProfileNameText(
        state: ProfileLoaded(ProfileData()),
        prefix: 'مرحباً',
        emptyFallback: 'حسابي',
      ),
    ));

    expect(find.text('حسابي'), findsOneWidget);
    expect(find.textContaining('مرحباً'), findsNothing);
    expect(find.byType(ShimmerBox), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows error + retry instead of an infinite skeleton',
      (tester) async {
    await tester.pumpWidget(wrap(
      const ProfileNameText(state: ProfileError('boom'), onRetry: _noop),
    ));

    expect(find.byType(ShimmerBox), findsNothing);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('تعذّر تحميل بياناتك الشخصية'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping retry invokes the retry callback', (tester) async {
    var retried = 0;

    await tester.pumpWidget(wrap(
      ProfileNameText(
        state: const ProfileError('boom'),
        onRetry: () => retried++,
      ),
    ));

    await tester.tap(find.text('إعادة المحاولة'));
    expect(retried, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loaded name respects prefix only when a name exists',
      (tester) async {
    await tester.pumpWidget(wrap(
      const ProfileNameText(
        state: ProfileLoaded(ProfileData(fullName: 'سامي')),
      ),
    ));

    expect(find.text('سامي'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

void _noop() {}