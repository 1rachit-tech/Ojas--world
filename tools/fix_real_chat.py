from pathlib import Path
import re


def text(path):
    return Path(path).read_text(encoding='utf-8')


def save(path, value):
    Path(path).write_text(value, encoding='utf-8')


def replace_once(path, old, new, label):
    value = text(path)
    if old not in value:
        raise SystemExit(f'{label}: expected block missing; refusing to modify.')
    save(path, value.replace(old, new, 1))


def ensure_import(path, anchor, import_line, label):
    value = text(path)
    if import_line in value:
        return
    if anchor not in value:
        raise SystemExit(f'{label}: import anchor missing; refusing to modify.')
    save(path, value.replace(anchor, anchor + import_line, 1))


# First chat: query existing participant conversations (allowed by rules), then
# create with set only when the deterministic conversation is not already present.
path = 'lib/services/messaging_service.dart'
value = text(path)
pattern = re.compile(r"  Future<String> openConversation\(OjasProfile otherUser\) async \{.*?\n  \}\n\n  Future<void> sendTextMessage", re.S)
match = pattern.search(value)
if not match:
    raise SystemExit('openConversation block missing; refusing to modify.')
replacement = '''  Future<String> openConversation(OjasProfile otherUser) async {
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
        .limit(50)
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

  Future<void> sendTextMessage'''
value = value[:match.start()] + replacement + value[match.end():]
save(path, value)

# Never surface a zero-message conversation as an active chat.
replace_once(
    path,
    '''      return conversations;\n    });\n  }\n\n  Stream<OjasConversation> watchConversation''',
    '''      return conversations\n          .where((conversation) => conversation.lastMessage.trim().isNotEmpty)\n          .toList(growable: false);\n    });\n  }\n\n  Stream<OjasConversation> watchConversation''',
    'empty conversation filter',
)

# Existing conversations from older clients may not have participantProfiles.
messages = 'lib/screens/messages_screen.dart'
ensure_import(
    messages,
    "import '../services/messaging_service.dart';\n",
    "import '../services/profile_service.dart';\n",
    'Messages ProfileService import',
)
replace_once(
    messages,
    '''    final profileData =\n        conversation.profileFor(otherUid);\n\n    final profile =\n        OjasProfile.fromMap(\n      profileData,\n      uid: otherUid,\n    );\n\n    await Navigator.of(context).push(\n''',
    '''    final profileData = conversation.profileFor(otherUid);\n\n    OjasProfile profile;\n    if (profileData.isEmpty) {\n      final fetched = await ProfileService.instance.getProfile(otherUid);\n      profile = fetched ?? OjasProfile.empty(\n        uid: otherUid,\n        displayName: 'OJAS User',\n        photoUrl: 'avatar_1',\n      );\n    } else {\n      profile = OjasProfile.fromMap(\n        profileData,\n        uid: otherUid,\n      );\n      if (profile.ojasId.isEmpty) {\n        final fetched = await ProfileService.instance.getProfile(otherUid);\n        if (fetched != null) {\n          profile = fetched;\n        }\n      }\n    }\n\n    await Navigator.of(context).push(\n''',
    'Messages old-conversation profile fallback',
)
replace_once(
    messages,
    "              'Your messages live here',",
    "              'Find your Mitra',",
    'Messages empty-state title',
)

