import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_account.dart';
import '../domain/auth_repository.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.source);
  final AuthRemoteDataSource source;

  AuthAccount? _account(User? user) => user == null
      ? null
      : AuthAccount(
          uid: user.uid,
          email: user.email,
          isAnonymous: user.isAnonymous,
          hasGoogleProvider: user.providerData.any(
            (provider) => provider.providerId == 'google.com',
          ),
          hasAppleProvider: user.providerData.any(
            (provider) => provider.providerId == 'apple.com',
          ),
        );

  @override
  Stream<AuthAccount?> userChanges() => source.userChanges().map(_account);

  @override
  AuthAccount? get currentUser => _account(source.currentUser);

  @override
  Future<void> googleSignIn() => source.googleSignIn();

  @override
  Future<void> appleSignIn() => source.appleSignIn();

  @override
  Future<void> continueAsGuest() => source.continueAsGuest();

  @override
  Future<void> signOut() => source.signOut();

  @override
  Future<void> deleteAccount() => source.deleteAccount();
}
