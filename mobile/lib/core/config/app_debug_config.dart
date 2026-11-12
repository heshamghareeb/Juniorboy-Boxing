/// Central control for debug logs across the app.
/// Change any value from `false` to `true` whenever you want to re-enable logging in the console.
abstract final class AppDebugConfig {
  /// Toggle for Stripe checkout & PaymentSheet logs ([STRIPE_DEBUG])
  static const bool enableStripeLogs = true;

  /// Toggle for My Bookings screen state logs ([MY_BOOKINGS DEBUG])
  static const bool enableBookingsLogs = true;

  /// Toggle for Delete Account flow logs ([DELETE_ACCOUNT_DEBUG])
  static const bool enableDeleteAccountLogs = true;

  /// Toggle for Auth & Login flow logs ([LOGIN_DEBUG])
  static const bool enableAuthLoginLogs = true;
}

