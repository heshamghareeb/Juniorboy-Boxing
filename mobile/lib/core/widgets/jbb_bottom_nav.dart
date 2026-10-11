import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/widgets/sign_in_prompt_sheet.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import '../resources/app_icons.dart';
import '../resources/app_sizes.dart';
import '../resources/app_strings.dart';
import '../theme/app_palette.dart';
import 'app_icon.dart';

class JbbBottomNav extends ConsumerWidget {
  const JbbBottomNav({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).value?.role;
    final isAdmin = role == 'admin' || role == 'superAdmin';
    final authUser = ref.watch(authProvider).value;
    final isGuest = ref.watch(guestModeProvider) ||
        authUser == null ||
        authUser.isAnonymous;
    final items = [
      (AppStrings.navMore, AppIcons.navMore),
      (AppStrings.myBookings, AppIcons.navLog),
      (AppStrings.navHome, AppIcons.navHome),
      (AppStrings.navProfile, AppIcons.user),
      if (isAdmin) (AppStrings.adminDashboard, AppIcons.admin),
    ];
    return Container(
      decoration: BoxDecoration(
        color: context.palette.tabBar,
        border: Border(
          top: BorderSide(
            color: context.palette.separator,
            width: AppSizes.separatorWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final isRestrictedTab =
                          items[index].$1 == AppStrings.myBookings ||
                              items[index].$1 == AppStrings.navProfile;
                      if (isGuest && isRestrictedTab) {
                        final ok = await showSignInPrompt(context, ref);
                        if (ok && context.mounted) {
                          navigationShell.goBranch(
                            index,
                            initialLocation:
                                index == navigationShell.currentIndex,
                          );
                        }
                        return;
                      }
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          items[index].$2,
                          size: AppSizes.iconMedium,
                          color: index == navigationShell.currentIndex
                              ? context.palette.accent
                              : (isGuest &&
                                      (items[index].$1 ==
                                              AppStrings.myBookings ||
                                          items[index].$1 ==
                                              AppStrings.navProfile))
                                  ? context.palette.textSecondary
                                      .withValues(alpha: 0.5)
                                  : context.palette.textSecondary,
                        ),
                        const SizedBox(height: AppSizes.s4),
                        Text(
                          items[index].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppSizes.font10,
                            color: index == navigationShell.currentIndex
                                ? context.palette.accent
                                : (isGuest &&
                                        (items[index].$1 ==
                                                AppStrings.myBookings ||
                                            items[index].$1 ==
                                                AppStrings.navProfile))
                                    ? context.palette.textSecondary
                                        .withValues(alpha: 0.5)
                                    : context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
