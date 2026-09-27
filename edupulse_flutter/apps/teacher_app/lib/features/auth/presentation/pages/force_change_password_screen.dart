import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../../../core/router/routes.dart';
import '../providers/auth_provider.dart';

class ForceChangePasswordScreen extends ConsumerStatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  ConsumerState<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends ConsumerState<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
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

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_isPasswordStrong(newPassword)) {
      setState(() {
        _errorMessage = 'Please fulfill all password strength requirements.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'New passwords do not match.';
      });
      return;
    }

    if (currentPassword == newPassword) {
      setState(() {
        _errorMessage = 'New password cannot be identical to current temporary password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final changePasswordUseCase = ref.read(changePasswordUseCaseProvider);
    final result = await changePasswordUseCase(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    result.when(
      onSuccess: (_) {
        ref.read(authStateProvider.notifier).clearMustChangePassword();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully! Welcome to EduPulse.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go(AppRoutes.home);
      },
      onFailure: (failure) {
        setState(() {
          _errorMessage = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final gradients = theme.extension<AppGradients>() ?? const AppGradients.standard();

    final enteredPassword = _newPasswordController.text;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: gradients.primary),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius.lg),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: EdgeInsets.all(spacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: EdgeInsets.all(spacing.md),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.lock_reset, size: 48, color: Colors.amber.shade800),
                            ),
                            SizedBox(height: spacing.md),
                            Text(
                              'Password Update Required',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              'You have signed in with a temporary password. For security reasons, please establish a new permanent password to continue.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: spacing.md),
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
                              controller: _currentPasswordController,
                              obscureText: _obscureCurrent,
                              decoration: InputDecoration(
                                labelText: 'Current Temporary Password *',
                                prefixIcon: const Icon(Icons.key_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.md)),
                              ),
                              validator: (val) =>
                                  val == null || val.isEmpty ? 'Please enter your current temporary password' : null,
                            ),
                            SizedBox(height: spacing.md),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNew,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'New Password *',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
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
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password *',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.md)),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Please confirm new password';
                                if (val != _newPasswordController.text) return 'Passwords do not match';
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
                                  : const Text('Update Password & Continue'),
                            ),
                            SizedBox(height: spacing.sm),
                            TextButton(
                              onPressed: () {
                                ref.read(authStateProvider.notifier).logout();
                                context.go(AppRoutes.login);
                              },
                              child: const Text('Sign Out & Switch Account'),
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
