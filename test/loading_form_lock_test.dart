import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/widgets/loading_form_lock.dart';

void main() {
  testWidgets('أثناء التحميل يُمنع اللمس وتخفت المحتويات', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingFormLock(
            loading: true,
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('إرسال'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final absorb = tester.widget<AbsorbPointer>(
      find.descendant(
        of: find.byType(LoadingFormLock),
        matching: find.byType(AbsorbPointer),
      ),
    );
    expect(absorb.absorbing, isTrue);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0.55,
    );

    await tester.tap(find.text('إرسال'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('بعد انتهاء التحميل يعود اللمس', (tester) async {
    var taps = 0;
    var loading = true;
    late StateSetter setLoading;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setLoading = setState;
              return LoadingFormLock(
                loading: loading,
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('إرسال'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    setLoading(() => loading = false);
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1.0,
    );

    await tester.tap(find.text('إرسال'));
    expect(taps, 1);
  });
}
