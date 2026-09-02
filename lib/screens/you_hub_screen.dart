import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'settings_screen.dart';
import 'signup_screen.dart';

class YouHubScreen extends StatefulWidget {
  const YouHubScreen({
    super.key,
    this.onLoggedOut,
  });

  final VoidCallback? onLoggedOut;

  @override
  State<YouHubScreen> createState() => _YouHubScreenState();
}

class _YouHubScreenState extends State<YouHubScreen> {
  static const Color _backgroundColor = Colors.white;
  static const Color _primaryColor = Color(0xFF111827);
  static const Color _secondaryColor = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _softBackground = Color(0xFFF8F9FB);
  static const Color _accentColor = Color(0xFFFFC107);

  final _accountStore = _LocalAccountStore();

  int _selectedSection = 1;

  List<_LocalAccount> _savedAccounts = [];

  bool _accountsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountStore.loadAccounts();

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await _accountStore.rememberCurrentUser(user);

        final updatedAccounts = await _accountStore.loadAccounts();

        if (!mounted) return;

        setState(() {
          _savedAccounts = updatedAccounts;
          _accountsLoading = false;
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        _savedAccounts = accounts;
        _accountsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _accountsLoading = false;
      });
    }
  }

  Future<void> _refreshAccounts() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await _accountStore.rememberCurrentUser(user);
    }

    final accounts = await _accountStore.loadAccounts();

    if (!mounted) return;

    setState(() {
      _savedAccounts = accounts;
    });
  }

  void _selectSection(int index) {
    if (_selectedSection == index) return;

    HapticFeedback.selectionClick();

    setState(() {
      _selectedSection = index;
    });
  }

  Future<void> _openAccountSwitcher(
    User user,
    Map<String, dynamic>? profile,
  ) async {
    HapticFeedback.selectionClick();

    await _refreshAccounts();

    if (!mounted) return;

    final currentOjasId = _stringValue(
      profile?['ojasId'],
      fallback: user.displayName ?? 'ojas_user',
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _AccountSwitcherSheet(
          currentUser: user,
          currentOjasId: currentOjasId,
          savedAccounts: _savedAccounts,
          onAccountTap: (account) async {
            Navigator.of(sheetContext).pop();

            await _switchAccount(account);
          },
          onAddAccount: () async {
            Navigator.of(sheetContext).pop();

            await _addAnotherAccount();
          },
          onCreateAccount: () async {
            Navigator.of(sheetContext).pop();

            await _createNewAccount();
          },
          onManageAccounts: () async {
            Navigator.of(sheetContext).pop();

            await _manageAccounts();
          },
          onLogout: () async {
            Navigator.of(sheetContext).pop();

            await _handleLogout();
          },
        );
      },
    );
  }

  Future<void> _switchAccount(_LocalAccount account) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser?.uid == account.uid) {
      return;
    }

    if (!mounted) return;

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Switch account',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Sign in to @${account.ojasId} to switch accounts securely.',
            style: const TextStyle(
              color: _secondaryColor,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true || !mounted) {
      return;
    }

    await _openLoginScreen();
  }

  Future<void> _addAnotherAccount() async {
    await _openLoginScreen();
  }

  Future<void> _openLoginScreen() async {
    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const LoginScreen(),
      ),
    );

    if (result == true) {
      await _refreshAccounts();
    }
  }

  Future<void> _createNewAccount() async {
    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const SignupScreen(),
      ),
    );

    if (result == true) {
      await _refreshAccounts();
    }
  }

  Future<void> _manageAccounts() async {
    await _refreshAccounts();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Manage accounts',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Accounts remembered on this device.',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_savedAccounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No saved accounts yet.',
                            style: TextStyle(
                              color: _secondaryColor,
                            ),
                          ),
                        )
                      else
                        ..._savedAccounts.map(
                          (account) {
                            final isCurrent =
                                FirebaseAuth.instance.currentUser?.uid ==
                                    account.uid;

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _softBackground,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _borderColor,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  leading: _ProfileAvatar(
                                    radius: 24,
                                    photoUrl: account.photoUrl,
                                    displayName:
                                        account.displayName,
                                  ),
                                  title: Text(
                                    account.displayName,
                                    style: const TextStyle(
                                      color: _primaryColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '@${account.ojasId}',
                                    style: const TextStyle(
                                      color: _secondaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: isCurrent
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF16A34A),
                                        )
                                      : IconButton(
                                          tooltip:
                                              'Remove from this device',
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          onPressed: () async {
                                            await _accountStore
                                                .removeAccount(
                                              account.uid,
                                            );

                                            final accounts =
                                                await _accountStore
                                                    .loadAccounts();

                                            if (!mounted) return;

                                            setState(() {
                                              _savedAccounts =
                                                  accounts;
                                            });

                                            setSheetState(() {});
                                          },
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    if (!mounted) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Log out of OJAS?',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'You can sign in again anytime using your OJAS ID, email, or Google account.',
            style: TextStyle(
              color: _secondaryColor,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Log out',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await AuthService.instance.signOut();

      if (!mounted) return;

      widget.onLoggedOut?.call();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to log out right now. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );

    await _refreshAccounts();
  }

  Future<void> _openProfileSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ProfileSetupScreen(),
      ),
    );

    if (result == true) {
      await _refreshAccounts();
    }
  }

  Future<void> _shareProfile(
    Map<String, dynamic>? profile,
    User user,
  ) async {
    HapticFeedback.selectionClick();

    final ojasId = _stringValue(
      profile?['ojasId'],
      fallback: user.displayName ?? 'ojas_user',
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Follow @$ojasId on OJAS.\nDiscover creators, videos and communities on OJAS.',
          subject: 'OJAS Profile',
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to share the profile right now.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditProfile(
    User user,
    Map<String, dynamic>? profile,
  ) async {
    final displayNameController = TextEditingController(
      text: _stringValue(
        profile?['displayName'],
        fallback: user.displayName ?? '',
      ),
    );

    final bioController = TextEditingController(
      text: _stringValue(
        profile?['bio'],
      ),
    );

    final websiteController = TextEditingController(
      text: _stringValue(
        profile?['website'],
      ),
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext)
                .viewInsets
                .bottom,
          ),
          child: _EditProfileSheet(
            initialPhotoUrl: _stringValue(
              profile?['photoUrl'],
              fallback: user.photoURL ?? '',
            ),
            displayNameController: displayNameController,
            bioController: bioController,
            websiteController: websiteController,
            onSave: (
              displayName,
              bio,
              website,
              photoUrl,
            ) async {
              final cleanName = displayName.trim();

              if (cleanName.isEmpty) {
                throw Exception('Display name cannot be empty.');
              }

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set(
                {
                  'uid': user.uid,
                  'displayName': cleanName,
                  'bio': bio.trim(),
                  'website': website.trim(),
                  'photoUrl': photoUrl,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );

              await user.updateDisplayName(cleanName);

              await _accountStore.rememberCurrentUser(
                user,
                displayName: cleanName,
                photoUrl: photoUrl,
              );

              return true;
            },
          ),
        );
      },
    );

    displayNameController.dispose();
    bioController.dispose();
    websiteController.dispose();

    if (result == true) {
      await _refreshAccounts();
    }
  }

  Future<void> _changeAvatar(
    User user,
    Map<String, dynamic>? profile,
  ) async {
    final currentPhotoUrl = _stringValue(
      profile?['photoUrl'],
      fallback: user.photoURL ?? 'avatar_1',
    );

    final selectedAvatar = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AvatarPickerSheet(
          currentAvatar: currentPhotoUrl,
        );
      },
    );

    if (selectedAvatar == null || selectedAvatar == currentPhotoUrl) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'photoUrl': selectedAvatar,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _accountStore.rememberCurrentUser(
        user,
        photoUrl: selectedAvatar,
      );

      await _refreshAccounts();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update your profile picture.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  int _intValue(dynamic value) {
    if (value is int) return value;

    if (value is num) return value.toInt();

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: _primaryColor,
              ),
            ),
          );
        }

        if (user == null) {
          return _SignedOutView(
            onLogin: _openLoginScreen,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data?.data();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_accountsLoading) {
                _accountStore.rememberCurrentUser(
                  user,
                  displayName: _stringValue(
                    profile?['displayName'],
                    fallback:
                        user.displayName ?? 'OJAS User',
                  ),
                  ojasId: _stringValue(
                    profile?['ojasId'],
                    fallback:
                        user.displayName ?? 'ojas_user',
                  ),
                  photoUrl: _stringValue(
                    profile?['photoUrl'],
                    fallback: user.photoURL ?? '',
                  ),
                );
              }
            });

            return Scaffold(
              backgroundColor: _backgroundColor,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(
                      user,
                      profile,
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedSection,
                        children: [
                          _MessagesSection(
                            onStartConversation: () {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Messaging will connect to real OJAS users next.',
                                  ),
                                  behavior:
                                      SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          _ProfileSection(
                            user: user,
                            profile: profile,
                            isLoading:
                                profileSnapshot.connectionState ==
                                    ConnectionState.waiting,
                            onEditProfile: () =>
                                _openEditProfile(
                              user,
                              profile,
                            ),
                            onShareProfile: () =>
                                _shareProfile(
                              profile,
                              user,
                            ),
                            onChangeAvatar: () =>
                                _changeAvatar(
                              user,
                              profile,
                            ),
                            onCompleteProfile:
                                _openProfileSetup,
                            getString: _stringValue,
                            getInt: _intValue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(
    User user,
    Map<String, dynamic>? profile,
  ) {
    final photoUrl = _stringValue(
      profile?['photoUrl'],
      fallback: user.photoURL ?? '',
    );

    final displayName = _stringValue(
      profile?['displayName'],
      fallback: user.displayName ?? 'OJAS User',
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        10,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openAccountSwitcher(
              user,
              profile,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _ProfileAvatar(
                  radius: 25,
                  photoUrl: photoUrl,
                  displayName: displayName,
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _TopTabButton(
                      label: 'Messages',
                      selected: _selectedSection == 0,
                      onTap: () => _selectSection(0),
                    ),
                  ),
                  Expanded(
                    child: _TopTabButton(
                      label: 'Profile',
                      selected: _selectedSection == 1,
                      onTap: () => _selectSection(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: _primaryColor,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTabButton extends StatelessWidget {
  const _TopTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _primaryColor = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? _primaryColor
                  : const Color(0xFF9CA3AF),
              fontSize: 15,
              fontWeight: selected
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagesSection extends StatefulWidget {
  const _MessagesSection({
    required this.onStartConversation,
  });

  final VoidCallback onStartConversation;

  @override
  State<_MessagesSection> createState() =>
      _MessagesSectionState();
}

class _MessagesSectionState extends State<_MessagesSection> {
  final TextEditingController _searchController =
      TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        Row(
          children: [
            const Text(
              'Messages',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'New message',
              onPressed: widget.onStartConversation,
              icon: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _query = value.trim();
            });
          },
          decoration: InputDecoration(
            hintText: 'Search conversations',
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF6B7280),
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _query = '';
                      });
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
            filled: true,
            fillColor: const Color(0xFFF5F6F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF111827),
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 44),
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 38,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'No conversations yet',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Connect with creators and start a conversation on OJAS.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: OutlinedButton.icon(
            onPressed: widget.onStartConversation,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF111827),
              side: const BorderSide(
                color: Color(0xFF111827),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(
              Icons.add_comment_outlined,
            ),
            label: const Text(
              'Start a conversation',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.user,
    required this.profile,
    required this.isLoading,
    required this.onEditProfile,
    required this.onShareProfile,
    required this.onChangeAvatar,
    required this.onCompleteProfile,
    required this.getString,
    required this.getInt,
  });

  final User user;
  final Map<String, dynamic>? profile;
  final bool isLoading;

  final Future<void> Function() onEditProfile;
  final Future<void> Function() onShareProfile;
  final Future<void> Function() onChangeAvatar;
  final Future<void> Function() onCompleteProfile;

  final String Function(
    dynamic value, {
    String fallback,
  }) getString;

  final int Function(dynamic value) getInt;

  static const Color _primaryColor = Color(0xFF111827);
  static const Color _secondaryColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final ojasId = getString(
      profile?['ojasId'],
      fallback: '',
    );

    final displayName = getString(
      profile?['displayName'],
      fallback: user.displayName ?? 'OJAS Creator',
    );

    final photoUrl = getString(
      profile?['photoUrl'],
      fallback: user.photoURL ?? '',
    );

    final bio = getString(
      profile?['bio'],
      fallback: '',
    );

    final website = getString(
      profile?['website'],
      fallback: '',
    );

    final following = getInt(
      profile?['followingCount'],
    );

    final followers = getInt(
      profile?['followersCount'],
    );

    final likes = getInt(
      profile?['likesCount'],
    );

    final profileComplete =
        profile?['profileComplete'] == true;

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (
          context,
          innerBoxIsScrolled,
        ) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  20,
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ProfileAvatar(
                          radius: 56,
                          photoUrl: photoUrl,
                          displayName: displayName,
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Material(
                            color: const Color(0xFFFFC107),
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder:
                                  const CircleBorder(),
                              onTap: () {
                                onChangeAvatar();
                              },
                              child: const SizedBox(
                                width: 38,
                                height: 38,
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  color: Color(0xFF111827),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (ojasId.isNotEmpty)
                      Text(
                        '@$ojasId',
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          onCompleteProfile();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7D6),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Create your OJAS ID',
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _secondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        _ProfileStat(
                          value: _formatNumber(following),
                          label: 'Following',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE5E7EB),
                        ),
                        _ProfileStat(
                          value: _formatNumber(followers),
                          label: 'Followers',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE5E7EB),
                        ),
                        _ProfileStat(
                          value: _formatNumber(likes),
                          label: 'Likes',
                        ),
                      ],
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _secondaryColor,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (website.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        website,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      onEditProfile();
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF111827),
                                foregroundColor:
                                    Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () {
                                onShareProfile();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    const Color(0xFF111827),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Share Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!profileComplete) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius:
                            BorderRadius.circular(12),
                        onTap: () {
                          onCompleteProfile();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFD97706),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Complete your OJAS identity to unlock all profile features.',
                                  style: TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabDelegate(
                const TabBar(
                  indicatorColor: Color(0xFF111827),
                  indicatorWeight: 2,
                  labelColor: Color(0xFF111827),
                  unselectedLabelColor: Color(0xFF9CA3AF),
                  tabs: [
                    Tab(
                      icon: Icon(
                        Icons.grid_view_rounded,
                      ),
                    ),
                    Tab(
                      icon: Icon(
                        Icons.bookmark_border_rounded,
                      ),
                    ),
                    Tab(
                      icon: Icon(
                        Icons.lock_outline_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: const TabBarView(
          children: [
            _ProfileContentEmptyState(
              icon: Icons.video_library_outlined,
              title: 'No videos yet',
              subtitle:
                  'Videos you publish will appear here.',
            ),
            _ProfileContentEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No saved videos yet',
              subtitle:
                  'Videos you save will appear here.',
            ),
            _ProfileContentEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Private content',
              subtitle:
                  'Only you can see your private content.',
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000000) {
      final number = value / 1000000;

      return '${number.toStringAsFixed(number % 1 == 0 ? 0 : 1)}M';
    }

    if (value >= 1000) {
      final number = value / 1000;

      return '${number.toStringAsFixed(number % 1 == 0 ? 0 : 1)}K';
    }

    return value.toString();
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProfileContentEmptyState extends StatelessWidget {
  const _ProfileContentEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabDelegate
    extends SliverPersistentHeaderDelegate {
  const _ProfileTabDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0xFFF3F4F6),
          ),
          bottom: BorderSide(
            color: Color(0xFFF3F4F6),
          ),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(
    covariant _ProfileTabDelegate oldDelegate,
  ) {
    return oldDelegate.tabBar != tabBar;
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.radius,
    required this.photoUrl,
    required this.displayName,
  });

  final double radius;
  final String photoUrl;
  final String displayName;

  static const Map<String, IconData> _starterAvatars = {
    'avatar_1': Icons.wb_sunny_outlined,
    'avatar_2': Icons.auto_awesome_outlined,
    'avatar_3': Icons.local_florist_outlined,
    'avatar_4': Icons.nightlight_outlined,
  };

  static const Map<String, Color> _avatarColors = {
    'avatar_1': Color(0xFFFFE8A3),
    'avatar_2': Color(0xFFB8D8D8),
    'avatar_3': Color(0xFFE8B4B8),
    'avatar_4': Color(0xFFC7D2FE),
  };

  @override
  Widget build(BuildContext context) {
    final normalizedPhoto = photoUrl.trim();

    if (_starterAvatars.containsKey(normalizedPhoto)) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _avatarColors[normalizedPhoto],
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Icon(
          _starterAvatars[normalizedPhoto],
          size: radius,
          color: const Color(0xFF111827),
        ),
      );
    }

    final isNetworkImage =
        normalizedPhoto.startsWith('http://') ||
            normalizedPhoto.startsWith('https://');

    if (isNetworkImage) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFF3F4F6),
        backgroundImage: NetworkImage(
          normalizedPhoto,
        ),
        onBackgroundImageError: (
          exception,
          stackTrace,
        ) {},
      );
    }

    final letter = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'O';

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF3F4F6),
      child: Text(
        letter,
        style: TextStyle(
          color: const Color(0xFF111827),
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AccountSwitcherSheet extends StatelessWidget {
  const _AccountSwitcherSheet({
    required this.currentUser,
    required this.currentOjasId,
    required this.savedAccounts,
    required this.onAccountTap,
    required this.onAddAccount,
    required this.onCreateAccount,
    required this.onManageAccounts,
    required this.onLogout,
  });

  final User currentUser;
  final String currentOjasId;
  final List<_LocalAccount> savedAccounts;

  final Future<void> Function(
    _LocalAccount account,
  ) onAccountTap;

  final Future<void> Function() onAddAccount;
  final Future<void> Function() onCreateAccount;
  final Future<void> Function() onManageAccounts;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final otherAccounts = savedAccounts
        .where(
          (account) => account.uid != currentUser.uid,
        )
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'OJAS accounts',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: _ProfileAvatar(
                  radius: 26,
                  photoUrl: currentUser.photoURL ?? '',
                  displayName:
                      currentUser.displayName ?? 'OJAS User',
                ),
                title: Text(
                  currentUser.displayName ??
                      'OJAS User',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '@$currentOjasId',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
            if (otherAccounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...otherAccounts.map(
                (account) {
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    leading: _ProfileAvatar(
                      radius: 24,
                      photoUrl: account.photoUrl,
                      displayName:
                          account.displayName,
                    ),
                    title: Text(
                      account.displayName,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '@${account.ojasId}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                    onTap: () {
                      onAccountTap(account);
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            const Divider(
              color: Color(0xFFE5E7EB),
            ),
            _AccountActionTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Add another account',
              onTap: onAddAccount,
            ),
            _AccountActionTile(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Create new OJAS account',
              onTap: onCreateAccount,
            ),
            const SizedBox(height: 4),
            _AccountActionTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Manage accounts',
              onTap: onManageAccounts,
            ),
            _AccountActionTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              destructive: true,
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final bool destructive;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFDC2626)
        : const Color(0xFF111827);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () {
        onTap();
      },
    );
  }
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({
    required this.currentAvatar,
  });

  final String currentAvatar;

  static const List<_AvatarChoice> _choices = [
    _AvatarChoice(
      'avatar_1',
      Icons.wb_sunny_outlined,
      Color(0xFFFFE8A3),
    ),
    _AvatarChoice(
      'avatar_2',
      Icons.auto_awesome_outlined,
      Color(0xFFB8D8D8),
    ),
    _AvatarChoice(
      'avatar_3',
      Icons.local_florist_outlined,
      Color(0xFFE8B4B8),
    ),
    _AvatarChoice(
      'avatar_4',
      Icons.nightlight_outlined,
      Color(0xFFC7D2FE),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 22),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose profile picture',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: _choices.map(
                  (choice) {
                    final selected =
                        currentAvatar == choice.id;

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context)
                            .pop(choice.id);
                      },
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: choice.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF111827)
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          choice.icon,
                          color: const Color(0xFF111827),
                          size: 34,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarChoice {
  const _AvatarChoice(
    this.id,
    this.icon,
    this.color,
  );

  final String id;
  final IconData icon;
  final Color color;
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.initialPhotoUrl,
    required this.displayNameController,
    required this.bioController,
    required this.websiteController,
    required this.onSave,
  });

  final String initialPhotoUrl;

  final TextEditingController displayNameController;
  final TextEditingController bioController;
  final TextEditingController websiteController;

  final Future<bool> Function(
    String displayName,
    String bio,
    String website,
    String photoUrl,
  ) onSave;

  @override
  State<_EditProfileSheet> createState() =>
      _EditProfileSheetState();
}

class _EditProfileSheetState
    extends State<_EditProfileSheet> {
  bool _saving = false;

  String? _error;

  Future<void> _save() async {
    if (_saving) return;

    if (widget.displayNameController.text.trim().isEmpty) {
      setState(() {
        _error = 'Display name cannot be empty.';
      });

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final success = await widget.onSave(
        widget.displayNameController.text,
        widget.bioController.text,
        widget.websiteController.text,
        widget.initialPhotoUrl,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Unable to save your profile. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius:
                        BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Edit profile',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller:
                    widget.displayNameController,
                maxLength: 50,
                decoration: _inputDecoration(
                  label: 'Display name',
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: widget.bioController,
                maxLength: 160,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(
                  label: 'Bio',
                  icon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller:
                    widget.websiteController,
                keyboardType:
                    TextInputType.url,
                decoration: _inputDecoration(
                  label: 'Website',
                  icon: Icons.link_rounded,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFECACA),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
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
          width: 1.5,
        ),
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView({
    required this.onLogin,
  });

  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 40,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to OJAS',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to access your profile and messages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    onLogin();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalAccount {
  const _LocalAccount({
    required this.uid,
    required this.ojasId,
    required this.displayName,
    required this.photoUrl,
    required this.email,
    required this.lastUsedAt,
  });

  final String uid;
  final String ojasId;
  final String displayName;
  final String photoUrl;
  final String email;
  final int lastUsedAt;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'ojasId': ojasId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'email': email,
      'lastUsedAt': lastUsedAt,
    };
  }

  factory _LocalAccount.fromJson(
    Map<String, dynamic> json,
  ) {
    return _LocalAccount(
      uid: json['uid'] as String? ?? '',
      ojasId: json['ojasId'] as String? ?? 'ojas_user',
      displayName:
          json['displayName'] as String? ?? 'OJAS User',
      photoUrl: json['photoUrl'] as String? ?? '',
      email: json['email'] as String? ?? '',
      lastUsedAt: json['lastUsedAt'] as int? ?? 0,
    );
  }
}

class _LocalAccountStore {
  static const String _storageKey =
      'ojas_saved_accounts_v1';

  Future<List<_LocalAccount>> loadAccounts() async {
    final preferences =
        await SharedPreferences.getInstance();

    final rawList =
        preferences.getStringList(_storageKey) ??
            const [];

    final accounts = <_LocalAccount>[];

    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map<String, dynamic>) {
          final account =
              _LocalAccount.fromJson(decoded);

          if (account.uid.isNotEmpty) {
            accounts.add(account);
          }
        }
      } catch (_) {}
    }

    accounts.sort(
      (a, b) => b.lastUsedAt.compareTo(a.lastUsedAt),
    );

    return accounts;
  }

  Future<void> rememberCurrentUser(
    User user, {
    String? displayName,
    String? ojasId,
    String? photoUrl,
  }) async {
    final accounts = await loadAccounts();

    final existingIndex = accounts.indexWhere(
      (account) => account.uid == user.uid,
    );

    final existing = existingIndex >= 0
        ? accounts[existingIndex]
        : null;

    final account = _LocalAccount(
      uid: user.uid,
      ojasId: _clean(
        ojasId,
        existing?.ojasId ??
            user.displayName ??
            'ojas_user',
      ),
      displayName: _clean(
        displayName,
        existing?.displayName ??
            user.displayName ??
            'OJAS User',
      ),
      photoUrl: _clean(
        photoUrl,
        existing?.photoUrl ?? user.photoURL ?? '',
      ),
      email: user.email ??
          existing?.email ??
          '',
      lastUsedAt:
          DateTime.now().millisecondsSinceEpoch,
    );

    if (existingIndex >= 0) {
      accounts.removeAt(existingIndex);
    }

    accounts.insert(0, account);

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setStringList(
      _storageKey,
      accounts
          .map(
            (item) => jsonEncode(
              item.toJson(),
            ),
          )
          .toList(),
    );
  }

  Future<void> removeAccount(String uid) async {
    final accounts = await loadAccounts();

    accounts.removeWhere(
      (account) => account.uid == uid,
    );

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setStringList(
      _storageKey,
      accounts
          .map(
            (item) => jsonEncode(
              item.toJson(),
            ),
          )
          .toList(),
    );
  }

  String _clean(
    String? value,
    String fallback,
  ) {
    if (value != null &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }
}
