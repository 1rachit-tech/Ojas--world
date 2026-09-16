import 'package:flutter/material.dart';

class HomeManageTopicsScreen extends StatefulWidget {
  const HomeManageTopicsScreen({super.key, this.initialTopics = const <String>[]});

  final List<String> initialTopics;

  @override
  State<HomeManageTopicsScreen> createState() => _HomeManageTopicsScreenState();
}

class _HomeManageTopicsScreenState extends State<HomeManageTopicsScreen> {
  late final Set<String> _selected = widget.initialTopics.toSet();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Topics'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList(growable: false)),
            child: const Text('Done'),
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
