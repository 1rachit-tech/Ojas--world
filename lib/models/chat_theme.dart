import 'package:flutter/material.dart';

/// Per-chat visual theme — simple, modern, relationship-aware.
class ChatTheme {
  const ChatTheme({
    required this.id,
    required this.label,
    required this.emoji,
    required this.mineBubble,
    required this.theirsBubble,
    required this.mineText,
    required this.theirsText,
    required this.accent,
    required this.background,
    required this.composerFill,
    required this.appBarTint,
  });

  final String id;
  final String label;
  final String emoji;
  final Color mineBubble;
  final Color theirsBubble;
  final Color mineText;
  final Color theirsText;
  final Color accent;
  final Color background;
  final Color composerFill;
  final Color appBarTint;

  static const ChatTheme classic = ChatTheme(
    id: 'classic',
    label: 'Classic',
    emoji: '💬',
    mineBubble: Color(0xFF111827),
    theirsBubble: Color(0xFFF0F2F5),
    mineText: Colors.white,
    theirsText: Color(0xFF111827),
    accent: Color(0xFF111827),
    background: Colors.white,
    composerFill: Color(0xFFF4F5F7),
    appBarTint: Colors.white,
  );

  static const ChatTheme mitra = ChatTheme(
    id: 'mitra',
    label: 'Mitra',
    emoji: '🤝',
    mineBubble: Color(0xFF0EA5E9),
    theirsBubble: Color(0xFFE0F2FE),
    mineText: Colors.white,
    theirsText: Color(0xFF0C4A6E),
    accent: Color(0xFF0284C7),
    background: Color(0xFFF0F9FF),
    composerFill: Color(0xFFE0F2FE),
    appBarTint: Color(0xFFF0F9FF),
  );

  static const ChatTheme family = ChatTheme(
    id: 'family',
    label: 'Family',
    emoji: '👨‍👩‍👧',
    mineBubble: Color(0xFF7C3AED),
    theirsBubble: Color(0xFFEDE9FE),
    mineText: Colors.white,
    theirsText: Color(0xFF4C1D95),
    accent: Color(0xFF6D28D9),
    background: Color(0xFFFAF5FF),
    composerFill: Color(0xFFEDE9FE),
    appBarTint: Color(0xFFFAF5FF),
  );

  static const ChatTheme sibling = ChatTheme(
    id: 'sibling',
    label: 'Sibling',
    emoji: '👯',
    mineBubble: Color(0xFF059669),
    theirsBubble: Color(0xFFD1FAE5),
    mineText: Colors.white,
    theirsText: Color(0xFF064E3B),
    accent: Color(0xFF047857),
    background: Color(0xFFECFDF5),
    composerFill: Color(0xFFD1FAE5),
    appBarTint: Color(0xFFECFDF5),
  );

  static const ChatTheme partner = ChatTheme(
    id: 'partner',
    label: 'Partner',
    emoji: '💕',
    mineBubble: Color(0xFFE11D48),
    theirsBubble: Color(0xFFFFE4E6),
    mineText: Colors.white,
    theirsText: Color(0xFF9F1239),
    accent: Color(0xFFBE123C),
    background: Color(0xFFFFF1F2),
    composerFill: Color(0xFFFFE4E6),
    appBarTint: Color(0xFFFFF1F2),
  );

  static const ChatTheme baby = ChatTheme(
    id: 'baby',
    label: 'Baby',
    emoji: '🍼',
    mineBubble: Color(0xFFF59E0B),
    theirsBubble: Color(0xFFFEF3C7),
    mineText: Colors.white,
    theirsText: Color(0xFF92400E),
    accent: Color(0xFFD97706),
    background: Color(0xFFFFFBEB),
    composerFill: Color(0xFFFEF3C7),
    appBarTint: Color(0xFFFFFBEB),
  );

  static const ChatTheme night = ChatTheme(
    id: 'night',
    label: 'Night',
    emoji: '🌙',
    mineBubble: Color(0xFF6366F1),
    theirsBubble: Color(0xFF1F2937),
    mineText: Colors.white,
    theirsText: Color(0xFFE5E7EB),
    accent: Color(0xFF818CF8),
    background: Color(0xFF0B0F19),
    composerFill: Color(0xFF1F2937),
    appBarTint: Color(0xFF0B0F19),
  );

  static const List<ChatTheme> all = [
    classic,
    mitra,
    family,
    sibling,
    partner,
    baby,
    night,
  ];

  static ChatTheme byId(String? id) {
    if (id == null || id.isEmpty) return classic;
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return classic;
  }

  bool get isDark => id == 'night';
}
