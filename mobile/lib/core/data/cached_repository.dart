import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

bool _isPermissionDenied(Object? error) {
  if (error == null) return false;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return true;
  }
  final s = error.toString().toLowerCase();
  return s.contains('permission-denied') ||
      s.contains('insufficient permissions');
}

abstract class CachedRepository {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  Box get cache => Hive.box('jbb_cache');
  dynamic normalize(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), normalize(v)));
    }
    if (value is List) return value.map(normalize).toList();
    return value;
  }

  Stream<List<Map<String, dynamic>>> watchQuery(
    Query<Map<String, dynamic>> query,
    String key,
  ) async* {
    final cacheKey =
        '${FirebaseAuth.instance.currentUser?.uid ?? 'public'}:$key';
    final stored = cache.get(cacheKey);
    if (stored is String) {
      yield (jsonDecode(stored) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final stream = query.snapshots().handleError(
      (Object _) {},
      test: _isPermissionDenied,
    );
    try {
      await for (final snapshot in stream) {
        if (snapshot.metadata.isFromCache &&
            snapshot.docs.isEmpty &&
            stored is String) {
          continue;
        }
        final rows = snapshot.docs
            .map(
              (d) => <String, dynamic>{
                ...Map<String, dynamic>.from(normalize(d.data())),
                'id': d.id,
              },
            )
            .toList();
        await cache.put(cacheKey, jsonEncode(rows));
        yield rows;
      }
    } catch (e) {
      if (_isPermissionDenied(e)) {
        return;
      }
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> watchDocument(
    DocumentReference<Map<String, dynamic>> ref,
    String key,
  ) async* {
    final cacheKey =
        '${FirebaseAuth.instance.currentUser?.uid ?? 'public'}:$key';
    final stored = cache.get(cacheKey);
    if (stored is String) yield Map<String, dynamic>.from(jsonDecode(stored));
    final stream = ref.snapshots().handleError(
      (Object _) {},
      test: _isPermissionDenied,
    );
    try {
      await for (final snapshot in stream) {
        if (!snapshot.exists) continue;
        final row = <String, dynamic>{
          ...Map<String, dynamic>.from(normalize(snapshot.data()!)),
          'id': snapshot.id,
        };
        await cache.put(cacheKey, jsonEncode(row));
        yield row;
      }
    } catch (e) {
      if (_isPermissionDenied(e)) {
        return;
      }
      rethrow;
    }
  }
}

