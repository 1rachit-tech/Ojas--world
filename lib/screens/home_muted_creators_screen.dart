import 'package:flutter/material.dart';

class HomeMutedCreatorsScreen extends StatelessWidget {
  const HomeMutedCreatorsScreen({
    super.key,
    required this.creatorIds,
    required this.onUnmute,
  });

  final List<String> creatorIds;
  final Future<void> Function(String creatorId) onUnmute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Muted Creators')),
      body: creatorIds.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have not muted any creators from Home.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: creatorIds.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final creatorId = creatorIds[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      creatorId.isEmpty ? '?' : creatorId.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(creatorId),
                  subtitle: const Text('Posts are hidden from Home recommendations'),
                  trailing: TextButton(
                    onPressed: () => onUnmute(creatorId),
                    child: const Text('Unmute'),
                  ),
                );
              },
            ),
    );
  }
}
