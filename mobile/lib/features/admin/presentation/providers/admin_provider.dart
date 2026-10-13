import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_remote_data_source.dart';
import '../../data/admin_repository_impl.dart';
import '../../domain/admin_repository.dart';
import '../../../booking/domain/booking.dart';
import '../../../membership/domain/membership_plan.dart';
import '../../../payments/domain/payment.dart';
import '../../../home/domain/home_ad.dart';
import '../../domain/staff_member.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(AdminRemoteDataSource()),
);
final adminPlansProvider = StreamProvider<List<MembershipPlan>>(
  (ref) => ref.watch(adminRepositoryProvider).plans(),
);
final adminAdsProvider = StreamProvider<List<HomeAd>>(
  (ref) => ref.watch(adminRepositoryProvider).ads(),
);
final adminOrdersProvider = StreamProvider<List<Payment>>(
  (ref) => ref.watch(adminRepositoryProvider).orders(),
);
final adminBookingsProvider = StreamProvider<List<Booking>>(
  (ref) => ref.watch(adminRepositoryProvider).bookings(),
);
final adminStaffProvider = StreamProvider<List<StaffMember>>(
  (ref) => ref.watch(adminRepositoryProvider).staff(),
);
