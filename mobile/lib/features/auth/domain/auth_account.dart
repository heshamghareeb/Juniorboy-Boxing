class AuthAccount {
  const AuthAccount({
    required this.uid,
    required this.email,
    required this.isAnonymous,
    required this.hasGoogleProvider,
    required this.hasAppleProvider,
  });

  final String uid;
  final String? email;
  final bool isAnonymous, hasGoogleProvider, hasAppleProvider;
}
