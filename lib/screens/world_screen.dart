import 'package:flutter/material.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  int _selectedFilter = 0;
  int _banner = 0;
  bool _searching = false;

  static const _filters = [
    '🔥 Trending',
    '🎬 Viral Clips',
    '🎵 Sounds',
    '✨ Top Creators',
    '⚡ Challenges',
  ];
  static const _banners = [
    _TrendBanner(
      '#OjasVibes',
      'A softer way to see the city',
      Color(0xFF263238),
      Color(0xFFB46A42),
      Icons.wb_twilight_rounded,
    ),
    _TrendBanner(
      '#MusicTrend',
      'The sound behind this week',
      Color(0xFF27364A),
      Color(0xFFB08B46),
      Icons.graphic_eq_rounded,
    ),
    _TrendBanner(
      '#MakeItYours',
      'Creators are rewriting the rules',
      Color(0xFF31433F),
      Color(0xFF6E9B88),
      Icons.auto_awesome_rounded,
    ),
  ];
  static const _cards = [
    _DiscoveryCard(
      'Maya Chen',
      '@mayamakes',
      '2.4M',
      Color(0xFFB46A42),
      Icons.wb_twilight_rounded,
      true,
    ),
    _DiscoveryCard(
      'Rohan Mehta',
      '@rohanbuilds',
      '892K',
      Color(0xFF4A6C72),
      Icons.architecture_rounded,
      false,
    ),
    _DiscoveryCard(
      'Nia Kapoor',
      '@niakcreates',
      '1.1M',
      Color(0xFF9A6472),
      Icons.music_note_rounded,
      false,
    ),
    _DiscoveryCard(
      'Arjun Rao',
      '@arjunframes',
      '640K',
      Color(0xFF5C8068),
      Icons.landscape_rounded,
      false,
    ),
    _DiscoveryCard(
      'Zoya Malik',
      '@zoyamakes',
      '3.8M',
      Color(0xFF7D7188),
      Icons.brush_rounded,
      true,
    ),
  ];
  static const _sounds = [
    _Sound('Afterglow / Luma', '1.8M plays', Color(0xFFF5B942)),
    _Sound('Slow Motion / Kairo', '924K plays', Color(0xFFB8D8D8)),
    _Sound('Golden Hour / Nox', '702K plays', Color(0xFFE8B4B8)),
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(
      () => setState(() => _searching = _searchFocusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSearchHeader()),
        SliverToBoxAdapter(child: _buildFilters()),
        SliverToBoxAdapter(child: _buildBanner()),
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Discover the moment',
            'Fresh from the community',
          ),
        ),
        SliverToBoxAdapter(child: _buildDiscoveryGrid()),
        SliverToBoxAdapter(
          child: _sectionTitle('Trending sounds', 'Listen now'),
        ),
        SliverToBoxAdapter(child: _buildSounds()),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _buildSearchHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
    child: Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _searching
                    ? const Color(0xFFF5B942)
                    : Colors.transparent,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hint: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Text(
                    _searching
                        ? 'Search creators, sounds, hashtags...'
                        : 'Search the world',
                    key: ValueKey<bool>(_searching),
                    style: const TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {},
          tooltip: 'Open filters',
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
  );

  Widget _buildFilters() => SizedBox(
    height: 48,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      itemCount: _filters.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) => ChoiceChip(
        label: Text(_filters[index]),
        selected: _selectedFilter == index,
        onSelected: (_) => setState(() => _selectedFilter = index),
        selectedColor: const Color(0xFFFFF5D9),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: _selectedFilter == index
              ? const Color(0xFFF5B942)
              : const Color(0xFFE5E7EB),
        ),
        labelStyle: TextStyle(
          color: _selectedFilter == index
              ? const Color(0xFF8A641A)
              : const Color(0xFF6B7280),
          fontWeight: _selectedFilter == index
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _buildBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: SizedBox(
      height: 156,
      child: PageView.builder(
        itemCount: _banners.length,
        onPageChanged: (index) => setState(() => _banner = index),
        itemBuilder: (context, index) {
          final banner = _banners[index];
          return Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [banner.start, banner.end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  top: -28,
                  child: Icon(
                    banner.icon,
                    size: 150,
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRENDING NOW',
                        style: TextStyle(
                          color: Color(0xFFF5B942),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        banner.tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        banner.subtitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
        Text(
          '${_banner + 1}/3',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFB08220),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildSounds() => SizedBox(
    height: 94,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      itemCount: _sounds.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final sound = _sounds[index];
        return Container(
          width: 190,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sound.color.withValues(alpha: .3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.album_rounded,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: CustomPaint(
                            size: const Size(50, 10),
                            painter: _WavePainter(color: sound.color),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          sound.plays,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _buildDiscoveryGrid() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      final feature = Expanded(child: _DiscoveryTile(card: _cards[0]));
      final stacked = Expanded(
        child: Column(
          children: [
            Expanded(child: _DiscoveryTile(card: _cards[1])),
            const SizedBox(height: 10),
            Expanded(child: _DiscoveryTile(card: _cards[2])),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          children: [
            SizedBox(
              height: compact ? 330 : 390,
              child: Row(
                children: [feature, const SizedBox(width: 10), stacked],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: compact ? 170 : 210,
              child: Row(
                children: [
                  Expanded(child: _DiscoveryTile(card: _cards[3])),
                  const SizedBox(width: 10),
                  Expanded(child: _DiscoveryTile(card: _cards[4])),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DiscoveryTile extends StatelessWidget {
  const _DiscoveryTile({required this.card});
  final _DiscoveryCard card;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: card.color,
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _DiscoveryPainter(
              color: Colors.white.withValues(alpha: .12),
            ),
          ),
        ),
        Center(
          child: Icon(
            card.icon,
            size: card.featured ? 54 : 38,
            color: Colors.white.withValues(alpha: .78),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .72),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 10,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 13,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${card.views} views',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.white.withValues(alpha: .8),
                    child: Text(
                      card.creator[0],
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      card.handle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryPainter extends CustomPainter {
  const _DiscoveryPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 30) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiscoveryPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = 2.0; x < size.width; x += 5) {
      final height = (x * 1.7).remainder(8) + 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrendBanner {
  const _TrendBanner(this.tag, this.subtitle, this.start, this.end, this.icon);
  final String tag;
  final String subtitle;
  final Color start;
  final Color end;
  final IconData icon;
}

class _DiscoveryCard {
  const _DiscoveryCard(
    this.creator,
    this.handle,
    this.views,
    this.color,
    this.icon,
    this.featured,
  );
  final String creator;
  final String handle;
  final String views;
  final Color color;
  final IconData icon;
  final bool featured;
}

class _Sound {
  const _Sound(this.title, this.plays, this.color);
  final String title;
  final String plays;
  final Color color;
}
