import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../profile/domain/member.dart';
import '../providers/admin_provider.dart';

class AdjustCreditsDialog extends ConsumerStatefulWidget {
  const AdjustCreditsDialog({
    super.key,
    required this.member,
  });

  final Member member;

  static Future<bool?> show(BuildContext context, {required Member member}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdjustCreditsDialog(member: member),
    );
  }

  @override
  ConsumerState<AdjustCreditsDialog> createState() => _AdjustCreditsDialogState();
}

class _AdjustCreditsDialogState extends ConsumerState<AdjustCreditsDialog> {
  final _reasonController = TextEditingController();
  int _groupDelta = 0;
  int _privateDelta = 0;
  int _duoDelta = 0;
  bool _busy = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_groupDelta == 0 && _privateDelta == 0 && _duoDelta == 0) {
      showMessage(context, 'No changes made.');
      return;
    }
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).adjustCredits(
            userId: widget.member.id,
            groupDelta: _groupDelta,
            privateDelta: _privateDelta,
            duoDelta: _duoDelta,
            reason: _reasonController.text.trim().isNotEmpty
                ? _reasonController.text.trim()
                : null,
          );

      if (mounted) {
        showMessage(context, 'Credits updated successfully!');
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
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final name = '${widget.member.fullName ?? ''} ${widget.member.lastName ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : 'Member';

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
                      child: Icon(
                        Icons.tune,
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
                          'Adjust Session Credits',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font17,
                          ),
                        ),
                        Text(
                          displayName,
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
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSizes.s16),
                children: [
                  // Explanatory note
                  Container(
                    padding: const EdgeInsets.all(AppSizes.s12),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                      border: Border.all(color: context.palette.separator),
                    ),
                    child: Text(
                      'Use + or - to add or deduct session credits. Negative adjustments will decrease the remaining balance.',
                      style: TextStyle(
                        fontSize: AppSizes.font12,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s16),

                  // Group Credits Row
                  _creditAdjustRow(
                    label: 'Group Sessions',
                    current: widget.member.groupSessionsRemaining,
                    delta: _groupDelta,
                    onMinus: () => setState(() => _groupDelta--),
                    onPlus: () => setState(() => _groupDelta++),
                    onReset: () => setState(() => _groupDelta = 0),
                  ),
                  const Divider(height: AppSizes.s20),

                  // Private Credits Row
                  _creditAdjustRow(
                    label: 'Private Sessions',
                    current: widget.member.privateSessionsRemaining,
                    delta: _privateDelta,
                    onMinus: () => setState(() => _privateDelta--),
                    onPlus: () => setState(() => _privateDelta++),
                    onReset: () => setState(() => _privateDelta = 0),
                  ),
                  const Divider(height: AppSizes.s20),

                  // Duo Credits Row
                  _creditAdjustRow(
                    label: 'Duo Sessions',
                    current: widget.member.duoSessionsRemaining,
                    delta: _duoDelta,
                    onMinus: () => setState(() => _duoDelta--),
                    onPlus: () => setState(() => _duoDelta++),
                    onReset: () => setState(() => _duoDelta = 0),
                  ),
                  const SizedBox(height: AppSizes.s20),

                  // Reason text field
                  TextFormField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason / Note (optional)',
                      hintText: 'e.g. Free trial bonus / manual fix',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s24),

                  // Submit Button
                  JbbButton(
                    label: 'Save Credit Adjustments',
                    busy: _busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creditAdjustRow({
    required String label,
    required int current,
    required int delta,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required VoidCallback onReset,
  }) {
    final projected = current + delta;
    final deltaStr = delta > 0 ? '+$delta' : '$delta';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.font15,
                ),
              ),
              const SizedBox(height: AppSizes.s4),
              Text(
                'Current: $current → New: $projected',
                style: TextStyle(
                  fontSize: AppSizes.font12,
                  color: delta != 0
                      ? context.palette.accent
                      : context.palette.textSecondary,
                  fontWeight: delta != 0 ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
        // Minus Button
        IconButton.filledTonal(
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: context.palette.surface,
            foregroundColor: context.palette.accent,
          ),
        ),
        // Delta Badge
        GestureDetector(
          onTap: delta != 0 ? onReset : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s8, vertical: AppSizes.s6),
            margin: const EdgeInsets.symmetric(horizontal: AppSizes.s6),
            decoration: BoxDecoration(
              color: delta == 0
                  ? context.palette.surface
                  : (delta > 0
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              border: Border.all(
                color: delta == 0
                    ? context.palette.separator
                    : (delta > 0 ? Colors.green : Colors.red),
              ),
            ),
            child: Text(
              deltaStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.font14,
                color: delta == 0
                    ? context.palette.textSecondary
                    : (delta > 0 ? Colors.green : Colors.red),
              ),
            ),
          ),
        ),
        // Plus Button
        IconButton.filledTonal(
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: context.palette.surface,
            foregroundColor: context.palette.accent,
          ),
        ),
      ],
    );
  }
}
