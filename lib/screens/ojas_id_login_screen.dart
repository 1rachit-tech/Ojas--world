import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';

class OjasIdLoginScreen extends StatefulWidget {
  const OjasIdLoginScreen({super.key});
  @override
  State<OjasIdLoginScreen> createState() => _OjasIdLoginScreenState();
}

class _OjasIdLoginScreenState extends State<OjasIdLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final loginEmail = await ProfileService.instance.emailForOjasId(_idController.text);
      if (loginEmail == null) throw const ProfileException('OJAS ID not found. Check it and try again.');
      await AuthService.instance.signInWithEmail(loginEmail, _passwordController.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ProfileException catch (error) {
      _setError(error.message);
    } on FirebaseAuthException catch (error) {
      _setError(error.code == 'invalid-credential' || error.code == 'wrong-password' ? 'OJAS ID or password is incorrect.' : error.message ?? 'Unable to sign in.');
    } catch (_) {
      _setError('Unable to sign in right now. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(String error) { if (mounted) setState(() => _error = error); }

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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OJAS', style: _brandStyle),
                    const SizedBox(height: 56),
                    const Text('Log in with OJAS ID', style: _titleStyle),
                    const SizedBox(height: 8),
                    const Text('Use your OJAS ID and password.', style: _subtitleStyle),
                    const SizedBox(height: 34),
                    _field(
                      _idController,
                      'OJAS ID',
                      Icons.alternate_email_rounded,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter your OJAS ID'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _passwordController,
                      'Password',
                      Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      suffix: IconButton(
                        onPressed: _loading ? null : () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Use at least 6 characters'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 22),
                      _ErrorBox(_error!),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827)),
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Log in'),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _loading
          ? const LinearProgressIndicator(minHeight: 2, color: Color(0xFFF5B942))
          : null,
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool obscureText = false, Widget? suffix, String? Function(String?)? validator}) => TextFormField(controller: controller, enabled: !_loading, obscureText: obscureText, validator: validator, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: suffix, filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD1D5DB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD1D5DB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF111827), width: 2))));
}

class _ErrorBox extends StatelessWidget { const _ErrorBox(this.message); final String message; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)), child: Text(message, style: const TextStyle(color: Color(0xFF991B1B)))); }

const _brandStyle = TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3);
const _titleStyle = TextStyle(color: Color(0xFF111827), fontSize: 32, fontWeight: FontWeight.w800);
const _subtitleStyle = TextStyle(color: Color(0xFF4B5563), fontSize: 15);