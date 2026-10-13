import 'dart:io';

import '../../booking/data/booking_model.dart';
import '../../booking/domain/booking.dart';
import '../../membership/data/membership_plan_model.dart';
import '../../payments/data/payment_model.dart';
import '../../membership/domain/membership_plan.dart';
import '../../payments/domain/payment.dart';
import '../../profile/domain/member.dart';
import '../domain/admin_repository.dart';
import 'admin_remote_data_source.dart';
import '../../home/domain/home_ad.dart';
import '../../home/data/home_ad_model.dart';
import '../domain/staff_member.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this.source);
  final AdminRemoteDataSource source;

  @override
  String newId() => source.newId();
  @override
  Stream<List<MembershipPlan>> plans() => source.plans().map(
    (rows) => rows.map<MembershipPlan>(MembershipPlanModel.fromMap).toList(),
  );
  @override
  Stream<List<HomeAd>> ads() => source.ads().map(
    (rows) => rows.map<HomeAd>(HomeAdModel.fromMap).toList(),
  );
  @override
  Stream<List<Payment>> orders() => source.orders().map(
    (rows) => rows.map<Payment>(PaymentModel.fromMap).toList(),
  );
  @override
  Stream<List<Booking>> bookings() => source.bookings().map(
    (rows) => rows.map<Booking>(BookingModel.fromMap).toList(),
  );
  @override
  Future<Member?> buyer(String userId) => source.buyer(userId);
  @override
  Future<void> saveAd(String id, Map<String, dynamic> values) =>
      source.saveAd(id, values);
  @override
  Future<void> deleteAd(String id) => source.deleteAd(id);
  @override
  Future<String> uploadAdImage(String id, File file) =>
      source.uploadAdImage(id, file);
  @override
  Future<void> saveGymInfo({
    required String houseNumber,
    required String streetName,
    required String city,
    required String country,
    required String zipCode,
    required String phone,
  }) => source.saveGymInfo(
    houseNumber: houseNumber,
    streetName: streetName,
    city: city,
    country: country,
    zipCode: zipCode,
    phone: phone,
  );
  @override
  Future<void> saveSocialLinks(Map<String, String> links) =>
      source.saveSocialLinks(links);
  @override
  Future<void> setOrderDelivery(String id, DateTime date, String note) =>
      source.setOrderDelivery(id, date, note);
  @override
  Future<void> deletePayment(String id) => source.deletePayment(id);
  @override
  Future<void> markAttendance(String id, String status) =>
      source.markAttendance(id, status);
  @override
  Future<void> cancelBookingAsAdmin(String id, String reason) =>
      source.cancelBookingAsAdmin(id, reason);
  @override
  Stream<List<StaffMember>> staff() => source.staff().map(
    (rows) => rows.map<StaffMember>(StaffMember.fromMap).toList(),
  );
  @override
  Future<List<StaffMember>> listStaff() => source.listStaff();
  @override
  Future<void> upsertStaff({
    required String email,
    required String displayName,
    required String role,
    required Map<String, bool> permissions,
  }) => source.upsertStaff(
    email: email,
    displayName: displayName,
    role: role,
    permissions: permissions,
  );
  @override
  Future<void> removeStaff(String uid) => source.removeStaff(uid);
}
