import '../../../../core/theme/app_palette.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_debug_config.dart';
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
import '../../../auth/presentation/widgets/sign_in_prompt_sheet.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../providers/profile_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider).value;
    final user = ref.watch(profileProvider).value;
    final isGuest = authUser == null;
    final themeMode = ref.watch(themeModeProvider);
    final favCount = ref.watch(totalFavoritesCountProvider);
    return PageContent(
      title: AppStrings.more,
      children: [
        JbbCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.avatarRadiusLarge,
                backgroundColor: context.palette.accentTint,
                backgroundImage: (!isGuest && (user?.avatarUrl ?? '').isNotEmpty)
                    ? CachedNetworkImageProvider(user!.avatarUrl!)
                    : null,
                child: (isGuest || (user?.avatarUrl ?? '').isEmpty)
                    ? AppIcon(AppIcons.user, color: context.palette.accent)
                    : null,
              ),
              SizedBox(width: AppSizes.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !isGuest
                          ? ((user?.childName.isNotEmpty ?? false)
                              ? user!.childName
                              : (user?.fullName ?? AppStrings.uiMember))
                          : 'Guest',
                      style: TextStyle(
                        fontSize: AppSizes.font20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isGuest &&
                        user != null &&
                        user.memberSince.millisecondsSinceEpoch > 0) ...[
                      Text(
                        'Member since ${dateLabel(readDate(user.memberSince))}',
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color: context.palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s2),
                      Text(
                        user.sessionsRemaining > 0
                            ? '${user.sessionsRemaining} session credits available'
                            : 'No active session package',
                        style: TextStyle(
                          fontSize: AppSizes.font11,
                          fontWeight: FontWeight.w600,
                          color: user.sessionsRemaining > 0
                              ? context.palette.accent
                              : context.palette.textSecondary,
                        ),
                      ),
                    ] else if (isGuest)
                      Text(
                        'Sign in to book sessions & memberships',
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color: context.palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (isGuest)
                TextButton(
                  onPressed: () => showSignInPrompt(context, ref),
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: context.palette.accent,
                      fontWeight: FontWeight.bold,
                    ),
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
              // (AppStrings.navMembership, AppIcons.crown, AppRoutes.membership),
              (AppStrings.gymStore, AppIcons.shoppingBag, AppRoutes.store),
            ])
              SettingsRow(
                icon: item.$2,
                title: item.$1,
                onTap: () async {
                  if (item.$3 == AppRoutes.bookings && isGuest) {
                    final ok = await showSignInPrompt(context, ref);
                    if (ok && context.mounted) {
                      context.safeNavigate(item.$3);
                    }
                    return;
                  }
                  context.safeNavigate(item.$3);
                },
              ),
            SettingsRow(
              icon: AppIcons.heart,
              title: AppStrings.favorites,
              trailing: (favCount > 0)
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.s8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$favCount',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.font11,
                        ),
                      ),
                    )
                  : null,
              onTap: () => context.safeNavigate(AppRoutes.favorites),
            ),
            for (final item in [
              (AppStrings.reviewsRatings, AppIcons.star, AppRoutes.reviews),
              // (AppStrings.myAccount, AppIcons.receipt, AppRoutes.payments),
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
        if (!isGuest) ...[
          SizedBox(height: AppSizes.s20),
          OutlinedButton(
            onPressed: () async {
              try {
                final authRepo = ref.read(authRepositoryProvider);
                final guestNotifier = ref.read(guestModeProvider.notifier);
                await authRepo.signOut();
                await guestNotifier.setGuest(false);
                ref.invalidate(profileProvider);
                ref.invalidate(bookingsProvider);
                ref.invalidate(paymentsProvider);
                if (context.mounted) context.go(AppRoutes.welcome);
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
        ] else ...[
          SizedBox(height: AppSizes.s20),
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton(
              onPressed: () => showSignInPrompt(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.palette.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                ),
              ),
              child: const Text(
                'Sign In / Create Account',
                style: TextStyle(
                  fontSize: AppSizes.font16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final account = ref.read(authRepositoryProvider).currentUser;
    final requiresPassword = account?.hasEmailProvider ?? false;

    if (AppDebugConfig.enableDeleteAccountLogs) {
      debugPrint('👉 [DELETE_ACCOUNT_DEBUG #0] Opening delete account confirmation dialog...');
    }

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => _DeleteAccountConfirmDialog(
        requiresPassword: requiresPassword,
        onDelete: (password) async {
          await ref.read(authRepositoryProvider).deleteAccount(
            password: password,
          );
        },
      ),
    );
  }
}

class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog({
    required this.requiresPassword,
    required this.onDelete,
  });

  final bool requiresPassword;
  final Future<void> Function(String? password) onDelete;

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final pwd = _passwordController.text.trim();
    if (widget.requiresPassword && pwd.isEmpty) {
      setState(() {
        _errorText = AppStrings.uiPasswordRequired;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await widget.onDelete(pwd.isNotEmpty ? pwd : null);
      if (AppDebugConfig.enableDeleteAccountLogs) {
        debugPrint('👉 [DELETE_ACCOUNT_DEBUG #8] deleteAccount finished. Showing snackbar & redirecting to Welcome...');
      }
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        showMessage(context, AppStrings.uiAccountDeleted);
        context.go(AppRoutes.welcome);
      }
    } catch (e, stack) {
      if (AppDebugConfig.enableDeleteAccountLogs) {
        debugPrint('❌ [DELETE_ACCOUNT_DEBUG_ERROR] UI caught error: $e');
        debugPrint('   └── Stack: $stack');
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e is FirebaseAuthException &&
            (e.code == 'wrong-password' || e.code == 'invalid-credential')) {
          _errorText = AppStrings.uiWrongPassword;
        }
      });
      if (e is! FirebaseAuthException ||
          (e.code != 'wrong-password' && e.code != 'invalid-credential')) {
        showMessage(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppStrings.uiDeleteAccountConfirmTitle,
        style: TextStyle(
          color: context.palette.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.uiDeleteAccountConfirmMessage,
              style: TextStyle(color: context.palette.textSecondary),
            ),
            if (widget.requiresPassword) ...[
              const SizedBox(height: 16),
              Text(
                AppStrings.uiDeleteAccountPasswordPrompt,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                autofocus: true,
                style: TextStyle(color: context.palette.textPrimary),
                decoration: InputDecoration(
                  labelText: AppStrings.uiPassword,
                  errorText: _errorText,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: context.palette.textSecondary,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                onSubmitted: (_) {
                  if (!_isLoading) _handleDelete();
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(
            AppStrings.uiCancel,
            style: TextStyle(
              color: _isLoading
                  ? context.palette.textTertiary
                  : context.palette.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _handleDelete,
          child: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.palette.accent,
                  ),
                )
              : Text(
                  AppStrings.uiDelete,
                  style: TextStyle(
                    color: context.palette.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
