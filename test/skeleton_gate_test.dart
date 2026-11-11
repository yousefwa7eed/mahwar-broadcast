import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/widgets/skeletons.dart';

/// مضيف اختباري بسيط: يشغّل المهمة عند الفتح ويكتب ما يراه المستخدم.
class _Host extends StatefulWidget {
  const _Host(this.task);

  final Future<void> Function() task;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SkeletonGate<_Host> {
  @override
  void initState() {
    super.initState();
    runWithSkeleton(widget.task);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(skeletonVisible ? 'skeleton' : 'content'),
    );
  }
}

void main() {
  testWidgets('الهيكل يظهر للحد الأدنى حتى لو انتهت المهمة فوراً', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _Host(() async {})));
    expect(find.text('skeleton'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('skeleton'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('الهيكل لا يختفي قبل انتهاء المهمة الطويلة', (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: _Host(() => completer.future)));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('skeleton'), findsOneWidget);

    completer.complete();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('إعادة التشغيل (سحب للتحديث) تُظهر الهيكل من جديد', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _Host(() async {})));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('content'), findsOneWidget);

    final state = tester.state<_HostState>(find.byType(_Host));
    state.runWithSkeleton(() async {});
    await tester.pump();
    expect(find.text('skeleton'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
  });
}
