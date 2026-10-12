import '../../../core/utils/date_utils.dart';
import '../../../core/utils/non_empty.dart';
import '../domain/payment.dart';

class PaymentModel extends Payment {
  const PaymentModel({
    required super.id,
    required super.userId,
    required super.productId,
    required super.membershipPlanId,
    required super.credits,
    required super.amount,
    required super.status,
    required super.paymentMethod,
    required super.createdAt,
    required super.productName,
    required super.size,
    required super.estimatedDeliveryDate,
    required super.deliveryNote,
    super.trainingType,
    super.sessionId,
    super.sessionTitle,
    super.timeSlot,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
    id: map['id'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    productId: nonEmpty(map['productId'] as String?),
    membershipPlanId: nonEmpty(map['membershipPlanId'] as String?),
    credits: (map['credits'] as num?)?.toInt(),
    amount: map['amount'] as num? ?? 0,
    status: map['status'] as String? ?? '',
    paymentMethod: nonEmpty(map['paymentMethod'] as String?),
    createdAt: readDate(map['createdAt']),
    productName: nonEmpty(map['productName'] as String?),
    size: nonEmpty(map['size'] as String?),
    estimatedDeliveryDate: map['estimatedDeliveryDate'] == null
        ? null
        : readDate(map['estimatedDeliveryDate']),
    deliveryNote: nonEmpty(map['deliveryNote'] as String?),
    trainingType: nonEmpty(map['trainingType'] as String?),
    sessionId: nonEmpty(map['sessionId'] as String?),
    sessionTitle: nonEmpty(map['sessionTitle'] as String?),
    timeSlot: nonEmpty(map['timeSlot'] as String?),
  );
}
