import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../providers/auth_provider.dart';

class EmailAuthSheet extends ConsumerStatefulWidget {
  const EmailAuthSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radius16),
          ),
        ),
        builder: (_) => const EmailAuthSheet(),
      );

  @override
  ConsumerState<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends ConsumerState<EmailAuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_isSignUp) {
        await ref.read(authRepositoryProvider).signUpWithEmail(
              _emailController.text,
              _passwordController.text,
              fullName: _nameController.text.trim(),
            );
      } else {
        await ref.read(authRepositoryProvider).signInWithEmail(
              _emailController.text,
              _passwordController.text,
            );
      }
      if (mounted) {
        Navigator.of(context).pop();
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || Validators.email(email) != null) {
      showMessage(context, 'Please enter a valid email address first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        showMessage(context, 'Password reset link sent to $email');
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.s24,
        AppSizes.s12,
        AppSizes.s24,
        AppSizes.s24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSizes.s16),
                  decoration: BoxDecoration(
                    color: context.palette.separator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isSignUp ? 'Create an Account' : 'Sign in with Email',
                style: TextStyle(
                  fontSize: AppSizes.font20,
                  fontWeight: FontWeight.bold,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.s4),
              Text(
                _isSignUp
                    ? 'Join Junior Boy Boxing to book sessions and train'
                    : 'Enter your credentials to access your account',
                style: TextStyle(
                  fontSize: AppSizes.font13,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.s20),

              if (_isSignUp) ...[
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. John Doe',
                  ),
                  validator: (v) => _isSignUp ? Validators.required(v) : null,
                ),
                const SizedBox(height: AppSizes.s14),
              ],

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'you@example.com',
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: AppSizes.s14),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: AppSizes.s20,
                      color: context.palette.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: Validators.password,
              ),

              if (!_isSignUp) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: AppSizes.font12,
                        color: context.palette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: AppSizes.s16),

              const SizedBox(height: AppSizes.s8),
              JbbButton(
                label: _isSignUp ? 'Create Account' : 'Sign In',
                busy: _busy,
                onPressed: _busy ? null : _submit,
              ),

              const SizedBox(height: AppSizes.s12),
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                          });
                        },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: AppSizes.font13,
                        color: context.palette.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : "Don't have an account? ",
                        ),
                        TextSpan(
                          text: _isSignUp ? 'Sign In' : 'Sign Up',
                          style: TextStyle(
                            color: context.palette.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
