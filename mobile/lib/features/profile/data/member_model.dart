import '../../../core/utils/date_utils.dart';
import '../../../core/utils/non_empty.dart';
import '../domain/member.dart';

class MemberModel extends Member {
  const MemberModel({
    required super.id,
    required super.fullName,
    required super.lastName,
    required super.email,
    required super.phone,
    required super.age,
    required super.address,
    required super.zipCode,
    required super.avatarUrl,
    required super.role,
    required super.isActive,
    required super.memberSince,
    required super.membershipPlanId,
    required super.sessionsRemaining,
    required super.sessionsReserved,
    required super.childName,
    required super.childAge,
    required super.waiverVersion,
    required super.waiverParticipantName,
    required super.waiverParticipantAge,
    required super.pushNotifications,
    required super.emailNotifications,
    super.termsAccepted,
    super.dateOfBirth,
    super.profilePicUrl,
    super.privateSessionsRemaining,
    super.privateSessionsReserved,
    super.groupSessionsRemaining,
    super.groupSessionsReserved,
    super.duoSessionsRemaining,
    super.duoSessionsReserved,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    final preferences = map['notificationPreferences'] as Map?;
    return MemberModel(
      id: map['id'] as String? ?? '',
      fullName: nonEmpty(map['fullName'] as String?),
      lastName: nonEmpty(map['lastName'] as String?),
      email: nonEmpty(map['email'] as String?),
      phone: nonEmpty(map['phone'] as String?),
      age: (map['age'] as num?)?.toInt() ?? 0,
      address: nonEmpty(map['address'] as String?),
      zipCode: nonEmpty(map['zipCode'] as String?),
      avatarUrl: nonEmpty(map['avatarUrl'] as String?),
      role: map['role'] as String?,
      isActive: map['isActive'] as bool?,
      memberSince: readDate(map['memberSince']),
      membershipPlanId: nonEmpty(map['membershipPlanId'] as String?),
      sessionsRemaining: (map['sessionsRemaining'] as num?)?.toInt() ?? 0,
      sessionsReserved: (map['sessionsReserved'] as num?)?.toInt() ?? 0,
      childName: map['childName'] as String? ?? '',
      childAge: (map['childAge'] as num?)?.toInt() ?? 0,
      waiverVersion: map['waiverVersion'] as String? ?? '',
      waiverParticipantName: map['waiverParticipantName'] as String?,
      waiverParticipantAge: (map['waiverParticipantAge'] as num?)?.toInt(),
      pushNotifications: preferences?['push'] as bool? ?? true,
      emailNotifications: preferences?['email'] as bool? ?? true,
      termsAccepted: map['termsAccepted'] as bool? ?? false,
      dateOfBirth: map['dateOfBirth'] == null ? null : readDate(map['dateOfBirth']),
      profilePicUrl: nonEmpty(map['profilePicUrl'] as String?),
      privateSessionsRemaining:
          (map['privateSessionsRemaining'] as num?)?.toInt() ?? 0,
      privateSessionsReserved:
          (map['privateSessionsReserved'] as num?)?.toInt() ?? 0,
      groupSessionsRemaining:
          (map['groupSessionsRemaining'] as num?)?.toInt() ?? 0,
      groupSessionsReserved:
          (map['groupSessionsReserved'] as num?)?.toInt() ?? 0,
      duoSessionsRemaining: (map['duoSessionsRemaining'] as num?)?.toInt() ?? 0,
      duoSessionsReserved: (map['duoSessionsReserved'] as num?)?.toInt() ?? 0,
    );
  }
}
