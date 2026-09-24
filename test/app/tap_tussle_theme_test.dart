import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';

void main() {
  test('uses Fredoka for interface text and Lilita One for display text', () {
    final theme = buildTapTussleTheme();

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Fredoka');
    expect(theme.textTheme.displayLarge?.fontFamily, 'Lilita One');
    expect(theme.textTheme.headlineMedium?.fontFamily, 'Lilita One');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Lilita One');
    expect(
      theme.filledButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
      'Lilita One',
    );
  });

  testWidgets('branded backdrop and arcade panel compose without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: const Scaffold(
          body: TapTussleBackdrop(
            child: Center(
              child: ArcadePanel(
                key: ValueKey('arcade-panel'),
                accent: TapTussleColors.gold,
                child: Text('Ready'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('arcade-panel')), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
