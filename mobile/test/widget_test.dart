import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junior_boy_boxing/core/utils/validators.dart';
import 'package:junior_boy_boxing/core/theme/app_theme.dart';
import 'package:junior_boy_boxing/features/auth/presentation/screens/welcome_screen.dart';

void main() {
  test('registration rejects malformed email and short password', () {
    expect(Validators.email('bad'), isNotNull);
    expect(Validators.email('parent@example.com'), isNull);
    expect(Validators.password('123'), isNotNull);
    expect(Validators.age('-1'), isNotNull);
  });
  testWidgets('welcome remains usable on a small screen', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: lightTheme, home: const WelcomeScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('welcome shows Continue with Apple on iOS', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme.copyWith(platform: TargetPlatform.iOS),
        home: const WelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
