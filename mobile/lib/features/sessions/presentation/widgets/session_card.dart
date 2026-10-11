import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import '../../models/session_model.dart';
import '../providers/session_provider.dart';
import 'avatar_stack.dart';

class SessionCard extends ConsumerStatefulWidget {
  const SessionCard({super.key, required this.session});
  final SessionModel session;
  @override
  ConsumerState<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<SessionCard> {
  bool busy = false;

  String get _dateRange {
    final session = widget.session;
    final fmt = DateFormat('MMM d');
    return session.startDate.day == session.endDate.day &&
            session.startDate.month == session.endDate.month &&
            session.startDate.year == session.endDate.year
        ? fmt.format(session.startDate)
        : '${fmt.format(session.startDate)} – ${fmt.format(session.endDate)}';
  }

  Future<void> join() async {
    final session = widget.session;
    final slots = session.resolvedTimeSlots;
    String? selectedSlot = slots.isNotEmpty
        ? '${slots.first.startTime}–${slots.first.endTime}'
        : null;

    final confirmedSlot = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radius16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.s20,
                AppSizes.s12,
                AppSizes.s20,
                AppSizes.s20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSizes.s16),
                      decoration: BoxDecoration(
                        color: context.palette.separator,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    session.title,
                    style: TextStyle(
                      fontSize: AppSizes.font18,
                      fontWeight: FontWeight.bold,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s4),
                  Text(
                    '$_dateRange · \$${session.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: AppSizes.font13,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  if (slots.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.s16),
                    Text(
                      slots.length > 1 ? 'Select Time Slot' : 'Session Time',
                      style: TextStyle(
                        fontSize: AppSizes.font14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s8),
                    ...slots.map((slot) {
                      final slotStr = '${slot.startTime}–${slot.endTime}';
                      final isSelected = selectedSlot == slotStr;
                      return InkWell(
                        onTap: slots.length > 1
                            ? () => setSheetState(() => selectedSlot = slotStr)
                            : null,
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSizes.s8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.s12,
                            vertical: AppSizes.s12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.palette.accent.withValues(alpha: 0.1)
                                : context.palette.surface,
                            borderRadius: BorderRadius.circular(AppSizes.radius8),
                            border: Border.all(
                              color: isSelected
                                  ? context.palette.accent
                                  : context.palette.separator,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AppIcon(
                                AppIcons.clock,
                                size: AppSizes.s16,
                                color: isSelected
                                    ? context.palette.accent
                                    : context.palette.textSecondary,
                              ),
                              const SizedBox(width: AppSizes.s10),
                              Expanded(
                                child: Text(
                                  slotStr,
                                  style: TextStyle(
                                    fontSize: AppSizes.font14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? context.palette.accent
                                        : context.palette.textPrimary,
                                  ),
                                ),
                              ),
                              if (slots.length > 1)
                                AppIcon(
                                  isSelected
                                      ? AppIcons.checkCircle
                                      : AppIcons.circle,
                                  size: AppSizes.s18,
                                  color: isSelected
                                      ? context.palette.accent
                                      : context.palette.textSecondary.withValues(alpha: 0.4),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: AppSizes.s16),
                  JbbButton(
                    label: 'Join · \$${session.price.toStringAsFixed(2)}',
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(selectedSlot ?? ''),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmedSlot == null) return;
    setState(() => busy = true);
    try {
      final message = await ref.read(sessionRepositoryProvider).join(
        session.id,
        timeSlot: confirmedSlot.isNotEmpty ? confirmedSlot : null,
      );
      if (mounted) showMessage(context, message);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get _typeLabel => switch (widget.session.type) {
    'team' => 'Group',
    'duo' => 'Duo',
    _ => 'Individual',
  };

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final joined = uid != null && session.joinedUserIds.contains(uid);
    final full = session.joinedUserIds.length >= session.maxParticipants;
    final role = ref.watch(profileProvider).value?.role;
    final isAdmin = role == 'admin' || role == 'superAdmin';
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radius12),
      child: Material(
        color: context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          side: BorderSide(color: context.palette.separator),
        ),
        child: InkWell(
          onTap: () => context.safeNavigate(
            AppRoutes.sessionDetail,
            extra: session,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (session.images.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: session.images.first,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      height: 170,
                      color: context.palette.accentTint,
                      child: Center(
                        child: AppIcon(
                          AppIcons.boxingGlove,
                          size: 36,
                          color: context.palette.accent,
                        ),
                      ),
                    ),
                  Positioned(
                    top: AppSizes.s10,
                    right: AppSizes.s10,
                    child: FavoriteHeartButton(
                      id: session.id,
                      type: FavoriteTargetType.session,
                      size: 20,
                      padding: const EdgeInsets.all(7),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.s14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.s8,
                            vertical: AppSizes.s2,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.accentTint,
                            borderRadius: BorderRadius.circular(AppSizes.radius8),
                          ),
                          child: Text(
                            _typeLabel,
                            style: TextStyle(
                              color: context.palette.accent,
                              fontSize: AppSizes.font11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.s8),
                        Expanded(
                          child: Text(
                            _dateRange,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: AppSizes.font12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.s8),
                    Text(
                      session.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.font17,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s10),
                    InkWell(
                      onTap: () => context.safeNavigate(
                        AppRoutes.sessionMembers,
                        extra: session,
                      ),
                      child: Row(
                        children: [
                          FutureBuilder(
                            future: ref
                                .read(sessionRepositoryProvider)
                                .fetchMembers(session.id),
                            builder: (context, snapshot) => AvatarStack(
                              photoUrls: [
                                for (final m in snapshot.data ?? const [])
                                  if (m.profilePicUrl != null) m.profilePicUrl!,
                              ],
                              totalCount: session.joinedUserIds.length,
                            ),
                          ),
                          const SizedBox(width: AppSizes.s8),
                          Text(
                            '${session.joinedUserIds.length}/${session.maxParticipants} joined',
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: AppSizes.font12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (session.resolvedTimeSlots.length > 1) ...[
                      const SizedBox(height: AppSizes.s10),
                      Wrap(
                        spacing: AppSizes.s6,
                        runSpacing: AppSizes.s6,
                        children: [
                          for (final slot in session.resolvedTimeSlots)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.s8,
                                vertical: AppSizes.s4,
                              ),
                              decoration: BoxDecoration(
                                color: context.palette.surface,
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radius8),
                                border: Border.all(
                                  color: context.palette.separator,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    AppIcons.clock,
                                    size: AppSizes.s12,
                                    color: context.palette.accent,
                                  ),
                                  const SizedBox(width: AppSizes.s4),
                                  Text(
                                    '${slot.startTime}–${slot.endTime}',
                                    style: TextStyle(
                                      color: context.palette.textSecondary,
                                      fontSize: AppSizes.font11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (!isAdmin) ...[
                      const SizedBox(height: AppSizes.s12),
                      JbbButton(
                        label: joined
                            ? "You're in"
                            : full
                            ? 'Full'
                            : 'Join · \$${session.price.toStringAsFixed(2)}',
                        busy: busy,
                        onPressed: joined || full ? null : join,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
