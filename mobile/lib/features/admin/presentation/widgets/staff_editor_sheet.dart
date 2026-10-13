import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../domain/staff_member.dart';
import '../providers/admin_provider.dart';

class StaffEditorSheet extends ConsumerStatefulWidget {
  const StaffEditorSheet({super.key, this.staff});

  final StaffMember? staff;

  static Future<bool?> show(BuildContext context, {StaffMember? staff}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StaffEditorSheet(staff: staff),
    );
  }

  @override
  ConsumerState<StaffEditorSheet> createState() => _StaffEditorSheetState();
}

class _StaffEditorSheetState extends ConsumerState<StaffEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  late String _role;
  late Map<String, bool> _permissions;
  bool _busy = false;

  bool get _isEditing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.staff?.email ?? '');
    _nameController = TextEditingController(text: widget.staff?.displayName ?? '');
    _role = widget.staff?.role ?? 'admin';
    _permissions = Map<String, bool>.from(
      widget.staff?.permissions ?? {for (var k in StaffPermissions.all) k: true},
    );
    for (final key in StaffPermissions.all) {
      _permissions.putIfAbsent(key, () => _role == 'superAdmin');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final key in StaffPermissions.all) {
        _permissions[key] = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      final permsToSave = _role == 'superAdmin'
          ? {for (var k in StaffPermissions.all) k: true}
          : _permissions;

      await ref.read(adminRepositoryProvider).upsertStaff(
            email: _emailController.text.trim(),
            displayName: _nameController.text.trim(),
            role: _role,
            permissions: permsToSave,
          );
      if (mounted) {
        showMessage(
          context,
          _isEditing ? 'Staff member updated successfully.' : 'Staff member added successfully.',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isSuper = _role == 'superAdmin';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.s20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSizes.s20, AppSizes.s16, AppSizes.s20, AppSizes.s8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Staff Member' : 'Add Staff Member',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Form fields list
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.s20),
                  children: [
                    // Email
                    Text(
                      'Email Address',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppSizes.font13,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s6),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isEditing,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'staff@example.com',
                        filled: true,
                        fillColor: _isEditing ? palette.surface : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.s12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an email address.';
                        }
                        if (!val.contains('@')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.s16),

                    // Display Name
                    Text(
                      'Display Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppSizes.font13,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s6),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Full Name / Nickname',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.s12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.s16),

                    // Role Selection
                    Text(
                      'Role & Access Level',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppSizes.font13,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSizes.s12),
                        border: Border.all(color: palette.separator),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _role,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Administrator (Custom Permissions)'),
                            ),
                            DropdownMenuItem(
                              value: 'superAdmin',
                              child: Text('Super Administrator (Full Access)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _role = val;
                                if (_role == 'superAdmin') {
                                  _toggleAll(true);
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.s20),

                    // Permissions section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Permissions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font15,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (!isSuper)
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _toggleAll(true),
                                child: const Text('All'),
                              ),
                              TextButton(
                                onPressed: () => _toggleAll(false),
                                child: const Text('None'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.s6),

                    if (isSuper)
                      Container(
                        padding: const EdgeInsets.all(AppSizes.s12),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.s10),
                          border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield, color: palette.accent, size: AppSizes.s20),
                            const SizedBox(width: AppSizes.s10),
                            Expanded(
                              child: Text(
                                'Super administrators have complete unrestricted access to all features.',
                                style: TextStyle(
                                  fontSize: AppSizes.font13,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...StaffPermissions.all.map((key) {
                        final label = StaffPermissions.labels[key] ?? key;
                        final isChecked = _permissions[key] ?? false;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: AppSizes.font14,
                              color: palette.textPrimary,
                            ),
                          ),
                          value: isChecked,
                          activeColor: palette.accent,
                          onChanged: (val) {
                            setState(() {
                              _permissions[key] = val ?? false;
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),

              // Bottom Action Button
              Padding(
                padding: const EdgeInsets.all(AppSizes.s20),
                child: JbbButton(
                  label: _isEditing ? 'Save Changes' : 'Add Staff Member',
                  busy: _busy,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
