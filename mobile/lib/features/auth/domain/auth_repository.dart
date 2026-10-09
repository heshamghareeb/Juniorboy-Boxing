import 'auth_account.dart';

abstract class AuthRepository {
  Stream<AuthAccount?> userChanges();
  AuthAccount? get currentUser;
  Future<void> googleSignIn();
  Future<void> appleSignIn();
  Future<void> continueAsGuest();
  Future<void> signOut();
  Future<void> deleteAccount();
}
