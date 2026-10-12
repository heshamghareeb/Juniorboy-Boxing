import '../../../core/utils/date_utils.dart';
import '../../../core/utils/non_empty.dart';
import '../domain/booking.dart';

class BookingModel extends Booking {
  const BookingModel({
    required super.id,
    required super.userId,
    required super.className,
    required super.date,
    required super.endAt,
    required super.status,
    super.category,
    super.trainingType,
    super.startTime,
    super.endTime,
    super.timeSlot,
    super.scheduleId,
    super.sessionId,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map) => BookingModel(
    id: map['id'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    className: map['className'] as String? ?? '',
    date: readDate(map['date']),
    endAt: readDate(map['endAt']),
    status: map['status'] as String? ?? '',
    category: nonEmpty(map['category'] as String?),
    trainingType: nonEmpty(map['trainingType'] as String?),
    startTime: nonEmpty(map['startTime'] as String?),
    endTime: nonEmpty(map['endTime'] as String?),
    timeSlot: nonEmpty(map['timeSlot'] as String?),
    scheduleId: nonEmpty(map['scheduleId'] as String?),
    sessionId: nonEmpty(map['sessionId'] as String?),
  );
}
