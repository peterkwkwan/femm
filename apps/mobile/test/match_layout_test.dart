import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: Petal Soft FilledButton min size must not be infinite-wide
/// inside match upsell Rows (was crashing after "See your match").
void main() {
  testWidgets('FilledButton theme has finite minimum width', (tester) async {
    late Size? minSize;
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: Builder(
          builder: (context) {
            minSize = FilledButtonTheme.of(context).style?.minimumSize
                ?.resolve(const <WidgetState>{});
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(minSize, isNotNull);
    expect(minSize!.width.isFinite, isTrue);
  });

  testWidgets('upsell Book button lays out inside a Row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: Scaffold(
          body: ListView(
            children: [
              Row(
                children: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Book'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Book'), findsOneWidget);
  });
}
