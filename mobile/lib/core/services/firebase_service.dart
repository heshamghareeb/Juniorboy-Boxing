import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import '../../firebase_options.dart';

abstract final class FirebaseService {
  static const useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  static const host = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: useEmulators
            ? const FirebaseOptions(apiKey:'demo-api-key',appId:'1:123456789:android:demo',messagingSenderId:'123456789',projectId:'demo-jbb',storageBucket:'demo-jbb.appspot.com')
            : DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    if (useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    } else {
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleDeviceCheckProvider(),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firebase App Check activation skipped or non-fatal: $e');
      }
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      bool isPermissionDenied(Object? error) {
        if (error == null) return false;
        if (error is FirebaseException && error.code == 'permission-denied') {
          return true;
        }
        final s = error.toString().toLowerCase();
        return s.contains('permission-denied') ||
            s.contains('insufficient permissions');
      }

      FlutterError.onError = (details) {
        if (isPermissionDenied(details.exception)) {
          return;
        }
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (isPermissionDenied(error)) {
          return true;
        }
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        !kDebugMode,
      );
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        !kDebugMode,
      );
    }
  }
}
