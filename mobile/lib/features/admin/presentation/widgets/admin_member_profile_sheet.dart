import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_loading.dart';
import '../../../profile/domain/member.dart';
import '../providers/admin_provider.dart';

/// Shows a comprehensive profile sheet for a member with their details,
/// remaining credits, contact information, and direct action buttons (Call/WhatsApp/Email).
class AdminMemberProfileSheet extends ConsumerStatefulWidget {
  const AdminMemberProfileSheet({super.key, required this.userId});
  final String userId;

  static Future<void> show(BuildContext context, String userId) =>
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AdminMemberProfileSheet(userId: userId),
      );

  @override
  ConsumerState<AdminMemberProfileSheet> createState() =>
      _AdminMemberProfileSheetState();
}

class _AdminMemberProfileSheetState
    extends ConsumerState<AdminMemberProfileSheet> {
  Member? member;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    try {
      final res = await ref.read(adminRepositoryProvider).buyer(widget.userId);
      if (mounted) {
        setState(() {
          member = res;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          loading = false;
        });
      }
    }
  }

  Future<void> _launchUri(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        showMessage(context, AppStrings.couldNotOpenThisLink);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    }
  }

  void _callPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    _launchUri(Uri.parse('tel:$clean'));
  }

  void _openWhatsApp(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    _launchUri(Uri.parse('https://wa.me/$clean'));
  }

  void _sendEmail(String email) {
    if (email.trim().isEmpty) return;
    _launchUri(Uri.parse('mailto:${email.trim()}'));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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
          // Top title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Client Profile',
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
          Expanded(
            child: loading
                ? const Center(child: JbbLoading())
                : error != null
                    ? Center(
                        child: Text(
                          error!,
                          style: TextStyle(color: context.palette.textSecondary),
                        ),
                      )
                    : member == null
                        ? Center(
                            child: Text(
                              'Member not found (${widget.userId})',
                              style: TextStyle(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          )
                        : _buildMemberContent(member!),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberContent(Member m) {
    final name = '${m.fullName ?? ''} ${m.lastName ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : 'Member';
    final hasPhone = (m.phone ?? '').trim().isNotEmpty;
    final hasEmail = (m.email ?? '').trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.s16),
      children: [
        // Member Avatar & Header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: context.palette.accent.withValues(alpha: 0.12),
                backgroundImage: m.profilePicUrl != null &&
                        m.profilePicUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(m.profilePicUrl!)
                    : null,
                child: m.profilePicUrl == null || m.profilePicUrl!.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName.substring(0, 1).toUpperCase()
                            : 'M',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: context.palette.accent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.font20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s8,
                      vertical: AppSizes.s2,
                    ),
                    decoration: BoxDecoration(
                      color: m.isActive == true
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    child: Text(
                      m.isActive == true ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: AppSizes.font11,
                        fontWeight: FontWeight.bold,
                        color: m.isActive == true
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s8,
                      vertical: AppSizes.s2,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.separator,
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    child: Text(
                      m.role != null && m.role!.isNotEmpty
                          ? m.role!.toUpperCase()
                          : 'MEMBER',
                      style: TextStyle(
                        fontSize: AppSizes.font11,
                        fontWeight: FontWeight.bold,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s20),

        // Quick Communication Buttons
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: AppIcons.phone,
                label: 'Call',
                enabled: hasPhone,
                onTap: () => _callPhone(m.phone!),
              ),
            ),
            const SizedBox(width: AppSizes.s8),
            Expanded(
              child: _actionButton(
                icon: AppIcons.whatsapp,
                label: 'WhatsApp',
                enabled: hasPhone,
                onTap: () => _openWhatsApp(m.phone!),
              ),
            ),
            const SizedBox(width: AppSizes.s8),
            Expanded(
              child: _actionButton(
                icon: AppIcons.mail,
                label: 'Email',
                enabled: hasEmail,
                onTap: () => _sendEmail(m.email!),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.s20),

        // Session Credits Card
        _sectionCard(
          title: 'Session Credits',
          icon: AppIcons.crown,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _creditPill(
                      'Private',
                      m.privateSessionsRemaining,
                      m.privateSessionsReserved,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: _creditPill(
                      'Group',
                      m.groupSessionsRemaining,
                      m.groupSessionsReserved,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: _creditPill(
                      'Duo',
                      m.duoSessionsRemaining,
                      m.duoSessionsReserved,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s8),
              Text(
                'Total Available Credits: ${m.sessionsRemaining} (${m.sessionsReserved} reserved)',
                style: TextStyle(
                  fontSize: AppSizes.font12,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s12),

        // Contact Information Card
        _sectionCard(
          title: 'Contact Information',
          icon: AppIcons.user,
          child: Column(
            children: [
              _infoTile(
                icon: AppIcons.phone,
                label: 'Phone Number',
                value: hasPhone ? m.phone! : 'No phone number on file',
              ),
              const Divider(height: AppSizes.s16),
              _infoTile(
                icon: AppIcons.mail,
                label: 'Email Address',
                value: hasEmail ? m.email! : 'No email address on file',
              ),
              const Divider(height: AppSizes.s16),
              _infoTile(
                icon: AppIcons.location,
                label: 'Address',
                value: (m.address ?? '').isNotEmpty
                    ? '${m.address}${(m.zipCode ?? '').isNotEmpty ? ', ${m.zipCode}' : ''}'
                    : 'No address on file',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s12),

        // Participant / Child Information (if available)
        if (m.childName.trim().isNotEmpty) ...[
          _sectionCard(
            title: 'Participant / Child',
            icon: AppIcons.boxingGlove,
            child: Column(
              children: [
                _infoTile(
                  icon: AppIcons.user,
                  label: 'Participant Name',
                  value: m.childName,
                ),
                if (m.childAge > 0) ...[
                  const Divider(height: AppSizes.s16),
                  _infoTile(
                    icon: AppIcons.info,
                    label: 'Age',
                    value: '${m.childAge} years old',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s12),
        ],

        // Registration & Legal Info
        _sectionCard(
          title: 'Account & Waiver',
          icon: AppIcons.document,
          child: Column(
            children: [
              _infoTile(
                icon: AppIcons.calendar,
                label: 'Member Since',
                value: dateLabel(m.memberSince),
              ),
              const Divider(height: AppSizes.s16),
              _infoTile(
                icon: AppIcons.shield,
                label: 'Liability Waiver',
                value: m.waiverVersion.isNotEmpty
                    ? 'Signed (Version ${m.waiverVersion})'
                    : 'Not Signed',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s20),
      ],
    );
  }

  Widget _actionButton({
    required String icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.s12),
          side: BorderSide(
            color: enabled
                ? context.palette.accent
                : context.palette.separator,
          ),
        ),
        onPressed: enabled ? onTap : null,
        icon: AppIcon(
          icon,
          size: AppSizes.s16,
          color: enabled
              ? context.palette.accent
              : context.palette.textSecondary,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.font13,
            color: enabled
                ? context.palette.accent
                : context.palette.textSecondary,
          ),
        ),
      );

  Widget _sectionCard({
    required String title,
    required String icon,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(AppSizes.s14),
        decoration: BoxDecoration(
          color: context.palette.separator.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(color: context.palette.separator),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  icon,
                  size: AppSizes.s16,
                  color: context.palette.accent,
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.font14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s12),
            child,
          ],
        ),
      );

  Widget _creditPill(String title, int remaining, int reserved) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
        decoration: BoxDecoration(
          color: context.palette.separator.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Column(
          children: [
            Text(
              '$remaining',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.font16,
                color: remaining > 0
                    ? context.palette.accent
                    : context.palette.textSecondary,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: AppSizes.font11,
                color: context.palette.textSecondary,
              ),
            ),
            if (reserved > 0)
              Text(
                '($reserved res)',
                style: TextStyle(
                  fontSize: AppSizes.font10,
                  color: context.palette.textSecondary,
                ),
              ),
          ],
        ),
      );

  Widget _infoTile({
    required String icon,
    required String label,
    required String value,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            icon,
            size: AppSizes.s16,
            color: context.palette.textSecondary,
          ),
          const SizedBox(width: AppSizes.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppSizes.font11,
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: AppSizes.font13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
