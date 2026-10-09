import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/waiver.dart';
import '../domain/waiver_repository.dart';
import 'waiver_model.dart';

class WaiverRepositoryImpl implements WaiverRepository {
  @override
  Stream<Waiver> watch() => FirebaseFirestore.instance
      .doc('legalDocuments/waiver')
      .snapshots()
      .handleError((e) {
        if (e is FirebaseException && e.code == 'permission-denied') return;
        final s = e.toString().toLowerCase();
        if (s.contains('permission-denied') ||
            s.contains('insufficient permissions')) {
          return;
        }
        throw e;
      })
      .map((snapshot) => WaiverModel.fromMap(snapshot.data()));

  @override
  Future<void> accept({
    required String? version,
    required String signerName,
    required bool guardian,
    required bool adult,
    required bool agree,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('acceptWaiver').call({
      'version': version,
      'signerName': signerName,
      'capacity': guardian ? 'guardian' : 'participant',
      'adult': adult,
      'agree': agree,
    });
  }
}
