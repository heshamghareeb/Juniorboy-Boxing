import '../../../core/utils/date_utils.dart';

class Booking {
  const Booking({
    required this.id,
    required this.userId,
    required this.className,
    required this.date,
    required this.endAt,
    required this.status,
    this.category,
    this.trainingType,
    this.startTime,
    this.endTime,
    this.timeSlot,
    this.scheduleId,
    this.sessionId,
  });

  final String id;
  final String userId;
  final String className;
  final DateTime date;
  final DateTime endAt;
  final String status;
  final String? category, trainingType;
  final String? startTime, endTime, timeSlot, scheduleId, sessionId;

  /// Returns the explicit slot time if available (e.g. "10:00 AM – 11:00 AM"),
  /// or falls back to timeLabel of the date.
  String get formattedSlotTime {
    if (timeSlot != null && timeSlot!.trim().isNotEmpty) {
      return timeSlot!.trim();
    }
    if (startTime != null && startTime!.trim().isNotEmpty) {
      if (endTime != null && endTime!.trim().isNotEmpty) {
        return '${startTime!.trim()} – ${endTime!.trim()}';
      }
      return startTime!.trim();
    }
    return timeLabel(date);
  }
}
