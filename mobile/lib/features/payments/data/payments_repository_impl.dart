import '../domain/payment.dart';
import '../domain/payments_repository.dart';
import 'payment_model.dart';
import 'payments_remote_data_source.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl(this.source);
  final PaymentsRemoteDataSource source;

  @override
  Stream<List<Payment>> watch() => source.watch().map(
    (rows) => rows.map<Payment>(PaymentModel.fromMap).toList(),
  );

  @override
  Future<void> cancelPendingOrder(String paymentId) =>
      source.cancelPendingOrder(paymentId);
}
