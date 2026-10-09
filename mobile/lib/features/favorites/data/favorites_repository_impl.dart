import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/favorites_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl() {
    _initLocal();
    _initRemoteSync();
  }

  static const String _boxName = 'jbb_device';
  static const String _productsKey = 'favorite_product_ids';
  static const String _plansKey = 'favorite_plan_ids';
  static const String _sessionsKey = 'favorite_session_ids';

  final _productsController = StreamController<List<String>>.broadcast();
  final _plansController = StreamController<List<String>>.broadcast();
  final _sessionsController = StreamController<List<String>>.broadcast();

  final Set<String> _productIds = {};
  final Set<String> _planIds = {};
  final Set<String> _sessionIds = {};

  Box get _box {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.box('jbb_cache');
  }

  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  void _initLocal() {
    try {
      final storedProducts = _box.get(_productsKey);
      if (storedProducts is List) {
        _productIds.addAll(storedProducts.map((e) => e.toString()));
      }
      final storedPlans = _box.get(_plansKey);
      if (storedPlans is List) {
        _planIds.addAll(storedPlans.map((e) => e.toString()));
      }
      final storedSessions = _box.get(_sessionsKey);
      if (storedSessions is List) {
        _sessionIds.addAll(storedSessions.map((e) => e.toString()));
      }
    } catch (_) {}
  }

  void _initRemoteSync() {
    final uid = _uid;
    if (uid == null) return;

    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((doc) {
        if (!doc.exists) return;
        final data = doc.data();
        if (data == null) return;

        if (data['favoriteProductIds'] is List) {
          final remoteProducts =
              (data['favoriteProductIds'] as List).map((e) => e.toString()).toSet();
          if (!_areSetsEqual(_productIds, remoteProducts)) {
            _productIds.clear();
            _productIds.addAll(remoteProducts);
            _box.put(_productsKey, _productIds.toList());
            _productsController.add(_productIds.toList());
          }
        }

        if (data['favoritePlanIds'] is List) {
          final remotePlans =
              (data['favoritePlanIds'] as List).map((e) => e.toString()).toSet();
          if (!_areSetsEqual(_planIds, remotePlans)) {
            _planIds.clear();
            _planIds.addAll(remotePlans);
            _box.put(_plansKey, _planIds.toList());
            _plansController.add(_planIds.toList());
          }
        }

        if (data['favoriteSessionIds'] is List) {
          final remoteSessions =
              (data['favoriteSessionIds'] as List).map((e) => e.toString()).toSet();
          if (!_areSetsEqual(_sessionIds, remoteSessions)) {
            _sessionIds.clear();
            _sessionIds.addAll(remoteSessions);
            _box.put(_sessionsKey, _sessionIds.toList());
            _sessionsController.add(_sessionIds.toList());
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  bool _areSetsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  List<String> getFavoriteProductIds() => List.unmodifiable(_productIds);

  @override
  List<String> getFavoritePlanIds() => List.unmodifiable(_planIds);

  @override
  List<String> getFavoriteSessionIds() => List.unmodifiable(_sessionIds);

  @override
  Stream<List<String>> watchFavoriteProductIds() async* {
    yield List.unmodifiable(_productIds);
    yield* _productsController.stream;
  }

  @override
  Stream<List<String>> watchFavoritePlanIds() async* {
    yield List.unmodifiable(_planIds);
    yield* _plansController.stream;
  }

  @override
  Stream<List<String>> watchFavoriteSessionIds() async* {
    yield List.unmodifiable(_sessionIds);
    yield* _sessionsController.stream;
  }

  @override
  Future<void> toggleProductFavorite(String productId) async {
    final willBeFav = !_productIds.contains(productId);
    await setProductFavorite(productId, willBeFav);
  }

  @override
  Future<void> togglePlanFavorite(String planId) async {
    final willBeFav = !_planIds.contains(planId);
    await setPlanFavorite(planId, willBeFav);
  }

  @override
  Future<void> toggleSessionFavorite(String sessionId) async {
    final willBeFav = !_sessionIds.contains(sessionId);
    await setSessionFavorite(sessionId, willBeFav);
  }

  @override
  Future<void> setProductFavorite(String productId, bool isFav) async {
    if (isFav) {
      _productIds.add(productId);
    } else {
      _productIds.remove(productId);
    }
    _box.put(_productsKey, _productIds.toList());
    _productsController.add(List.unmodifiable(_productIds));

    final uid = _uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'favoriteProductIds': isFav
              ? FieldValue.arrayUnion([productId])
              : FieldValue.arrayRemove([productId]),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Future<void> setPlanFavorite(String planId, bool isFav) async {
    if (isFav) {
      _planIds.add(planId);
    } else {
      _planIds.remove(planId);
    }
    _box.put(_plansKey, _planIds.toList());
    _plansController.add(List.unmodifiable(_planIds));

    final uid = _uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'favoritePlanIds': isFav
              ? FieldValue.arrayUnion([planId])
              : FieldValue.arrayRemove([planId]),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Future<void> setSessionFavorite(String sessionId, bool isFav) async {
    if (isFav) {
      _sessionIds.add(sessionId);
    } else {
      _sessionIds.remove(sessionId);
    }
    _box.put(_sessionsKey, _sessionIds.toList());
    _sessionsController.add(List.unmodifiable(_sessionIds));

    final uid = _uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'favoriteSessionIds': isFav
              ? FieldValue.arrayUnion([sessionId])
              : FieldValue.arrayRemove([sessionId]),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}
