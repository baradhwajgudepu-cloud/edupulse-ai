import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../../../core/router/routes.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? initialToken;

  const ResetPasswordScreen({super.key, this.initialToken});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _resetSuccess = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _hasMinLength(String pwd) => pwd.length >= 8;
  bool _hasUppercase(String pwd) => RegExp(r'[A-Z]').hasMatch(pwd);
  bool _hasLowercase(String pwd) => RegExp(r'[a-z]').hasMatch(pwd);
  bool _hasDigit(String pwd) => RegExp(r'[0-9]').hasMatch(pwd);
  bool _hasSpecialChar(String pwd) => RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pwd);

  bool _isPasswordStrong(String pwd) {
    return _hasMinLength(pwd) &&
        _hasUppercase(pwd) &&
        _hasLowercase(pwd) &&
        _hasDigit(pwd) &&
        _hasSpecialChar(pwd);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _tokenController.text.trim();
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_isPasswordStrong(newPassword)) {
      setState(() {
        _errorMessage = 'Please ensure your password meets all complexity requirements.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final resetPasswordUseCase = ref.read(resetPasswordUseCaseProvider);
    final result = await resetPasswordUseCase(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    result.when(
      onSuccess: (_) {
        setState(() {
          _resetSuccess = true;
        });
      },
      onFailure: (failure) {
        String msg = failure.message;
        if (msg.toLowerCase().contains('invalid') || msg.toLowerCase().contains('expired')) {
          msg = 'Invalid or expired password reset token. Please request a new link.';
        }
        setState(() {
          _errorMessage = msg;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final gradients = theme.extension<AppGradients>() ?? const AppGradients.standard();

    final enteredPassword = _passwordController.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(local?.translate('reset_password') ?? 'Reset Password'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: gradients.accent,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.lg),
                ),
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: _resetSuccess
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                            SizedBox(height: spacing.md),
                            Text(
                              'Password Reset Successful!',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: spacing.sm),
                            Text(
                              'Your password has been updated successfully. You may now sign in to view student progress.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: spacing.lg),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => context.go(AppRoutes.login),
                                child: const Text('Back to Login'),
                              ),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Set New Password',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: spacing.sm),
                              Text(
                                'Enter the reset code/token sent to your email along with your new password.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: spacing.lg),
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: EdgeInsets.all(spacing.md),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(radius.md),
                                    border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                                      SizedBox(width: spacing.sm),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: spacing.md),
                              ],
                              TextFormField(
                                controller: _tokenController,
                                decoration: InputDecoration(
                                  labelText: 'Reset Token / Code *',
                                  hintText: 'Paste token from reset email',
                                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.md)),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty ? 'Please enter the reset token' : null,
                              ),
                              SizedBox(height: spacing.md),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'New Password *',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.md)),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Please enter new password';
                                  if (!_isPasswordStrong(val)) return 'Password does not meet complexity requirements';
                                  return null;
                                },
                              ),
                              SizedBox(height: spacing.xs),
                              // Password rules helper
                              Container(
                                padding: EdgeInsets.all(spacing.sm),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(radius.sm),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildRequirementItem('At least 8 characters', _hasMinLength(enteredPassword)),
                                    _buildRequirementItem('Uppercase letter (A-Z)', _hasUppercase(enteredPassword)),
                                    _buildRequirementItem('Lowercase letter (a-z)', _hasLowercase(enteredPassword)),
                                    _buildRequirementItem('At least 1 number (0-9)', _hasDigit(enteredPassword)),
                                    _buildRequirementItem('Special character (!@#\$%^&*)', _hasSpecialChar(enteredPassword)),
                                  ],
                                ),
                              ),
                              SizedBox(height: spacing.md),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm New Password *',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.md)),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Please confirm your new password';
                                  if (val != _passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                              ),
                              SizedBox(height: spacing.lg),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: spacing.md),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Reset Password'),
                              ),
                              SizedBox(height: spacing.sm),
                              TextButton(
                                onPressed: () => context.go(AppRoutes.login),
                                child: const Text('Back to Login'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green.shade800 : Colors.grey.shade700,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
