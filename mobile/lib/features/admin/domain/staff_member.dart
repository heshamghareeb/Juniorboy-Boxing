import 'package:cloud_firestore/cloud_firestore.dart';

class StaffMember {
  const StaffMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.permissions,
    this.lastSignIn,
  });

  final String uid;
  final String email;
  final String displayName;
  final String role; // 'admin' | 'superAdmin'
  final Map<String, bool> permissions;
  final DateTime? lastSignIn;

  bool get isSuperAdmin => role == 'superAdmin';

  factory StaffMember.fromMap(Map<String, dynamic> map) {
    DateTime? parsedLastSignIn;
    final lastSignInRaw = map['lastSignIn'] ?? map['lastSignInTime'] ?? map['updatedAt'] ?? map['createdAt'];
    if (lastSignInRaw is String && lastSignInRaw.isNotEmpty) {
      parsedLastSignIn = DateTime.tryParse(lastSignInRaw);
    } else if (lastSignInRaw is Timestamp) {
      parsedLastSignIn = lastSignInRaw.toDate();
    }

    final rawPerms = map['permissions'];
    final perms = <String, bool>{};
    if (rawPerms is Map) {
      for (final entry in rawPerms.entries) {
        perms[entry.key.toString()] = entry.value == true;
      }
    }

    final name = (map['displayName'] as String?)?.trim();
    final fullName = (map['fullName'] as String?)?.trim();
    final effectiveName = (name != null && name.isNotEmpty)
        ? name
        : (fullName != null && fullName.isNotEmpty)
            ? fullName
            : '';

    return StaffMember(
      uid: (map['uid'] as String?) ?? (map['id'] as String?) ?? '',
      email: map['email'] as String? ?? '',
      displayName: effectiveName,
      role: map['role'] as String? ?? 'admin',
      permissions: perms,
      lastSignIn: parsedLastSignIn,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role,
    'permissions': permissions,
  };
}

abstract final class StaffPermissions {
  static const manageOffers = 'manageOffers';
  static const checkIn = 'checkIn';
  static const approveRequests = 'approveRequests';
  static const cancelOccurrences = 'cancelOccurrences';
  static const refund = 'refund';
  static const bookForMember = 'bookForMember';
  static const viewRevenue = 'viewRevenue';
  static const manageMembers = 'manageMembers';
  static const manageStore = 'manageStore';
  static const manageContent = 'manageContent';

  static const List<String> all = [
    manageOffers,
    checkIn,
    approveRequests,
    cancelOccurrences,
    refund,
    bookForMember,
    viewRevenue,
    manageMembers,
    manageStore,
    manageContent,
  ];

  static const Map<String, String> labels = {
    manageOffers: 'Manage sessions & schedule',
    checkIn: 'Check in bookings',
    approveRequests: 'Approve session requests',
    cancelOccurrences: 'Cancel occurrences',
    refund: 'Issue refunds',
    bookForMember: 'Book for members',
    viewRevenue: 'View revenue & exports',
    manageMembers: 'Manage members',
    manageStore: 'Manage store',
    manageContent: 'Manage content',
  };
}
