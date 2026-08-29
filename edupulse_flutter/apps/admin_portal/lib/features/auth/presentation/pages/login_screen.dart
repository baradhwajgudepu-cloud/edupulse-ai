import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_assets/edupulse_assets.dart';
import '../providers/auth_provider.dart';
import '../../../../core/routing/routes.dart';

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
    final savedEmail = prefs.getString('admin_remembered_email');
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
        await prefs.setString('admin_remembered_email', email);
      } else {
        await prefs.remove('admin_remembered_email');
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
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final gradients = theme.extension<AppGradients>() ?? const AppGradients.standard();

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthError) {
        String errorMsg = next.message;
        if (next.message == 'SERVER_UNREACHABLE') {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Connection Error'),
              content: const Text(
                'Unable to connect to the EduPulse server.\n\n'
                'Please verify:\n'
                '• The backend server is running locally\n'
                '• The API host matches your environment configuration',
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
          if (next.message == 'ACCESS_DENIED') {
            errorMsg = 'Access Denied: Insufficient administrative privileges.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(errorMsg)),
                ],
              ),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
              width: 380,
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Hero(
                            tag: 'app_logo',
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primaryContainer,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Image.asset(
                                  EduPulseAssets.mark,
                                  package: EduPulseAssets.package,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'EduPulse Admin',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Administrative Control Portal',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Semantics(
                          label: 'Email Input Field',
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
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
                        ),
                        const SizedBox(height: 20),
                        Semantics(
                          label: 'Password Input Field',
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !isLoading,
                            onFieldSubmitted: (_) => _submit(),
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Password',
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
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
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
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Remember Me',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.push(AppRoutes.forgotPassword),
                              child: Text(
                                'Forgot Password?',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),


                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius.md),
                            ),
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
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'Version 1.0.0',
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
    );
  }
}