# Notification taps also work with old conversation documents.
router = 'lib/screens/notification_chat_router.dart'
ensure_import(
    router,
    "import '../services/notification_service.dart';\n",
    "import '../services/profile_service.dart';\n",
    'Notification ProfileService import',
)
replace_once(
    router,
    '''      final profiles = data['participantProfiles'];\n      if (profiles is! Map) {\n        throw StateError('Conversation profile data is unavailable.');\n      }\n\n      final rawProfile = profiles[widget.openData.senderId];\n      if (rawProfile is! Map) {\n        throw StateError('The sender profile is unavailable.');\n      }\n\n      final profile = OjasProfile.fromMap(\n        Map<String, dynamic>.from(rawProfile),\n        uid: widget.openData.senderId,\n      );\n''',
    '''      final profiles = data['participantProfiles'];\n      OjasProfile? profile;\n\n      if (profiles is Map) {\n        final rawProfile = profiles[widget.openData.senderId];\n        if (rawProfile is Map) {\n          profile = OjasProfile.fromMap(\n            Map<String, dynamic>.from(rawProfile),\n            uid: widget.openData.senderId,\n          );\n        }\n      }\n\n      profile ??= await ProfileService.instance.getProfile(\n        widget.openData.senderId,\n      );\n\n      if (profile == null) {\n        throw StateError('The sender profile is unavailable.');\n      }\n''',
    'Notification old-conversation profile fallback',
)

# You: replace the fragile hand-swiped IndexedStack with PageView.
you = 'lib/screens/you_hub_screen.dart'
replace_once(
    you,
    '''  final _accountStore = _LocalAccountStore();\n\n  int _selectedTab = 0;\n''',
    '''  final _accountStore = _LocalAccountStore();\n  late final PageController _pageController;\n\n  int _selectedTab = 0;\n''',
    'You PageController field',
)
replace_once(
    you,
    '''  @override\n  void initState() {\n    super.initState();\n    _loadAccounts();\n  }\n''',
    '''  @override\n  void initState() {\n    super.initState();\n    _pageController = PageController(initialPage: 0);\n    _loadAccounts();\n  }\n''',
    'You PageController init',
)
replace_once(
    you,
    '''  void _changeTab(int index) {\n    if (_selectedTab == index) {\n      return;\n    }\n\n    HapticFeedback.selectionClick();\n\n    setState(() {\n      _selectedTab = index;\n    });\n  }\n''',
    '''  void _changeTab(int index) {\n    if (_selectedTab == index) {\n      return;\n    }\n\n    HapticFeedback.selectionClick();\n    setState(() {\n      _selectedTab = index;\n    });\n\n    if (_pageController.hasClients) {\n      _pageController.animateToPage(\n        index,\n        duration: const Duration(milliseconds: 220),\n        curve: Curves.easeOutCubic,\n      );\n    }\n  }\n\n  void _onPageChanged(int index) {\n    if (_selectedTab == index) {\n      return;\n    }\n\n    HapticFeedback.selectionClick();\n    setState(() {\n      _selectedTab = index;\n    });\n  }\n''',
    'You tab handler',
)
replace_once(
    you,
    '''  @override\n  Widget build(BuildContext context) {\n''',
    '''  @override\n  void dispose() {\n    _pageController.dispose();\n    super.dispose();\n  }\n\n  @override\n  Widget build(BuildContext context) {\n''',
    'You PageController dispose',
)
replace_once(
    you,
    '''                    Expanded(\n                      child: GestureDetector(\n                        behavior: HitTestBehavior.opaque,\n                        onHorizontalDragEnd: (details) {\n                          final velocity =\n                              details.primaryVelocity ?? 0;\n                          if (velocity < -220 &&\n                              _selectedTab == 0) {\n                            _changeTab(1);\n                          } else if (velocity > 220 &&\n                              _selectedTab == 1) {\n                            _changeTab(0);\n                          }\n                        },\n                        child: IndexedStack(\n                          index: _selectedTab,\n                          children: [\n                            const MessagesScreen(\n                              showAppBar: false,\n                            ),\n                            _ProfilePage(\n''',
    '''                    Expanded(\n                      child: PageView(\n                        controller: _pageController,\n                        onPageChanged: _onPageChanged,\n                        physics: const PageScrollPhysics(),\n                        children: [\n                          const MessagesScreen(\n                            showAppBar: false,\n                          ),\n                          _ProfilePage(\n''',
    'You PageView',
)

print('guarded real messaging and You navigation fixes prepared')
