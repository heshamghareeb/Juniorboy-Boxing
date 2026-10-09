import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../providers/auth_provider.dart';

Future<bool> showSignInPrompt(BuildContext context, WidgetRef ref) async {
  final isApple = defaultTargetPlatform == TargetPlatform.iOS;
  if (!isApple) {
    try {
      await ref.read(authRepositoryProvider).googleSignIn();
      return ref.read(authRepositoryProvider).currentUser?.isAnonymous == false;
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
      return false;
    }
  }

  return await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radius20),
          ),
        ),
        builder: (sheetContext) => _SignInSheet(ref: ref),
      ) ??
      false;
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  bool busy = false;

  Future<void> _handle(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      final user = widget.ref.read(authRepositoryProvider).currentUser;
      if (mounted) {
        Navigator.of(context).pop(user != null && !user.isAnonymous);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.s24,
          AppSizes.s20,
          AppSizes.s24,
          AppSizes.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: AppSizes.s16),
            Text(
              AppStrings.uiSignInToContinue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.font20,
                fontWeight: FontWeight.bold,
                color: context.palette.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.s8),
            Text(
              AppStrings.uiSignInPromptSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.font14,
                color: context.palette.textSecondary,
              ),
            ),
            SizedBox(height: AppSizes.s24),
            // Sign in with Apple
            SizedBox(
              height: AppSizes.buttonHeight,
              child: busy
                  ? Center(
                      child: SizedBox(
                        width: AppSizes.s20,
                        height: AppSizes.s20,
                        child: CircularProgressIndicator(
                          strokeWidth: AppSizes.s2,
                          color: context.palette.accent,
                        ),
                      ),
                    )
                  : SignInWithAppleButton(
                      onPressed: () => _handle(
                        widget.ref.read(authRepositoryProvider).appleSignIn,
                      ),
                      text: AppStrings.uiContinueWithApple,
                      height: AppSizes.buttonHeight,
                      style: isDark
                          ? SignInWithAppleButtonStyle.white
                          : SignInWithAppleButtonStyle.black,
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                    ),
            ),
            SizedBox(height: AppSizes.s12),
            // Sign in with Google
            SizedBox(
              height: AppSizes.buttonHeight,
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _handle(
                          widget.ref.read(authRepositoryProvider).googleSignIn,
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.textPrimary,
                  side: BorderSide(color: context.palette.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                  ),
                ),
                icon: AppIcon(AppIcons.logIn),
                label: Text(
                  AppStrings.uiContinueWithGoogle,
                  style: TextStyle(
                    fontSize: AppSizes.font17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
