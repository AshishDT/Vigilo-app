import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/views/no_lock_screen.dart';
import 'package:vigilo/views/widgets/security_privacy_shield.dart';

void main() {
  testWidgets('SecurityPrivacyShield has change theme button in AppBar actions', (WidgetTester tester) async {
    bool themeToggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SecurityPrivacyShield(
          dark: false,
          onToggleTheme: () => themeToggled = true,
          onUnlockPressed: () {},
        ),
      ),
    );
    await tester.pump();

    final appBarFinder = find.byType(AppBar);
    expect(appBarFinder, findsOneWidget);

    final themeIconFinder = find.descendant(
      of: appBarFinder,
      matching: find.byIcon(Icons.dark_mode_outlined),
    );
    expect(themeIconFinder, findsOneWidget);

    await tester.tap(themeIconFinder);
    expect(themeToggled, isTrue);
  });

  testWidgets('NoLockScreen has change theme button in AppBar actions', (WidgetTester tester) async {
    bool themeToggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: NoLockScreen(
          dark: true,
          onToggleTheme: () => themeToggled = true,
          onLockDetected: () {},
        ),
      ),
    );
    await tester.pump();

    final appBarFinder = find.byType(AppBar);
    expect(appBarFinder, findsOneWidget);

    final themeIconFinder = find.descendant(
      of: appBarFinder,
      matching: find.byIcon(Icons.wb_sunny_outlined),
    );
    expect(themeIconFinder, findsOneWidget);

    await tester.tap(themeIconFinder);
    expect(themeToggled, isTrue);
  });
}
