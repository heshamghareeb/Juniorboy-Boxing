import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../profile/domain/member.dart';
import '../../../sessions/models/session_model.dart';
import '../providers/admin_provider.dart';

class EnrollMemberSheet extends ConsumerStatefulWidget {
  const EnrollMemberSheet({
    super.key,
    required this.session,
  });

  final SessionModel session;

  static Future<bool?> show(BuildContext context, {required SessionModel session}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EnrollMemberSheet(session: session),
    );
  }

  @override
  ConsumerState<EnrollMemberSheet> createState() => _EnrollMemberSheetState();
}

class _EnrollMemberSheetState extends ConsumerState<EnrollMemberSheet> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Member> _searchResults = const [];
  Member? _selectedMember;
  String? _selectedTimeSlot;
  bool _searching = false;
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    final slots = widget.session.resolvedTimeSlots;
    if (slots.isNotEmpty) {
      _selectedTimeSlot = '${slots.first.startTime}–${slots.first.endTime}';
    }
    _doSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _doSearch(query);
    });
  }

  Future<void> _doSearch(String query) async {
    setState(() => _searching = true);
    try {
      final results =
          await ref.read(adminRepositoryProvider).searchMembers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _enroll() async {
    if (_selectedMember == null) {
      showMessage(context, 'Please select a member to enroll.');
      return;
    }
    if (_enrolling) return;

    setState(() => _enrolling = true);
    try {
      await ref.read(adminRepositoryProvider).enrollMemberInSession(
            sessionId: widget.session.id,
            userId: _selectedMember!.id,
            timeSlot: _selectedTimeSlot,
          );

      if (mounted) {
        showMessage(context, 'Member enrolled successfully!');
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      debugPrint('👉 [ENROLL_SHEET_ERROR] Error enrolling member: $e\n$st');
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  String _memberDisplayName(Member m) {
    final child = m.childName.trim();
    final full = '${m.fullName ?? ''} ${m.lastName ?? ''}'.trim();
    if (child.isNotEmpty) {
      return (full.isNotEmpty && full != child) ? '$child ($full)' : child;
    }
    return full.isNotEmpty ? full : 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final slots = widget.session.resolvedTimeSlots;

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
                        Icons.person_add_alt_1,
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
                          'Enroll Walk-in Member',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font17,
                          ),
                        ),
                        Text(
                          widget.session.title,
                          style: TextStyle(
                            fontSize: AppSizes.font12,
                            color: context.palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

            // Time Slot selection if multiple
            if (slots.length > 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.s16,
                  AppSizes.s12,
                  AppSizes.s16,
                  AppSizes.s0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Time Slot',
                      style: TextStyle(
                        fontSize: AppSizes.font12,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s6),
                    Wrap(
                      spacing: AppSizes.s8,
                      children: slots.map((s) {
                        final label = '${s.startTime}–${s.endTime}';
                        final selected = _selectedTimeSlot == label;
                        return ChoiceChip(
                          label: Text('$label (${s.joinedCount}/${s.maxParticipants})'),
                          selected: selected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedTimeSlot = label);
                          },
                          selectedColor: context.palette.accent,
                          labelStyle: TextStyle(
                            fontSize: AppSizes.font12,
                            color: selected ? Colors.white : null,
                            fontWeight: selected ? FontWeight.bold : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // Search Input
            Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search member by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _doSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.palette.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                    borderSide: BorderSide(color: context.palette.separator),
                  ),
                ),
              ),
            ),

            // Selected Member Banner (if chosen)
            if (_selectedMember != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                padding: const EdgeInsets.all(AppSizes.s12),
                decoration: BoxDecoration(
                  color: context.palette.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  border: Border.all(color: context.palette.accent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected: ${_memberDisplayName(_selectedMember!)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Credits: ${_selectedMember!.sessionsRemaining} available',
                            style: TextStyle(
                              fontSize: AppSizes.font12,
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedMember = null),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.s12),
            ],

            // Search Results List
            Expanded(
              child: _searching
                  ? const Center(child: JbbLoading())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'No members found',
                            style: TextStyle(color: context.palette.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = _searchResults[index];
                            final isAlreadyJoined =
                                widget.session.joinedUserIds.contains(m.id);
                            final isSelected = _selectedMember?.id == m.id;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.s8,
                                vertical: AppSizes.s4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: context.palette.accentTint,
                                backgroundImage: m.profilePicUrl != null &&
                                        m.profilePicUrl!.isNotEmpty
                                    ? CachedNetworkImageProvider(m.profilePicUrl!)
                                    : null,
                                child: m.profilePicUrl == null ||
                                        m.profilePicUrl!.isEmpty
                                    ? AppIcon(
                                        AppIcons.user,
                                        color: context.palette.accent,
                                        size: 18,
                                      )
                                    : null,
                              ),
                              title: Text(
                                _memberDisplayName(m),
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if ((m.email ?? '').isNotEmpty) m.email!,
                                  if ((m.phone ?? '').isNotEmpty) m.phone!,
                                  'Credits: ${m.sessionsRemaining}',
                                ].join(' • '),
                                style: TextStyle(
                                  fontSize: AppSizes.font12,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              trailing: isAlreadyJoined
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSizes.s8,
                                        vertical: AppSizes.s4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppSizes.radius6),
                                      ),
                                      child: const Text(
                                        'Joined',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: AppSizes.font11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelected
                                            ? Colors.green
                                            : context.palette.accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSizes.s12,
                                          vertical: AppSizes.s6,
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() => _selectedMember = m);
                                      },
                                      child: Text(isSelected ? 'Selected' : 'Select'),
                                    ),
                            );
                          },
                        ),
            ),

            // Confirm Enroll Button
            if (_selectedMember != null)
              Padding(
                padding: const EdgeInsets.all(AppSizes.s16),
                child: JbbButton(
                  label: 'Enroll ${_memberDisplayName(_selectedMember!)} Now',
                  busy: _enrolling,
                  onPressed: _enroll,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
