import '../../../../core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../core/resources/app_assets.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../providers/auth_provider.dart';

/// Entry screen: brand mark, Apple / Google sign-in buttons, and a Skip button
/// (continue as guest).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeState();
}

class _WelcomeState extends ConsumerState<WelcomeScreen> {
  bool busy = false;
  bool googleBusy = false;
  bool appleBusy = false;

  Future<void> skip() async {
    setState(() => busy = true);
    try {
      await ref.read(authRepositoryProvider).continueAsGuest();
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signInGoogle() async {
    setState(() => googleBusy = true);
    try {
      await ref.read(authRepositoryProvider).googleSignIn();
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => googleBusy = false);
    }
  }

  Future<void> signInApple() async {
    setState(() => appleBusy = true);
    try {
      await ref.read(authRepositoryProvider).appleSignIn();
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => appleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApple = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAnyBusy = busy || googleBusy || appleBusy;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s28),
          child: Column(
            children: [
              Spacer(),
              Image.asset(
                AppAssets.welcome,
                width: AppSizes.welcomeLogoWidth,
                semanticLabel: AppStrings.gymName,
              ),
              Spacer(),
              if (isApple) ...[
                // Apple sign-in button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: appleBusy
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
                          onPressed: isAnyBusy ? null : signInApple,
                          text: AppStrings.uiContinueWithApple,
                          height: AppSizes.buttonHeight,
                          style: isDark
                              ? SignInWithAppleButtonStyle.white
                              : SignInWithAppleButtonStyle.black,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radius12),
                        ),
                ),
                SizedBox(height: AppSizes.s12),
              ],
              // Google sign-in button
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: isAnyBusy ? null : signInGoogle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.textPrimary,
                    side: BorderSide(color: context.palette.textSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                    ),
                  ),
                  icon: googleBusy
                      ? SizedBox(
                          width: AppSizes.s18,
                          height: AppSizes.s18,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSizes.s2,
                          ),
                        )
                      : AppIcon(AppIcons.logIn),
                  label: Text(
                    AppStrings.uiContinueWithGoogle,
                    style: TextStyle(
                      fontSize: AppSizes.font17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSizes.s12),
              // Skip button (guest)
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: isAnyBusy ? null : skip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.palette.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                    ),
                  ),
                  icon: busy
                      ? SizedBox(
                          width: AppSizes.s18,
                          height: AppSizes.s18,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSizes.s2,
                            color: Colors.white,
                          ),
                        )
                      : AppIcon(AppIcons.fastForward),
                  label: Text(
                    AppStrings.uiSkip,
                    style: TextStyle(
                      fontSize: AppSizes.font17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSizes.s24),
            ],
          ),
        ),
      ),
    );
  }
}
