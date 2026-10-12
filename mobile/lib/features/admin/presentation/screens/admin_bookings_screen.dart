import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../providers/admin_provider.dart';
import '../../../booking/domain/booking.dart';
import '../../../payments/domain/payment.dart';
import '../../../profile/domain/member.dart';
import '../../../sessions/models/session_model.dart';
import '../../../sessions/presentation/providers/session_provider.dart';
import '../widgets/buyer_name.dart';
import '../widgets/admin_member_profile_sheet.dart';

/// Unified representation of a session enrolment or class booking
class _UnifiedBookingItem {
  const _UnifiedBookingItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.slotTime,
    required this.date,
    required this.status,
    required this.isSession,
    this.rawBooking,
    this.rawPayment,
  });

  final String id;
  final String userId;
  final String title;
  final String slotTime;
  final DateTime date;
  final String status;
  final bool isSession;
  final Booking? rawBooking;
  final Payment? rawPayment;
}

/// Dedicated admin view of class bookings and session enrolments, so the admin
/// can search by member name, see the exact session and hour/slot members signed up for,
/// view their full profile, mark attendance, or cancel on their behalf.
class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen> {
  String _selectedStatus = 'all'; // 'all', 'upcoming', 'completed', 'cancelled'
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

  String _resolveSlotTime({
    required String userId,
    required String title,
    String? rawSlotTime,
    String? rawStartTime,
    String? rawEndTime,
    DateTime? rawDate,
    DateTime? rawEndAt,
    required List<SessionModel> sessions,
  }) {
    if (rawSlotTime != null && rawSlotTime.trim().isNotEmpty) {
      return rawSlotTime.trim();
    }
    if (rawStartTime != null && rawStartTime.trim().isNotEmpty) {
      if (rawEndTime != null && rawEndTime.trim().isNotEmpty) {
        return '${rawStartTime.trim()} – ${rawEndTime.trim()}';
      }
      return rawStartTime.trim();
    }

    final matchingSession = sessions.where(
      (s) => s.title.trim().toLowerCase() == title.trim().toLowerCase(),
    ).firstOrNull;

    if (matchingSession != null) {
      for (final slot in matchingSession.timeSlots) {
        if (slot.joinedUserIds.contains(userId)) {
          return '${slot.startTime} – ${slot.endTime}';
        }
      }
      if (matchingSession.formattedTimes.isNotEmpty) {
        return matchingSession.formattedTimes;
      }
      if (matchingSession.startTime.isNotEmpty) {
        return matchingSession.endTime.isNotEmpty
            ? '${matchingSession.startTime} – ${matchingSession.endTime}'
            : matchingSession.startTime;
      }
    }

    if (rawDate != null && rawEndAt != null && rawEndAt.isAfter(rawDate)) {
      return '${timeLabel(rawDate)} – ${timeLabel(rawEndAt)}';
    }
    if (rawDate != null) {
      return timeLabel(rawDate);
    }
    return 'Training Hour';
  }

