import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../models/session_model.dart';
import '../providers/session_provider.dart';
import '../widgets/avatar_stack.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.session});
  final SessionModel session;

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  bool busy = false;
  int selectedSlotIndex = 0;

  String get _typeLabel => switch (widget.session.type) {
    'team' => 'Group',
    'duo' => 'Duo',
    _ => 'Individual',
  };

  String get _dateRange {
    final session = widget.session;
    final fmt = DateFormat('MMM d, yyyy');
    return session.startDate.day == session.endDate.day &&
            session.startDate.month == session.endDate.month &&
            session.startDate.year == session.endDate.year
        ? fmt.format(session.startDate)
        : '${fmt.format(session.startDate)} – ${fmt.format(session.endDate)}';
  }

  Future<void> join() async {
    final session = widget.session;
    final slots = session.resolvedTimeSlots;
    final chosenSlot = slots.isNotEmpty && selectedSlotIndex < slots.length
        ? '${slots[selectedSlotIndex].startTime}–${slots[selectedSlotIndex].endTime}'
        : null;

    setState(() => busy = true);
    try {
      final message = await ref.read(sessionRepositoryProvider).join(
        session.id,
        timeSlot: chosenSlot,
      );
      if (mounted) showMessage(context, message);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final joined = uid != null && session.joinedUserIds.contains(uid);
    final full = session.joinedUserIds.length >= session.maxParticipants;
    final role = ref.watch(profileProvider).value?.role;
    final isAdmin = role == 'admin' || role == 'superAdmin';
    final slots = session.resolvedTimeSlots;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(session.title),
        actions: [
          FavoriteHeartButton(
            id: session.id,
            type: FavoriteTargetType.session,
            size: 20,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Hero Image
            if (session.images.isNotEmpty)
              CachedNetworkImage(
                imageUrl: session.images.first,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 180,
                color: context.palette.accentTint,
                child: Center(
                  child: AppIcon(
                    AppIcons.boxingGlove,
                    size: 48,
                    color: context.palette.accent,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(AppSizes.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Wrap(
                    spacing: AppSizes.s8,
                    runSpacing: AppSizes.s8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.s10,
                          vertical: AppSizes.s4,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.accentTint,
                          borderRadius: BorderRadius.circular(AppSizes.radius8),
                        ),
                        child: Text(
                          _typeLabel,
                          style: TextStyle(
                            color: context.palette.accent,
                            fontSize: AppSizes.font12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.s10,
                          vertical: AppSizes.s4,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          borderRadius: BorderRadius.circular(AppSizes.radius8),
                          border: Border.all(color: context.palette.separator),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              AppIcons.calendar,
                              size: AppSizes.s12,
                              color: context.palette.accent,
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Text(
                              _dateRange,
                              style: TextStyle(
                                color: context.palette.textSecondary,
                                fontSize: AppSizes.font12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.s10,
                          vertical: AppSizes.s4,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          borderRadius: BorderRadius.circular(AppSizes.radius8),
                          border: Border.all(color: context.palette.separator),
                        ),
                        child: Text(
                          '\$${session.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: AppSizes.font12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s16),

                  // Session Title
                  Text(
                    session.title,
                    style: TextStyle(
                      fontSize: AppSizes.font24,
                      fontWeight: FontWeight.bold,
                      color: context.palette.textPrimary,
                    ),
                  ),

                  // Description
                  if (session.description.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.s16),
                    Text(
                      'About This Session',
                      style: TextStyle(
                        fontSize: AppSizes.font14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s6),
                    Text(
                      session.description,
                      style: TextStyle(
                        fontSize: AppSizes.font14,
                        height: 1.5,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],

                  // Session Timings Selection
                  if (slots.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.s24),
                    Text(
                      slots.length > 1 ? 'SELECT SESSION TIMING' : 'SESSION TIMING',
                      style: TextStyle(
                        fontSize: AppSizes.font12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s10),
                    for (int i = 0; i < slots.length; i++) ...[
                      () {
                        final slot = slots[i];
                        final slotStr = '${slot.startTime}–${slot.endTime}';
                        final isSelected = selectedSlotIndex == i;
                        return InkWell(
                          onTap: slots.length > 1
                              ? () => setState(() => selectedSlotIndex = i)
                              : null,
                          borderRadius: BorderRadius.circular(AppSizes.radius12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppSizes.s8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.s16,
                              vertical: AppSizes.s14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.palette.accent.withValues(alpha: 0.08)
                                  : context.palette.surface,
                              borderRadius: BorderRadius.circular(AppSizes.radius12),
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
                                  size: AppSizes.s18,
                                  color: isSelected
                                      ? context.palette.accent
                                      : context.palette.textSecondary,
                                ),
                                const SizedBox(width: AppSizes.s12),
                                Expanded(
                                  child: Text(
                                    slotStr,
                                    style: TextStyle(
                                      fontSize: AppSizes.font15,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
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
                                    size: AppSizes.s20,
                                    color: isSelected
                                        ? context.palette.accent
                                        : context.palette.textSecondary
                                            .withValues(alpha: 0.4),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }(),
                    ],
                  ],

                  // Joined Members section
                  const SizedBox(height: AppSizes.s24),
                  Text(
                    'PARTICIPANTS',
                    style: TextStyle(
                      fontSize: AppSizes.font12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s10),
                  InkWell(
                    onTap: () => context.safeNavigate(
                      AppRoutes.sessionMembers,
                      extra: session,
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.s14),
                      decoration: BoxDecoration(
                        color: context.palette.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radius12),
                        border: Border.all(color: context.palette.separator),
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
                          const SizedBox(width: AppSizes.s12),
                          Expanded(
                            child: Text(
                              '${session.joinedUserIds.length} / ${session.maxParticipants} joined',
                              style: TextStyle(
                                color: context.palette.textPrimary,
                                fontSize: AppSizes.font14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AppIcon(
                            AppIcons.chevronRight,
                            size: AppSizes.s16,
                            color: context.palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: !isAdmin
          ? Container(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.s20,
                AppSizes.s12,
                AppSizes.s20,
                AppSizes.s20,
              ),
              decoration: BoxDecoration(
                color: context.palette.surface,
                border: Border(top: BorderSide(color: context.palette.separator)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL PRICE',
                          style: TextStyle(
                            fontSize: AppSizes.font11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: context.palette.textSecondary,
                          ),
                        ),
                        Text(
                          '\$${session.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: AppSizes.font20,
                            fontWeight: FontWeight.bold,
                            color: context.palette.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSizes.s20),
                    Expanded(
                      child: JbbButton(
                        label: joined
                            ? "You're in"
                            : full
                                ? 'Full'
                                : 'Join Session',
                        busy: busy,
                        onPressed: joined || full ? null : join,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
