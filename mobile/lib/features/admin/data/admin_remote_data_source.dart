import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/data/cached_repository.dart';
import '../../profile/data/member_model.dart';
import '../../profile/domain/member.dart';
import '../domain/staff_member.dart';

/// Admin-only data access for the in-app dashboard: membership plan
/// prices and class schedule times. Firestore rules already restrict
/// writes to these collections to role:'admin' accounts, matching the
/// same pattern the web admin panel uses.
class AdminRemoteDataSource extends CachedRepository {
  String newId() => db.collection('membershipPlans').doc().id;
  Stream<List<Map<String, dynamic>>> plans() =>
      watchQuery(db.collection('membershipPlans'), 'admin_plans');
  Stream<List<Map<String, dynamic>>> ads() =>
      watchQuery(db.collection('homeAds'), 'admin_ads');

  Future<void> _saveCatalogDocument(String path, Map<String, dynamic> values) async {
    final reference = db.doc(path);
    final exists = (await reference.get()).exists;
    await reference.set({
      ...values,
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveAd(String id, Map<String, dynamic> values) =>
      _saveCatalogDocument('homeAds/$id', values);

  Future<void> deleteAd(String id) => db.doc('homeAds/$id').delete();

  /// Shares the same `gym/ads/{id}` Storage path the web admin panel uploads
  /// to, so a photo added from either platform shows on both.
  Future<String> uploadAdImage(String adId, File file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('Image must be smaller than 5 MB');
    }
    final ref = FirebaseStorage.instance.ref('gym/ads/$adId');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> saveGymInfo({
    required String houseNumber,
    required String streetName,
    required String city,
    required String country,
    required String zipCode,
    required String phone,
  }) => db.doc('gymSettings/config').set({
    // Street, city, zip, country — the conventional mailing-address order.
    // Built here (not via the shared composeAddress helper used for member
    // profiles) so zip lands between city and country instead of after.
    'address': [
      [houseNumber, streetName].where((s) => s.trim().isNotEmpty).join(' '),
      city,
      zipCode,
      country,
    ].where((s) => s.trim().isNotEmpty).join(', '),
    'zipCode': zipCode,
    'phone': phone,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> saveSocialLinks(Map<String, String> links) =>
      db.doc('gymSettings/config').set({
        'socialLinks': links,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<Map<String, dynamic>>> orders() => watchQuery(
    db.collection('payments').orderBy('createdAt', descending: true).limit(200),
    'admin_orders',
  );

  Future<Member?> buyer(String userId) async {
    final snap = await db.doc('users/$userId').get();
    final data = snap.data();
    return data == null ? null : MemberModel.fromMap({...data, 'id': snap.id});
  }

  Future<void> setOrderDelivery(
    String paymentId,
    DateTime estimatedDeliveryDate,
    String note,
  ) => FirebaseFunctions.instance.httpsCallable('setOrderDelivery').call({
    'paymentId': paymentId,
    'estimatedDeliveryDate': estimatedDeliveryDate.toIso8601String(),
    'note': note,
  });

  Future<void> deletePayment(String paymentId) => FirebaseFunctions.instance
      .httpsCallable('deletePayment')
      .call({'paymentId': paymentId});

  Stream<List<Map<String, dynamic>>> bookings() => watchQuery(
    db.collection('bookings').orderBy('date', descending: true).limit(200),
    'admin_bookings',
  );

  Future<void> markAttendance(String bookingId, String status) =>
      FirebaseFunctions.instance.httpsCallable('markBookingCompleted').call({
        'bookingId': bookingId,
        'status': status,
      });

  Future<void> cancelBookingAsAdmin(String bookingId, String reason) =>
      FirebaseFunctions.instance.httpsCallable('cancelBooking').call({
        'bookingId': bookingId,
        'reason': reason,
      });

  Stream<List<Map<String, dynamic>>> staff() => watchQuery(
    db
        .collection('users')
        .where('role', whereIn: ['admin', 'superAdmin']),
    'admin_staff',
  );

  Future<List<StaffMember>> listStaff() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('listStaff')
        .call();
    final data = result.data;
    final rawList = data is Map ? data['staff'] as List<dynamic>? ?? [] : [];
    return rawList
        .whereType<Map>()
        .map((m) => StaffMember.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> upsertStaff({
    required String email,
    required String displayName,
    required String role,
    required Map<String, bool> permissions,
  }) => FirebaseFunctions.instance.httpsCallable('upsertStaff').call({
    'email': email,
    'displayName': displayName,
    'role': role,
    'permissions': permissions,
  });

  Future<void> removeStaff(String uid) => FirebaseFunctions.instance
      .httpsCallable('removeStaff')
      .call({'uid': uid});
}