  DateTime _resolveDate({
    required String title,
    required DateTime fallbackDate,
    required List<SessionModel> sessions,
  }) {
    final matching = sessions.where(
      (s) => s.title.trim().toLowerCase() == title.trim().toLowerCase(),
    ).firstOrNull;
    if (matching != null) {
      return matching.startDate;
    }
    return fallbackDate;
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(adminBookingsProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);
    final sessions = ref.watch(sessionsProvider).value ?? const <SessionModel>[];

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.bookings)),
      body: bookingsAsync.when(
        data: (bookingRows) {
          final payments = ordersAsync.value ?? const <Payment>[];
          final sessionPayments =
              payments.where((p) => p.sessionId != null && p.sessionId!.isNotEmpty).toList();

          final List<_UnifiedBookingItem> unifiedItems = [];

          // 1. Add Class Bookings
          for (final b in bookingRows) {
            final slot = _resolveSlotTime(
              userId: b.userId,
              title: b.className,
              rawSlotTime: b.timeSlot,
              rawStartTime: b.startTime,
              rawEndTime: b.endTime,
              rawDate: b.date,
              rawEndAt: b.endAt,
              sessions: sessions,
            );
            final resolvedDate = _resolveDate(
              title: b.className,
              fallbackDate: b.date,
              sessions: sessions,
            );

            unifiedItems.add(
              _UnifiedBookingItem(
                id: b.id,
                userId: b.userId,
                title: b.className.isNotEmpty ? b.className : 'Class Session',
                slotTime: slot,
                date: resolvedDate,
                status: b.status,
                isSession: false,
                rawBooking: b,
              ),
            );
          }

          // 2. Add Session Purchases/Enrollments from payments
          for (final sp in sessionPayments) {
            final title = (sp.sessionTitle != null && sp.sessionTitle!.isNotEmpty)
                ? sp.sessionTitle!
                : 'Training Session';
            final slot = _resolveSlotTime(
              userId: sp.userId,
              title: title,
              rawSlotTime: sp.timeSlot,
              rawDate: sp.createdAt,
              sessions: sessions,
            );
            final resolvedDate = _resolveDate(
              title: title,
              fallbackDate: sp.createdAt,
              sessions: sessions,
            );

            unifiedItems.add(
              _UnifiedBookingItem(
                id: sp.id,
                userId: sp.userId,
                title: title,
                slotTime: slot,
                date: resolvedDate,
                status: sp.status,
                isSession: true,
                rawPayment: sp,
              ),
            );
          }

          // 3. Add any enrolled members from sessionsProvider not already listed
          for (final s in sessions) {
            for (final uid in s.joinedUserIds) {
              final alreadyAdded = unifiedItems.any(
                (item) => item.userId == uid && item.title.toLowerCase() == s.title.toLowerCase(),
              );
              if (!alreadyAdded) {
                String slotStr = s.formattedTimes.isNotEmpty
                    ? s.formattedTimes
                    : '${s.startTime}–${s.endTime}';
                for (final slot in s.timeSlots) {
                  if (slot.joinedUserIds.contains(uid)) {
                    slotStr = '${slot.startTime} – ${slot.endTime}';
                    break;
                  }
                }
                unifiedItems.add(
                  _UnifiedBookingItem(
                    id: '${s.id}_$uid',
                    userId: uid,
                    title: s.title,
                    slotTime: slotStr.isNotEmpty ? slotStr : 'Session Time',
                    date: s.startDate,
                    status: 'confirmed',
                    isSession: true,
                  ),
                );
              }
            }
          }

          // Sort by date descending
          unifiedItems.sort((a, b) => b.date.compareTo(a.date));

          // Prefetch member names for search matching
          final userIdsToFetch = unifiedItems
              .map((e) => e.userId)
              .where((uid) => !_memberCache.containsKey(uid))
              .toSet()
              .toList();
          if (userIdsToFetch.isNotEmpty) {
            _prefetchMembers(userIdsToFetch);
          }

          if (unifiedItems.isEmpty) {
            return const JbbEmptyState(
              message: AppStrings.noBookingsYetTheyWillAppearHere,
            );
          }

          final now = DateTime.now();
          final upcomingList = unifiedItems
              .where((item) =>
                  item.status.toLowerCase() == 'confirmed' &&
                  (item.date.isAfter(now) || item.date.day == now.day))
              .toList();
          final completedList = unifiedItems
              .where((item) =>
                  item.status.toLowerCase() == 'completed' ||
                  (item.status.toLowerCase() == 'confirmed' && item.date.isBefore(now) && item.date.day != now.day))
              .toList();
          final cancelledList = unifiedItems
              .where((item) =>
                  item.status.toLowerCase() == 'cancelled' ||
                  item.status.toLowerCase() == 'no-show')
              .toList();

          // 1. Filter by Status
          List<_UnifiedBookingItem> filtered = switch (_selectedStatus) {
            'upcoming' => upcomingList,
            'completed' => completedList,
            'cancelled' => cancelledList,
            _ => unifiedItems,
          };



          // 3. Filter by Search Query
          final query = _searchQuery.trim().toLowerCase();
          if (query.isNotEmpty) {
            filtered = filtered.where((item) {
              if (item.title.toLowerCase().contains(query)) return true;
              if (item.slotTime.toLowerCase().contains(query)) return true;
              final m = _memberCache[item.userId];
              if (m != null) {
                final fullName = '${m.fullName ?? ''} ${m.lastName ?? ''}'.toLowerCase();
                if (fullName.contains(query)) return true;
                if (m.childName.toLowerCase().contains(query)) return true;
                if ((m.phone ?? '').contains(query)) return true;
                if ((m.email ?? '').toLowerCase().contains(query)) return true;
              }
              if (item.userId.toLowerCase().contains(query)) return true;
              return false;
            }).toList();
          }

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
                    hintText: 'Search by member, child, or session...',
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

              // Filter Chips: Status & Type
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s16,
                  vertical: AppSizes.s6,
                ),
                child: Row(
                  children: [
                    _statusChip('all', 'All (${unifiedItems.length})'),
                    const SizedBox(width: AppSizes.s8),
                    _statusChip('upcoming', 'Upcoming (${upcomingList.length})'),
                    const SizedBox(width: AppSizes.s8),
                    _statusChip('completed', 'Completed (${completedList.length})'),
                    if (cancelledList.isNotEmpty) ...[
                      const SizedBox(width: AppSizes.s8),
                      _statusChip('cancelled', 'Cancelled (${cancelledList.length})'),
                    ],
                  ],
                ),
              ),

              // Results List
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
                                    ? 'No results found for "$_searchQuery"'
                                    : 'No $_selectedStatus items found',
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
                          final item = filtered[index];
                          return JbbCard(
                            onTap: () {
                              if (item.rawBooking != null) {
                                showModalBottomSheet(
                                  context: context,
                                  useRootNavigator: true,
                                  isScrollControlled: true,
                                  builder: (_) => _BookingDetailSheet(
                                    booking: item.rawBooking!,
                                    slotTime: item.slotTime,
                                  ),
                                );
                              } else {
                                showModalBottomSheet(
                                  context: context,
                                  useRootNavigator: true,
                                  isScrollControlled: true,
                                  builder: (_) => _SessionEnrollmentDetailSheet(
                                    item: item,
                                  ),
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Session / Class icon container
                                    Container(
                                      width: AppSizes.s40,
                                      height: AppSizes.s40,
                                      decoration: BoxDecoration(
                                        color: item.isSession
                                            ? Colors.amber.withValues(alpha: 0.15)
                                            : context.palette.accent.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(AppSizes.radius10),
                                      ),
                                      child: Center(
                                        child: AppIcon(
                                          item.isSession
                                              ? AppIcons.crown
                                              : AppIcons.calendarCheck,
                                          color: item.isSession
                                              ? Colors.amber.shade800
                                              : context.palette.accent,
                                          size: AppSizes.s22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.s12),
                                    // Title & details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: AppSizes.font16,
                                                  ),
                                                ),
                                              ),
                                              // Type Tag
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: AppSizes.s6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: item.isSession
                                                      ? Colors.amber.withValues(alpha: 0.15)
                                                      : Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(AppSizes.radius4),
                                                ),
                                                child: Text(
                                                  item.isSession ? 'SESSION' : 'CLASS',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: item.isSession
                                                        ? Colors.amber.shade900
                                                        : Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSizes.s6),
                                          // Training Slot Badge (Protected with Expanded)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSizes.s8,
                                              vertical: AppSizes.s4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.palette.separator.withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(AppSizes.radius8),
                                              border: Border.all(
                                                color: context.palette.separator,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                AppIcon(
                                                  AppIcons.clock,
                                                  size: AppSizes.s14,
                                                  color: context.palette.accent,
                                                ),
                                                const SizedBox(width: AppSizes.s6),
                                                Expanded(
                                                  child: Text(
                                                    'Slot: ${item.slotTime}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: AppSizes.font12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.s8),
                                    // Status Badge & Chevron
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _BookingStatusBadge(status: item.status),
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
                                const Divider(height: AppSizes.s20),
                                // Bottom Row: Member Info + Direct Profile Button
                                Row(
                                  children: [
                                    AppIcon(
                                      AppIcons.user,
                                      size: AppSizes.s14,
                                      color: context.palette.textSecondary,
                                    ),
                                    const SizedBox(width: AppSizes.s6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          BuyerName(userId: item.userId),
                                          Text(
                                            dateLabel(item.date),
                                            style: TextStyle(
                                              color: context.palette.textSecondary,
                                              fontSize: AppSizes.font11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Direct "Profile" Chip Button
                                    InkWell(
                                      onTap: () => AdminMemberProfileSheet.show(
                                        context,
                                        item.userId,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(AppSizes.radius20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSizes.s10,
                                          vertical: AppSizes.s6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.palette.accent.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(AppSizes.radius20),
                                          border: Border.all(
                                            color: context.palette.accent.withValues(alpha: 0.3),
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
          onRetry: () {
            ref.invalidate(adminBookingsProvider);
            ref.invalidate(adminOrdersProvider);
            ref.invalidate(sessionsProvider);
          },
        ),
        loading: () => const JbbLoading(),
      ),
    );
  }

  Widget _statusChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatus = statusKey),
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
      'completed' || 'paid' || 'succeeded' => (
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
  const _BookingDetailSheet({
    required this.booking,
    required this.slotTime,
  });
  final Booking booking;
  final String slotTime;

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
            const SizedBox(height: AppSizes.s8),
            Container(
              padding: const EdgeInsets.all(AppSizes.s12),
              decoration: BoxDecoration(
                color: context.palette.separator.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(
                        AppIcons.clock,
                        size: AppSizes.s16,
                        color: context.palette.accent,
                      ),
                      const SizedBox(width: AppSizes.s8),
                      Expanded(
                        child: Text(
                          'Training Slot: ${widget.slotTime}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s6),
                  Row(
                    children: [
                      AppIcon(
                        AppIcons.calendar,
                        size: AppSizes.s16,
                        color: context.palette.textSecondary,
                      ),
                      const SizedBox(width: AppSizes.s8),
                      Text(
                        'Date: ${dateLabel(widget.booking.date)}',
                        style: TextStyle(
                          color: context.palette.textSecondary,
                          fontSize: AppSizes.font13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            if (loading)
              const Center(child: JbbLoading())
            else
              Container(
                padding: const EdgeInsets.all(AppSizes.s14),
                decoration: BoxDecoration(
                  color: context.palette.separator.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  border: Border.all(
                    color: context.palette.separator,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${member?.fullName ?? ''} ${member?.lastName ?? ''}'.trim().isNotEmpty
                                ? '${member?.fullName ?? ''} ${member?.lastName ?? ''}'.trim()
                                : 'Member',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.font15,
                            ),
                          ),
                        ),
                        // Direct profile action
                        InkWell(
                          onTap: () => AdminMemberProfileSheet.show(
                            context,
                            widget.booking.userId,
                          ),
                          borderRadius: BorderRadius.circular(AppSizes.radius20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.s10,
                              vertical: AppSizes.s6,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSizes.radius20),
                              border: Border.all(
                                color: context.palette.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person, size: 14, color: context.palette.accent),
                                const SizedBox(width: AppSizes.s4),
                                Text(
                                  'Profile',
                                  style: TextStyle(
                                    fontSize: AppSizes.font12,
                                    fontWeight: FontWeight.bold,
                                    color: context.palette.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
            const SizedBox(height: AppSizes.s16),
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

/// Detail sheet for Session enrolments
class _SessionEnrollmentDetailSheet extends StatelessWidget {
  const _SessionEnrollmentDetailSheet({required this.item});
  final _UnifiedBookingItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.s20,
        right: AppSizes.s20,
        top: AppSizes.s12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.font18,
                  ),
                ),
              ),
              _BookingStatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: AppSizes.s8),
          Container(
            padding: const EdgeInsets.all(AppSizes.s12),
            decoration: BoxDecoration(
              color: context.palette.separator.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSizes.radius10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(AppIcons.clock, size: AppSizes.s16, color: context.palette.accent),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: Text(
                        'Training Hour: ${item.slotTime}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.font14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s6),
                Text(
                  'Date: ${dateLabel(item.date)}',
                  style: TextStyle(
                    fontSize: AppSizes.font13,
                    color: context.palette.textSecondary,
                  ),
                ),
                if (item.rawPayment != null) ...[
                  const SizedBox(height: AppSizes.s4),
                  Text(
                    'Price: \$${(item.rawPayment!.amount / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.font13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s16),
          // Member section
          Container(
            padding: const EdgeInsets.all(AppSizes.s12),
            decoration: BoxDecoration(
              color: context.palette.separator.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppSizes.radius10),
            ),
            child: Row(
              children: [
                AppIcon(AppIcons.user, size: AppSizes.s18, color: context.palette.accent),
                const SizedBox(width: AppSizes.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enrolled Trainee',
                        style: TextStyle(
                          fontSize: AppSizes.font11,
                          color: Colors.grey,
                        ),
                      ),
                      BuyerName(userId: item.userId),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s20),
          FilledButton.icon(
            onPressed: () => AdminMemberProfileSheet.show(
              context,
              item.userId,
            ),
            icon: AppIcon(AppIcons.user, size: AppSizes.s16),
            label: const Text('Open Trainee Profile & Contact'),
          ),
        ],
      ),
    );
  }
}
