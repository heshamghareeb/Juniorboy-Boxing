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

/// Shown when a member taps a session card's joined-avatars stack — shows
/// the session's own details (type, date, time, capacity) plus every
/// joined member's name and photo in full.
class SessionMembersScreen extends ConsumerWidget {
  const SessionMembersScreen({super.key, required this.session});
  final SessionModel session;

  String get _typeLabel => switch (session.type) {
    'team' => 'Group',
    'duo' => 'Duo',
    _ => 'Individual',
  };

  String get _dateRange {
    final fmt = DateFormat('MMM d, yyyy');
    return session.startDate.day == session.endDate.day &&
            session.startDate.month == session.endDate.month &&
            session.startDate.year == session.endDate.year
        ? fmt.format(session.startDate)
        : '${fmt.format(session.startDate)} – ${fmt.format(session.endDate)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text(AppStrings.uiJoinedMembers)),
    body: Column(
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
                  _InfoChip(icon: AppIcons.user, label: _typeLabel),
                  _InfoChip(
                    icon: AppIcons.calendar,
                    label: _dateRange,
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
                '${session.joinedUserIds.length}/${session.maxParticipants} joined',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: AppSizes.font13,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: ref
                .read(sessionRepositoryProvider)
                .fetchMembers(session.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    AppStrings.uiNoOneHasJoinedYet,
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                );
              }
              if (!snapshot.hasData) return const JbbLoading();
              final members = snapshot.data!;
              if (members.isEmpty) {
                return Center(
                  child: Text(
                    AppStrings.uiNoOneHasJoinedYet,
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(AppSizes.s16),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.palette.accentTint,
                      backgroundImage: member.profilePicUrl != null
                          ? CachedNetworkImageProvider(member.profilePicUrl!)
                          : null,
                      child: member.profilePicUrl == null
                          ? AppIcon(AppIcons.user, color: context.palette.accent)
                          : null,
                    ),
                    title: Text(member.displayName),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
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
