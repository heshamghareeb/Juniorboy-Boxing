import 'booking.dart';

bool isUpcomingBooking(Booking booking, DateTime now) {
  final status = booking.status.toLowerCase();
  if (status != 'confirmed') return false;
  if (booking.date.isAfter(now)) return true;
  return booking.date.year == now.year &&
      booking.date.month == now.month &&
      booking.date.day == now.day;
}

bool canCancelBooking(Booking booking, DateTime now, num policyHours) =>
    booking.status.toLowerCase() == 'confirmed' &&
    booking.date.difference(now).inSeconds >= policyHours * 3600;
