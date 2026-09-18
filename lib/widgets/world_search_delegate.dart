import 'package:flutter/material.dart';

import '../features/discovery/search/ui/search_screen.dart';

class WorldSearchSheet {
  const WorldSearchSheet._();

  static void show(
    BuildContext context, {
    String initialQuery = '',
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.96,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
            child: SearchScreen(
              initialQuery: initialQuery,
              embedded: true,
            ),
          ),
        );
      },
    );
  }
}
