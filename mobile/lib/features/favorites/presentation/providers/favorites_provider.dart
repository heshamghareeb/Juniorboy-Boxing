import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/favorites_repository_impl.dart';
import '../../domain/favorites_repository.dart';
import '../../../store/presentation/providers/store_provider.dart';
import '../../../store/domain/product.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/domain/membership_plan.dart';

import '../../../sessions/models/session_model.dart';
import '../../../sessions/presentation/providers/session_provider.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepositoryImpl();
});

final favoriteProductIdsProvider = StreamProvider<List<String>>((ref) {
  final repo = ref.watch(favoritesRepositoryProvider);
  return repo.watchFavoriteProductIds();
});

final favoritePlanIdsProvider = StreamProvider<List<String>>((ref) {
  final repo = ref.watch(favoritesRepositoryProvider);
  return repo.watchFavoritePlanIds();
});

final favoriteSessionIdsProvider = StreamProvider<List<String>>((ref) {
  final repo = ref.watch(favoritesRepositoryProvider);
  return repo.watchFavoriteSessionIds();
});

/// Returns list of favorite products currently available or cached
final favoriteProductsListProvider = Provider<List<Product>>((ref) {
  final favIds = ref.watch(favoriteProductIdsProvider).value ?? const [];
  if (favIds.isEmpty) return const [];
  final activeProducts = ref.watch(productsProvider).value ?? const [];
  final adminProducts = ref.watch(productsAdminProvider).value ?? const [];
  final allProducts = adminProducts.isNotEmpty ? adminProducts : activeProducts;

  return allProducts.where((p) => favIds.contains(p.id)).toList();
});

/// Returns list of favorite membership plans currently available
final favoritePlansListProvider = Provider<List<MembershipPlan>>((ref) {
  final favIds = ref.watch(favoritePlanIdsProvider).value ?? const [];
  if (favIds.isEmpty) return const [];
  final plans = ref.watch(plansProvider).value ?? const [];

  return plans.where((p) => favIds.contains(p.id)).toList();
});

/// Returns list of favorite sessions currently available
final favoriteSessionsListProvider = Provider<List<SessionModel>>((ref) {
  final favIds = ref.watch(favoriteSessionIdsProvider).value ?? const [];
  if (favIds.isEmpty) return const [];
  final sessions = ref.watch(sessionsProvider).value ?? const [];

  return sessions.where((s) => favIds.contains(s.id)).toList();
});

/// Total count of all favorites combined
final totalFavoritesCountProvider = Provider<int>((ref) {
  final favProducts = ref.watch(favoriteProductsListProvider);
  final favPlans = ref.watch(favoritePlansListProvider);
  final favSessions = ref.watch(favoriteSessionsListProvider);
  return favProducts.length + favPlans.length + favSessions.length;
});
