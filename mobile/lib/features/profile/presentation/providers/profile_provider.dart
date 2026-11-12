import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/user_repository_impl.dart';
import '../../data/user_remote_data_source.dart';
import '../../domain/user_repository.dart';
import '../../data/waiver_repository_impl.dart';
import '../../domain/waiver_repository.dart';
import '../../domain/gym_settings.dart';
import '../../domain/member.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepositoryImpl(UserRemoteDataSource()),
);
final profileProvider = StreamProvider<Member>((ref) {
  final isGuest = ref.watch(guestModeProvider);
  final user = ref.watch(authProvider).value;
  if (isGuest || user == null || user.isAnonymous) {
    return const Stream.empty();
  }
  return ref.watch(userRepositoryProvider).watch();
});
final settingsProvider = StreamProvider<GymSettings>(
  (ref) => ref.watch(userRepositoryProvider).settings(),
);
final waiverRepositoryProvider = Provider<WaiverRepository>(
  (ref) => WaiverRepositoryImpl(),
);
final waiverProvider = StreamProvider(
  (ref) => ref.watch(waiverRepositoryProvider).watch(),
);
