import 'payment.dart';

abstract class PaymentsRepository {
  Stream<List<Payment>> watch();
  Future<void> cancelPendingOrder(String paymentId);
}
