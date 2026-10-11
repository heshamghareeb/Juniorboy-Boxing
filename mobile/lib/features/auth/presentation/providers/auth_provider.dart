import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/auth_remote_data_source.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_account.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(AuthRemoteDataSource()),
);
final authProvider = StreamProvider<AuthAccount?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);

class GuestModeNotifier extends StateNotifier<bool> {
  GuestModeNotifier(this._authRepo) : super(_authRepo.isGuest);

  final AuthRepository _authRepo;

  Future<void> setGuest(bool value) async {
    if (value) {
      await _authRepo.continueAsGuest();
    } else {
      if (Hive.isBoxOpen('jbb_cache')) {
        await Hive.box('jbb_cache').delete('is_guest_mode');
      }
    }
    state = value && _authRepo.currentUser == null;
  }
}

final guestModeProvider = StateNotifierProvider<GuestModeNotifier, bool>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return GuestModeNotifier(repo);
});
