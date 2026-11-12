import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/config/app_debug_config.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
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
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  void _loadRememberedEmail() {
    if (Hive.isBoxOpen('jbb_cache')) {
      final savedEmail =
          Hive.box('jbb_cache').get('remembered_email') as String?;
      if (AppDebugConfig.enableAuthLoginLogs) {
        debugPrint(
          '👉 [LOGIN_DEBUG] Loaded remembered_email from cache: $savedEmail',
        );
      }
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
        _rememberMe = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mode = _isSignUp ? 'Sign Up' : 'Sign In';
    if (AppDebugConfig.enableAuthLoginLogs) {
      debugPrint('👉 [LOGIN_DEBUG #0] User clicked $mode button. Email: ${_emailController.text.trim()}');
    }
    if (!_formKey.currentState!.validate()) {
      if (AppDebugConfig.enableAuthLoginLogs) {
        debugPrint('👉 [LOGIN_DEBUG #1] Form validation failed.');
      }
      return;
    }
    if (AppDebugConfig.enableAuthLoginLogs) {
      debugPrint('👉 [LOGIN_DEBUG #1] Form validation passed. Setting busy = true.');
    }
    final authRepo = ref.read(authRepositoryProvider);
    final guestNotifier = ref.read(guestModeProvider.notifier);

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      if (_isSignUp) {
        if (AppDebugConfig.enableAuthLoginLogs) {
          debugPrint('👉 [LOGIN_DEBUG #1b] Calling signUpWithEmail...');
        }
        await authRepo.signUpWithEmail(
              _emailController.text,
              _passwordController.text,
              fullName: _nameController.text.trim(),
            );
      } else {
        if (AppDebugConfig.enableAuthLoginLogs) {
          debugPrint('👉 [LOGIN_DEBUG #1b] Calling signInWithEmail...');
        }
        await authRepo.signInWithEmail(
              _emailController.text,
              _passwordController.text,
            );
        if (Hive.isBoxOpen('jbb_cache')) {
          if (_rememberMe) {
            final emailToSave = _emailController.text.trim();
            await Hive.box('jbb_cache').put('remembered_email', emailToSave);
            if (AppDebugConfig.enableAuthLoginLogs) {
              debugPrint('👉 [LOGIN_DEBUG] Saved remembered_email to cache: $emailToSave');
            }
          } else {
            await Hive.box('jbb_cache').delete('remembered_email');
            if (AppDebugConfig.enableAuthLoginLogs) {
              debugPrint('👉 [LOGIN_DEBUG] Deleted remembered_email from cache.');
            }
          }
        }
      }
      if (AppDebugConfig.enableAuthLoginLogs) {
        debugPrint('👉 [LOGIN_DEBUG #9] Repository call succeeded. Setting guestMode = false...');
      }
      await guestNotifier.setGuest(false);
      if (AppDebugConfig.enableAuthLoginLogs) {
        debugPrint('👉 [LOGIN_DEBUG #10] Closing EmailAuthSheet modal bottom sheet...');
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (AppDebugConfig.enableAuthLoginLogs) {
        debugPrint('👉 [LOGIN_DEBUG #11] Auth flow 100% finished successfully! ✅');
      }
    } catch (e, stack) {
      if (!mounted) return;
      if (AppDebugConfig.enableAuthLoginLogs) {
        debugPrint('❌ [LOGIN_DEBUG_ERROR] _submit caught error: $e');
        if (e is FirebaseAuthException) {
          debugPrint('   ├── FirebaseAuthException code: ${e.code}');
          debugPrint('   ├── FirebaseAuthException message: ${e.message}');
        }
        debugPrint('   └── Stack: $stack');
      }
      final msg = friendlyError(e);
      setState(() => _errorMessage = msg);
      showMessage(context, msg);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (AppDebugConfig.enableAuthLoginLogs) {
          debugPrint('👉 [LOGIN_DEBUG #12] Reset busy = false.');
        }
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || Validators.email(email) != null) {
      setState(() => _errorMessage = 'Please enter a valid email address first.');
      showMessage(context, 'Please enter a valid email address first.');
      return;
    }
    final authRepo = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await authRepo.sendPasswordReset(email);
      if (mounted) {
        showMessage(context, 'Password reset link sent to $email');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() => _errorMessage = msg);
      showMessage(context, msg);
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
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
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
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _busy
                          ? null
                          : () {
                              setState(() => _rememberMe = !_rememberMe);
                            },
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.s4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: _busy
                                    ? null
                                    : (val) {
                                        setState(
                                          () => _rememberMe = val ?? false,
                                        );
                                      },
                                activeColor: context.palette.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppSizes.radius4),
                                ),
                                side: BorderSide(
                                  color: context.palette.separator,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSizes.s8),
                            Text(
                              AppStrings.rememberMe,
                              style: TextStyle(
                                fontSize: AppSizes.font13,
                                color: context.palette.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
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
                  ],
                ),
              ] else
                const SizedBox(height: AppSizes.s16),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSizes.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.s12,
                    vertical: AppSizes.s10,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                    border: Border.all(
                      color: context.palette.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: context.palette.accent,
                        size: 20,
                      ),
                      const SizedBox(width: AppSizes.s8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: context.palette.accent,
                            fontSize: AppSizes.font13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.s12),
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
                            _errorMessage = null;
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
