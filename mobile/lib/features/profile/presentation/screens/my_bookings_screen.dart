import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/domain/booking_eligibility.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../payments/domain/payment.dart';
import '../../../sessions/models/session_model.dart';
import '../../../sessions/presentation/providers/session_provider.dart';
import '../../../store/presentation/providers/store_provider.dart';
import '../providers/profile_provider.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});
  @override
  ConsumerState<MyBookingsScreen> createState() => _BookingsState();
}

class _BookingsState extends ConsumerState<MyBookingsScreen> {
  int selected = 0;
  final pending = <String>{};
  Future<bool> cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.cancelThisBooking),
        content: Text(AppStrings.yourReservedSessionCreditWillBeReleased),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.keepBooking),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.cancelBooking),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    setState(() => pending.add(booking.id));
    try {
      await ref.read(bookingRepositoryProvider).cancel(booking.id);
      if (mounted) showMessage(context, AppStrings.bookingCancelled);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => pending.remove(booking.id));
    }
    return false;
  }

String? _safeCurrentUid() {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
}

String? _safeCurrentEmail() {
  try {
    return FirebaseAuth.instance.currentUser?.email;
  } catch (_) {
    return null;
  }
}

  @override
  Widget build(BuildContext context) {
    final authUid = ref.watch(authProvider).value?.uid;
    final fbUid = _safeCurrentUid();
    final uid = fbUid ?? authUid;

    final sessionsAsync = ref.watch(sessionsProvider);
    final bookingsAsync = ref.watch(bookingsProvider);
    final paymentsAsync = ref.watch(paymentsProvider);

    final allSessions = sessionsAsync.value ?? const [];
    final mySessions = uid == null
        ? const <SessionModel>[]
        : allSessions.where((s) => s.joinedUserIds.contains(uid)).toList();

    final now = DateTime.now();
    final sessionItems = mySessions.where((s) {
      final upcoming = s.endDate.isAfter(now) || s.startDate.isAfter(now);
      return selected == 0 ? upcoming : !upcoming;
    }).toList();

    if (kDebugMode) {
      debugPrint('==================================================');
      debugPrint('[MY_BOOKINGS DEBUG 1] Authentication:');
      debugPrint('  - FirebaseAuth UID: $fbUid (Email: ${_safeCurrentEmail()})');
      debugPrint('  - AuthProvider UID: $authUid');
      debugPrint('  - Effective UID used: $uid');

      debugPrint('[MY_BOOKINGS DEBUG 2] Sessions State:');
      debugPrint('  - Status: ${sessionsAsync.isLoading ? "LOADING" : sessionsAsync.hasError ? "ERROR: ${sessionsAsync.error}" : "DATA"}');
      debugPrint('  - Total Sessions in DB: ${allSessions.length}');
      debugPrint('  - Sessions joined by user: ${mySessions.length}');
      for (final s in allSessions) {
        debugPrint('    * Session "${s.title}": joinedUserIds: ${s.joinedUserIds} (Start: ${s.startDate}, End: ${s.endDate})');
      }

      debugPrint('[MY_BOOKINGS DEBUG 3] Bookings State:');
      debugPrint('  - Status: ${bookingsAsync.isLoading ? "LOADING" : bookingsAsync.hasError ? "ERROR: ${bookingsAsync.error}" : "DATA"}');
      debugPrint('  - Total Bookings for user: ${bookingsAsync.value?.length ?? 0}');

      debugPrint('[MY_BOOKINGS DEBUG 4] Payments & Store Orders:');
      debugPrint('  - Status: ${paymentsAsync.isLoading ? "LOADING" : paymentsAsync.hasError ? "ERROR: ${paymentsAsync.error}" : "DATA"}');
      final allPayments = paymentsAsync.value ?? const <Payment>[];
      final storeOrders = allPayments.where((p) => p.productId != null).toList();
      final membershipPacks = allPayments.where((p) => p.membershipPlanId != null).toList();
      debugPrint('  - Total Payments count: ${allPayments.length}');
      debugPrint('  - Store Orders count: ${storeOrders.length}');
      for (final o in storeOrders) {
        debugPrint('    * Product: "${o.productName}" | Status: "${o.status}" | Size: "${o.size}" | Amount: \$${(o.amount / 100).toStringAsFixed(2)}');
      }
      debugPrint('  - Membership Packs count: ${membershipPacks.length}');
      debugPrint('==================================================');
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.myBookings)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bookingsProvider);
          ref.invalidate(sessionsProvider);
          ref.invalidate(paymentsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.s16),
          children: [
            const _MembershipPurchases(),
            const _StorePurchases(),
            SizedBox(height: AppSizes.s24),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(AppStrings.upcoming)),
                ButtonSegment(value: 1, label: Text(AppStrings.past)),
              ],
              selected: {selected},
              onSelectionChanged: (s) => setState(() => selected = s.first),
            ),
            SizedBox(height: AppSizes.s20),
            ref
                .watch(bookingsProvider)
                .when(
                  data: (rows) {
                    final items = rows.where((b) {
                      final upcoming = isUpcomingBooking(b, DateTime.now());
                      return selected == 0 ? upcoming : !upcoming;
                    }).toList();
                    if (items.isEmpty && sessionItems.isEmpty) {
                      return JbbEmptyState(message: AppStrings.noBookingsHereYet);
                    }
                    return Column(
                      children: [
                        for (final session in sessionItems)
                          _JoinedSessionCard(session: session),
                        for (final b in items) ...[
                          Builder(
                            builder: (context) {
                              final hours =
                                  ref
                                      .watch(settingsProvider)
                                      .value
                                      ?.cancellationPolicyHours ??
                                  24;
                              final allowed = canCancelBooking(b, DateTime.now(), hours);
                              return Dismissible(
                                key: ValueKey(b.id),
                                direction: allowed
                                    ? DismissDirection.endToStart
                                    : DismissDirection.none,
                                confirmDismiss: (_) => cancel(b),
                                background: Container(
                                  color: context.palette.accent,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.all(AppSizes.s20),
                                  child: AppIcon(AppIcons.circleX),
                                ),
                                child: JbbCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.className.isEmpty
                                            ? AppStrings.uiBoxingClass
                                            : b.className,
                                        style: TextStyle(
                                          fontSize: AppSizes.font18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if ((b.category ?? '').isNotEmpty)
                                        Text(
                                          b.category!.toUpperCase(),
                                          style: TextStyle(
                                            color: context.palette.accent,
                                            fontSize: AppSizes.font11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      SizedBox(height: AppSizes.s8),
                                      Text(
                                        '${dateLabel(b.date)} · ${timeLabel(b.date)} PT',
                                      ),
                                      SizedBox(height: AppSizes.s8),
                                      Text(
                                        b.status.toString().toUpperCase(),
                                        style: TextStyle(
                                          color: b.status == 'cancelled'
                                              ? context.palette.accent
                                              : context.palette.success,
                                          fontSize: AppSizes.font12,
                                        ),
                                      ),
                                      if (allowed)
                                        TextButton(
                                          onPressed: pending.contains(b.id)
                                              ? null
                                              : () => cancel(b),
                                          child: Text(AppStrings.cancelBooking),
                                        ),
                                      if (!allowed && b.status == 'confirmed')
                                        Padding(
                                          padding: EdgeInsets.only(top: AppSizes.s8),
                                          child: Text(
                                            AppStrings.uiForLateChangesContactTheGym,
                                            style: TextStyle(
                                              color: context.palette.textSecondary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                  error: (e, s) {
                    if (sessionItems.isNotEmpty) {
                      return Column(
                        children: [
                          for (final session in sessionItems)
                            _JoinedSessionCard(session: session),
                        ],
                      );
                    }
                    return JbbEmptyState(
                      message: friendlyError(e),
                      onRetry: () => ref.invalidate(bookingsProvider),
                    );
                  },
                  loading: () => sessionItems.isNotEmpty
                      ? Column(
                          children: [
                            for (final session in sessionItems)
                              _JoinedSessionCard(session: session),
                          ],
                        )
                      : const JbbLoading(),
                ),
          ],
        ),
      ),
    );
  }
}

class _MembershipPurchases extends ConsumerWidget {
  const _MembershipPurchases();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    final plans = ref.watch(plansProvider).value ?? const [];
    final purchases =
        (ref.watch(paymentsProvider).value ?? const <Payment>[])
            .where((p) => p.membershipPlanId != null && p.status == 'completed')
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (user == null || purchases.isEmpty) return const SizedBox.shrink();
    final used = <String, int>{};
    for (final type in ['private', 'group', 'duo']) {
      final sameType = purchases.where(
        (p) => (p.trainingType ?? 'private') == type,
      );
      final total = sameType.fold<int>(0, (sum, p) => sum + (p.credits ?? 0));
      final remaining = switch (type) {
        'group' => user.groupSessionsRemaining,
        'duo' => user.duoSessionsRemaining,
        _ => user.privateSessionsRemaining,
      };
      var toAllocate = (total - remaining).clamp(0, total);
      for (final p in sameType) {
        final count = p.credits ?? 0;
        used[p.id] = toAllocate.clamp(0, count);
        toAllocate -= used[p.id]!;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.membershipPurchases,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.font18,
          ),
        ),
        SizedBox(height: AppSizes.s12),
        for (final payment in purchases.reversed)
          JbbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plans
                                .where((p) => p.id == payment.membershipPlanId)
                                .firstOrNull
                                ?.name ??
                            '${payment.credits ?? 0}-Session Pack',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text('\$${(payment.amount / 100).toStringAsFixed(2)}'),
                  ],
                ),
                Text(
                  '${payment.credits ?? 0} sessions · ${payment.trainingType ?? 'private'}',
                ),
                Text(
                  '${used[payment.id] ?? 0} of ${payment.credits ?? 0} used',
                  style: TextStyle(color: context.palette.textSecondary),
                ),
                Text(
                  dateLabel(payment.createdAt),
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StorePurchases extends ConsumerWidget {
  const _StorePurchases();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProducts = ref.watch(productsProvider).value ?? const [];
    final adminProducts = ref.watch(productsAdminProvider).value ?? const [];
    final allProducts = adminProducts.isNotEmpty ? adminProducts : activeProducts;

    final purchases =
        (ref.watch(paymentsProvider).value ?? const <Payment>[])
            .where(
              (p) =>
                  p.productId != null &&
                  !['cancelled', 'canceled', 'refunded'].contains(
                    p.status.toLowerCase(),
                  ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (purchases.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcons.shoppingBag,
                size: AppSizes.s18,
                color: context.palette.accent,
              ),
              const SizedBox(width: AppSizes.s8),
              Text(
                AppStrings.storeOrders,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.font18,
                ),
              ),
              const SizedBox(width: AppSizes.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.palette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                  border: Border.all(
                    color: context.palette.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${purchases.length}',
                  style: TextStyle(
                    fontSize: AppSizes.font11,
                    fontWeight: FontWeight.bold,
                    color: context.palette.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          for (final payment in purchases)
            Builder(
              builder: (context) {
                final product = allProducts
                    .where(
                      (p) =>
                          p.id == payment.productId ||
                          (payment.productName != null &&
                              p.name?.toLowerCase() ==
                                  payment.productName!.toLowerCase()),
                    )
                    .firstOrNull;

                final imageUrl = (product?.imageUrl?.isNotEmpty == true)
                    ? product!.imageUrl
                    : (product?.imageUrls.isNotEmpty == true)
                        ? product!.imageUrls.first
                        : null;

                final hasSize = payment.size != null && payment.size!.isNotEmpty;
                final productName = payment.productName?.isNotEmpty == true
                    ? payment.productName!
                    : product?.name ?? AppStrings.uiProduct;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.s12),
                  child: JbbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radius12,
                              ),
                              child: Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  color: context.palette.elevated,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radius12,
                                  ),
                                  border: Border.all(
                                    color: context.palette.separator,
                                    width: 1,
                                  ),
                                ),
                                child: (imageUrl != null && imageUrl.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: context.palette.accent,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            _buildPlaceholderImage(context),
                                      )
                                    : _buildPlaceholderImage(context),
                              ),
                            ),
                            const SizedBox(width: AppSizes.s14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (product?.category != null &&
                                      product!.category!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.palette.accent
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radius4,
                                        ),
                                      ),
                                      child: Text(
                                        product.category!.toUpperCase(),
                                        style: TextStyle(
                                          color: context.palette.accent,
                                          fontSize: AppSizes.font10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: AppSizes.font16,
                                      letterSpacing: -0.2,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: AppSizes.s6),
                                  Wrap(
                                    spacing: AppSizes.s6,
                                    runSpacing: AppSizes.s4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (hasSize)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSizes.s8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.palette.surface,
                                            borderRadius:
                                                BorderRadius.circular(
                                              AppSizes.radius4,
                                            ),
                                            border: Border.all(
                                              color: context.palette.separator,
                                            ),
                                          ),
                                          child: Text(
                                            'Size: ${payment.size}',
                                            style: TextStyle(
                                              fontSize: AppSizes.font11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  context.palette.textSecondary,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        dateLabel(payment.createdAt),
                                        style: TextStyle(
                                          fontSize: AppSizes.font12,
                                          color:
                                              context.palette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSizes.s8),
                            Text(
                              '\$${(payment.amount / 100).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.font17,
                                color: context.palette.accent,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: AppSizes.s12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.s12,
                            vertical: AppSizes.s8,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.surface.withValues(
                              alpha: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radius8,
                            ),
                            border: Border.all(
                              color: context.palette.separator.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.palette.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.palette.success
                                          .withValues(alpha: 0.45),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSizes.s8),
                              Expanded(
                                child: Text(
                                  payment.estimatedDeliveryDate != null
                                      ? 'Pickup scheduled: ${dateLabel(payment.estimatedDeliveryDate!)}'
                                      : 'Ready for pickup at gym 🥊',
                                  style: TextStyle(
                                    color: context.palette.textPrimary,
                                    fontSize: AppSizes.font12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (payment.deliveryNote != null &&
                                  payment.deliveryNote!.isNotEmpty)
                                Text(
                                  payment.deliveryNote!,
                                  style: TextStyle(
                                    color: context.palette.textSecondary,
                                    fontSize: AppSizes.font11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static Widget _buildPlaceholderImage(BuildContext context) {
    return Center(
      child: AppIcon(
        AppIcons.boxingGlove,
        size: AppSizes.s32,
        color: context.palette.accent.withValues(alpha: 0.8),
      ),
    );
  }
}

class _JoinedSessionCard extends StatelessWidget {
  const _JoinedSessionCard({required this.session});
  final SessionModel session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s12),
      child: JbbCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          onTap: () => context.safeNavigate(
            AppRoutes.sessionMembers,
            extra: session,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (session.images.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                  child: CachedNetworkImage(
                    imageUrl: session.images.first,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppSizes.s10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: const TextStyle(
                        fontSize: AppSizes.font18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s8,
                      vertical: AppSizes.s4,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                      border: Border.all(
                        color: context.palette.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'SESSION',
                      style: TextStyle(
                        color: context.palette.accent,
                        fontSize: AppSizes.font11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s6),
              Text(
                '${dateLabel(session.startDate)} – ${dateLabel(session.endDate)} · ${session.startTime}–${session.endTime}',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: AppSizes.font13,
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.palette.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSizes.s6),
                      Text(
                        'ENROLLED',
                        style: TextStyle(
                          color: context.palette.success,
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.font12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${session.joinedUserIds.length}/${session.maxParticipants} joined',
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
      ),
    );
  }
}
