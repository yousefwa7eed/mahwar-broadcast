// السكيليتون (بنود 4): صفحات الإشعارات والطلبات ترسم هياكل شيمر أثناء
// التحميل الأول بدل مؤشر دوّار. لا نستخدم pumpAndSettle لأن الشيمر متحرك دائمًا.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/widgets/shimmer_box.dart';
import 'package:mahwar/core/widgets/skeletons.dart';

void main() {
  testWidgets('سكيليتون الإشعارات: 4 هياكل شيمر لكل عنصر وبلا مؤشر تحميل', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NotificationListSkeleton(items: 3)),
      ),
    );
    await tester.pump();

    expect(find.byType(ShimmerBox), findsNWidgets(3 * 4));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('سكيليتون الطلبات: 4 هياكل شيمر لكل عنصر وبلا مؤشر تحميل', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OrderListSkeleton(items: 2))),
    );
    await tester.pump();

    expect(find.byType(ShimmerBox), findsNWidgets(2 * 4));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('السكيليتون مخفي عن قارئ الشاشة (ExcludeSemantics)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NotificationListSkeleton(items: 1)),
      ),
    );
    await tester.pump();

    expect(find.byType(ExcludeSemantics), findsWidgets);
  });
}
