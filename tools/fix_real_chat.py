from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'{label}: expected block missing; refusing to modify.')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# Create/read a deterministic conversation without a get() on a missing document.
messaging = Path('lib/services/messaging_service.dart')
text = messaging.read_text(encoding='utf-8')
start = text.index('  Future<String> openConversation(OjasProfile otherUser) async {')
end = text.index('  Future<void> sendTextMessage({', start)
new_open_conversation = '''  Future<String> openConversation(OjasProfile otherUser) async {
    final uid = currentUid;
    if (uid == null) {
      throw const MessagingException('Please sign in again.');
    }
    if (otherUser.uid.isEmpty || otherUser.uid == uid) {
      throw const MessagingException('Invalid OJAS user.');
    }

    final currentProfile = await _getCurrentProfile(uid);
    final conversationId = conversationIdFor(uid, otherUser.uid);
    final reference = conversationReference(conversationId);

    final existing = await _conversations
        .where('participants', arrayContains: uid)
        .get();

    for (final document in existing.docs) {
      if (document.id == conversationId) {
        return conversationId;
      }
    }

    await reference.set({
      'participants': [uid, otherUser.uid],
      'participantProfiles': {
        uid: _profileMap(currentProfile),
        otherUser.uid: _profileMap(otherUser),
      },
      'lastMessage': '',
      'lastMessageSenderId': '',
      'unreadCounts': {uid: 0, otherUser.uid: 0},
      'lastReadAtBy': {uid: FieldValue.serverTimestamp()},
      'typingBy': {uid: false, otherUser.uid: false},
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    return conversationId;
  }

'''
messaging.write_text(text[:start] + new_open_conversation + text[end:], encoding='utf-8')

# Hide an empty conversation until the first real message is sent.
replace_once(
    'lib/services/messaging_service.dart',
    '''      return conversations;
    });
  }

  Stream<OjasConversation> watchConversation''',
    '''      return conversations
          .where((conversation) =>
              conversation.lastMessage.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Stream<OjasConversation> watchConversation''',
    'conversation empty-state filter',
)

# Older conversations may not contain participantProfiles.
messages = Path('lib/screens/messages_screen.dart')
text = messages.read_text(encoding='utf-8')
if "import '../services/profile_service.dart';\n" not in text:
    text = text.replace(
        "import '../services/messaging_service.dart';\n",
        "import '../services/messaging_service.dart';\nimport '../services/profile_service.dart';\n",
        1,
    )
old_open = '''    final profileData =
        conversation.profileFor(otherUid);

    final profile =
        OjasProfile.fromMap(
      profileData,
      uid: otherUid,
    );

    await Navigator.of(context).push(
'''
new_open = '''    final profileData =
        conversation.profileFor(otherUid);

    OjasProfile profile;
    if (profileData.isEmpty) {
      profile = await ProfileService.instance.getProfile(otherUid) ??
          OjasProfile.empty(
            uid: otherUid,
            displayName: 'OJAS User',
            photoUrl: 'avatar_1',
          );
    } else {
      profile = OjasProfile.fromMap(
        profileData,
        uid: otherUid,
      );
      if (profile.ojasId.isEmpty) {
        final fetched = await ProfileService.instance.getProfile(otherUid);
        if (fetched != null) {
          profile = fetched;
        }
      }
    }

    await Navigator.of(context).push(
'''
replace_once('lib/screens/messages_screen.dart', old_open, new_open, 'messages older-conversation profile fallback')
replace_once(
    'lib/screens/messages_screen.dart',
    '''            const Text(
              'Your messages live here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
''',
    '''            const Text(
              'Find your Mitra',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.25,
              ),
            ),
''',
    'messages empty-state title',
)

# Notification taps also support older conversation documents.
router = Path('lib/screens/notification_chat_router.dart')
text = router.read_text(encoding='utf-8')
if "import '../services/profile_service.dart';\n" not in text:
    text = text.replace(
        "import '../services/notification_service.dart';\n",
        "import '../services/notification_service.dart';\nimport '../services/profile_service.dart';\n",
        1,
    )
old_router = '''      final profiles = data['participantProfiles'];
      if (profiles is! Map) {
        throw StateError('Conversation profile data is unavailable.');
      }

      final rawProfile = profiles[widget.openData.senderId];
      if (rawProfile is! Map) {
        throw StateError('The sender profile is unavailable.');
      }

      final profile = OjasProfile.fromMap(
        Map<String, dynamic>.from(rawProfile),
        uid: widget.openData.senderId,
      );
'''
new_router = '''      final profiles = data['participantProfiles'];
      OjasProfile? profile;

      if (profiles is Map) {
        final rawProfile = profiles[widget.openData.senderId];
        if (rawProfile is Map) {
          profile = OjasProfile.fromMap(
            Map<String, dynamic>.from(rawProfile),
            uid: widget.openData.senderId,
          );
        }
      }

      profile ??= await ProfileService.instance.getProfile(
        widget.openData.senderId,
      );

      if (profile == null) {
        throw StateError('The sender profile is unavailable.');
      }
'''
replace_once('lib/screens/notification_chat_router.dart', old_router, new_router, 'notification profile fallback')

# Remove unused simulation-only notification code.
replace_once(
    'lib/services/notification_service.dart',
    '''  void simulateIncomingNotification({
    required String title,
    required String body,
    required String type,
  }) {
    debugPrint('Simulation only: $title / $body / $type');
  }

''',
    '',
    'simulation-only notification helper',
)

# Use PageView so top tabs and horizontal swipes share the same navigation state.
replace_once(
    'lib/screens/you_hub_screen.dart',
    '''  final _accountStore = _LocalAccountStore();

  int _selectedTab = 0;
''',
    '''  final _accountStore = _LocalAccountStore();
  late final PageController _pageController;

  int _selectedTab = 0;
''',
    'You PageController field',
)
replace_once(
    'lib/screens/you_hub_screen.dart',
    '''  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }
''',
    '''  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadAccounts();
  }
''',
    'You PageController init',
)
replace_once(
    'lib/screens/you_hub_screen.dart',
    '''  void _changeTab(int index) {
    if (_selectedTab == index) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _selectedTab = index;
    });
  }
''',
    '''  void _changeTab(int index) {
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
''',
    'You tab controller',
)
replace_once(
    'lib/screens/you_hub_screen.dart',
    '''  @override
  Widget build(BuildContext context) {
''',
    '''  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
''',
    'You PageController dispose',
)
replace_once(
    'lib/screens/you_hub_screen.dart',
    '''                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (details) {
                          final velocity =
                              details.primaryVelocity ?? 0;
                          if (velocity < -220 &&
                              _selectedTab == 0) {
                            _changeTab(1);
                          } else if (velocity > 220 &&
                              _selectedTab == 1) {
                            _changeTab(0);
                          }
                        },
                        child: IndexedStack(
                          index: _selectedTab,
                          children: [
                            const MessagesScreen(
                              showAppBar: false,
                            ),
                            _ProfilePage(
''',
    '''                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        physics: const PageScrollPhysics(),
                        children: [
                          const MessagesScreen(
                            showAppBar: false,
                          ),
                          _ProfilePage(
''',
    'You PageView',
)

print('real Mitra chat and You navigation fixes prepared')
