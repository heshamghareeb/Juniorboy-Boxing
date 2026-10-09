import '../../../../core/theme/app_palette.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../../core/widgets/page_content.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/sign_in_prompt_sheet.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/store_provider.dart';
import '../../domain/product.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import 'product_editor_screen.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String? busyProductId;
  final Map<String, String> selectedSize = {};

  Future<void> buyNow(Product product) async {
    if (busyProductId != null) return;
    final id = product.id;
    final sizes = product.sizes;
    if (sizes.isNotEmpty && selectedSize[id] == null) {
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
          .purchaseProduct(id, size: selectedSize[id]);
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

  Widget productCard(Product product, bool isAdmin) {
    final discountPercent = product.discountPercent.toDouble();
    final hasDiscount = product.discountActive == true && discountPercent > 0;
    final priceCents = product.price ?? 0;
    final saleCents = hasDiscount
        ? (priceCents * (1 - discountPercent / 100)).round()
        : priceCents;
    return JbbCard(
      onTap: isAdmin
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductEditorScreen(product: product),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            child: (product.imageUrl ?? '').isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    width: AppSizes.productThumbnailSize,
                    height: AppSizes.productThumbnailSize,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        const _ProductPlaceholder(),
                  )
                : const _ProductPlaceholder(),
          ),
          SizedBox(width: AppSizes.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name ?? AppStrings.uiProduct,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.font16,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.s8),
                    FavoriteHeartButton(
                      id: product.id,
                      type: FavoriteTargetType.product,
                      size: 18,
                      padding: const EdgeInsets.all(6),
                    ),
                    if (isAdmin && product.isActive != true)
                      Padding(
                        padding: EdgeInsets.only(left: AppSizes.s8),
                        child: Text(
                          AppStrings.uiHidden,
                          style: TextStyle(
                            color: context.palette.warning,
                            fontSize: AppSizes.font11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isAdmin && product.isFeatured == true)
                      Padding(
                        padding: EdgeInsets.only(left: AppSizes.s8),
                        child: Text(
                          AppStrings.uiFeatured,
                          style: TextStyle(
                            color: context.palette.accent,
                            fontSize: AppSizes.font11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (hasDiscount)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSizes.s8),
                        child: Text(
                          '${discountPercent.toStringAsFixed(0)}% OFF',
                          style: TextStyle(
                            color: context.palette.success,
                            fontSize: AppSizes.font11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if ((product.description ?? '').isNotEmpty) ...[
                  SizedBox(height: AppSizes.s4),
                  Text(
                    product.description!,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: AppSizes.font13,
                    ),
                    maxLines: AppSizes.cardTextLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: AppSizes.s8),
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
                      SizedBox(width: AppSizes.s8),
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
                if (!isAdmin) ...[
                  if (product.sizes.isNotEmpty) ...[
                    SizedBox(height: AppSizes.s8),
                    Wrap(
                      spacing: AppSizes.s6,
                      runSpacing: AppSizes.s6,
                      children: [
                        for (final size in product.sizes)
                          ChoiceChip(
                            label: Text(size),
                            selected: selectedSize[product.id] == size,
                            onSelected: (_) =>
                                setState(() => selectedSize[product.id] = size),
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: AppSizes.s10),
                  SizedBox(
                    width: double.infinity,
                    child: JbbButton(
                      label: AppStrings.buyNow,
                      busy: busyProductId == product.id,
                      onPressed: busyProductId == null
                          ? () => buyNow(product)
                          : () {},
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAdmin)
            AppIcon(
              AppIcons.chevronRight,
              color: context.palette.textSecondary,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(profileProvider).value?.role;
    final isAdmin = role == 'admin' || role == 'superAdmin';
    final products = ref.watch(
      isAdmin ? productsAdminProvider : productsProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.gymStore),
        actions: [
          IconButton(
            tooltip: AppStrings.favorites,
            icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
            onPressed: () => context.safeNavigate(AppRoutes.favorites),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ProductEditorScreen())),
              icon: AppIcon(AppIcons.plus),
              label: Text(AppStrings.addProduct),
            )
          : null,
      body: PageContent(
        children: [
          products.when(
            data: (rows) {
              final sorted = [...rows]
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
              if (sorted.isEmpty) {
                return JbbEmptyState(
                  message: isAdmin
                      ? AppStrings.uiNoProductsYetTapAddProductToCreate
                      : AppStrings.uiProductsWillAppearHereWhenAvailable,
                );
              }
              return Column(
                children: [
                  for (final product in sorted) productCard(product, isAdmin),
                  if (!isAdmin) ...[
                    SizedBox(height: AppSizes.s8),
                    TextButton(
                      onPressed: () => context.safeNavigate(AppRoutes.contact),
                      child: Text(
                        AppStrings.uiQuestionAboutAnOrderContactTheGym,
                      ),
                    ),
                  ],
                ],
              );
            },
            error: (e, s) => JbbEmptyState(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(
                isAdmin ? productsAdminProvider : productsProvider,
              ),
            ),
            loading: () => JbbLoading(),
          ),
        ],
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.productThumbnailSize,
    height: AppSizes.productThumbnailSize,
    color: context.palette.separator,
    child: AppIcon(AppIcons.shoppingBag, color: context.palette.textSecondary),
  );
}
