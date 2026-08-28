import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      _showError(_messageFor(error));
    } catch (_) {
      _showError('Unable to sign in right now. Please try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      _showError(_messageFor(error));
    } catch (_) {
      _showError(
        kIsWeb
            ? 'Google sign-in is not configured for this web preview. Use Continue as Guest or configure Google OAuth credentials.'
            : 'Google sign-in was cancelled or unavailable.',
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(text: _emailController.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailController.text),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || email.trim().isEmpty || !mounted) return;
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) _showMessage('Password reset email sent.');
    } on FirebaseAuthException catch (error) {
      _showError(_messageFor(error));
    }
  }

  void _showError(String message) => setState(() => _error = message);

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to keep creating with OJAS.',
      loading: _loading,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _field(
              _emailController,
              'Email address',
              Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 14),
            _field(
              _passwordController,
              'Password',
              Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) => value == null || value.length < 6
                  ? 'Use at least 6 characters'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text('Forgot Password?'),
              ),
            ),
            if (_error != null) _ErrorText(_error!),
            const SizedBox(height: 8),
            _primaryButton('Log in', _submit),
            const SizedBox(height: 14),
            _googleButton(_googleSignIn),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).pop(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFF111827)),
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Continue as Guest'),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
              child: const Text("Don't have an account? Create one"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF4B5563)),
      floatingLabelStyle: const TextStyle(color: Color(0xFF111827)),
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF111827), width: 2),
      ),
    ),
    style: const TextStyle(color: Color(0xFF111827)),
  );
  Widget _primaryButton(String label, VoidCallback action) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: _loading ? null : action,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    ),
  );
  Widget _googleButton(VoidCallback action) => SizedBox(
    width: double.infinity,
    height: 54,
    child: OutlinedButton.icon(
      onPressed: _loading ? null : action,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF111827),
        side: const BorderSide(color: Color(0xFF111827)),
      ),
      icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
      label: const Text('Continue with Google'),
    ),
  );
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.loading,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OJAS',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 56),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 34),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: loading
          ? const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFFFFC107),
            )
          : null,
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xFF991B1B))),
  );
}
