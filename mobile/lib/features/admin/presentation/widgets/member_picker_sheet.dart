import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../profile/domain/member.dart';
import '../providers/admin_provider.dart';

class MemberPickerSheet extends ConsumerStatefulWidget {
  const MemberPickerSheet({super.key});

  static Future<Member?> show(BuildContext context) {
    return showModalBottomSheet<Member>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MemberPickerSheet(),
    );
  }

  @override
  ConsumerState<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<MemberPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Member> _members = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
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
          _members = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Member',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.font17,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search),
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
            Expanded(
              child: _searching
                  ? const Center(child: JbbLoading())
                  : _members.isEmpty
                      ? Center(
                          child: Text(
                            'No members found',
                            style: TextStyle(color: context.palette.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                          itemCount: _members.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = _members[index];
                            return ListTile(
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
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  if ((m.email ?? '').isNotEmpty) m.email!,
                                  'Credits: ${m.sessionsRemaining}',
                                ].join(' • '),
                                style: TextStyle(
                                  fontSize: AppSizes.font12,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(m),
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
