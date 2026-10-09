import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/utils/snackbar_utils.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.session.title),
        content: Text(
          'Join this session for \$${widget.session.price.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      final message = await ref
          .read(sessionRepositoryProvider)
          .join(widget.session.id);
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radius12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.palette.separator),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (session.images.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: session.images.first,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  Container(height: 160, color: context.palette.accentTint),
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.s12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.palette.background.withValues(alpha: 0),
                          context.palette.background.withValues(alpha: .9),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font18,
                            color: context.palette.textPrimary,
                          ),
                        ),
                        Text(
                          '$_dateRange · ${session.startTime}–${session.endTime}',
                          style: TextStyle(
                            color: context.palette.accent,
                            fontSize: AppSizes.font12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
    );
  }
}
