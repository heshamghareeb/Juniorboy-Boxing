import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class StripeService {
  void _log(int step, String title, String details) {
    debugPrint('👉 [STRIPE_DEBUG #$step] $title: $details');
  }

  void _logError(int step, String context, dynamic error, [StackTrace? stack]) {
    debugPrint('❌ [STRIPE_DEBUG_ERROR #$step] $context failed: $error');
    if (error is StripeException) {
      debugPrint('   ├── FailureCode: ${error.error.code}');
      debugPrint('   ├── Message: ${error.error.message}');
      debugPrint('   ├── LocalizedMessage: ${error.error.localizedMessage}');
      debugPrint('   ├── StripeErrorCode: ${error.error.stripeErrorCode}');
      debugPrint('   └── DeclineCode: ${error.error.declineCode}');
    } else if (error is FirebaseFunctionsException) {
      debugPrint('   ├── FunctionsCode: ${error.code}');
      debugPrint('   ├── Message: ${error.message}');
      debugPrint('   └── Details: ${error.details}');
    } else if (error is FirebaseException) {
      debugPrint('   ├── FirebaseCode: ${error.code}');
      debugPrint('   ├── Message: ${error.message}');
      debugPrint('   └── Plugin: ${error.plugin}');
    }
  }

  Future<String> _resolvePublishableKey() async {
    _log(1, 'Fetch Publishable Key', 'Checking environment and Firestore...');
    const configuredKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    if (configuredKey.isNotEmpty) {
      _log(1, 'Fetch Publishable Key', 'Found in environment: ${configuredKey.substring(0, configuredKey.length.clamp(0, 10))}...');
      return configuredKey;
    }

    _log(1, 'Fetch Publishable Key', 'Not in environment; reading gymSettings/config...');
    final settings = await FirebaseFirestore.instance
        .doc('gymSettings/config')
        .get();
    final key = settings.data()?['stripePublishableKey'] as String? ?? '';
    if (key.isNotEmpty) {
      _log(1, 'Fetch Publishable Key', 'Found in Firestore: ${key.substring(0, key.length.clamp(0, 10))}...');
    } else {
      _log(1, 'Fetch Publishable Key', 'KEY IS EMPTY in both environment and Firestore!');
    }
    return key;
  }

  Future<void> _configureStripe(String key) async {
    if (!RegExp(r'^pk_(test|live)_').hasMatch(key)) {
      _logError(1, 'Validate Key Format', 'Invalid key format: "$key" (Must start with pk_test_ or pk_live_)');
      throw const FormatException(
        'Card payments are not configured yet. Contact the gym for a cash or manual payment.',
      );
    }
    _log(1, 'Apply Settings', 'Applying Stripe publishable key to SDK...');
    Stripe.publishableKey = key;
    await Stripe.instance.applySettings();
    _log(1, 'Apply Settings', 'Stripe SDK initialized successfully.');
  }

  Future<String> purchase(String planId) async {
    _log(0, 'Purchase Flow Started', 'Initiating purchase for planId: $planId');
    try {
      final key = await _resolvePublishableKey();
      await _configureStripe(key);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _logError(2, 'Auth Check', 'No logged in user found in FirebaseAuth!');
        throw const FormatException('User is not authenticated.');
      }
      final uid = currentUser.uid;
      _log(2, 'Auth & Idempotency', 'User UID: $uid');

      final attemptKey = 'checkout:$uid:$planId';
      final box = Hive.box('jbb_device');
      final requestId = box.get(attemptKey) as String? ?? const Uuid().v4();
      await box.put(attemptKey, requestId);
      _log(2, 'Auth & Idempotency', 'Attempt key: $attemptKey | RequestId: $requestId');

      _log(3, 'Cloud Function Call', 'Calling createPaymentIntent with {planId: $planId, requestId: $requestId}...');
      dynamic data;
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('createPaymentIntent')
            .call({'planId': planId, 'requestId': requestId});
        data = result.data;
        _log(3, 'Cloud Function Call', 'Response received: $data');
      } on FirebaseFunctionsException catch (e) {
        _logError(3, 'createPaymentIntent', e);
        await box.delete(attemptKey);
        rethrow;
      } catch (e, st) {
        _logError(3, 'createPaymentIntent unexpected', e, st);
        await box.delete(attemptKey);
        rethrow;
      }

      final status = data['status'] as String? ?? 'unknown';
      _log(4, 'Inspect Payment Status', 'Status from backend: $status');

      if (['completed', 'refunded', 'canceled'].contains(status)) {
        await box.delete(attemptKey);
        _log(4, 'Inspect Payment Status', 'Terminal status ($status) -> cleared attempt key');
        return status == 'completed'
            ? 'Payment confirmed. Your credits have been added. To buy another pack, tap Continue again.'
            : 'The previous order was $status. You can start a new purchase.';
      }
      if ([
        'succeeded',
        'processing',
        'requires_capture',
        'refund_pending',
      ].contains(status)) {
        _log(4, 'Inspect Payment Status', 'Pending confirmation status: $status');
        return 'Payment is still being confirmed. Check Payments before purchasing again.';
      }

      final secret = data['clientSecret'] as String?;
      if (secret == null || secret.isEmpty) {
        _logError(5, 'Validate ClientSecret', 'clientSecret is missing or empty in backend response!');
        throw const FormatException('Payment is not available for this order.');
      }
      _log(5, 'Validate ClientSecret', 'ClientSecret present: ${secret.substring(0, secret.length.clamp(0, 15))}...');

      _log(6, 'Init PaymentSheet', 'Initializing PaymentSheet with clientSecret...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: secret,
          merchantDisplayName: 'Junior Boy Boxing',
          style: ThemeMode.dark,
        ),
      );
      _log(6, 'Init PaymentSheet', 'PaymentSheet initialized successfully.');

      _log(7, 'Present PaymentSheet', 'Presenting PaymentSheet to user...');
      try {
        await Stripe.instance.presentPaymentSheet();
        _log(7, 'Present PaymentSheet', 'PaymentSheet completed successfully by user.');
      } on StripeException catch (e) {
        _logError(7, 'presentPaymentSheet', e);
        if (e.error.code == FailureCode.Canceled) {
          _log(7, 'Present PaymentSheet', 'PaymentSheet was canceled / dismissed by user.');
          return 'Payment sheet closed. Check Payments if you submitted a payment.';
        }
        rethrow;
      }

      final paymentId = data['paymentId'];
      _log(8, 'Verify Firestore Payment', 'Querying payments/$paymentId...');
      final payment = await FirebaseFirestore.instance
          .doc('payments/$paymentId')
          .get();
      final finalStatus = payment.data()?['status'];
      _log(8, 'Verify Firestore Payment', 'Firestore payment record status: $finalStatus');

      if (finalStatus == 'completed') {
        _log(9, 'Purchase Flow Finished', 'Payment confirmed! Credits added.');
        return 'Payment confirmed. Your session credits have been added.';
      }
      _log(9, 'Purchase Flow Finished', 'Payment submitted but waiting on webhook/confirmation.');
      return 'Payment submitted. Check Payments for confirmation; do not pay again while pending.';
    } catch (e, st) {
      _logError(99, 'Purchase Flow Failed', e, st);
      rethrow;
    }
  }

  Future<String> joinSession(String sessionId, {String? timeSlot}) async {
    _log(0, 'Join Session Flow Started', 'sessionId: $sessionId | timeSlot: $timeSlot');
    try {
      final key = await _resolvePublishableKey();
      await _configureStripe(key);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _logError(2, 'Auth Check', 'No logged in user found in FirebaseAuth!');
        throw const FormatException('User is not authenticated.');
      }
      final uid = currentUser.uid;
      _log(2, 'Auth & Idempotency', 'User UID: $uid');

      final attemptKey = 'checkout_session:$uid:$sessionId${timeSlot != null ? ':$timeSlot' : ''}';
      final box = Hive.box('jbb_device');
      final requestId = box.get(attemptKey) as String? ?? const Uuid().v4();
      await box.put(attemptKey, requestId);
      _log(2, 'Auth & Idempotency', 'Attempt key: $attemptKey | RequestId: $requestId');

      _log(3, 'Cloud Function Call', 'Calling joinSession with {sessionId: $sessionId, requestId: $requestId, timeSlot: $timeSlot}...');
      dynamic data;
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('joinSession')
            .call({
              'sessionId': sessionId,
              'requestId': requestId,
              if (timeSlot != null && timeSlot.isNotEmpty) 'timeSlot': timeSlot,
            });
        data = result.data;
        _log(3, 'Cloud Function Call', 'Response received: $data');
      } on FirebaseFunctionsException catch (e) {
        _logError(3, 'joinSession', e);
        await box.delete(attemptKey);
        rethrow;
      } catch (e, st) {
        _logError(3, 'joinSession unexpected', e, st);
        await box.delete(attemptKey);
        rethrow;
      }

      final status = data['status'] as String? ?? 'unknown';
      _log(4, 'Inspect Payment Status', 'Status from backend: $status');

      if (['completed', 'refunded', 'canceled'].contains(status)) {
        await box.delete(attemptKey);
        _log(4, 'Inspect Payment Status', 'Terminal status ($status) -> cleared attempt key');
        return status == 'completed'
            ? "You're in! Payment confirmed."
            : 'The previous attempt was $status. You can try joining again.';
      }
      if ([
        'succeeded',
        'processing',
        'requires_capture',
        'refund_pending',
      ].contains(status)) {
        _log(4, 'Inspect Payment Status', 'Pending confirmation status: $status');
        return 'Payment is still being confirmed. Check Payments before trying again.';
      }

      final secret = data['clientSecret'] as String?;
      if (secret == null || secret.isEmpty) {
        _logError(5, 'Validate ClientSecret', 'clientSecret is missing or empty in backend response!');
        throw const FormatException('This session is not available to join.');
      }
      _log(5, 'Validate ClientSecret', 'ClientSecret present: ${secret.substring(0, secret.length.clamp(0, 15))}...');

      _log(6, 'Init PaymentSheet', 'Initializing PaymentSheet with clientSecret...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: secret,
          merchantDisplayName: 'Junior Boy Boxing',
          style: ThemeMode.dark,
        ),
      );
      _log(6, 'Init PaymentSheet', 'PaymentSheet initialized successfully.');

      _log(7, 'Present PaymentSheet', 'Presenting PaymentSheet to user...');
      try {
        await Stripe.instance.presentPaymentSheet();
        _log(7, 'Present PaymentSheet', 'PaymentSheet completed successfully by user.');
      } on StripeException catch (e) {
        _logError(7, 'presentPaymentSheet', e);
        if (e.error.code == FailureCode.Canceled) {
          _log(7, 'Present PaymentSheet', 'PaymentSheet was canceled / dismissed by user.');
          return 'Payment sheet closed. Check Payments if you submitted a payment.';
        }
        rethrow;
      }

      final paymentId = data['paymentId'];
      _log(8, 'Verify Firestore Payment', 'Querying payments/$paymentId...');
      final payment = await FirebaseFirestore.instance
          .doc('payments/$paymentId')
          .get();
      final finalStatus = payment.data()?['status'];
      _log(8, 'Verify Firestore Payment', 'Firestore payment record status: $finalStatus');

      if (finalStatus == 'completed') {
        _log(9, 'Join Session Finished', 'Payment confirmed! Enrolled in session.');
        return "You're in! Payment confirmed.";
      }
      _log(9, 'Join Session Finished', 'Payment submitted but waiting on webhook/confirmation.');
      return 'Payment submitted. Check Payments for confirmation; do not pay again while pending.';
    } catch (e, st) {
      _logError(99, 'Join Session Flow Failed', e, st);
      rethrow;
    }
  }

  Future<String> purchaseProduct(String productId, {String? size}) async {
    _log(0, 'Purchase Product Started', 'productId: $productId | size: $size');
    try {
      final key = await _resolvePublishableKey();
      await _configureStripe(key);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _logError(2, 'Auth Check', 'No logged in user found in FirebaseAuth!');
        throw const FormatException('User is not authenticated.');
      }
      final uid = currentUser.uid;
      _log(2, 'Auth & Idempotency', 'User UID: $uid');

      final attemptKey = 'checkout_product:$uid:$productId:${size ?? ''}';
      final box = Hive.box('jbb_device');
      final requestId = box.get(attemptKey) as String? ?? const Uuid().v4();
      await box.put(attemptKey, requestId);
      _log(2, 'Auth & Idempotency', 'Attempt key: $attemptKey | RequestId: $requestId');

      _log(3, 'Cloud Function Call', 'Calling createProductPaymentIntent with {productId: $productId, requestId: $requestId, size: $size}...');
      dynamic data;
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('createProductPaymentIntent')
            .call({
              'productId': productId,
              'requestId': requestId,
              if (size != null && size.isNotEmpty) 'size': size,
            });
        data = result.data;
        _log(3, 'Cloud Function Call', 'Response received: $data');
      } on FirebaseFunctionsException catch (e) {
        _logError(3, 'createProductPaymentIntent', e);
        await box.delete(attemptKey);
        rethrow;
      } catch (e, st) {
        _logError(3, 'createProductPaymentIntent unexpected', e, st);
        await box.delete(attemptKey);
        rethrow;
      }

      final status = data['status'] as String? ?? 'unknown';
      _log(4, 'Inspect Payment Status', 'Status from backend: $status');

      if (['completed', 'refunded', 'canceled'].contains(status)) {
        await box.delete(attemptKey);
        _log(4, 'Inspect Payment Status', 'Terminal status ($status) -> cleared attempt key');
        return status == 'completed'
            ? 'Order confirmed. Pick it up at the gym. To buy another, tap Buy Now again.'
            : 'The previous order was $status. You can order again.';
      }
      if ([
        'succeeded',
        'processing',
        'requires_capture',
        'refund_pending',
      ].contains(status)) {
        _log(4, 'Inspect Payment Status', 'Pending confirmation status: $status');
        return 'Payment is still being confirmed. Check Payments before ordering again.';
      }

      final secret = data['clientSecret'] as String?;
      if (secret == null || secret.isEmpty) {
        _logError(5, 'Validate ClientSecret', 'clientSecret is missing or empty in backend response!');
        throw const FormatException('This item is not available for purchase.');
      }
      _log(5, 'Validate ClientSecret', 'ClientSecret present: ${secret.substring(0, secret.length.clamp(0, 15))}...');

      _log(6, 'Init PaymentSheet', 'Initializing PaymentSheet with clientSecret...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: secret,
          merchantDisplayName: 'Junior Boy Boxing',
          style: ThemeMode.dark,
        ),
      );
      _log(6, 'Init PaymentSheet', 'PaymentSheet initialized successfully.');

      _log(7, 'Present PaymentSheet', 'Presenting PaymentSheet to user...');
      try {
        await Stripe.instance.presentPaymentSheet();
        _log(7, 'Present PaymentSheet', 'PaymentSheet completed successfully by user.');
      } on StripeException catch (e) {
        _logError(7, 'presentPaymentSheet', e);
        if (e.error.code == FailureCode.Canceled) {
          _log(7, 'Present PaymentSheet', 'PaymentSheet was canceled / dismissed by user.');
          return 'Payment sheet closed. Check Payments if you submitted a payment.';
        }
        rethrow;
      }

      final paymentId = data['paymentId'];
      _log(8, 'Verify Firestore Payment', 'Querying payments/$paymentId...');
      final payment = await FirebaseFirestore.instance
          .doc('payments/$paymentId')
          .get();
      final finalStatus = payment.data()?['status'];
      _log(8, 'Verify Firestore Payment', 'Firestore payment record status: $finalStatus');

      if (finalStatus == 'completed') {
        _log(9, 'Purchase Product Finished', 'Order confirmed! Pick it up at the gym.');
        return 'Order confirmed. Pick it up at the gym.';
      }
      _log(9, 'Purchase Product Finished', 'Payment submitted but waiting on webhook/confirmation.');
      return 'Payment submitted. Check Payments for confirmation; do not pay again while pending.';
    } catch (e, st) {
      _logError(99, 'Purchase Product Flow Failed', e, st);
      rethrow;
    }
  }
}
