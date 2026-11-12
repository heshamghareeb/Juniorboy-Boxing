import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/config/app_debug_config.dart';
import '../../../core/services/notification_service.dart';

class AuthRemoteDataSource {
  final auth = FirebaseAuth.instance;

  Stream<User?> userChanges() => auth.userChanges();
  User? get currentUser => auth.currentUser;

  // google_sign_in 7.x's Credential Manager flow on Android has a known,
  // reproducible regression (flutter/flutter#187395) where the account
  // picker silently fails to render and the call throws
  // GoogleSignInExceptionCode.canceled / "Account reauth failed". Staying
  // on the pre-7.0 API sidesteps Credential Manager entirely.
  final _googleSignIn = GoogleSignIn(
    serverClientId: const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue:
          '772438105367-q284tguvctru8ltf50np6nfck80rhmf3.apps.googleusercontent.com',
    ),
  );

  Future<void> initializeProfile() async {
    _logLogin('#6a [Profile] Calling Cloud Function initializeProfile...');
    await FirebaseFunctions.instance.httpsCallable('initializeProfile').call();
    _logLogin('#6b [Profile] Cloud Function initializeProfile finished successfully!');
  }

  Future<void> googleSignIn() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    if (auth.currentUser?.isAnonymous == true) {
      try {
        await auth.currentUser?.delete();
      } catch (_) {}
    }
    await auth.signInWithCredential(credential);
    if (Hive.isBoxOpen('jbb_cache')) {
      await Hive.box('jbb_cache').delete('is_guest_mode');
    }
    await initializeProfile();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  Future<void> appleSignIn() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      rethrow;
    }

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final givenName = appleCredential.givenName?.trim() ?? '';
    final familyName = appleCredential.familyName?.trim() ?? '';
    final fullName = [
      givenName,
      familyName,
    ].where((s) => s.isNotEmpty).join(' ').trim();

    if (auth.currentUser?.isAnonymous == true) {
      try {
        await auth.currentUser?.delete();
      } catch (_) {}
    }
    await auth.signInWithCredential(credential);
    if (Hive.isBoxOpen('jbb_cache')) {
      await Hive.box('jbb_cache').delete('is_guest_mode');
    }

    await initializeProfile();

    if (fullName.isNotEmpty && auth.currentUser != null) {
      await auth.currentUser!.updateDisplayName(fullName);
      try {
        await FirebaseFirestore.instance
            .doc('users/${auth.currentUser!.uid}')
            .set({
              'fullName': fullName,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    _logLogin('#2 [SignIn] Starting signInWithEmail for: $cleanEmail');
    if (auth.currentUser?.isAnonymous == true) {
      _logLogin('#2a [SignIn] Anonymous user detected, deleting anonymous session...');
      try {
        await auth.currentUser?.delete();
        _logLogin('#2b [SignIn] Anonymous user deleted.');
      } catch (e) {
        _logLoginError('#2 [SignIn] Non-fatal error deleting anonymous user: $e');
      }
    }
    _logLogin('#3 [SignIn] Calling auth.signInWithEmailAndPassword...');
    final userCredential = await auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
    _logLogin('#4 [SignIn] Firebase Auth success! UID=${userCredential.user?.uid} | email=${userCredential.user?.email}');
    if (Hive.isBoxOpen('jbb_cache')) {
      _logLogin('#5 [SignIn] Clearing is_guest_mode from Hive cache...');
      await Hive.box('jbb_cache').delete('is_guest_mode');
    }
    _logLogin('#6 [SignIn] Calling initializeProfile Firebase Function (with 10s timeout)...');
    try {
      await initializeProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logLoginError('#6 [SignIn] initializeProfile timed out after 10s! Continuing...');
        },
      );
      _logLogin('#7 [SignIn] initializeProfile finished successfully!');
    } catch (e) {
      _logLoginError('#6 [SignIn] initializeProfile threw error (non-fatal): $e');
    }
    _logLogin('#8 [SignIn] signInWithEmail complete! ✅');
  }

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = fullName?.trim() ?? '';
    _logLogin('#2 [SignUp] Starting signUpWithEmail for: $cleanEmail, name: $cleanName');
    if (auth.currentUser?.isAnonymous == true) {
      _logLogin('#2a [SignUp] Anonymous user detected, deleting anonymous session...');
      try {
        await auth.currentUser?.delete();
        _logLogin('#2b [SignUp] Anonymous user deleted.');
      } catch (e) {
        _logLoginError('#2 [SignUp] Non-fatal error deleting anonymous user: $e');
      }
    }
    _logLogin('#3 [SignUp] Calling auth.createUserWithEmailAndPassword...');
    final credential = await auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
    _logLogin('#4 [SignUp] User created successfully! UID=${credential.user?.uid}');
    if (Hive.isBoxOpen('jbb_cache')) {
      _logLogin('#5 [SignUp] Clearing is_guest_mode from Hive cache...');
      await Hive.box('jbb_cache').delete('is_guest_mode');
    }
    if (cleanName.isNotEmpty && credential.user != null) {
      _logLogin('#5a [SignUp] Updating displayName: $cleanName');
      await credential.user!.updateDisplayName(cleanName);
      try {
        _logLogin('#5b [SignUp] Saving user profile to Firestore users/${credential.user!.uid}');
        await FirebaseFirestore.instance
            .doc('users/${credential.user!.uid}')
            .set({
              'fullName': cleanName,
              'email': cleanEmail,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        _logLogin('#5c [SignUp] Profile saved to Firestore.');
      } catch (e) {
        _logLoginError('#5 [SignUp] Non-fatal error saving profile to Firestore: $e');
      }
    }
    _logLogin('#6 [SignUp] Calling initializeProfile Firebase Function (with 10s timeout)...');
    try {
      await initializeProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logLoginError('#6 [SignUp] initializeProfile timed out after 10s! Continuing...');
        },
      );
      _logLogin('#7 [SignUp] initializeProfile finished successfully!');
    } catch (e) {
      _logLoginError('#6 [SignUp] initializeProfile threw error (non-fatal): $e');
    }
    _logLogin('#8 [SignUp] signUpWithEmail complete! ✅');
  }

  Future<void> sendPasswordReset(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  bool get isGuest {
    try {
      if (!Hive.isBoxOpen('jbb_cache')) return false;
      return Hive.box('jbb_cache').get('is_guest_mode', defaultValue: false) ==
              true &&
          auth.currentUser == null;
    } catch (_) {
      return false;
    }
  }

  Future<void> continueAsGuest() async {
    if (auth.currentUser != null) {
      if (auth.currentUser!.isAnonymous) {
        try {
          await auth.currentUser!.delete();
        } catch (_) {
          await auth.signOut();
        }
      } else {
        await auth.signOut();
      }
    }
    if (Hive.isBoxOpen('jbb_cache')) {
      await Hive.box('jbb_cache').put('is_guest_mode', true);
    }
  }

  Future<void> signOut() async {
    try {
      await NotificationService.instance.unregister();
    } catch (_) {
      // Signing out must remain available when the device is offline.
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    if (auth.currentUser?.isAnonymous == true) {
      try {
        await auth.currentUser?.delete();
      } catch (_) {}
    }
    await auth.signOut();
    if (Hive.isBoxOpen('jbb_cache')) {
      final rememberedEmail = Hive.box('jbb_cache').get('remembered_email');
      await Hive.box('jbb_cache').clear();
      if (rememberedEmail != null) {
        await Hive.box('jbb_cache').put('remembered_email', rememberedEmail);
        _logLogin('Preserved remembered_email across signOut: $rememberedEmail');
      }
    }
  }

  void _logDelete(String message) {
    if (AppDebugConfig.enableDeleteAccountLogs) {
      debugPrint('👉 [DELETE_ACCOUNT_DEBUG] $message');
    }
  }

  void _logDeleteError(String message) {
    if (AppDebugConfig.enableDeleteAccountLogs) {
      debugPrint('❌ [DELETE_ACCOUNT_DEBUG_ERROR] $message');
    }
  }

  void _logLogin(String message) {
    if (AppDebugConfig.enableAuthLoginLogs) {
      debugPrint('👉 [LOGIN_DEBUG] $message');
    }
  }

  void _logLoginError(String message) {
    if (AppDebugConfig.enableAuthLoginLogs) {
      debugPrint('❌ [LOGIN_DEBUG_ERROR] $message');
    }
  }

  Future<void> deleteAccount({String? password}) async {
    final user = auth.currentUser;
    if (user == null) {
      _logDeleteError('#1 User is null in FirebaseAuth! Cannot proceed with deletion.');
      return;
    }

    final providers = user.providerData.map((p) => p.providerId).toList();
    _logDelete(
      '#1 User found: UID=${user.uid} | Email=${user.email ?? "none"} | isAnonymous=${user.isAnonymous} | Providers=$providers',
    );

    final isPassword = providers.contains('password');
    final isApple = providers.contains('apple.com');
    final isGoogle = providers.contains('google.com');

    if (isPassword && password != null && password.isNotEmpty && user.email != null) {
      _logDelete('#1a [Password] Re-authenticating user with provided password...');
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        _logDelete('#1b [Password] Re-authentication successful!');
      } on FirebaseAuthException catch (e) {
        _logDeleteError('#1 [Password] Re-authentication failed: code=${e.code} | message=${e.message}');
        rethrow;
      }
    }

    if (isApple) {
      _logDelete('#2 [Apple] Apple Sign-In detected. Requesting authorization credential for token revocation...');
      try {
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [],
        );
        final authCode = appleCredential.authorizationCode;
        if (authCode.isNotEmpty) {
          _logDelete('#2a [Apple] Revoking Apple token via revokeTokenWithAuthorizationCode...');
          await auth.revokeTokenWithAuthorizationCode(authCode);
          _logDelete('#2b [Apple] Apple token successfully revoked.');
        } else {
          _logDelete('#2a [Apple] Warning: authCode is empty, skipping token revocation.');
        }
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          _logDelete('#2 [Apple] User canceled Apple authorization dialog.');
          return;
        }
        _logDeleteError('#2 [Apple] SignInWithAppleAuthorizationException: code=${e.code} | message=${e.message}');
        rethrow;
      } catch (e) {
        _logDeleteError('#2 [Apple] Failed to revoke Apple token: $e');
        rethrow;
      }
    } else {
      _logDelete('#2 [Apple] Not an Apple account.');
    }

    if (isGoogle) {
      _logDelete('#3 [Google] Google Sign-In detected. Signing out of Google SDK...');
      try {
        await _googleSignIn.signOut();
        _logDelete('#3a [Google] Successfully signed out of Google SDK.');
      } catch (e) {
        _logDeleteError('#3 [Google] Non-fatal error signing out of Google SDK: $e');
      }
    } else {
      _logDelete('#3 [Google] Not a Google account.');
    }

    _logDelete('#4 Unregistering push notifications (FCM / APNS)...');
    try {
      await NotificationService.instance.unregister();
      _logDelete('#4a Push notifications unregistered successfully.');
    } catch (e) {
      _logDeleteError('#4 [Push] Non-fatal error unregistering notifications: $e');
    }

    _logDelete('#4b Anonymizing user profile in Firestore (users/${user.uid})...');
    try {
      await FirebaseFirestore.instance.doc('users/${user.uid}').set({
        'status': 'deleted',
        'isActive': false,
        'fullName': 'Deleted User',
        'email': '',
        'phoneNumber': '',
        'photoUrl': null,
        'fcmToken': null,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _logDelete('#4c User profile anonymized in Firestore successfully.');
    } catch (e) {
      _logDeleteError('#4b Non-fatal error anonymizing Firestore profile: $e');
    }

    _logDelete('#5 Deleting user from Firebase Authentication (await user.delete())...');
    try {
      await user.delete();
      _logDelete('#5a Firebase Authentication user deleted successfully!');
    } on FirebaseAuthException catch (e) {
      _logDeleteError('#5 FirebaseAuthException on user.delete(): code=${e.code} | message=${e.message}');
      if (e.code == 'requires-recent-login') {
        _logDeleteError(
          '#5 [CRITICAL] Firebase requires recent login before account deletion! Attempting provider re-authentication...',
        );
        if (isApple) {
          try {
            await user.reauthenticateWithProvider(AppleAuthProvider());
            _logDelete('#5 [Apple] Re-authenticated! Retrying user.delete()...');
            await user.delete();
            _logDelete('#5a Firebase Authentication user deleted successfully after Apple re-authentication!');
          } catch (reauthError) {
            _logDeleteError('#5 [Apple] Re-authentication failed: $reauthError');
            rethrow;
          }
        } else if (isGoogle) {
          try {
            await _googleSignIn.signOut();
            final googleUser = await _googleSignIn.signIn();
            if (googleUser != null) {
              final googleAuth = await googleUser.authentication;
              final cred = GoogleAuthProvider.credential(
                idToken: googleAuth.idToken,
                accessToken: googleAuth.accessToken,
              );
              await user.reauthenticateWithCredential(cred);
              _logDelete('#5 [Google] Re-authenticated! Retrying user.delete()...');
              await user.delete();
              _logDelete('#5a Firebase Authentication user deleted successfully after Google re-authentication!');
            } else {
              _logDelete('#5 [Google] User canceled Google re-authentication.');
              return;
            }
          } catch (reauthError) {
            _logDeleteError('#5 [Google] Re-authentication failed: $reauthError');
            rethrow;
          }
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    } catch (e) {
      _logDeleteError('#5 user.delete() failed with unexpected error: $e');
      rethrow;
    }

    _logDelete('#6 Clearing local cache (Hive)...');
    try {
      if (Hive.isBoxOpen('jbb_cache')) {
        await Hive.box('jbb_cache').clear();
      }
      _logDelete('#6a Local cache cleared.');
    } catch (e) {
      _logDeleteError('#6 Non-fatal error clearing Hive cache: $e');
    }

    _logDelete('#7 Account deletion flow completed 100% successfully! ✅');
  }
}
