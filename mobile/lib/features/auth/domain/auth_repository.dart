import 'auth_account.dart';

abstract class AuthRepository {
  Stream<AuthAccount?> userChanges();
  AuthAccount? get currentUser;
  Future<void> googleSignIn();
  Future<void> appleSignIn();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password, {String? fullName});
  Future<void> sendPasswordReset(String email);
  Future<void> continueAsGuest();
  Future<void> signOut();
  Future<void> deleteAccount();
}
