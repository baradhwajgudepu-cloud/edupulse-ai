import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../../../core/routing/routes.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? initialToken;

  const ResetPasswordScreen({
    super.key,
    this.initialToken,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = widget.initialToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid or missing password reset token. Please request a new link.';
      });
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

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
          _isSuccess = true;
        });
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

    final token = widget.initialToken?.trim() ?? '';
    final hasValidToken = token.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: gradients.primary,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.lg),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.xl,
                    vertical: spacing.xxl,
                  ),
                  child: _isSuccess
                      ? _buildSuccessView(context, theme, radius, spacing)
                      : (!hasValidToken
                          ? _buildMissingTokenView(context, theme, radius, spacing)
                          : _buildFormView(context, theme, radius, spacing)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(
    BuildContext context,
    ThemeData theme,
    AppRadius radius,
    AppSpacing spacing,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.login),
                tooltip: 'Back to Sign In',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reset Password',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'Create a strong password with at least 8 characters, an uppercase letter, a lowercase letter, a number, and a special character.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(radius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius.md),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters long';
              }
              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                return 'Password must contain at least one uppercase letter';
              }
              if (!RegExp(r'[a-z]').hasMatch(value)) {
                return 'Password must contain at least one lowercase letter';
              }
              if (!RegExp(r'[0-9]').hasMatch(value)) {
                return 'Password must contain at least one digit';
              }
              if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                return 'Password must contain at least one special character';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius.md),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: !_isLoading ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Return to Sign In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    ThemeData theme,
    AppRadius radius,
    AppSpacing spacing,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            size: 36,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Password Reset Complete',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your password has been successfully updated. You can now sign in using your new password.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.login),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
            ),
          ),
          child: const Text(
            'Sign In with New Password',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildMissingTokenView(
    BuildContext context,
    ThemeData theme,
    AppRadius radius,
    AppSpacing spacing,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 36,
            color: Colors.amber.shade800,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Invalid Reset Link',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'The password reset link is missing a valid security token or has expired. Please request a new link.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.forgotPassword),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
            ),
          ),
          child: const Text(
            'Request New Reset Link',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Return to Sign In'),
        ),
      ],
    );
  }
}
