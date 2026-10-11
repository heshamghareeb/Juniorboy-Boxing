import 'dart:io';

import '../../account/models/user_model.dart';
import '../models/session_model.dart';

abstract class SessionRepository {
  String newId();
  Stream<List<SessionModel>> watch();
  Future<void> save(String id, Map<String, dynamic> values);
  Future<void> delete(String id);
  Future<String> uploadImage(String id, File file);
  Future<List<UserModel>> fetchMembers(String sessionId);
  Future<String> join(String sessionId, {String? timeSlot});
}
