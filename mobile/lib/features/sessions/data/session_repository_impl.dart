import 'dart:io';

import '../../../core/services/stripe_service.dart';
import '../../account/models/user_model.dart';
import '../domain/session_repository.dart';
import '../models/session_model.dart';
import 'session_remote_data_source.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this.source, this.stripe);
  final SessionRemoteDataSource source;
  final StripeService stripe;

  @override
  String newId() => source.newId();

  @override
  Stream<List<SessionModel>> watch() =>
      source.watch().map((rows) => rows.map(SessionModel.fromMap).toList());

  @override
  Future<void> save(String id, Map<String, dynamic> values) =>
      source.save(id, values);

  @override
  Future<void> delete(String id) => source.delete(id);

  @override
  Future<String> uploadImage(String id, File file) =>
      source.uploadImage(id, file);

  @override
  Future<List<UserModel>> fetchMembers(String sessionId) async {
    final rows = await source.fetchMembers(sessionId);
    return rows.map(UserModel.fromMap).toList();
  }

  @override
  Future<String> join(String sessionId, {String? timeSlot}) =>
      stripe.joinSession(sessionId, timeSlot: timeSlot);
}
