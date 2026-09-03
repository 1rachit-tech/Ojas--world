from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding='utf-8')


def replace_once(path: str, old: str, new: str, label: str) -> None:
    text = read(path)
    if old not in text:
        raise SystemExit(f'{label}: expected block missing; refusing to modify.')
    write(path, text.replace(old, new, 1))


def ensure_import(path: str, anchor: str, import_line: str, label: str) -> None:
    text = read(path)
    if import_line in text:
        return
    if anchor not in text:
        raise SystemExit(f'{label}: import anchor missing; refusing to modify.')
    write(path, text.replace(anchor, anchor + import_line, 1))


# Real first-chat creation: do not read a missing conversation document.
# Firestore's participant read rule denies a get when the document does not exist.
messaging_path = 'lib/services/messaging_service.dart'
text = read(messaging_path)
pattern = re.compile(
    r"  Future<String> openConversation\(OjasProfile otherUser\) async \{.*?\n  \}\n\n  Future<void> sendTextMessage",
    re.S,
)
match = pattern.search(text)
if not match:
    raise SystemExit('real conversation creation method missing; refusing to modify.')
new_method = '''  Future<String> openConversation(OjasProfile otherUser) async {
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
    final data = {
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
    };

    try {
      await reference.create(data);
    } on FirebaseException catch (error) {
      if (error.code != 'already-exists') {
        rethrow;
      }
    }

    return conversationId;
  }

  Future<void> sendTextMessage'''
text = text[:match.start()] + new_method + text[match.end():]
write(messaging_path, text)

# Keep empty conversations out of the list until a real message exists.
replace_once(
    messaging_path,
    '''      return conversations;
    });
  }

  Stream<OjasConversation> watchConversation''',
    '''      return conversations
          .where((conversation) => conversation.lastMessage.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Stream<OjasConversation> watchConversation''',
    'empty conversation filter',
)

# Older conversations can lack the newer participantProfiles snapshot.
messages_path = 'lib/screens/messages_screen.dart'
ensure_import(
    messages_path,
    "import '../services/messaging_service.dart';\n",
    "import '../services/profile_service.dart';\n",
    'Messages profile service import',
)
replace_once(
    messages_path,
    '''    final profileData =
        conversation.profileFor(otherUid);

    final profile =
        OjasProfile.fromMap(
      profileData,
      uid: otherUid,
    );

    await Navigator.of(context).push(
''',
    '''    final profileData = conversation.profileFor(otherUid);

    OjasProfile profile;
    if (profileData.isEmpty) {
      final fetched = await ProfileService.instance.getProfile(otherUid);
      profile = fetched ??
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
''',
    'Messages old conversation profile fallback',
)
replace_once(
    messages_path,
    "              'Your messages live here',",
    "              'Find your Mitra',",
    'Messages empty-state title',
)

# Notification tap compatibility with older conversation documents.
router_path = 'lib/screens/notification_chat_router.dart'
ensure_import(
    router_path,
    "import '../services/notification_service.dart';\n",
    "import '../services/profile_service.dart';\n",
    'Notification router profile service import',
)
replace_once(
    router_path,
    '''      final profiles = data['participantProfiles'];
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
''',
    '''      final profiles = data['participantProfiles'];
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
''',
    'Notification old conversation profile fallback',
)

# Make You use a real PageView so top tabs and horizontal swipes share one state.
you_path = 'lib/screens/you_hub_screen.dart'
replace_once(
    you_path,
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
    you_path,
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
    you_path,
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
    'You tab handler',
)
replace_once(
    you_path,
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
    you_path,
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

print('guarded real messaging and You navigation fixes prepared')
