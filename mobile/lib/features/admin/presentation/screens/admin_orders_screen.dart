import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../providers/admin_provider.dart';
import '../../../payments/domain/payment.dart';
import '../../../profile/domain/member.dart';
import '../../../store/domain/product.dart';
import '../../../store/presentation/providers/store_provider.dart';
import '../widgets/buyer_name.dart';
import '../widgets/admin_member_profile_sheet.dart';

/// Dedicated admin view of store orders (product purchases only), separate
/// from membership payments. Lets the admin see product pictures, who bought what,
/// search by name/item, and reach customer contact/address for pickup or shipping.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Member> _memberCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _prefetchMembers(List<String> userIds) {
    for (final uid in userIds) {
      if (!_memberCache.containsKey(uid) && uid.isNotEmpty) {
        ref.read(adminRepositoryProvider).buyer(uid).then((m) {
          if (m != null && mounted) {
            setState(() => _memberCache[uid] = m);
          }
        });
      }
    }
  }

  String? _findProductImageUrl(Payment order, List<Product> products) {
    Product? matched;
    if (order.productId != null && order.productId!.isNotEmpty) {
      matched = products.where((p) => p.id == order.productId).firstOrNull;
    }
    if (matched == null && order.productName != null) {
      matched = products
          .where((p) =>
              p.name?.trim().toLowerCase() ==
              order.productName?.trim().toLowerCase())
          .firstOrNull;
    }
    if (matched != null) {
      if ((matched.imageUrl ?? '').isNotEmpty) {
        return matched.imageUrl;
      }
      if (matched.imageUrls.isNotEmpty) {
        return matched.imageUrls.first;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(adminOrdersProvider);
    final productsList = ref.watch(productsAdminProvider).value ??
        ref.watch(productsProvider).value ??
        const <Product>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.storeOrders),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh orders',
            onPressed: () {
              ref.invalidate(adminOrdersProvider);
              ref.invalidate(productsAdminProvider);
              ref.invalidate(productsProvider);
            },
          ),
        ],
      ),
      body: orders.when(
        data: (rows) {
          final products = rows.where((p) => p.productId != null).toList();
          if (products.isEmpty) {
            return const JbbEmptyState(
              message: AppStrings.uiNoStoreOrdersYetTheyWillAppearHere,
            );
          }

          // Sort by creation date descending
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Prefetch buyer information for search
          final userIdsToFetch = products
              .map((e) => e.userId)
              .where((uid) => !_memberCache.containsKey(uid))
              .toSet()
              .toList();
          if (userIdsToFetch.isNotEmpty) {
            _prefetchMembers(userIdsToFetch);
          }

          // Filter by Search Query
          List<Payment> filtered = products;
          final query = _searchQuery.trim().toLowerCase();
          if (query.isNotEmpty) {
            filtered = filtered.where((order) {
              if ((order.productName ?? '').toLowerCase().contains(query)) {
                return true;
              }
              if ((order.size ?? '').toLowerCase().contains(query)) {
                return true;
              }
              if (order.id.toLowerCase().contains(query)) {
                return true;
              }
              final m = _memberCache[order.userId];
              if (m != null) {
                final fullName =
                    '${m.fullName ?? ''} ${m.lastName ?? ''}'.toLowerCase();
                if (fullName.contains(query)) return true;
                if (m.childName.toLowerCase().contains(query)) return true;
                if ((m.phone ?? '').contains(query)) return true;
                if ((m.email ?? '').toLowerCase().contains(query)) return true;
              }
              if (order.userId.toLowerCase().contains(query)) return true;
              return false;
            }).toList();
          }

          // Calculate total store sales
          final totalSales = products.fold<num>(
            0,
            (acc, curr) => acc + (curr.amount / 100),
          );

          return Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.s16,
                  AppSizes.s12,
                  AppSizes.s16,
                  AppSizes.s8,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by buyer, child, or product...',
                    hintStyle: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: AppSizes.font13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: context.palette.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.palette.separator.withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s16,
                      vertical: AppSizes.s12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Total Store Sales Banner (Green theme)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s16,
                  vertical: AppSizes.s6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.s14,
                    vertical: AppSizes.s10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radius10),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: AppSizes.s8),
                          Text(
                            'Store Sales (${products.length} orders)',
                            style: TextStyle(
                              fontSize: AppSizes.font13,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${totalSales.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: AppSizes.font16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Orders List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.s24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: context.palette.textSecondary,
                              ),
                              const SizedBox(height: AppSizes.s12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No orders found matching "$_searchQuery"'
                                    : 'No orders found',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppSizes.font15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: AppSizes.s8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: const Text('Clear Search'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.s16,
                          vertical: AppSizes.s8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final productImgUrl =
                              _findProductImageUrl(order, productsList);

                          return JbbCard(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              useRootNavigator: true,
                              isScrollControlled: true,
                              builder: (_) => _OrderDetailSheet(
                                order: order,
                                productImageUrl: productImgUrl,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Image Thumbnail
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radius10,
                                      ),
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: context.palette.separator
                                              .withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radius10,
                                          ),
                                        ),
                                        child: (productImgUrl != null &&
                                                productImgUrl.isNotEmpty)
                                            ? CachedNetworkImage(
                                                imageUrl: productImgUrl,
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                                errorWidget:
                                                    (context, url, error) =>
                                                        _fallbackProductIcon(
                                                            context),
                                                placeholder: (context, url) =>
                                                    Center(
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: context
                                                          .palette.accent,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : _fallbackProductIcon(context),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.s12),
                                    // Title & details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  order.size != null
                                                      ? '${order.productName ?? AppStrings.uiProduct} · Size ${order.size}'
                                                      : order.productName ??
                                                          AppStrings.uiProduct,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: AppSizes.font15,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: AppSizes.s8),
                                              Text(
                                                '\$${(order.amount / 100).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: AppSizes.font16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSizes.s4),
                                          // Buyer Name
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person_outline,
                                                size: 14,
                                                color: context
                                                    .palette.textSecondary,
                                              ),
                                              const SizedBox(
                                                  width: AppSizes.s4),
                                              Expanded(
                                                child: BuyerName(
                                                  userId: order.userId,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSizes.s4),
                                          // Date & Time
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: context
                                                    .palette.textSecondary,
                                              ),
                                              const SizedBox(
                                                  width: AppSizes.s4),
                                              Text(
                                                '${dateLabel(readDate(order.createdAt))} · ${timeLabel(readDate(order.createdAt))}',
                                                style: TextStyle(
                                                  color: context
                                                      .palette.textSecondary,
                                                  fontSize: AppSizes.font12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.estimatedDeliveryDate != null) ...[
                                  const SizedBox(height: AppSizes.s10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSizes.s10,
                                      vertical: AppSizes.s6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.palette.accent
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radius8,
                                      ),
                                      border: Border.all(
                                        color: context.palette.accent
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_shipping_outlined,
                                          size: 14,
                                          color: context.palette.accent,
                                        ),
                                        const SizedBox(width: AppSizes.s6),
                                        Flexible(
                                          child: Text(
                                            'Delivery: ${dateLabel(readDate(order.estimatedDeliveryDate))}',
                                            style: TextStyle(
                                              color: context.palette.accent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: AppSizes.font12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSizes.s12),
                                const Divider(height: 1),
                                const SizedBox(height: AppSizes.s8),
                                // Bottom row: Status Badge & Direct Profile Button
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _OrderStatusBadge(status: order.status),
                                    InkWell(
                                      onTap: () => AdminMemberProfileSheet.show(
                                        context,
                                        order.userId,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radius20,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSizes.s10,
                                          vertical: AppSizes.s6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.palette.accent
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radius20,
                                          ),
                                          border: Border.all(
                                            color: context.palette.accent
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Profile',
                                              style: TextStyle(
                                                fontSize: AppSizes.font12,
                                                fontWeight: FontWeight.bold,
                                                color: context.palette.accent,
                                              ),
                                            ),
                                            const SizedBox(width: AppSizes.s4),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 10,
                                              color: context.palette.accent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        error: (e, s) => JbbEmptyState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(adminOrdersProvider),
        ),
        loading: () => const JbbLoading(),
      ),
    );
  }

  Widget _fallbackProductIcon(BuildContext context) {
    return Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        color: context.palette.accent,
        size: AppSizes.s24,
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (Color bg, Color text, String label, IconData icon) = switch (s) {
      'completed' || 'paid' || 'succeeded' => (
        Colors.green.withValues(alpha: 0.15),
        Colors.green.shade700,
        'Completed',
        Icons.check_circle_outline,
      ),
      'refunded' => (
        Colors.purple.withValues(alpha: 0.15),
        Colors.purple.shade700,
        'Refunded',
        Icons.replay,
      ),
      'pending' => (
        Colors.orange.withValues(alpha: 0.15),
        Colors.orange.shade800,
        'Pending',
        Icons.hourglass_empty,
      ),
      _ => (
        context.palette.separator,
        context.palette.textSecondary,
        status,
        Icons.info_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s8,
        vertical: AppSizes.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: AppSizes.s4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: AppSizes.font11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailSheet extends ConsumerStatefulWidget {
  const _OrderDetailSheet({
    required this.order,
    this.productImageUrl,
  });

  final Payment order;
  final String? productImageUrl;

  @override
  ConsumerState<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<_OrderDetailSheet> {
  Member? buyer;
  bool loading = true, busy = false;
  DateTime? deliveryDate;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.order.deliveryNote != null) {
      note.text = widget.order.deliveryNote!;
    }
    if (widget.order.estimatedDeliveryDate != null) {
      deliveryDate = readDate(widget.order.estimatedDeliveryDate);
    }
    ref
        .read(adminRepositoryProvider)
        .buyer(widget.order.userId)
        .then((value) {
          if (mounted) setState(() => buyer = value);
        })
        .whenComplete(() {
          if (mounted) setState(() => loading = false);
        });
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (deliveryDate == null) {
      showMessage(context, AppStrings.pickAnExpectedDeliveryPickupDate);
      return;
    }
    setState(() => busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setOrderDelivery(widget.order.id, deliveryDate!, note.text.trim());
      if (mounted) {
        showMessage(context, AppStrings.deliveryDateSaved);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteThisOrder),
        content: const Text(
          'This removes the order record only. It does not refund the '
          'customer or reverse fulfillment — use Refund first if the '
          'purchase itself needs to be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await ref.read(adminRepositoryProvider).deletePayment(widget.order.id);
      if (mounted) {
        showMessage(context, AppStrings.orderDeleted);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.s20,
          right: AppSizes.s20,
          top: AppSizes.s20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Product Header with Image
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.productImageUrl != null &&
                      widget.productImageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radius10),
                      child: CachedNetworkImage(
                        imageUrl: widget.productImageUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: AppSizes.s12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.order.size != null
                              ? '${widget.order.productName ?? AppStrings.uiOrder} · Size ${widget.order.size}'
                              : widget.order.productName ?? AppStrings.uiOrder,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font17,
                          ),
                        ),
                        const SizedBox(height: AppSizes.s4),
                        Row(
                          children: [
                            Text(
                              '\$${(widget.order.amount / 100).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.font16,
                              ),
                            ),
                            const SizedBox(width: AppSizes.s8),
                            _OrderStatusBadge(status: widget.order.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : delete,
                    icon: const AppIcon(AppIcons.trash),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s16),
              if (loading)
                const Center(child: JbbLoading())
              else
                Container(
                  padding: const EdgeInsets.all(AppSizes.s12),
                  decoration: BoxDecoration(
                    color: context.palette.separator.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                    border: Border.all(
                      color: context.palette.separator.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (buyer?.childName ?? '').trim().isNotEmpty
                                  ? buyer!.childName.trim()
                                  : '${buyer?.fullName ?? ''} ${buyer?.lastName ?? ''}'
                                      .trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.font15,
                              ),
                            ),
                          ),
                          // View full profile button
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.s8,
                                vertical: AppSizes.s4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => AdminMemberProfileSheet.show(
                              context,
                              widget.order.userId,
                            ),
                            icon: const Icon(Icons.person, size: 14),
                            label: const Text(
                              'Full Profile',
                              style: TextStyle(fontSize: AppSizes.font12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.s6),
                      if ((buyer?.phone ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSizes.s4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: context.palette.textSecondary,
                              ),
                              const SizedBox(width: AppSizes.s6),
                              Text(buyer!.phone!),
                            ],
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSizes.s4),
                          child: Text(AppStrings.uiNoPhoneOnFile),
                        ),
                      if ((buyer?.email ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSizes.s4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: context.palette.textSecondary,
                              ),
                              const SizedBox(width: AppSizes.s6),
                              Text(buyer!.email!),
                            ],
                          ),
                        ),
                      if ((buyer?.address ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.s2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: context.palette.textSecondary,
                              ),
                              const SizedBox(width: AppSizes.s6),
                              Expanded(
                                child: Text(
                                  '${buyer!.address}${(buyer?.zipCode ?? '').isNotEmpty ? ', ${buyer!.zipCode}' : ''}',
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: AppSizes.s2),
                          child: Text(AppStrings.uiNoAddressOnFile),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSizes.s16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  deliveryDate == null
                      ? 'Set expected delivery / pickup date'
                      : 'Expected ${dateLabel(deliveryDate!)}',
                ),
                trailing: const AppIcon(AppIcons.calendar),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: deliveryDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => deliveryDate = picked);
                },
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: AppStrings.noteForTheBuyerOptional,
                  hintText: AppStrings.eGShipsViaUspsOrReady,
                ),
              ),
              const SizedBox(height: AppSizes.s16),
              JbbButton(
                label: AppStrings.saveDeliveryDate,
                busy: busy,
                onPressed: widget.order.status == 'completed' ? save : null,
              ),
            ],
          ),
        ),
      );
}
