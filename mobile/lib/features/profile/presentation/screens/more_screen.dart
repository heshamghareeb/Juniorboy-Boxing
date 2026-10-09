import '../../../../core/theme/app_palette.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../../../core/widgets/page_content.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/social_links_row.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    return PageContent(
      title: AppStrings.more,
      children: [
        JbbCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.avatarRadiusLarge,
                backgroundColor: context.palette.accentTint,
                backgroundImage: (user?.avatarUrl ?? '').isNotEmpty
                    ? CachedNetworkImageProvider(user!.avatarUrl!)
                    : null,
                child: (user?.avatarUrl ?? '').isEmpty
                    ? AppIcon(AppIcons.user, color: context.palette.accent)
                    : null,
              ),
              SizedBox(width: AppSizes.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user?.childName.isNotEmpty ?? false)
                          ? user!.childName
                          : (user?.fullName ?? AppStrings.uiMember),
                      style: TextStyle(
                        fontSize: AppSizes.font20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user != null &&
                        user.memberSince.millisecondsSinceEpoch > 0)
                      Text(
                        'Member since ${dateLabel(readDate(user.memberSince))}',
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color: context.palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Center(child: SocialLinksRow()),
        SizedBox(height: 10),
        SettingsGroup(
          children: [
            for (final item in [
              (AppStrings.myBookings, AppIcons.calendar, AppRoutes.bookings),
              (AppStrings.navMembership, AppIcons.crown, AppRoutes.membership),
              (AppStrings.gymStore, AppIcons.shoppingBag, AppRoutes.store),
              (AppStrings.reviewsRatings, AppIcons.star, AppRoutes.reviews),
              (AppStrings.myAccount, AppIcons.receipt, AppRoutes.payments),
              (
                AppStrings.notifications,
                AppIcons.notification,
                AppRoutes.notifications,
              ),
              (AppStrings.contactUs, AppIcons.phone, AppRoutes.contact),
              (AppStrings.uiLocation, AppIcons.location, AppRoutes.contact),
              (AppStrings.uiAboutUs, AppIcons.info, AppRoutes.about),
              (AppStrings.blog, AppIcons.document, AppRoutes.blog),
              (AppStrings.uiPrivacyPolicy, AppIcons.shield, AppRoutes.privacy),
              (AppStrings.uiTermsOfService, AppIcons.document, AppRoutes.terms),
              (AppStrings.waiverDisclaimer, AppIcons.gavel, AppRoutes.waiver),
            ])
              SettingsRow(
                icon: item.$2,
                title: item.$1,
                onTap: () => context.safeNavigate(item.$3),
              ),
            SettingsRow(
              icon: AppIcons.appearance,
              title: 'Appearance',
              trailing: Text(
                themeMode.name[0].toUpperCase() + themeMode.name.substring(1),
                style: TextStyle(color: context.palette.textSecondary),
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                showDragHandle: true,
                builder: (sheetContext) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.s16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Appearance',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSizes.s16),
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (value) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(value.first);
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSizes.s20),
        OutlinedButton(
          onPressed: () async {
            try {
              if (context.mounted) context.go(AppRoutes.welcome);
              await ref.read(authRepositoryProvider).signOut();
            } catch (e) {
              if (context.mounted) showMessage(context, friendlyError(e));
            }
          },
          child: Text(
            AppStrings.signOut,
            style: TextStyle(color: context.palette.accent),
          ),
        ),
        SizedBox(height: AppSizes.s8),
        TextButton(
          onPressed: () => _confirmDeleteAccount(context, ref),
          child: Text(
            AppStrings.uiDeleteAccount,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: AppSizes.font13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppStrings.uiDeleteAccountConfirmTitle,
          style: TextStyle(
            color: dialogContext.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          AppStrings.uiDeleteAccountConfirmMessage,
          style: TextStyle(color: dialogContext.palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppStrings.uiCancel,
              style: TextStyle(color: dialogContext.palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppStrings.uiDelete,
              style: TextStyle(
                color: dialogContext.palette.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (context.mounted) {
        showMessage(context, AppStrings.uiAccountDeleted);
        context.go(AppRoutes.welcome);
      }
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
    }
  }
}
