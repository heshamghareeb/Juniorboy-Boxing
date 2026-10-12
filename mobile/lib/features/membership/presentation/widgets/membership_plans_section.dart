import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../../core/widgets/jbb_empty_state.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/sign_in_prompt_sheet.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/membership_plan.dart';
import '../providers/membership_provider.dart';
import '../widgets/plan_card.dart';

class MembershipPlansSection extends ConsumerStatefulWidget {
  const MembershipPlansSection({super.key});

  @override
  ConsumerState<MembershipPlansSection> createState() => _MembershipState();
}

class _MembershipState extends ConsumerState<MembershipPlansSection> {
  String selected = '';
  String _selectedType = 'all'; // 'all', 'group', 'private', 'duo'
  bool busy = false;

  Future<void> purchase() async {
    if (busy || selected.isEmpty) return;
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
    final plansAsync = ref.watch(plansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          AppStrings.chooseYourPlan,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSizes.s6),
        Text(
          'Select the training package that fits your schedule. No contracts or hidden fees.',
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: AppSizes.font13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSizes.s16),

        // User Current Session Credits Banner (if user has active credits)
        if (user != null && user.sessionsRemaining > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s14,
              vertical: AppSizes.s12,
            ),
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              border: Border.all(
                color: context.palette.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: AppSizes.s36,
                  height: AppSizes.s36,
                  decoration: BoxDecoration(
                    color: context.palette.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AppIcon(
                      AppIcons.crown,
                      size: AppSizes.s18,
                      color: context.palette.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.sessionsRemaining} Sessions Available',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.font14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${user.sessionsReserved} sessions reserved for classes',
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
          const SizedBox(height: AppSizes.s16),
        ],

        // Plans Stream Builder
        plansAsync.when(
          data: (rows) {
            final allPlans = [...rows]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

            if (allPlans.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.s24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.palette.separator.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: AppIcon(
                            AppIcons.crown,
                            size: 32,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.s16),
                      const Text(
                        'No Active Membership Plans',
                        style: TextStyle(
                          fontSize: AppSizes.font16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s8),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.s24,
                        ),
                        child: Text(
                          'Membership packages will appear here once published by the gym administration.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppSizes.font13,
                            color: context.palette.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.s16),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(plansProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Training type filter chips if multiple types exist
            final types = allPlans
                .map((p) => p.trainingType ?? 'group')
                .toSet()
                .toList();

            List<MembershipPlan> displayedPlans = allPlans;
            if (_selectedType != 'all') {
              displayedPlans = allPlans
                  .where((p) => (p.trainingType ?? 'group') == _selectedType)
                  .toList();
            }

            // Automatically select first plan if current selection is invalid
            if (displayedPlans.isNotEmpty &&
                !displayedPlans.any((p) => p.id == selected)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => selected = displayedPlans.first.id);
              });
            }

            MembershipPlan? selectedPlan;
            if (selected.isNotEmpty) {
              selectedPlan =
                  allPlans.where((p) => p.id == selected).firstOrNull;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (types.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: AppSizes.s12),
                    child: Row(
                      children: [
                        _filterChip('all', 'All Plans'),
                        const SizedBox(width: AppSizes.s8),
                        if (types.contains('group')) ...[
                          _filterChip('group', 'Group Training'),
                          const SizedBox(width: AppSizes.s8),
                        ],
                        if (types.contains('private')) ...[
                          _filterChip('private', 'Private 1-on-1'),
                          const SizedBox(width: AppSizes.s8),
                        ],
                        if (types.contains('duo'))
                          _filterChip('duo', 'Duo Training'),
                      ],
                    ),
                  ),
                ],

                // Plans List
                for (final plan in displayedPlans)
                  PlanCard(
                    plan: plan,
                    selected: selected == plan.id,
                    onTap: busy
                        ? () {}
                        : () => setState(() => selected = plan.id),
                  ),

                // Purchase Action Button
                if (selectedPlan != null) ...[
                  const SizedBox(height: AppSizes.s8),
                  JbbButton(
                    label:
                        'Continue to Purchase · ${selectedPlan.priceLabel}',
                    busy: busy,
                    onPressed: purchase,
                  ),
                  const SizedBox(height: AppSizes.s8),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: context.palette.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.s4),
                        Text(
                          'Secure payment powered by Stripe · Cancel anytime',
                          style: TextStyle(
                            fontSize: AppSizes.font11,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _filterChip(String typeKey, String label) {
    final isSelected = _selectedType == typeKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedType = typeKey),
      selectedColor: context.palette.accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color:
            isSelected ? context.palette.accent : context.palette.textPrimary,
        fontSize: AppSizes.font13,
      ),
    );
  }
}
