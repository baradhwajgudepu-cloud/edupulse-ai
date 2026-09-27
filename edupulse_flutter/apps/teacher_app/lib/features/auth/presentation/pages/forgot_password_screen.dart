import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../../../core/utils/email_validator.dart';
import '../../../../core/router/routes.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _successMessage = null;
        _errorMessage = null;
      });

      final forgotPasswordUseCase = ref.read(forgotPasswordUseCaseProvider);
      final result =
          await forgotPasswordUseCase(email: _emailController.text.trim());

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        result.when(
          onSuccess: (_) {
            setState(() {
              _successMessage =
                  EduLocalization.of(context)?.translate('reset_link_sent') ??
                      'Password reset link sent to your email.';
            });
          },
          onFailure: (failure) {
            setState(() {
              _errorMessage = failure.message;
            });
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final gradients =
        theme.extension<AppGradients>() ?? const AppGradients.standard();

    return Scaffold(
      appBar: AppBar(
        title: Text(local?.translate('forgot_password') ?? 'Forgot Password'),
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
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.lg),
              ),
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        local?.translate('forgot_password') ??
                            'Forgot Password',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: spacing.md),
                      Text(
                        local?.translate('forgot_password_desc') ??
                            'Enter your registered email to receive a password reset link.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: spacing.lg),
                      if (_successMessage != null) ...[
                        Container(
                          padding: EdgeInsets.all(spacing.md),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(radius.md),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade800),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: spacing.md),
                      ],
                      if (_errorMessage != null) ...[
                        Container(
                          padding: EdgeInsets.all(spacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(radius.md),
                            border: Border.all(
                                color: theme.colorScheme.error
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: spacing.md),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: local?.translate('email') ?? 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radius.md),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return local?.translate('email_required') ??
                                'Email is required';
                          }
                          if (!EmailValidator.validate(value)) {
                            return local?.translate('invalid_email_format') ??
                                'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: spacing.lg),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: spacing.md),
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
                            : Text(
                                local?.translate('submit') ?? 'Send Reset Link',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                      if (_successMessage != null) ...[
                        SizedBox(height: spacing.sm),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.vpn_key_outlined, size: 18),
                          label: const Text('Enter Reset Code / Token'),
                          onPressed: () => context.push(AppRoutes.resetPassword),
                        ),
                      ],
                      SizedBox(height: spacing.sm),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.resetPassword),
                        child: const Text('Have a reset code? Reset Password'),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : () => context.pop(),
                        child: Text(local?.translate('back_to_login') ??
                            'Back to Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
