import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../account/models/user_model.dart';
import '../../models/session_model.dart';
import '../providers/session_provider.dart';
import '../../../admin/presentation/providers/admin_provider.dart';
import '../../../admin/presentation/widgets/admin_member_profile_sheet.dart';
import '../../../admin/presentation/widgets/enroll_member_sheet.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Shown when a member taps a session card's joined-avatars stack — shows
/// the session's own details (type, date, time, capacity) plus every
/// joined member's name and photo in full.
class SessionMembersScreen extends ConsumerStatefulWidget {
  const SessionMembersScreen({super.key, required this.session});
  final SessionModel session;

  @override
  ConsumerState<SessionMembersScreen> createState() => _SessionMembersScreenState();
}

class _SessionMembersScreenState extends ConsumerState<SessionMembersScreen> {
  late Future<List<UserModel>> _membersFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    _membersFuture = ref.read(sessionRepositoryProvider).fetchMembers(widget.session.id);
  }

  String _typeLabel(SessionModel session) => switch (session.type) {
    'team' => 'Group',
    'duo' => 'Duo',
    _ => 'Individual',
  };

  String _dateRange(SessionModel session) {
    final fmt = DateFormat('MMM d, yyyy');
    return session.startDate.day == session.endDate.day &&
            session.startDate.month == session.endDate.month &&
            session.startDate.year == session.endDate.year
        ? fmt.format(session.startDate)
        : '${fmt.format(session.startDate)} – ${fmt.format(session.endDate)}';
  }

  Future<void> _confirmRemoveMember(UserModel member, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Session'),
        content: Text(
          'Are you sure you want to remove $displayName from this session? Their booking will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.palette.accent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    debugPrint('👉 [UI_REMOVE_DEBUG 1] Admin confirmed remove for: ${member.uid} ($displayName)');
    setState(() => _isProcessing = true);
    try {
      debugPrint('👉 [UI_REMOVE_DEBUG 2] Calling removeMemberFromSession on repository...');
      await ref.read(adminRepositoryProvider).removeMemberFromSession(
            sessionId: widget.session.id,
            userId: member.uid,
            reason: 'Removed by admin from session members list',
          );

      debugPrint('👉 [UI_REMOVE_DEBUG 3] Succeeded! Invalidating sessionsProvider and refreshing members...');
      ref.invalidate(sessionsProvider);
      setState(() {
        _loadMembers();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $displayName from session.'),
            backgroundColor: context.palette.accent,
          ),
        );
      }
    } catch (e) {
      debugPrint('👉 [UI_REMOVE_DEBUG ERROR] Exception in removeMember: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(profileProvider).value?.role;
    final isAdmin = role == 'admin' || role == 'superAdmin';

    final allSessions = ref.watch(sessionsProvider).value;
    final session = allSessions?.firstWhere(
          (s) => s.id == widget.session.id,
          orElse: () => widget.session,
        ) ??
        widget.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.uiJoinedMembers),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.s8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: context.palette.accent,
                ),
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final enrolled = await EnrollMemberSheet.show(
                          context,
                          session: session,
                        );
                        if (enrolled == true) {
                          ref.invalidate(sessionsProvider);
                          setState(() {
                            _loadMembers();
                          });
                        }
                      },
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text(
                  'Add Member',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.s16,
                  AppSizes.s16,
                  AppSizes.s16,
                  AppSizes.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.font18,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s6),
                    Wrap(
                      spacing: AppSizes.s12,
                      runSpacing: AppSizes.s4,
                      children: [
                        _InfoChip(icon: AppIcons.user, label: _typeLabel(session)),
                        _InfoChip(
                          icon: AppIcons.calendar,
                          label: _dateRange(session),
                        ),
                        _InfoChip(
                          icon: AppIcons.clock,
                          label: session.formattedTimes.isNotEmpty
                              ? session.formattedTimes
                              : '${session.startTime}–${session.endTime}',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.s6),
                    Text(
                      '${session.joinedUserIds.length}/${session.maxParticipants} total joined',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: AppSizes.font13,
                      ),
                    ),
                    if (session.resolvedTimeSlots.length > 1) ...[
                      const SizedBox(height: AppSizes.s8),
                      Wrap(
                        spacing: AppSizes.s8,
                        runSpacing: AppSizes.s4,
                        children: [
                          for (final s in session.resolvedTimeSlots)
                            _InfoChip(
                              icon: AppIcons.clock,
                              label:
                                  '${s.startTime}–${s.endTime}: ${s.joinedCount}/${s.maxParticipants}',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: session.joinedUserIds.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.uiNoOneHasJoinedYet,
                          style: TextStyle(color: context.palette.textSecondary),
                        ),
                      )
                    : FutureBuilder<List<UserModel>>(
                        future: _membersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const JbbLoading();
                          }
                          final members = snapshot.data ?? const [];
                          final count = session.joinedUserIds.length;
                          final showSlot = session.resolvedTimeSlots.length > 1;

                          return ListView.builder(
                            padding: const EdgeInsets.all(AppSizes.s16),
                            itemCount: members.isNotEmpty ? members.length : count,
                            itemBuilder: (context, index) {
                              if (index < members.length) {
                                final member = members[index];
                                final name = member.displayName.trim();
                                final display = name.isNotEmpty && name != 'Member'
                                    ? name
                                    : 'Member ${index + 1}';
                                return ListTile(
                                  onTap: isAdmin && member.uid.isNotEmpty
                                      ? () => AdminMemberProfileSheet.show(
                                            context,
                                            member.uid,
                                          )
                                      : null,
                                  leading: CircleAvatar(
                                    backgroundColor: context.palette.accentTint,
                                    backgroundImage: member.profilePicUrl != null &&
                                            member.profilePicUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            member.profilePicUrl!,
                                          )
                                        : null,
                                    child: member.profilePicUrl == null ||
                                            member.profilePicUrl!.isEmpty
                                        ? AppIcon(
                                            AppIcons.user,
                                            color: context.palette.accent,
                                          )
                                        : null,
                                  ),
                                  title: Text(display),
                                  subtitle: showSlot &&
                                          (member.timeSlot?.isNotEmpty ?? false)
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AppIcon(
                                              AppIcons.clock,
                                              size: AppSizes.s14,
                                              color: context.palette.accent,
                                            ),
                                            const SizedBox(width: AppSizes.s4),
                                            Text(
                                              member.timeSlot!,
                                              style: TextStyle(
                                                fontSize: AppSizes.font12,
                                                color: context.palette.textSecondary,
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                  trailing: isAdmin && member.uid.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.person_remove_outlined,
                                            color: Colors.redAccent,
                                            size: 22,
                                          ),
                                          tooltip: 'Remove from session',
                                          onPressed: _isProcessing
                                              ? null
                                              : () => _confirmRemoveMember(
                                                    member,
                                                    display,
                                                  ),
                                        )
                                      : null,
                                );
                              }
                              // Fallback when member profiles cannot be fetched
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: context.palette.accentTint,
                                  child: AppIcon(
                                    AppIcons.user,
                                    color: context.palette.accent,
                                  ),
                                ),
                                title: Text('Member ${index + 1}'),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black38,
              child: const Center(child: JbbLoading()),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final String icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(icon, size: AppSizes.s14, color: context.palette.accent),
      const SizedBox(width: AppSizes.s4),
      Text(
        label,
        style: TextStyle(
          fontSize: AppSizes.font12,
          color: context.palette.textSecondary,
        ),
      ),
    ],
  );
}
