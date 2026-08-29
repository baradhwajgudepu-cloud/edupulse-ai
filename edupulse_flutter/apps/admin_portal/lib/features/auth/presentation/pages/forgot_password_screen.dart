import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../../../core/routing/routes.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final forgotPasswordUseCase = ref.read(forgotPasswordUseCaseProvider);
    final result = await forgotPasswordUseCase(email: email);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      // Always treat as submitted to prevent account enumeration
      _isSubmitted = true;
    });

    result.when(
      onSuccess: (_) {},
      onFailure: (failure) {
        // If it's a rate limit error (429), surface it
        if (failure.statusCode == 429) {
          setState(() {
            _isSubmitted = false;
            _errorMessage = failure.message;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final gradients = theme.extension<AppGradients>() ?? const AppGradients.standard();

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
                  child: _isSubmitted
                      ? _buildSubmittedView(context, theme, radius, spacing)
                      : _buildFormView(context, theme, radius, spacing),
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
                  'Forgot Password',
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
            'Enter your registered email address. We will send you instructions to securely reset your password.',
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
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'admin@school.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius.md),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value.trim())) {
                return 'Please enter a valid email address';
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
                    'Send Reset Link',
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

  Widget _buildSubmittedView(
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
            Icons.mark_email_read_outlined,
            size: 36,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Instructions Sent',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'If an account exists with ${_emailController.text.trim()}, you will receive password reset instructions shortly.\n\nPlease check your inbox and spam folder.',
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
            'Back to Sign In',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
