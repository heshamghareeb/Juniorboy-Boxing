import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../membership/domain/membership_plan.dart';
import '../providers/admin_provider.dart';

class AssignPlanDialog extends ConsumerStatefulWidget {
  const AssignPlanDialog({
    super.key,
    required this.userId,
    this.memberName,
  });

  final String userId;
  final String? memberName;

  static Future<bool?> show(
    BuildContext context, {
    required String userId,
    String? memberName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignPlanDialog(
        userId: userId,
        memberName: memberName,
      ),
    );
  }

  @override
  ConsumerState<AssignPlanDialog> createState() => _AssignPlanDialogState();
}

class _AssignPlanDialogState extends ConsumerState<AssignPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _creditsController = TextEditingController();

  MembershipPlan? _selectedPlan;
  String _paymentMethod = 'Cash';
  bool _busy = false;
  bool _overrideCredits = false;

  final List<String> _paymentMethods = const [
    'Cash',
    'Card (Offline)',
    'Comp / Free',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  void _onPlanChanged(MembershipPlan? plan) {
    setState(() {
      _selectedPlan = plan;
      if (!_overrideCredits && plan != null) {
        _creditsController.text = (plan.sessionCount ?? 0).toString();
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedPlan == null) {
      showMessage(context, 'Please select a membership plan.');
      return;
    }
    if (_busy) return;

    setState(() => _busy = true);
    try {
      int? customCredits;
      if (_overrideCredits) {
        customCredits = int.tryParse(_creditsController.text.trim());
      }

      await ref.read(adminRepositoryProvider).assignMembershipPlan(
            userId: widget.userId,
            plan: _selectedPlan!,
            paymentMethod: _paymentMethod,
            customCredits: customCredits,
            note: _noteController.text.trim().isNotEmpty
                ? _noteController.text.trim()
                : null,
          );

      if (mounted) {
        showMessage(context, 'Plan assigned successfully!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(adminPlansProvider);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: AppSizes.s12, bottom: AppSizes.s8),
                decoration: BoxDecoration(
                  color: context.palette.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.palette.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.crown,
                        size: 20,
                        color: context.palette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Membership Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font17,
                          ),
                        ),
                        if (widget.memberName != null)
                          Text(
                            widget.memberName!,
                            style: TextStyle(
                              fontSize: AppSizes.font12,
                              color: context.palette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: plansAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSizes.s32),
                  child: Center(child: JbbLoading()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSizes.s24),
                  child: Center(
                    child: Text(
                      friendlyError(e),
                      style: TextStyle(color: context.palette.accent),
                    ),
                  ),
                ),
                data: (plans) {
                  final activePlans = plans.where((p) => p.isActive != false).toList();
                  if (activePlans.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSizes.s32),
                      child: Center(
                        child: Text('No active membership plans available.'),
                      ),
                    );
                  }

                  if (_selectedPlan == null && activePlans.isNotEmpty) {
                    _selectedPlan = activePlans.first;
                    _creditsController.text =
                        (_selectedPlan!.sessionCount ?? 0).toString();
                  }

                  return Form(
                    key: _formKey,
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(AppSizes.s16),
                      children: [
                        // Plan Selector
                        Text(
                          'Choose Plan / Package',
                          style: TextStyle(
                            fontSize: AppSizes.font13,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12),
                          decoration: BoxDecoration(
                            color: context.palette.surface,
                            borderRadius: BorderRadius.circular(AppSizes.radius12),
                            border: Border.all(color: context.palette.separator),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<MembershipPlan>(
                              value: _selectedPlan,
                              isExpanded: true,
                              items: activePlans.map((plan) {
                                return DropdownMenuItem(
                                  value: plan,
                                  child: Text(
                                    '${plan.name} - \$${(plan.price ?? 0).toStringAsFixed(0)} (${plan.sessionCount ?? 0} sessions)',
                                    style: const TextStyle(fontSize: AppSizes.font14),
                                  ),
                                );
                              }).toList(),
                              onChanged: _onPlanChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.s16),

                        // Plan Summary Card
                        if (_selectedPlan != null)
                          Container(
                            padding: const EdgeInsets.all(AppSizes.s12),
                            decoration: BoxDecoration(
                              color: context.palette.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppSizes.radius12),
                              border: Border.all(
                                color: context.palette.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedPlan!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppSizes.font15,
                                      ),
                                    ),
                                    Text(
                                      '\$${(_selectedPlan!.price ?? 0).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppSizes.font16,
                                        color: context.palette.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.s6),
                                Text(
                                  'Sessions: ${_selectedPlan!.sessionCount ?? 0} • Type: ${_selectedPlan!.trainingType ?? _selectedPlan!.category ?? "General"}',
                                  style: TextStyle(
                                    fontSize: AppSizes.font12,
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSizes.s16),

                        // Payment Method Selection
                        Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: AppSizes.font13,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.s8),
                        Wrap(
                          spacing: AppSizes.s8,
                          children: _paymentMethods.map((method) {
                            final selected = _paymentMethod == method;
                            return ChoiceChip(
                              label: Text(method),
                              selected: selected,
                              onSelected: (val) {
                                if (val) setState(() => _paymentMethod = method);
                              },
                              selectedColor: context.palette.accent,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : null,
                                fontWeight: selected ? FontWeight.bold : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSizes.s16),

                        // Custom Credits Checkbox
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Override session credits count',
                            style: TextStyle(fontSize: AppSizes.font14),
                          ),
                          value: _overrideCredits,
                          onChanged: (val) {
                            setState(() {
                              _overrideCredits = val ?? false;
                              if (!_overrideCredits && _selectedPlan != null) {
                                _creditsController.text =
                                    (_selectedPlan!.sessionCount ?? 0).toString();
                              }
                            });
                          },
                        ),
                        if (_overrideCredits) ...[
                          TextFormField(
                            controller: _creditsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Number of Sessions to Add',
                              hintText: 'e.g. 10',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.radius12),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.s16),
                        ],

                        // Notes field
                        TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: 'Notes (optional)',
                            hintText: 'e.g. Paid cash at front desk / receipt #1234',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radius12),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.s24),

                        // Submit Button
                        JbbButton(
                          label: 'Assign Plan & Credit Account',
                          busy: _busy,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
