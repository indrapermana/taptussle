import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/app_bootstrap.dart';

void main() {
  testWidgets('shows loading progress before opening the game catalog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final loading = Completer<SharedPreferences>();

    await tester.pumpWidget(
      TapTussleBootstrap(
        minimumDisplayDuration: Duration.zero,
        preferencesLoader: () => loading.future,
      ),
    );

    expect(find.byKey(const ValueKey('startup-progress')), findsOneWidget);
    expect(find.text('LOADING…'), findsOneWidget);

    loading.complete(await SharedPreferences.getInstance());
    await tester.pumpAndSettle();

    expect(find.text('PICK YOUR CHALLENGE'), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-progress')), findsNothing);
  });
}
