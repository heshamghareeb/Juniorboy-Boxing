import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/sign_in_prompt_sheet.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/membership_provider.dart';
import '../widgets/plan_card.dart';

class MembershipPlansSection extends ConsumerStatefulWidget {
  const MembershipPlansSection({super.key});
  @override
  ConsumerState<MembershipPlansSection> createState() => _MembershipState();
}

class _MembershipState extends ConsumerState<MembershipPlansSection> {
  String selected = 'ten';
  bool busy = false;
  Future<void> purchase() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final authUser = ref.read(authRepositoryProvider).currentUser;
      if (authUser == null || authUser.isAnonymous) {
        final ok = await showSignInPrompt(context, ref);
        if (ok && mounted) {
          showMessage(
            context,
            AppStrings.signedInCompleteYourProfileThenChoose,
          );
        }
        return;
      }
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      if (profile == null || !profile.isProfileComplete) {
        final completed = await context.push<bool>(AppRoutes.completeProfile);
        if (completed != true || !mounted) return;
      }
      final message = await ref
          .read(membershipRepositoryProvider)
          .purchase(selected);
      if (mounted) showMessage(context, message);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is FormatException ? e.message : friendlyError(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.chooseYourPlan, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSizes.s16),
        const Wrap(
          spacing: AppSizes.s8,
          children: [
            Chip(label: Text(AppStrings.buildConfidence)),
            Chip(label: Text(AppStrings.getStronger)),
            Chip(label: Text(AppStrings.realProgress)),
          ],
        ),
        const SizedBox(height: AppSizes.s16),
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.s20),
            child: Text(
              '${user.sessionsRemaining} sessions remaining · ${user.sessionsReserved} reserved',
            ),
          ),
        ref
            .watch(plansProvider)
            .when(
              data: (rows) {
                final plans = [...rows]
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                if (plans.isNotEmpty && !plans.any((p) => p.id == selected)) {
                  selected = plans.first.id;
                }
                return Column(
                  children: [
                    for (final plan in plans)
                      PlanCard(
                        plan: plan,
                        selected: selected == plan.id,
                        onTap: busy
                            ? () {}
                            : () => setState(() {
                                selected = plan.id;
                              }),
                      ),
                    if (plans.isEmpty)
                      const JbbEmptyState(
                        message: AppStrings
                            .uiMembershipPlansWillAppearHereWhenAvailable,
                      ),
                    if (plans.any((p) => p.id == selected))
                      JbbButton(
                        label: AppStrings.continueAction,
                        busy: busy,
                        onPressed: purchase,
                      ),
                  ],
                );
              },
              error: (e, s) => JbbEmptyState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(plansProvider),
              ),
              loading: () => const JbbLoading(),
            ),
      ],
    );
  }
}
