abstract class FavoritesRepository {
  List<String> getFavoriteProductIds();
  List<String> getFavoritePlanIds();
  List<String> getFavoriteSessionIds();
  Stream<List<String>> watchFavoriteProductIds();
  Stream<List<String>> watchFavoritePlanIds();
  Stream<List<String>> watchFavoriteSessionIds();
  Future<void> toggleProductFavorite(String productId);
  Future<void> togglePlanFavorite(String planId);
  Future<void> toggleSessionFavorite(String sessionId);
  Future<void> setProductFavorite(String productId, bool isFav);
  Future<void> setPlanFavorite(String planId, bool isFav);
  Future<void> setSessionFavorite(String sessionId, bool isFav);
}
