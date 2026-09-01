import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_assets/edupulse_assets.dart';
import '../providers/auth_provider.dart';
import '../../../../core/router/routes.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_email', email);
      } else {
        await prefs.remove('remembered_email');
      }

      ref.read(authStateProvider.notifier).login(
            email,
            _passwordController.text,
          );
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

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthError) {
        if (next.message == 'SERVER_UNREACHABLE') {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Connection Error'),
              content: const Text(
                'Unable to connect to the EduPulse server.\n\n'
                'Please verify:\n'
                '• Backend is running\n'
                '• Phone and PC are on the same Wi-Fi\n'
                '• Firewall allows port 8000',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (next is Authenticated) {
        context.go(AppRoutes.dashboard);
      }
    });

    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AuthLoading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: gradients.primary,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: spacing.lg, vertical: spacing.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius.lg),
                  ),
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: spacing.lg, vertical: spacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: gradients.accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Image.asset(
                                  EduPulseAssets.mark,
                                  package: EduPulseAssets.package,
                                  fit: BoxFit.contain,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: spacing.md),
                          Text(
                            local?.translate('app_title') ?? 'EduPulse AI',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            local?.translate('splash_tagline') ??
                                'Pulse of Education',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: spacing.lg),
                           TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.text,
                            enabled: !isLoading,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email or Parent Login ID',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(radius.md),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email or Parent Login ID is required';
                              }
                              final val = value.trim();
                              final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val);
                              final isLoginId = RegExp(r'^[A-Za-z0-9]+P\d+$').hasMatch(val);
                              if (!isEmail && !isLoginId) {
                                return 'Please enter a valid email or Parent Login ID';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: spacing.md),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !isLoading,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText:
                                  local?.translate('password') ?? 'Password',
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
                                return local?.translate('password_required') ??
                                    'Password is required';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: spacing.xs),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: spacing.sm,
                            runSpacing: spacing.xs,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: isLoading
                                          ? null
                                          : (val) {
                                              setState(() {
                                                _rememberMe = val ?? false;
                                              });
                                            },
                                    ),
                                  ),
                                  SizedBox(width: spacing.xs),
                                  Text(
                                    local?.translate('remember_me') ??
                                        'Remember Me',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => context
                                        .push(AppRoutes.forgotPassword),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                    local?.translate('forgot_password') ??
                                        'Forgot Password?'),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.md),
                          ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding:
                                  EdgeInsets.symmetric(vertical: spacing.md),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius.md),
                              ),
                              elevation: 2,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    local?.translate('login') ?? 'Login',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                          SizedBox(height: spacing.lg),
                          Center(
                            child: Text(
                              '${local?.translate('version') ?? 'Version'} 1.0.0',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
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
    );
  }
}
