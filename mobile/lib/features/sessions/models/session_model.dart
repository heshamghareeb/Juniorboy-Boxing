import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/non_empty.dart';

class SessionTimeSlot {
  const SessionTimeSlot({
    required this.startTime,
    required this.endTime,
  });

  final String startTime;
  final String endTime;

  factory SessionTimeSlot.fromMap(Map<String, dynamic> map) => SessionTimeSlot(
        startTime: map['startTime'] as String? ?? '',
        endTime: map['endTime'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'startTime': startTime,
        'endTime': endTime,
      };
}

class SessionModel {
  const SessionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    this.timeSlots = const [],
    required this.maxParticipants,
    required this.joinedUserIds,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final List<String> images;
  final String type; // 'individual' | 'duo' | 'team'
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final List<SessionTimeSlot> timeSlots;
  final int maxParticipants;
  final List<String> joinedUserIds;

  List<SessionTimeSlot> get resolvedTimeSlots {
    if (timeSlots.isNotEmpty) return timeSlots;
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return [SessionTimeSlot(startTime: startTime, endTime: endTime)];
    }
    return const [];
  }

  String get formattedTimes {
    final slots = resolvedTimeSlots;
    if (slots.isEmpty) return '';
    return slots.map((s) => '${s.startTime}–${s.endTime}').join(' · ');
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    final rawSlots = (map['timeSlots'] as List?)
            ?.whereType<Map>()
            .map((m) => SessionTimeSlot.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        const <SessionTimeSlot>[];

    return SessionModel(
      id: map['id'] as String? ?? '',
      title: nonEmpty(map['title'] as String?) ?? '',
      description: nonEmpty(map['description'] as String?) ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      images: (map['images'] as List?)?.whereType<String>().toList() ?? const [],
      type: map['type'] as String? ?? 'individual',
      startDate: readDate(map['startDate']),
      endDate: readDate(map['endDate']),
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      timeSlots: rawSlots,
      maxParticipants: (map['maxParticipants'] as num?)?.toInt() ?? 1,
      joinedUserIds:
          (map['joinedUserIds'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'price': price,
    'images': images,
    'type': type,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'startTime': startTime,
    'endTime': endTime,
    'timeSlots': timeSlots.map((s) => s.toMap()).toList(),
    'maxParticipants': maxParticipants,
    'joinedUserIds': joinedUserIds,
  };
}

