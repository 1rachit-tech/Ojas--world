import 'package:flutter/material.dart';

class HomePollCard extends StatefulWidget {
  final String question;
  final List<String> options;

  const HomePollCard({
    super.key,
    required this.question,
    required this.options,
  });

  @override
  State<HomePollCard> createState() => _HomePollCardState();
}

class _HomePollCardState extends State<HomePollCard> {
  int? _votedIndex;
  late List<int> _votes;

  @override
  void initState() {
    super.initState();
    _votes = List.generate(widget.options.length, (i) => (i + 1) * 34);
  }

  int get _totalVotes => _votes.reduce((a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191F28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5B942).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, color: Color(0xFFF5B942), size: 18),
              const SizedBox(width: 6),
              const Text(
                'COMMUNITY POLL',
                style: TextStyle(
                  color: Color(0xFFF5B942),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '$_totalVotes votes',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.question,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(widget.options.length, (index) {
            final opt = widget.options[index];
            final percent = _totalVotes > 0
                ? ((_votes[index] / _totalVotes) * 100).round()
                : 0;
            final isSelected = _votedIndex == index;

            return GestureDetector(
              onTap: () {
                if (_votedIndex == null) {
                  setState(() {
                    _votedIndex = index;
                    _votes[index] += 1;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF232A34),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFF5B942)
                        : Colors.transparent,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_votedIndex != null)
                      FractionallySizedBox(
                        widthFactor: percent / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF5B942).withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            opt,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFFF5B942)
                                  : Colors.white,
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          if (_votedIndex != null)
                            Text(
                              '$percent%',
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFF5B942)
                                    : Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
