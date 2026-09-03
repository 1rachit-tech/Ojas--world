import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ojas_conversation.dart';
import '../models/ojas_profile.dart';
import '../services/messaging_service.dart';
import 'chat_room_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() =>
      _MessagesScreenState();
}

class _MessagesScreenState
    extends State<MessagesScreen> {
  final MessagingService _messagingService =
      MessagingService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _searchDebounce;

  List<OjasProfile> _searchResults = [];

  bool _isSearching = false;

  bool _isLoadingSearch = false;

  String _searchError = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startNewMessage() {
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchError = '';
    });
  }

  void _closeSearch() {
    _searchController.clear();

    setState(() {
      _isSearching = false;
      _isLoadingSearch = false;
      _searchResults = [];
      _searchError = '';
    });
  }

  void _onSearchChanged(
    String value,
  ) {
    _searchDebounce?.cancel();

    final query =
        value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoadingSearch = false;
        _searchError = '';
      });

      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        _searchUsers(query);
      },
    );
  }

  Future<void> _searchUsers(
    String query,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingSearch = true;
      _searchError = '';
    });

    try {
      final results =
          await _messagingService.searchUsers(
        query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = results;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchError =
            'Unable to search users right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSearch = false;
        });
      }
    }
  }

  Future<void> _openNewConversation(
    OjasProfile profile,
  ) async {
    try {
      HapticFeedback.selectionClick();

      final conversationId =
          await _messagingService.openConversation(
        profile,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatRoomScreen(
            conversationId: conversationId,
            otherUser: profile,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _errorMessage(error),
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openConversation(
    OjasConversation conversation,
  ) async {
    final uid =
        _messagingService.currentUid;

    if (uid == null) {
      return;
    }

    final otherUid =
        conversation.otherUserId(uid);

    if (otherUid.isEmpty) {
      return;
    }

    final profileData =
        conversation.profileFor(otherUid);

    final profile =
        OjasProfile.fromMap(
      profileData,
      uid: otherUid,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatRoomScreen(
          conversationId: conversation.id,
          otherUser: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSearching) {
      return _buildSearchPage();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New message',
            onPressed: _startNewMessage,
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<OjasConversation>>(
        stream:
            _messagingService.watchConversations(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final conversations =
              snapshot.data ?? [];

          if (conversations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              32,
            ),
            itemCount:
                conversations.length,
            separatorBuilder:
                (_, _) =>
                    const SizedBox(height: 4),
            itemBuilder:
                (context, index) {
              return _ConversationTile(
                conversation:
                    conversations[index],
                currentUid:
                    _messagingService.currentUid ??
                        '',
                onTap: () {
                  _openConversation(
                    conversations[index],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 36,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFF4F5F7),
                borderRadius:
                    BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 38,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your messages live here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Start a private conversation with any OJAS creator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startNewMessage,
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF111827),
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.edit_outlined,
              ),
              label: const Text(
                'New message',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 32,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            const Text(
              'Messages are temporarily unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {});
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPage() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _closeSearch,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111827),
          ),
        ),
        title: const Text(
          'New message',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              textInputAction:
                  TextInputAction.search,
              decoration: InputDecoration(
                hintText:
                    'Search name or OJAS ID',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _searchController
                                  .clear();

                              setState(() {
                                _searchResults =
                                    [];
                              });
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                filled: true,
                fillColor:
                    const Color(0xFFF4F5F7),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                  borderSide:
                      BorderSide.none,
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                  borderSide:
                      BorderSide.none,
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(
                    color: Color(0xFF111827),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoadingSearch) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchError.isNotEmpty) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(32),
          child: Text(
            _searchError,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Search for a creator or OJAS ID',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    return ListView.separated(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32,
      ),
      itemCount:
          _searchResults.length,
      separatorBuilder:
          (_, _) =>
              const Divider(height: 1),
      itemBuilder:
          (context, index) {
        final profile =
            _searchResults[index];

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(
            vertical: 8,
          ),
          leading:
              _ProfileAvatar(profile: profile),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  profile.displayName,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF111827),
                  ),
                ),
              ),
              if (profile.isVerified)
                const Padding(
                  padding:
                      EdgeInsets.only(left: 5),
                  child: Icon(
                    Icons.verified_rounded,
                    size: 17,
                    color: Color(0xFF3B82F6),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            profile.ojasId.isEmpty
                ? 'OJAS creator'
                : '@${profile.ojasId}',
            style: const TextStyle(
              color: Color(0xFF6B7280),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
          ),
          onTap: () {
            _openNewConversation(profile);
          },
        );
      },
    );
  }

  String _errorMessage(
    Object error,
  ) {
    if (error is MessagingException) {
      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUid,
    required this.onTap,
  });

  final OjasConversation conversation;

  final String currentUid;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otherUid =
        conversation.otherUserId(currentUid);

    final profile =
        conversation.profileFor(otherUid);

    final displayName =
        _string(
      profile['displayName'],
      fallback: 'OJAS User',
    );

    final ojasId =
        _string(profile['ojasId']);

    final unread =
        conversation.unreadCountFor(
      currentUid,
    );

    final time =
        _formatTimestamp(
      conversation.lastMessageAt,
    );

    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 7,
      ),
      leading: _ConversationAvatar(
        name: displayName,
        photoUrl:
            _string(profile['photoUrl']),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread > 0
                    ? FontWeight.w800
                    : FontWeight.w700,
                color:
                    const Color(0xFF111827),
              ),
            ),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: unread > 0
                    ? const Color(
                        0xFF111827,
                      )
                    : const Color(
                        0xFF9CA3AF,
                      ),
                fontWeight: unread > 0
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding:
            const EdgeInsets.only(top: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                conversation.lastMessage.isEmpty
                    ? ojasId.isEmpty
                        ? 'Start a conversation'
                        : '@$ojasId'
                    : conversation.lastMessage,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread > 0
                      ? const Color(
                          0xFF111827,
                        )
                      : const Color(
                          0xFF6B7280,
                        ),
                  fontWeight: unread > 0
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            if (unread > 0)
              Container(
                margin:
                    const EdgeInsets.only(
                  left: 8,
                ),
                constraints:
                    const BoxConstraints(
                  minWidth: 22,
                  minHeight: 22,
                ),
                alignment:
                    Alignment.center,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0xFF111827),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread > 99
                      ? '99+'
                      : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _string(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static String _formatTimestamp(
    dynamic timestamp,
  ) {
    if (timestamp is! Timestamp) {
      return '';
    }

    final date =
        timestamp.toDate();

    final now =
        DateTime.now();

    final difference =
        now.difference(date);

    if (difference.inDays == 0) {
      final hour =
          date.hour > 12
              ? date.hour - 12
              : date.hour == 0
                  ? 12
                  : date.hour;

      final minute =
          date.minute
              .toString()
              .padLeft(2, '0');

      final period =
          date.hour >= 12
              ? 'PM'
              : 'AM';

      return '$hour:$minute $period';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      const days = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];

      return days[date.weekday - 1];
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
  });

  final OjasProfile profile;

  @override
  Widget build(BuildContext context) {
    return _ConversationAvatar(
      name: profile.displayName,
      photoUrl: profile.photoUrl,
    );
  }
}

class _ConversationAvatar
    extends StatelessWidget {
  const _ConversationAvatar({
    required this.name,
    required this.photoUrl,
  });

  final String name;

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty
            ? 'O'
            : name.trim()[0].toUpperCase();

    final imageUrl =
        photoUrl.trim();

    return CircleAvatar(
      radius: 27,
      backgroundColor:
          const Color(0xFFF1F3F5),
      backgroundImage:
          imageUrl.startsWith('http')
              ? NetworkImage(imageUrl)
              : null,
      child: imageUrl.startsWith('http')
          ? null
          : Text(
              initial,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: Color(0xFF111827),
              ),
            ),
    );
  }
}
