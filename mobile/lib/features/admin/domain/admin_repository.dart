import 'dart:io';

import '../../booking/domain/booking.dart';
import '../../membership/domain/membership_plan.dart';
import '../../payments/domain/payment.dart';
import '../../profile/domain/member.dart';
import '../../home/domain/home_ad.dart';
import 'staff_member.dart';

abstract class AdminRepository {
  String newId();
  Stream<List<MembershipPlan>> plans();
  Stream<List<HomeAd>> ads();
  Stream<List<Payment>> orders();
  Stream<List<Booking>> bookings();
  Future<Member?> buyer(String userId);
  Future<void> saveAd(String id, Map<String, dynamic> values);
  Future<void> deleteAd(String id);
  Future<String> uploadAdImage(String id, File file);
  Future<void> saveGymInfo({
    required String houseNumber,
    required String streetName,
    required String city,
    required String country,
    required String zipCode,
    required String phone,
  });
  Future<void> saveSocialLinks(Map<String, String> links);
  Future<void> setOrderDelivery(String paymentId, DateTime date, String note);
  Future<void> deletePayment(String paymentId);
  Future<void> markAttendance(String bookingId, String status);
  Future<void> cancelBookingAsAdmin(String bookingId, String reason);
  Stream<List<StaffMember>> staff();
  Future<List<StaffMember>> listStaff();
  Future<void> upsertStaff({
    required String email,
    required String displayName,
    required String role,
    required Map<String, bool> permissions,
  });
  Future<void> removeStaff(String uid);
}
