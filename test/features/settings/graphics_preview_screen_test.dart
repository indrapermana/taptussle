import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/features/settings/graphics_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('candidate graphics stay unsaved until Apply', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(home: GraphicsPreviewScreen(settings: settings)),
    );
    await tester.pump();

    expect(find.text('Saved settings'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Economy 50%'), 300);
    await tester.tap(find.text('Economy 50%'));
    await tester.pump();
    expect(settings.resolution, ResolutionPreset.native);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('apply-graphics-settings')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('apply-graphics-settings')));
    await tester.pumpAndSettle();
    expect(settings.resolution, ResolutionPreset.economy);
  });
}
