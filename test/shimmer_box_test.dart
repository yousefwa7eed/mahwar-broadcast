import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/widgets/shimmer_box.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('renders a rectangle skeleton in light theme without errors',
      (tester) async {
    await tester.pumpWidget(wrap(const ShimmerBox(width: 120, height: 20)));

    expect(find.byType(ShimmerBox), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byType(ShimmerBox), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders a rectangle skeleton in dark theme without errors',
      (tester) async {
    await tester.pumpWidget(wrap(
      const ShimmerBox(width: 120, height: 20),
      brightness: Brightness.dark,
    ));

    expect(find.byType(ShimmerBox), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byType(ShimmerBox), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders a circular skeleton for avatars', (tester) async {
    await tester.pumpWidget(wrap(const ShimmerBox(width: 44, height: 44, circle: true)));

    expect(find.byType(ShimmerBox), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fills available space when no size is given', (tester) async {
    await tester.pumpWidget(wrap(const ShimmerBox()));

    final box = tester.widget<ShimmerBox>(find.byType(ShimmerBox));
    expect(box.width, isNull);
    expect(box.height, isNull);

    await tester.pumpWidget(const SizedBox());
  });
}