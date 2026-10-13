import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/staff_member.dart';
import '../providers/admin_provider.dart';
import '../widgets/staff_editor_sheet.dart';

class AdminStaffScreen extends ConsumerWidget {
  const AdminStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final currentUid = ref.watch(authProvider).value?.uid ?? '';
    final palette = context.palette;

    if (profile?.role != 'superAdmin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Management')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.s20),
            child: JbbEmptyState(
              message: 'Super administrator access is required to view or manage staff accounts.',
            ),
          ),
        ),
      );
    }

    final staffAsync = ref.watch(adminStaffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & Permissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: () => ref.invalidate(adminStaffProvider),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add staff',
            onPressed: () async {
              final updated = await StaffEditorSheet.show(context);
              if (updated == true) {
                ref.invalidate(adminStaffProvider);
              }
            },
          ),
        ],
      ),
      body: staffAsync.when(
        loading: () => const Center(child: JbbLoading()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load staff list:\n${friendlyError(error)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary),
                ),
                const SizedBox(height: AppSizes.s16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(adminStaffProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const JbbEmptyState(message: 'No staff accounts found.'),
                    const SizedBox(height: AppSizes.s16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await StaffEditorSheet.show(context);
                        if (updated == true) {
                          ref.invalidate(adminStaffProvider);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Staff Member'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sorted = List<StaffMember>.from(staffList)
            ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminStaffProvider);
              await ref.read(adminStaffProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.s16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.s12),
              itemBuilder: (context, index) {
                final staff = sorted[index];
                return _StaffMemberCard(
                  staff: staff,
                  isSelf: staff.uid == currentUid,
                  onEdit: () async {
                    final updated = await StaffEditorSheet.show(context, staff: staff);
                    if (updated == true) {
                      ref.invalidate(adminStaffProvider);
                    }
                  },
                  onRemove: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove Staff Access?'),
                        content: Text(
                          'Are you sure you want to revoke staff privileges for ${staff.displayName.isNotEmpty ? staff.displayName : staff.email}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      try {
                        await ref.read(adminRepositoryProvider).removeStaff(staff.uid);
                        if (context.mounted) {
                          showMessage(context, 'Staff access removed successfully.');
                          ref.invalidate(adminStaffProvider);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, friendlyError(e));
                        }
                      }
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StaffMemberCard extends StatelessWidget {
  const _StaffMemberCard({
    required this.staff,
    required this.isSelf,
    required this.onEdit,
    required this.onRemove,
  });

  final StaffMember staff;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isSuper = staff.isSuperAdmin;

    final activePerms = StaffPermissions.all.where((k) => staff.permissions[k] == true).toList();

    return JbbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name/Email + Role Badge
          Row(
            children: [
              CircleAvatar(
                radius: AppSizes.s20,
                backgroundColor: isSuper
                    ? const Color(0xFFE5A93C).withValues(alpha: 0.2)
                    : palette.accent.withValues(alpha: 0.15),
                child: Icon(
                  isSuper ? Icons.shield : Icons.admin_panel_settings,
                  color: isSuper ? const Color(0xFFE5A93C) : palette.accent,
                  size: AppSizes.s22,
                ),
              ),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.displayName.isNotEmpty ? staff.displayName : 'Unnamed',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.font15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      staff.email,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: AppSizes.font12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.s8),
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s10,
                  vertical: AppSizes.s4,
                ),
                decoration: BoxDecoration(
                  color: isSuper
                      ? const Color(0xFFE5A93C).withValues(alpha: 0.15)
                      : palette.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.s20),
                  border: Border.all(
                    color: isSuper
                        ? const Color(0xFFE5A93C).withValues(alpha: 0.4)
                        : palette.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isSuper ? 'Super Admin' : 'Admin',
                  style: TextStyle(
                    fontSize: AppSizes.font11,
                    fontWeight: FontWeight.bold,
                    color: isSuper ? const Color(0xFFE5A93C) : palette.accent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.s12),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.s12),

          // Permissions summary
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.key, size: AppSizes.s16, color: palette.textSecondary),
              const SizedBox(width: AppSizes.s6),
              Expanded(
                child: Text(
                  isSuper
                      ? 'All permissions granted'
                      : activePerms.isEmpty
                          ? 'No permissions assigned'
                          : '${activePerms.length} of ${StaffPermissions.all.length} permissions (${activePerms.map((k) => StaffPermissions.labels[k] ?? k).take(2).join(', ')}${activePerms.length > 2 ? '...' : ''})',
                  style: TextStyle(
                    fontSize: AppSizes.font12,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.s8),

          // Last sign in info
          Row(
            children: [
              Icon(Icons.access_time, size: AppSizes.s16, color: palette.textSecondary),
              const SizedBox(width: AppSizes.s6),
              Text(
                'Last active: ${staff.lastSignIn != null ? DateFormat('MMM d, y · h:mm a').format(staff.lastSignIn!) : 'Never'}',
                style: TextStyle(
                  fontSize: AppSizes.font12,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.s12),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: AppSizes.s16),
                label: const Text('Edit'),
              ),
              const SizedBox(width: AppSizes.s8),
              TextButton.icon(
                onPressed: isSelf ? null : onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline, size: AppSizes.s16),
                label: Text(isSelf ? 'Current User' : 'Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
