class Payment {
  const Payment({
    required this.id,
    required this.userId,
    required this.productId,
    required this.membershipPlanId,
    required this.credits,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.productName,
    required this.size,
    required this.estimatedDeliveryDate,
    required this.deliveryNote,
    this.trainingType,
    this.sessionId,
    this.sessionTitle,
    this.timeSlot,
  });

  final String id;
  final String userId;
  final String? productId, membershipPlanId;
  final int? credits;
  final num amount;
  final String status;
  final String? paymentMethod, productName, size, deliveryNote;
  final String? trainingType;
  final String? sessionId, sessionTitle, timeSlot;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryDate;
}
