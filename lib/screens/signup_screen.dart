import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signUpWithEmail(_email.text, _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _messageFor(error));
    } catch (_) {
      setState(() => _error = 'Unable to create your account right now.');
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
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = kIsWeb
              ? 'Google sign-in is not configured for this web preview. Return to login and use Continue as Guest, or configure Google OAuth credentials.'
              : 'Google sign-in was cancelled or unavailable.',
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password.';
      default:
        return error.message ?? 'Sign-up failed. Please try again.';
    }
  }

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
                  const Text(
                    'Create your space',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bring your ideas into the light.',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 15),
                  ),
                  const SizedBox(height: 34),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(
                          _email,
                          'Email address',
                          Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Enter a valid email address'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          _password,
                          'Password',
                          Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Use at least 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          _confirmPassword,
                          'Confirm password',
                          Icons.verified_user_outlined,
                          obscureText: _obscure,
                          validator: (value) => value != _password.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xFFFECACA),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Create account'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _googleSignIn,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF111827),
                              side: const BorderSide(
                                color: Color(0xFF111827),
                              ),
                            ),
                            icon: const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 30,
                            ),
                            label: const Text('Continue with Google'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                ),
                          child: const Text('Already have an account? Log in'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _loading
          ? const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFFFFC107),
            )
          : null,
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
}
