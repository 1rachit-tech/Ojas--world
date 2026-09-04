import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ojas_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

import 'login_screen.dart';
import 'messages_screen.dart';
import 'profile_setup_screen.dart';
import 'settings_screen.dart';
import 'signup_screen.dart';

class YouHubScreen extends StatefulWidget {
  const YouHubScreen({super.key, this.onLoggedOut});

  final VoidCallback? onLoggedOut;

  @override
  State<YouHubScreen> createState() => _YouHubScreenState();
}

class _YouHubSwipePhysics extends PageScrollPhysics {
  const _YouHubSwipePhysics({super.parent});

  @override
  double? get dragStartDistanceMotionThreshold => 4.0;

  @override
  double get minFlingDistance => 8.0;

  @override
  _YouHubSwipePhysics applyTo(ScrollPhysics? ancestor) {
    return _YouHubSwipePhysics(parent: buildParent(ancestor));
  }
}

class _YouHubScreenState extends State<YouHubScreen> {
  static const Color _primary = Color(0xFF111827);

  static const Color _secondary = Color(0xFF6B7280);

  static const Color _soft = Color(0xFFF7F8FA);

  final _accountStore = _LocalAccountStore();
  late final PageController _pageController;

  int _selectedTab = 0;

  List<_SavedAccount> _accounts = [];

