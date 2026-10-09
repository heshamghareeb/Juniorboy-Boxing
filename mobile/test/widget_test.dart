import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junior_boy_boxing/core/utils/validators.dart';
import 'package:junior_boy_boxing/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:junior_boy_boxing/features/auth/presentation/screens/welcome_screen.dart';
import 'package:junior_boy_boxing/features/profile/presentation/screens/my_bookings_screen.dart';
import 'package:junior_boy_boxing/features/payments/presentation/providers/payments_provider.dart';
import 'package:junior_boy_boxing/features/payments/domain/payment.dart';
import 'package:junior_boy_boxing/features/booking/presentation/providers/booking_provider.dart';
import 'package:junior_boy_boxing/features/sessions/presentation/providers/session_provider.dart';
import 'package:junior_boy_boxing/features/auth/presentation/providers/auth_provider.dart';
import 'package:junior_boy_boxing/features/auth/domain/auth_account.dart';

import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  tz_data.initializeTimeZones();
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
  testWidgets('my bookings displays store orders when available', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final samplePayment = Payment(
      id: 'pay-1',
      userId: 'user-1',
      productId: 'prod-glove',
      productName: 'Pro Boxing Gloves',
      size: '16oz',
      amount: 6500,
      status: 'completed',
      paymentMethod: 'card',
      createdAt: DateTime(2026, 10, 1),
      estimatedDeliveryDate: DateTime(2026, 10, 15),
      deliveryNote: 'Pick up at gym front desk',
      membershipPlanId: null,
      credits: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => Stream.value(
              const AuthAccount(
                uid: 'user-1',
                email: 'user@test.com',
                isAnonymous: false,
                hasGoogleProvider: false,
                hasAppleProvider: false,
              ),
            ),
          ),
          paymentsProvider.overrideWith((ref) => Stream.value([samplePayment])),
          bookingsProvider.overrideWith((ref) => Stream.value([])),
          sessionsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(theme: darkTheme, home: const MyBookingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Store Orders'), findsOneWidget);
    expect(find.text('Pro Boxing Gloves'), findsOneWidget);
    expect(find.text('Size: 16oz'), findsOneWidget);
    expect(find.text('\$65.00'), findsOneWidget);
    expect(find.textContaining('Oct 15'), findsOneWidget);
    expect(find.text('Pick up at gym front desk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
