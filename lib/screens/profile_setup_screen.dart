import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.popOnComplete = true,
  });

  final bool popOnComplete;

  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _ojasIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _checkingId = false;
  bool _obscurePassword = true;

  bool? _ojasIdAvailable;

  String _avatar = 'avatar_1';

  String? _error;

  static const _avatars = <(String, IconData, Color)>[
    (
      'avatar_1',
      Icons.wb_sunny_outlined,
      Color(0xFFF5B942),
    ),
    (
      'avatar_2',
      Icons.auto_awesome_outlined,
      Color(0xFFB8D8D8),
    ),
    (
      'avatar_3',
      Icons.local_florist_outlined,
      Color(0xFFE8B4B8),
    ),
    (
      'avatar_4',
      Icons.nightlight_outlined,
      Color(0xFFC7D2FE),
    ),
  ];

  bool get _needsPassword =>
      !AuthService.instance.hasPasswordProvider;

  @override
  void initState() {
    super.initState();

    _ojasIdController.addListener(_onOjasIdChanged);
  }

  @override
  void dispose() {
    _ojasIdController.removeListener(_onOjasIdChanged);

    _ojasIdController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _onOjasIdChanged() async {
    final rawValue = _ojasIdController.text;

    final normalizedId =
        ProfileService.normalizeOjasId(rawValue);

    if (!ProfileService.isValidOjasId(normalizedId)) {
      if (mounted) {
        setState(() {
          _ojasIdAvailable = null;
          _checkingId = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        _checkingId = true;
        _ojasIdAvailable = null;
      });
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    if (!mounted) {
      return;
    }

    final currentValue =
        ProfileService.normalizeOjasId(
      _ojasIdController.text,
    );

    if (currentValue != normalizedId) {
      return;
    }

    try {
      final available =
          await ProfileService.instance.isOjasIdAvailable(
        normalizedId,
      );

      if (!mounted) {
        return;
      }

      if (ProfileService.normalizeOjasId(
            _ojasIdController.text,
          ) ==
          normalizedId) {
        setState(() {
          _ojasIdAvailable = available;
          _checkingId = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingId = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showError('Please sign in again.');
      return;
    }

    final normalizedId =
        ProfileService.normalizeOjasId(
      _ojasIdController.text,
    );

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_needsPassword) {
        final email = user.email?.trim();

        if (email == null || email.isEmpty) {
          throw const ProfileException(
            'Your Google account did not provide an email address.',
          );
        }

        await AuthService.instance.linkEmailPasswordToCurrentUser(
          email: email,
          password: _passwordController.text,
        );
      }

      await ProfileService.instance.createOrUpdateProfile(
        ojasId: normalizedId,
        photoUrl: _avatar,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ProfileException catch (error) {
      _showError(error.message);
    } on FirebaseAuthException catch (error) {
      _showError(_messageFor(error));
    } catch (_) {
      _showError(
        'Unable to finish your profile right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = message;
    });
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'This email is already connected to another account.';

      case 'provider-already-linked':
        return 'A password login is already connected to this account.';

      case 'weak-password':
        return 'Choose a password with at least 6 characters.';

      case 'requires-recent-login':
        return 'Please sign in again and retry.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      default:
        return error.message ??
            'Unable to finish your profile. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsPassword = _needsPassword;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              24,
              24,
              40,
            ),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OJAS',
                      style: _brandStyle,
                    ),

                    const SizedBox(height: 48),

                    const Text(
                      'Create your OJAS identity',
                      style: _titleStyle,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      needsPassword
                          ? 'Choose a unique ID and password. You will be able to log in with Google, email, or your OJAS ID.'
                          : 'Choose a unique ID. Your email, password, and OJAS ID will all open the same account.',
                      style: _subtitleStyle,
                    ),

                    const SizedBox(height: 32),

                    _buildOjasIdField(),

                    if (needsPassword) ...[
                      const SizedBox(height: 14),

                      _buildPasswordField(),

                      const SizedBox(height: 8),

                      const Text(
                        'This password will also work with your email and OJAS ID.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    const Text(
                      'Choose your starter avatar',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'You can change this later.',
                      style: _subtitleStyle,
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _avatars
                          .map(_avatarOption)
                          .toList(),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 22),

                      _ErrorBox(_error!),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed:
                            _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Complete OJAS setup',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Center(
                      child: Text(
                        'Your OJAS ID becomes your unique identity on OJAS.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          height: 1.4,
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
      bottomNavigationBar: _loading
          ? const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFFF5B942),
            )
          : null,
    );
  }

  Widget _buildOjasIdField() {
    Color borderColor = const Color(0xFFD1D5DB);

    if (_ojasIdAvailable == true) {
      borderColor = const Color(0xFF16A34A);
    } else if (_ojasIdAvailable == false) {
      borderColor = const Color(0xFFDC2626);
    }

    Widget? suffix;

    if (_checkingId) {
      suffix = const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    } else if (_ojasIdAvailable == true) {
      suffix = const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF16A34A),
      );
    } else if (_ojasIdAvailable == false) {
      suffix = const Icon(
        Icons.cancel_rounded,
        color: Color(0xFFDC2626),
      );
    }

    return TextFormField(
      controller: _ojasIdController,
      enabled: !_loading,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 20,
      decoration: InputDecoration(
        labelText: 'Choose your OJAS ID',
        hintText: 'e.g. rachit_ojas',
        prefixIcon: const Icon(
          Icons.alternate_email_rounded,
        ),
        suffixIcon: suffix,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: borderColor == const Color(0xFFD1D5DB)
                ? const Color(0xFF111827)
                : borderColor,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        final normalized =
            ProfileService.normalizeOjasId(
          value ?? '',
        );

        if (!ProfileService.isValidOjasId(normalized)) {
          return 'Use 3–20 letters, numbers, or underscores.';
        }

        if (_ojasIdAvailable == false) {
          return 'This OJAS ID is already taken.';
        }

        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      enabled: !_loading,
      obscureText: _obscurePassword,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'Create OJAS password',
        hintText: 'At least 6 characters',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
        ),
        suffixIcon: IconButton(
          onPressed: _loading
              ? null
              : () {
                  setState(() {
                    _obscurePassword =
                        !_obscurePassword;
                  });
                },
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD1D5DB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD1D5DB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF111827),
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.length < 6) {
          return 'Use at least 6 characters.';
        }

        return null;
      },
    );
  }

  Widget _avatarOption(
    (String, IconData, Color) avatar,
  ) {
    final selected = _avatar == avatar.$1;

    return Semantics(
      button: true,
      selected: selected,
      label: avatar.$1,
      child: GestureDetector(
        onTap: _loading
            ? null
            : () {
                setState(() {
                  _avatar = avatar.$1;
                });
              },
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 150),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: avatar.$3.withValues(alpha: 0.30),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? const Color(0xFF111827)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            avatar.$2,
            color: const Color(0xFF111827),
            size: 27,
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _brandStyle = TextStyle(
  color: Color(0xFF111827),
  fontSize: 20,
  fontWeight: FontWeight.w900,
  letterSpacing: 3,
);

const _titleStyle = TextStyle(
  color: Color(0xFF111827),
  fontSize: 30,
  fontWeight: FontWeight.w800,
  height: 1.1,
);

const _subtitleStyle = TextStyle(
  color: Color(0xFF6B7280),
  fontSize: 15,
  height: 1.45,
);
