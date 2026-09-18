import 'package:flutter/material.dart';

import '../features/discovery/search/ui/search_screen.dart';

class WorldSearchSheet {
  const WorldSearchSheet._();

  static void show(
    BuildContext context, {
    String initialQuery = '',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          initialQuery: initialQuery,
          embedded: false,
        ),
      ),
    );
  }
}