  bool _accountsLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await _accountStore.rememberUser(user);
      }

      final accounts = await _accountStore.loadAccounts();

      if (!mounted) {
        return;
      }

      setState(() {
        _accounts = accounts;
        _accountsLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _accountsLoading = false;
      });
    }
  }

  Future<void> _refreshAccounts(OjasProfile? profile) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await _accountStore.rememberUser(
        user,
        displayName: profile?.displayName,
        ojasId: profile?.ojasId,
        photoUrl: profile?.photoUrl,
      );
    }

    final accounts = await _accountStore.loadAccounts();

    if (!mounted) {
      return;
    }

    setState(() {
      _accounts = accounts;
    });
  }

  void _changeTab(int index) {
    if (_selectedTab == index) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedTab = index;
    });

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int index) {
    if (_selectedTab == index) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedTab = index;
    });
  }

  Future<void> _openAccountSwitcher(User user, OjasProfile? profile) async {
    await _refreshAccounts(profile);

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _AccountSwitcher(
          currentUid: user.uid,
          accounts: _accounts,
          onAccountTap: (account) async {
            Navigator.of(sheetContext).pop();

            if (account.uid == user.uid) {
              return;
            }

            await _openLogin();
          },
          onAddAccount: () async {
            Navigator.of(sheetContext).pop();

            await _openLogin();
          },
          onCreateAccount: () async {
            Navigator.of(sheetContext).pop();

            await _openSignup();
          },
          onRemoveAccount: (account) async {
            await _accountStore.removeAccount(account.uid);

            final accounts = await _accountStore.loadAccounts();

            if (!mounted) {
              return;
            }

            setState(() {
              _accounts = accounts;
            });
          },
          onLogout: () async {
            Navigator.of(sheetContext).pop();

            await _logout();
          },
        );
      },
    );
  }

  Future<void> _openLogin() async {
    if (!mounted) {
      return;
    }

    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const LoginScreen()));

    if (result == true) {
      await _loadAccounts();
    }
  }

  Future<void> _openSignup() async {
    if (!mounted) {
      return;
    }

    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const SignupScreen()));

    if (result == true) {
      await _loadAccounts();
    }
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  Future<void> _openProfileSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileSetupScreen()),
    );

    if (result == true) {
      await _loadAccounts();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
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
            style: TextStyle(fontWeight: FontWeight.w800, color: _primary),
          ),
          content: const Text(
            'You can sign in again anytime using your OJAS ID, email, or Google account.',
            style: TextStyle(color: _secondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await AuthService.instance.signOut();

      if (!mounted) {
        return;
      }

      widget.onLoggedOut?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to log out. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareProfile(OjasProfile profile) async {
    HapticFeedback.selectionClick();

    final ojasId = profile.ojasId;

    if (ojasId.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create your OJAS ID before sharing your profile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    try {
      await Share.share(
        'Follow @${profile.ojasId} on OJAS.\n'
        'Discover creators, videos and communities on OJAS.',
        subject: 'OJAS Profile',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to share your profile right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editProfile(OjasProfile profile) async {
    final nameController = TextEditingController(text: profile.displayName);

    final bioController = TextEditingController(text: profile.bio);

    final websiteController = TextEditingController(text: profile.website);

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _EditProfileSheet(
            nameController: nameController,
            bioController: bioController,
            websiteController: websiteController,
            onSave: () async {
              await ProfileService.instance.updateCurrentProfile(
                displayName: nameController.text,
                bio: bioController.text,
                website: websiteController.text,
              );

              await _refreshAccounts(
                profile.copyWith(
                  displayName: nameController.text.trim(),
                  bio: bioController.text.trim(),
                  website: websiteController.text.trim(),
                ),
              );

              return true;
            },
          ),
        );
      },
    );

    nameController.dispose();
    bioController.dispose();
    websiteController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeAvatar(OjasProfile profile) async {
    final selectedAvatar = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AvatarPicker(selectedAvatar: profile.photoUrl);
      },
    );

    if (selectedAvatar == null || selectedAvatar == profile.photoUrl) {
      return;
    }

    try {
      await ProfileService.instance.updateProfilePhoto(selectedAvatar);

      await _refreshAccounts(profile.copyWith(photoUrl: selectedAvatar));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update profile picture.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: _primary)),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          return _LoggedOutPage(onLogin: _openLogin);
        }

        return StreamBuilder<OjasProfile?>(
          stream: ProfileService.instance.watchCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 52,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to load profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _secondary),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _openProfileSetup,
                            child: const Text('Try profile setup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data;

            return Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(user, profile),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        physics: const _YouHubSwipePhysics(),
                        children: [
                          const MessagesScreen(showAppBar: false),
                          _ProfilePage(
                            profile: profile,
                            firebaseUser: user,
                            onEdit: profile == null
                                ? _openProfileSetup
                                : () {
                                    _editProfile(profile);
                                  },
                            onShare: profile == null
                                ? _openProfileSetup
                                : () {
                                    _shareProfile(profile);
                                  },
                            onChangeAvatar: profile == null
                                ? _openProfileSetup
                                : () {
                                    _changeAvatar(profile);
                                  },
                            onCompleteProfile: _openProfileSetup,
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

  Widget _buildTopBar(User user, OjasProfile? profile) {
    final displayName = profile?.displayName ?? user.displayName ?? 'OJAS User';

    final photoUrl = profile?.photoUrl ?? user.photoURL ?? '';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 12),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              _openAccountSwitcher(user, profile);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _Avatar(
                  radius: 25,
                  photoUrl: photoUrl,
                  displayName: displayName,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _TopTab(
                      title: 'Messages',
                      selected: _selectedTab == 0,
                      onTap: () => _changeTab(0),
                    ),
                  ),
                  Expanded(
                    child: _TopTab(
                      title: 'Profile',
                      selected: _selectedTab == 1,
                      onTap: () => _changeTab(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: _primary,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedOutPage extends StatelessWidget {
  const _LoggedOutPage({required this.onLogin});

  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 56,
                  color: Color(0xFF111827),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to OJAS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to access your profile and messages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onLogin,
                    child: const Text('Log in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF111827)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.profile,
    required this.firebaseUser,
    required this.onEdit,
    required this.onShare,
    required this.onChangeAvatar,
    required this.onCompleteProfile,
  });

  final OjasProfile? profile;
  final User firebaseUser;

  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onChangeAvatar;
  final VoidCallback onCompleteProfile;

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile?.displayName ?? firebaseUser.displayName ?? 'OJAS User';

    final photoUrl = profile?.photoUrl ?? firebaseUser.photoURL ?? '';

    final ojasId = profile?.ojasId ?? '';

    final bio = profile?.bio ?? '';

    final website = profile?.website ?? '';

    final isCreator = profile?.isCreator ?? false;

    final category = profile?.creatorCategory ?? '';

    final isVerified = profile?.isVerified ?? false;

    final following = profile?.followingCount ?? 0;

    final followers = profile?.followersCount ?? 0;

    final likes = profile?.likesCount ?? 0;

    final posts = profile?.postsCount ?? 0;

    final profileComplete = profile != null && ojasId.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _Avatar(radius: 58, photoUrl: photoUrl, displayName: displayName),
              Positioned(
                right: -4,
                bottom: -2,
                child: Material(
                  color: const Color(0xFFF5B942),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onChangeAvatar,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 20,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        if (profileComplete)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '@$ojasId',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ],
            ],
          )
        else
          const Text(
            'Complete your OJAS ID',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),

        const SizedBox(height: 7),

        Text(
          displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, color: Color(0xFF6B7280)),
        ),

        if (isCreator && category.isNotEmpty) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                category,
                style: const TextStyle(
                  color: Color(0xFFB7791F),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],

        if (!profileComplete) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: onCompleteProfile,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Create OJAS ID'),
            ),
          ),
        ],

        const SizedBox(height: 30),

        Row(
          children: [
            Expanded(
              child: _Stat(value: _formatNumber(following), label: 'Following'),
            ),
            Expanded(
              child: _Stat(value: _formatNumber(followers), label: 'Followers'),
            ),
            Expanded(
              child: _Stat(value: _formatNumber(likes), label: 'Likes'),
            ),
          ],
        ),

        if (bio.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4B5563),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onEdit,
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onShare,
                  child: const Text(
                    'Share Profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 36),

        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    size: 27,
                    color: Color(0xFF111827),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    posts > 0 ? '$posts Posts' : 'Posts',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Icon(
                  Icons.bookmark_border_rounded,
                  size: 27,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 27,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        const Divider(color: Color(0xFFE5E7EB), height: 1),

        const SizedBox(height: 65),

        Icon(
          posts > 0
              ? Icons.video_library_outlined
              : Icons.video_library_outlined,
          size: 54,
          color: const Color(0xFFD1D5DB),
        ),

        const SizedBox(height: 16),

        Text(
          posts > 0 ? 'Your posts will appear here' : 'No posts yet',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Your videos and posts will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  static String _formatNumber(int value) {
    if (value >= 1000000) {
      final number = value / 1000000;

      return number % 1 == 0
          ? '${number.toInt()}M'
          : '${number.toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      final number = value / 1000;

      return number % 1 == 0
          ? '${number.toInt()}K'
          : '${number.toStringAsFixed(1)}K';
    }

    return value.toString();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.radius,
    required this.photoUrl,
    required this.displayName,
  });

  final double radius;
  final String photoUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    const avatarIcons = <String, IconData>{
      'avatar_1': Icons.wb_sunny_outlined,
      'avatar_2': Icons.auto_awesome_outlined,
      'avatar_3': Icons.local_florist_outlined,
      'avatar_4': Icons.nightlight_outlined,
    };

    if (avatarIcons.containsKey(photoUrl)) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF3F4F6),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        ),
        child: Icon(
          avatarIcons[photoUrl],
          size: radius,
          color: const Color(0xFF111827),
        ),
      );
    }

    if (photoUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _initialAvatar();
          },
        ),
      );
    }

    return _initialAvatar();
  }

  Widget _initialAvatar() {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'O';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF5B942),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.nameController,
    required this.bioController,
    required this.websiteController,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController bioController;
  final TextEditingController websiteController;

  final Future<bool> Function() onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  bool _saving = false;

  String? _error;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final success = await widget.onSave();

      if (!mounted) {
        return;
      }

      if (success) {
        Navigator.of(context).pop(true);
      }
    } on ProfileException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message ?? 'Unable to save your profile.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to save your profile. Please try again.';
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: SingleChildScrollView(
            child: Column(
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
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: widget.nameController,
                  enabled: !_saving,
                  maxLength: 50,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Display name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.bioController,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 160,
                  decoration: _inputDecoration('Bio'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.websiteController,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  maxLength: 200,
                  decoration: _inputDecoration('Website'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save changes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF111827), width: 2),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.selectedAvatar});

  final String selectedAvatar;

  @override
  Widget build(BuildContext context) {
    const avatars = <String, IconData>{
      'avatar_1': Icons.wb_sunny_outlined,
      'avatar_2': Icons.auto_awesome_outlined,
      'avatar_3': Icons.local_florist_outlined,
      'avatar_4': Icons.nightlight_outlined,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
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
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 22),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: avatars.entries.map((entry) {
                final selected = entry.key == selectedAvatar;

                return InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () {
                    Navigator.of(context).pop(entry.key);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF3F4F6),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF111827)
                            : const Color(0xFFE5E7EB),
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: Icon(entry.value, color: const Color(0xFF111827)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSwitcher extends StatelessWidget {
  const _AccountSwitcher({
    required this.currentUid,
    required this.accounts,
    required this.onAccountTap,
    required this.onAddAccount,
    required this.onCreateAccount,
    required this.onRemoveAccount,
    required this.onLogout,
  });

  final String currentUid;

  final List<_SavedAccount> accounts;

  final Future<void> Function(_SavedAccount account) onAccountTap;

  final Future<void> Function() onAddAccount;

  final Future<void> Function() onCreateAccount;

  final Future<void> Function(_SavedAccount account) onRemoveAccount;

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
              'Switch account',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Accounts remembered on this device',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),

            ...accounts.map((account) {
              final current = account.uid == currentUid;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  tileColor: const Color(0xFFF8F9FA),
                  leading: _Avatar(
                    radius: 23,
                    photoUrl: account.photoUrl,
                    displayName: account.displayName,
                  ),
                  title: Text(
                    account.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    account.ojasId.isNotEmpty
                        ? '@${account.ojasId}'
                        : 'OJAS account',
                  ),
                  trailing: current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                        )
                      : IconButton(
                          tooltip: 'Remove',
                          onPressed: () async {
                            await onRemoveAccount(account);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: () async {
                    await onAccountTap(account);
                  },
                ),
              );
            }),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () async {
                await onAddAccount();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log into another account'),
            ),

            const SizedBox(height: 8),

            TextButton.icon(
              onPressed: () async {
                await onCreateAccount();
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Create new OJAS account'),
            ),

            const Divider(height: 28),

            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () async {
                await onLogout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Log out',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAccount {
  const _SavedAccount({
    required this.uid,
    required this.displayName,
    required this.ojasId,
    required this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String ojasId;
  final String photoUrl;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'ojasId': ojasId,
      'photoUrl': photoUrl,
    };
  }

  factory _SavedAccount.fromJson(Map<String, dynamic> json) {
    return _SavedAccount(
      uid: json['uid']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'OJAS User',
      ojasId: json['ojasId']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString() ?? '',
    );
  }
}

class _LocalAccountStore {
  static const String _storageKey = 'ojas_saved_accounts_v1';

  Future<List<_SavedAccount>> loadAccounts() async {
    final preferences = await SharedPreferences.getInstance();

    final raw = preferences.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => _SavedAccount.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((account) => account.uid.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> rememberUser(
    User user, {
    String? displayName,
    String? ojasId,
    String? photoUrl,
  }) async {
    final accounts = await loadAccounts();

    final account = _SavedAccount(
      uid: user.uid,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : user.displayName ?? 'OJAS User',
      ojasId: ojasId?.trim().isNotEmpty == true ? ojasId!.trim() : '',
      photoUrl: photoUrl?.trim().isNotEmpty == true
          ? photoUrl!.trim()
          : user.photoURL ?? '',
    );

    final updated = <_SavedAccount>[
      account,
      ...accounts.where((item) => item.uid != user.uid),
    ];

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _storageKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> removeAccount(String uid) async {
    final accounts = await loadAccounts();

    final updated = accounts.where((account) => account.uid != uid);

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _storageKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }
}
