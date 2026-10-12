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
import '../../../booking/domain/booking.dart';
import '../../../profile/domain/member.dart';
import '../widgets/buyer_name.dart';

/// Dedicated admin view of class bookings, so the admin can see who
/// confirmed a session — with their full contact details — mark
/// attendance, or cancel on the member's behalf.
class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(adminBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.bookings)),
      body: bookingsAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const JbbEmptyState(
              message: AppStrings.noBookingsYetTheyWillAppearHere,
            );
          }

          final now = DateTime.now();
          final upcomingList = rows
              .where((b) => b.status == 'confirmed' && b.date.isAfter(now))
              .toList();
          final completedList = rows
              .where((b) =>
                  b.status == 'completed' ||
                  (b.status == 'confirmed' && b.endAt.isBefore(now)))
              .toList();
          final cancelledList = rows
              .where((b) => b.status == 'cancelled' || b.status == 'no-show')
              .toList();

          final filteredRows = switch (_selectedFilter) {
            'upcoming' => upcomingList,
            'completed' => completedList,
            'cancelled' => cancelledList,
            _ => rows,
          };

          return Column(
            children: [
              // Filter chips bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s16,
                  vertical: AppSizes.s8,
                ),
                child: Row(
                  children: [
                    _filterChip('all', 'All (${rows.length})'),
                    const SizedBox(width: AppSizes.s8),
                    _filterChip('upcoming', 'Upcoming (${upcomingList.length})'),
                    const SizedBox(width: AppSizes.s8),
                    _filterChip('completed', 'Completed (${completedList.length})'),
                    const SizedBox(width: AppSizes.s8),
                    _filterChip('cancelled', 'Cancelled (${cancelledList.length})'),
                  ],
                ),
              ),
              Expanded(
                child: filteredRows.isEmpty
                    ? Center(
                        child: Text(
                          'No $_selectedFilter bookings found',
                          style: TextStyle(color: context.palette.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.s16,
                          vertical: AppSizes.s8,
                        ),
                        itemCount: filteredRows.length,
                        itemBuilder: (context, index) {
                          final booking = filteredRows[index];
                          return JbbCard(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              useRootNavigator: true,
                              isScrollControlled: true,
                              builder: (_) => _BookingDetailSheet(booking: booking),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Class / Calendar leading icon
                                Container(
                                  width: AppSizes.s40,
                                  height: AppSizes.s40,
                                  decoration: BoxDecoration(
                                    color: context.palette.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppSizes.radius10),
                                  ),
                                  child: Center(
                                    child: AppIcon(
                                      AppIcons.calendarCheck,
                                      color: context.palette.accent,
                                      size: AppSizes.s22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.s12),
                                // Middle details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking.className.isEmpty
                                            ? AppStrings.uiClass
                                            : booking.className,
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
                                          BuyerName(userId: booking.userId),
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
                                            '${dateLabel(readDate(booking.date))} · ${timeLabel(readDate(booking.date))}',
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
                                // Right column: Status badge & Chevron arrow
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _BookingStatusBadge(status: booking.status),
                                    const SizedBox(height: AppSizes.s8),
                                    AppIcon(
                                      AppIcons.chevronRight,
                                      size: AppSizes.s18,
                                      color: context.palette.textSecondary,
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
          onRetry: () => ref.invalidate(adminBookingsProvider),
        ),
        loading: () => const JbbLoading(),
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      selectedColor: context.palette.accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? context.palette.accent : context.palette.textPrimary,
        fontSize: AppSizes.font13,
      ),
    );
  }
}

class _BookingStatusBadge extends StatelessWidget {
  const _BookingStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color text, String label) = switch (status.toLowerCase()) {
      'confirmed' => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          'Confirmed',
        ),
      'completed' => (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
          'Completed',
        ),
      'cancelled' => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          'Cancelled',
        ),
      'no-show' => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          'No-Show',
        ),
      _ => (
          context.palette.separator,
          context.palette.textSecondary,
          status.isNotEmpty ? status : 'Pending',
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
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: AppSizes.font11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _BookingDetailSheet extends ConsumerStatefulWidget {
  const _BookingDetailSheet({required this.booking});
  final Booking booking;
  @override
  ConsumerState<_BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends ConsumerState<_BookingDetailSheet> {
  Member? member;
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(adminRepositoryProvider)
        .buyer(widget.booking.userId)
        .then((value) {
          if (mounted) setState(() => member = value);
        })
        .whenComplete(() {
          if (mounted) setState(() => loading = false);
        });
  }

  Future<void> markAttendance(String status) async {
    setState(() => busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .markAttendance(widget.booking.id, status);
      if (mounted) {
        showMessage(
          context,
          status == 'completed'
              ? AppStrings.uiMarkedPresent
              : AppStrings.uiMarkedNoShow,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    final reason = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text(AppStrings.cancelThisBooking),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: AppStrings.reason),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.back),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                controller.text.trim().isEmpty
                    ? AppStrings.uiCancelledByAdmin
                    : controller.text.trim(),
              ),
              child: const Text(AppStrings.cancelBooking2),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    setState(() => busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .cancelBookingAsAdmin(widget.booking.id, reason);
      if (mounted) {
        showMessage(context, AppStrings.bookingCancelled);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.booking.status;
    final ended = widget.booking.endAt.isBefore(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.s20,
        right: AppSizes.s20,
        top: AppSizes.s12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSizes.s12),
                decoration: BoxDecoration(
                  color: context.palette.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.booking.className.isEmpty
                        ? AppStrings.uiBooking
                        : widget.booking.className,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.font18,
                    ),
                  ),
                ),
                _BookingStatusBadge(status: status),
              ],
            ),
            const SizedBox(height: AppSizes.s6),
            Text(
              '${dateLabel(widget.booking.date)} · ${timeLabel(widget.booking.date)}–${timeLabel(widget.booking.endAt)}',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: AppSizes.font13,
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            if (loading)
              const Center(child: JbbLoading())
            else
              Container(
                padding: const EdgeInsets.all(AppSizes.s14),
                decoration: BoxDecoration(
                  color: context.palette.separator.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  border: Border.all(
                    color: context.palette.separator,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${member?.fullName ?? ''} ${member?.lastName ?? ''}'.trim().isNotEmpty
                          ? '${member?.fullName ?? ''} ${member?.lastName ?? ''}'.trim()
                          : 'Member',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.font15,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s8),
                    _infoRow(
                      AppIcons.phone,
                      (member?.phone ?? '').isNotEmpty
                          ? member!.phone!
                          : AppStrings.uiNoPhoneOnFile,
                    ),
                    if ((member?.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSizes.s6),
                      _infoRow(AppIcons.mail, member!.email!),
                    ],
                    const SizedBox(height: AppSizes.s6),
                    _infoRow(
                      AppIcons.location,
                      (member?.address ?? '').isNotEmpty
                          ? '${member!.address}${(member?.zipCode ?? '').isNotEmpty ? ', ${member!.zipCode}' : ''}'
                          : AppStrings.uiNoAddressOnFile,
                    ),
                    if ((member?.childName ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSizes.s6),
                      _infoRow(
                        AppIcons.user,
                        'Participant: ${member!.childName}${(member?.childAge ?? 0) > 0 ? ' (${member!.childAge} yrs)' : ''}',
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSizes.s20),
            if (status == 'confirmed') ...[
              if (ended) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        onPressed: busy ? null : () => markAttendance('completed'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(AppStrings.present),
                      ),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => markAttendance('no-show'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text(AppStrings.noShow),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s8),
              ],
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                onPressed: busy ? null : cancel,
                child: const Text(AppStrings.cancelBooking2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String iconAsset, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            iconAsset,
            size: AppSizes.s16,
            color: context.palette.textSecondary,
          ),
          const SizedBox(width: AppSizes.s8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppSizes.font13,
                color: context.palette.textPrimary,
              ),
            ),
          ),
        ],
      );
}
