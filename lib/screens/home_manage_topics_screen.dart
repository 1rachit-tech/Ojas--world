import 'package:flutter/material.dart';

class HomeManageTopicsScreen extends StatefulWidget {
  const HomeManageTopicsScreen({
    super.key,
    this.initialTopics = const <String>[],
    this.onSave,
  });

  final List<String> initialTopics;
  final Future<void> Function(List<String> topics)? onSave;

  @override
  State<HomeManageTopicsScreen> createState() => _HomeManageTopicsScreenState();
}

class _HomeManageTopicsScreenState extends State<HomeManageTopicsScreen> {
  late final Set<String> _selected = widget.initialTopics.toSet();
  bool _saving = false;

  static const topics = <String>[
    'Music',
    'Comedy',
    'Cricket',
    'Technology',
    'Movies',
    'Education',
    'Gaming',
    'Travel',
    'Food',
    'Fitness',
    'Science',
    'Art',
  ];

  Future<void> _done() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(_selected.toList(growable: false));
      if (mounted) Navigator.pop(context, _selected.toList(growable: false));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Topics'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _done,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose topics you want to see more often in Home.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in topics)
                FilterChip(
                  label: Text(topic),
                  selected: _selected.contains(topic),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selected.add(topic);
                      } else {
                        _selected.remove(topic);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Your choices guide recommendations; they do not permanently lock your feed to these topics.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
