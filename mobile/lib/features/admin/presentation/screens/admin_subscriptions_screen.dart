import '../../../../core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../providers/admin_provider.dart';
import '../../../payments/domain/payment.dart';
import '../widgets/buyer_name.dart';

/// Dedicated admin view of membership purchases, separate from store
/// orders. Credits are added automatically on payment, so this is a
/// record/reporting view rather than something the admin has to act on.
class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key});
  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen> {
  String? busyId;

  Future<void> delete(Payment order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteThisSubscriptionRecord),
        content: const Text(
          'This removes the payment record only. It does not remove '
          'session credits already added — use Refund first if the '
          'purchase itself needs to be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busyId = order.id);
    try {
      await ref.read(adminRepositoryProvider).deletePayment(order.id);
      if (mounted) showMessage(context, AppStrings.recordDeleted);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(adminOrdersProvider);
    final plans = ref.watch(adminPlansProvider).value ?? [];
    final planNames = {
      for (final p in plans) p.id: p.name.isNotEmpty ? p.name : 'Plan',
    };

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.membershipSubscriptions)),
      body: orders.when(
        data: (rows) {
          final subs = rows.where((p) => p.membershipPlanId != null).toList();
          if (subs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: context.palette.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AppIcon(
                          AppIcons.crown,
                          color: context.palette.accent,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.s16),
                    Text(
                      AppStrings.noMembershipPurchasesYet,
                      style: const TextStyle(
                        fontSize: AppSizes.font18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.s8),
                    Text(
                      'When members purchase membership plans or training packages, their transactions, credits, and receipt records will appear here.',
                      style: TextStyle(
                        fontSize: AppSizes.font13,
                        color: context.palette.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final totalCents = subs.fold<num>(0, (sum, o) => sum + o.amount);

          return ListView(
            padding: const EdgeInsets.all(AppSizes.s16),
            children: [
              // Summary Banner
              Container(
                margin: const EdgeInsets.only(bottom: AppSizes.s16),
                padding: const EdgeInsets.all(AppSizes.s16),
                decoration: BoxDecoration(
                  color: context.palette.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  border: Border.all(
                    color: context.palette.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.s10),
                      decoration: BoxDecoration(
                        color: context.palette.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(
                        AppIcons.receipt,
                        color: context.palette.accent,
                        size: AppSizes.s20,
                      ),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${subs.length} Total Subscriptions',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.font14,
                            ),
                          ),
                          Text(
                            'Gross Revenue: \$${(totalCents / 100).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: AppSizes.font12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // List of Subscriptions
              ...subs.map(
                (order) => JbbCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Leading Crown Icon
                      Container(
                        width: AppSizes.s40,
                        height: AppSizes.s40,
                        decoration: BoxDecoration(
                          color: context.palette.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.radius10),
                        ),
                        child: Center(
                          child: AppIcon(
                            AppIcons.crown,
                            color: context.palette.accent,
                            size: AppSizes.s22,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.s12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planNames[order.membershipPlanId] ??
                                  AppStrings.navMembership,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.font16,
                              ),
                            ),
                            const SizedBox(height: AppSizes.s4),
                            Row(
                              children: [
                                AppIcon(
                                  AppIcons.user,
                                  size: AppSizes.s14,
                                  color: context.palette.textSecondary,
                                ),
                                const SizedBox(width: AppSizes.s4),
                                BuyerName(userId: order.userId),
                              ],
                            ),
                            const SizedBox(height: AppSizes.s4),
                            Row(
                              children: [
                                AppIcon(
                                  AppIcons.clock,
                                  size: AppSizes.s14,
                                  color: context.palette.textSecondary,
                                ),
                                const SizedBox(width: AppSizes.s4),
                                Text(
                                  '${dateLabel(readDate(order.createdAt))} · ${timeLabel(readDate(order.createdAt))}',
                                  style: TextStyle(
                                    color: context.palette.textSecondary,
                                    fontSize: AppSizes.font12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.s8),
                      // Price & Badges
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${(order.amount / 100).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.font15,
                            ),
                          ),
                          const SizedBox(height: AppSizes.s4),
                          if (order.credits != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.s6,
                                vertical: AppSizes.s2,
                              ),
                              decoration: BoxDecoration(
                                color: context.palette.separator.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(AppSizes.radius4),
                              ),
                              child: Text(
                                '${order.credits} credits',
                                style: TextStyle(
                                  fontSize: AppSizes.font11,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSizes.s4),
                          _SubscriptionStatusBadge(status: order.status),
                        ],
                      ),
                      IconButton(
                        onPressed: busyId != null ? null : () => delete(order),
                        icon: busyId == order.id
                            ? const SizedBox(
                                width: AppSizes.s18,
                                height: AppSizes.s18,
                                child: CircularProgressIndicator(
                                  strokeWidth: AppSizes.s2,
                                ),
                              )
                            : AppIcon(
                                AppIcons.trash,
                                color: Colors.red.shade400,
                                size: AppSizes.s18,
                              ),
                      ),
                    ],
                  ),
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
}

class _SubscriptionStatusBadge extends StatelessWidget {
  const _SubscriptionStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color text, String label) = switch (status.toLowerCase()) {
      'completed' || 'paid' || 'succeeded' => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          'Paid',
        ),
      'pending' => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          'Pending',
        ),
      'refunded' => (
          const Color(0xFFEDE7F6),
          const Color(0xFF512DA8),
          'Refunded',
        ),
      _ => (
          context.palette.separator,
          context.palette.textSecondary,
          status.isNotEmpty ? status : 'Unknown',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s6,
        vertical: AppSizes.s2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: AppSizes.font10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
