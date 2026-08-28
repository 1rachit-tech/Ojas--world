import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.popOnComplete = true});

  final bool popOnComplete;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ojasIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String _avatar = 'avatar_1';
  String? _error;

  static const _avatars = <(String, IconData, Color)>[
    ('avatar_1', Icons.wb_sunny_outlined, Color(0xFFF5B942)),
    ('avatar_2', Icons.auto_awesome_outlined, Color(0xFFB8D8D8)),
    ('avatar_3', Icons.local_florist_outlined, Color(0xFFE8B4B8)),
    ('avatar_4', Icons.nightlight_outlined, Color(0xFFC7D2FE)),
  ];

  @override
  void dispose() {
    _ojasIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ojasId = ProfileService.normalizeOjasId(_ojasIdController.text);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw const ProfileException('Please sign in again.');

      // TEMPORARY: replace the built-in avatar identifier with Firebase Storage
      // upload once the Firebase Blaze plan is active.
      final credential = EmailAuthProvider.credential(
        email: ProfileService.credentialEmailFor(ojasId),
        password: _passwordController.text,
      );
      await user.linkWithCredential(credential);
      await ProfileService.instance.createOrUpdateProfile(
        ojasId: ojasId,
        photoUrl: _avatar,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ProfileException catch (error) {
      _showError(error.message);
    } on FirebaseAuthException catch (error) {
      _showError(_messageFor(error));
    } catch (_) {
      _showError('Unable to save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'That OJAS ID is already taken. Choose another one.';
      case 'provider-already-linked':
        return 'This account already has an OJAS ID.';
      case 'weak-password':
        return 'Choose a password with at least 6 characters.';
      default:
        return error.message ?? 'Unable to save your profile. Please try again.';
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OJAS', style: _brandStyle),
                    const SizedBox(height: 56),
                    const Text('Set up your profile', style: _titleStyle),
                    const SizedBox(height: 8),
                    const Text('Choose how people will find you.', style: _subtitleStyle),
                    const SizedBox(height: 34),
                    _field(
                      _ojasIdController,
                      'OJAS ID',
                      Icons.alternate_email_rounded,
                      validator: (value) => value == null ||
                              !RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value.trim())
                          ? 'Use 3–20 letters, numbers, or underscores'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _passwordController,
                      'OJAS password',
                      Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Use at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    const Text('Profile Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Pick an avatar to get started.', style: _subtitleStyle),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _avatars.map(_avatarOption).toList(),
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
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Finish setup'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _loading ? const LinearProgressIndicator(minHeight: 2, color: Color(0xFFF5B942)) : null,
    );
  }

  Widget _avatarOption((String, IconData, Color) avatar) {
    final selected = _avatar == avatar.$1;
    return Semantics(
      button: true,
      selected: selected,
      label: avatar.$1,
      child: GestureDetector(
        onTap: _loading ? null : () => setState(() => _avatar = avatar.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: avatar.$3.withValues(alpha: .3),
            shape: BoxShape.circle,
            border: Border.all(color: selected ? const Color(0xFF111827) : Colors.transparent, width: 2),
          ),
          child: Icon(avatar.$2, color: const Color(0xFF111827), size: 28),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool obscureText = false, Widget? suffix, String? Function(String?)? validator}) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    validator: validator,
    enabled: !_loading,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF111827), width: 2)),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)), child: Text(message, style: const TextStyle(color: Color(0xFF991B1B))));
}

const _brandStyle = TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3);
const _titleStyle = TextStyle(color: Color(0xFF111827), fontSize: 32, fontWeight: FontWeight.w800);
const _subtitleStyle = TextStyle(color: Color(0xFF4B5563), fontSize: 15);