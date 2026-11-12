import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/data/cached_repository.dart';

class PaymentsRemoteDataSource extends CachedRepository {
  Stream<List<Map<String, dynamic>>> watch() => watchQuery(
    db
        .collection('payments')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100),
    'payments',
  );

  Future<void> cancelPendingOrder(String paymentId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cancelPendingPayment');
      await callable.call({'paymentId': paymentId});
    } catch (_) {
      await db.doc('payments/$paymentId').delete();
    }
  }
}
