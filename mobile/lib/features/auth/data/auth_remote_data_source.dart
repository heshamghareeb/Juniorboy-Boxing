import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
    await FirebaseFunctions.instance.httpsCallable('initializeProfile').call();
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
        await auth.currentUser!.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use') rethrow;
        await auth.signInWithCredential(credential);
      }
    } else {
      await auth.signInWithCredential(credential);
    }
    await initializeProfile();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
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
    final fullName = [givenName, familyName]
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();

    if (auth.currentUser?.isAnonymous == true) {
      try {
        await auth.currentUser!.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use') rethrow;
        await auth.signInWithCredential(credential);
      }
    } else {
      await auth.signInWithCredential(credential);
    }

    await initializeProfile();

    if (fullName.isNotEmpty && auth.currentUser != null) {
      await auth.currentUser!.updateDisplayName(fullName);
      try {
        await FirebaseFirestore.instance
            .doc('users/${auth.currentUser!.uid}')
            .set(
              {
                'fullName': fullName,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
      } catch (_) {}
    }
  }

  Future<void> continueAsGuest() async {
    await auth.signInAnonymously();
    await initializeProfile();
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
    await auth.signOut();
    await Hive.box('jbb_cache').clear();
  }

  Future<void> deleteAccount() async {
    final user = auth.currentUser;
    if (user == null) return;
    final isApple = user.providerData.any((p) => p.providerId == 'apple.com');
    if (isApple) {
      try {
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [],
        );
        final authCode = appleCredential.authorizationCode;
        if (authCode.isNotEmpty) {
          await auth.revokeTokenWithAuthorizationCode(authCode);
        }
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          return;
        }
        rethrow;
      }
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await NotificationService.instance.unregister();
    } catch (_) {
      // Deleting must proceed even if notifications fail to unregister.
    }
    await user.delete();
    await Hive.box('jbb_cache').clear();
  }
}
