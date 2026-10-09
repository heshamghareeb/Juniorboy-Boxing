import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/sign_in_prompt_sheet.dart';
import '../../../membership/domain/membership_plan.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/plan_card.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../store/domain/product.dart';
import '../../../store/presentation/providers/store_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/favorite_heart_button.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? busyProductId;
  String? busyPlanId;
  final Map<String, String> selectedSizes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _buyProduct(Product product) async {
    if (busyProductId != null) return;
    final id = product.id;
    if (product.sizes.isNotEmpty && selectedSizes[id] == null) {
      showMessage(context, AppStrings.chooseASizeFirst);
      return;
    }

    setState(() => busyProductId = id);
    try {
      final authUser = ref.read(authRepositoryProvider).currentUser;
      if (authUser == null || authUser.isAnonymous) {
        final ok = await showSignInPrompt(context, ref);
        if (ok && mounted) {
          showMessage(context, AppStrings.signedInTapBuyNowAgainTo);
        }
        return;
      }

      final message = await ref
          .read(productRepositoryProvider)
          .purchaseProduct(id, size: selectedSizes[id]);
      if (mounted) showMessage(context, message);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is FormatException ? e.message : friendlyError(e),
        );
      }
    } finally {
      if (mounted) setState(() => busyProductId = null);
    }
  }

  Future<void> _purchasePlan(MembershipPlan plan) async {
    if (busyPlanId != null) return;
    setState(() => busyPlanId = plan.id);
    try {
      final authUser = ref.read(authRepositoryProvider).currentUser;
      if (authUser == null || authUser.isAnonymous) {
        final ok = await showSignInPrompt(context, ref);
        if (ok && mounted) {
          showMessage(
            context,
            AppStrings.signedInCompleteYourProfileThenChoose,
          );
        }
        return;
      }
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      if (profile == null || !profile.isProfileComplete) {
        final completed = await context.push<bool>(AppRoutes.completeProfile);
        if (completed != true || !mounted) return;
      }
      final message =
          await ref.read(membershipRepositoryProvider).purchase(plan.id);
      if (mounted) showMessage(context, message);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is FormatException ? e.message : friendlyError(e),
        );
      }
    } finally {
      if (mounted) setState(() => busyPlanId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favProducts = ref.watch(favoriteProductsListProvider);
    final favPlans = ref.watch(favoritePlansListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.favorites),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.palette.accent,
          labelColor: context.palette.accent,
          unselectedLabelColor: context.palette.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    AppIcons.shoppingBag,
                    size: AppSizes.s16,
                    color: _tabController.index == 0
                        ? context.palette.accent
                        : context.palette.textSecondary,
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Text('${AppStrings.storeFavorites} (${favProducts.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    AppIcons.crown,
                    size: AppSizes.s16,
                    color: _tabController.index == 1
                        ? context.palette.accent
                        : context.palette.textSecondary,
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Text('${AppStrings.membershipFavorites} (${favPlans.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Products
          favProducts.isEmpty
              ? _buildEmptyProductsView()
              : _buildProductsList(favProducts),

          // Tab 2: Memberships
          favPlans.isEmpty
              ? _buildEmptyPlansView()
              : _buildPlansList(favPlans),
        ],
      ),
    );
  }

  Widget _buildEmptyProductsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.palette.separator),
              ),
              child: Center(
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: AppSizes.s36,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              AppStrings.noFavoritesYet,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.font18,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              AppStrings.noFavoritesHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: AppSizes.font14,
              ),
            ),
            const SizedBox(height: AppSizes.s24),
            JbbButton(
              label: AppStrings.exploreStore,
              onPressed: () => context.safeNavigate(AppRoutes.store),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlansView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.palette.separator),
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.crown,
                  size: AppSizes.s36,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              AppStrings.noFavoritesYet,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.font18,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              AppStrings.noFavoritesHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: AppSizes.font14,
              ),
            ),
            const SizedBox(height: AppSizes.s24),
            JbbButton(
              label: AppStrings.viewPlans,
              onPressed: () => context.safeNavigate(AppRoutes.membership),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.s16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final discountPercent = product.discountPercent.toDouble();
        final hasDiscount = product.discountActive == true && discountPercent > 0;
        final priceCents = product.price ?? 0;
        final saleCents = hasDiscount
            ? (priceCents * (1 - discountPercent / 100)).round()
            : priceCents;

        final imageUrl = (product.imageUrl?.isNotEmpty == true)
            ? product.imageUrl
            : (product.imageUrls.isNotEmpty == true)
                ? product.imageUrls.first
                : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.s12),
          child: JbbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image with Heart
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radius8),
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      _productThumbnailPlaceholder(),
                                )
                              : _productThumbnailPlaceholder(),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: FavoriteHeartButton(
                            id: product.id,
                            type: FavoriteTargetType.product,
                            size: 16,
                            padding: const EdgeInsets.all(5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.category != null &&
                              product.category!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.palette.accent
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radius4),
                              ),
                              child: Text(
                                product.category!.toUpperCase(),
                                style: TextStyle(
                                  color: context.palette.accent,
                                  fontSize: AppSizes.font10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          Text(
                            product.name ?? AppStrings.uiProduct,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.font16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSizes.s6),
                          if (hasDiscount)
                            Row(
                              children: [
                                Text(
                                  '\$${(priceCents / 100).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: AppSizes.font13,
                                    color: context.palette.textSecondary,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.s8),
                                Text(
                                  '\$${(saleCents / 100).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: AppSizes.font16,
                                    color: context.palette.success,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              product.priceLabel ??
                                  '\$${(priceCents / 100).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.font16,
                                color: context.palette.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (product.sizes.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s10),
                  Wrap(
                    spacing: AppSizes.s6,
                    runSpacing: AppSizes.s6,
                    children: [
                      for (final size in product.sizes)
                        ChoiceChip(
                          label: Text(size),
                          selected: selectedSizes[product.id] == size,
                          onSelected: (_) => setState(
                            () => selectedSizes[product.id] = size,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSizes.s12),
                SizedBox(
                  width: double.infinity,
                  child: JbbButton(
                    label: AppStrings.buyNow,
                    busy: busyProductId == product.id,
                    onPressed: busyProductId == null
                        ? () => _buyProduct(product)
                        : () {},
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _productThumbnailPlaceholder() {
    return Container(
      width: 86,
      height: 86,
      color: context.palette.elevated,
      child: Center(
        child: AppIcon(
          AppIcons.boxingGlove,
          size: AppSizes.s28,
          color: context.palette.accent,
        ),
      ),
    );
  }

  Widget _buildPlansList(List<MembershipPlan> plans) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.s16),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.s14),
          child: Stack(
            children: [
              PlanCard(
                plan: plan,
                selected: false,
                onTap: () => _purchasePlan(plan),
              ),
              Positioned(
                top: AppSizes.s12,
                right: AppSizes.s12,
                child: FavoriteHeartButton(
                  id: plan.id,
                  type: FavoriteTargetType.plan,
                  size: 20,
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
