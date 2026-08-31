import 'package:flutter/material.dart';

class OjasFilter {
  final int id;
  final String name;
  final String category;
  final IconData icon;
  final Color previewColor;
  final ColorFilter? matrixFilter;

  const OjasFilter({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.previewColor,
    this.matrixFilter,
  });
}

// 50 वर्किंग कलर मैट्रिक्स फ़िल्टर्स
final List<OjasFilter> kAllOjasFilters = [
  // 1-5: Base & AI Resolution Boost
  const OjasFilter(
    id: 0,
    name: 'Natural / Raw',
    category: 'Popular',
    icon: Icons.auto_awesome,
    previewColor: Colors.white24,
    matrixFilter: null,
  ),
  const OjasFilter(
    id: 1,
    name: '4K Ultra HDR',
    category: 'Ultra Boost',
    icon: Icons.hd_rounded,
    previewColor: Color(0xFFF5B942),
    matrixFilter: ColorFilter.matrix([
      1.25, 0, 0, 0, 10,
      0, 1.25, 0, 0, 10,
      0, 0, 1.25, 0, 10,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 2,
    name: '8K Hyper Clarity',
    category: 'Ultra Boost',
    icon: Icons.high_quality_rounded,
    previewColor: Color(0xFF38BDF8),
    matrixFilter: ColorFilter.matrix([
      1.35, 0, 0, 0, 15,
      0, 1.35, 0, 0, 15,
      0, 0, 1.35, 0, 15,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 3,
    name: 'Glow Beauty AI',
    category: 'Beauty',
    icon: Icons.face_retouching_natural_rounded,
    previewColor: Color(0xFFF472B6),
    matrixFilter: ColorFilter.matrix([
      1.10, 0, 0, 0, 18,
      0, 1.06, 0, 0, 12,
      0, 0, 1.04, 0, 8,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 4,
    name: 'Porcelain Skin',
    category: 'Beauty',
    icon: Icons.spa_rounded,
    previewColor: Color(0xFFFBCFE8),
    matrixFilter: ColorFilter.matrix([
      1.12, 0, 0, 0, 25,
      0, 1.08, 0, 0, 20,
      0, 0, 1.10, 0, 22,
      0, 0, 0, 1, 0,
    ]),
  ),

  // 6-12: Cinematic & Golden Hour
  const OjasFilter(
    id: 5,
    name: 'Golden Hour ☀️',
    category: 'Cinematic',
    icon: Icons.wb_sunny_rounded,
    previewColor: Color(0xFFF59E0B),
    matrixFilter: ColorFilter.matrix([
      1.30, 0, 0, 0, 25,
      0, 1.10, 0, 0, 10,
      0, 0, 0.85, 0, -15,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 6,
    name: 'Teal & Orange',
    category: 'Cinematic',
    icon: Icons.movie_filter_rounded,
    previewColor: Color(0xFF0D9488),
    matrixFilter: ColorFilter.matrix([
      1.30, 0, 0, 0, 20,
      0, 1.05, 0, 0, 0,
      0, 0, 1.25, 0, 15,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 7,
    name: 'Kodak Film 90s',
    category: 'Vintage',
    icon: Icons.camera_roll_rounded,
    previewColor: Color(0xFFD97706),
    matrixFilter: ColorFilter.matrix([
      1.15, 0, 0, 0, 12,
      0, 1.05, 0, 0, 6,
      0, 0, 0.80, 0, -5,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 8,
    name: 'Retro Sepia',
    category: 'Vintage',
    icon: Icons.history_edu_rounded,
    previewColor: Color(0xFFB45309),
    matrixFilter: ColorFilter.matrix([
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 9,
    name: 'Noir Mono B&W',
    category: 'Mood',
    icon: Icons.filter_b_and_w_rounded,
    previewColor: Colors.white70,
    matrixFilter: ColorFilter.matrix([
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  ),

  // 11-20: Cyber, Neon & Party
  const OjasFilter(
    id: 10,
    name: 'Cyberpunk Neon',
    category: 'Neon',
    icon: Icons.electric_bolt_rounded,
    previewColor: Color(0xFF8B5CF6),
    matrixFilter: ColorFilter.matrix([
      1.2, 0, 0, 0, 20,
      0, 0.8, 0, 0, -10,
      0, 0, 1.5, 0, 30,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 11,
    name: 'Tokyo Night AI',
    category: 'Neon',
    icon: Icons.nights_stay_rounded,
    previewColor: Color(0xFF6366F1),
    matrixFilter: ColorFilter.matrix([
      0.9, 0, 0, 0, 0,
      0, 1.1, 0, 0, 10,
      0, 0, 1.4, 0, 25,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 12,
    name: 'Emerald Lush',
    category: 'Nature',
    icon: Icons.forest_rounded,
    previewColor: Color(0xFF10B981),
    matrixFilter: ColorFilter.matrix([
      0.9, 0, 0, 0, -5,
      0, 1.35, 0, 0, 15,
      0, 0, 0.9, 0, -5,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 13,
    name: 'Sunset Velvet',
    category: 'Cinematic',
    icon: Icons.flare_rounded,
    previewColor: Color(0xFFE11D48),
    matrixFilter: ColorFilter.matrix([
      1.35, 0, 0, 0, 25,
      0, 0.95, 0, 0, 0,
      0, 0, 1.10, 0, 10,
      0, 0, 0, 1, 0,
    ]),
  ),
  const OjasFilter(
    id: 14,
    name: 'Cold Glacier Blue',
    category: 'Mood',
    icon: Icons.ac_unit_rounded,
    previewColor: Color(0xFF06B6D4),
    matrixFilter: ColorFilter.matrix([
      0.85, 0, 0, 0, -10,
      0, 1.05, 0, 0, 5,
      0, 0, 1.40, 0, 30,
      0, 0, 0, 1, 0,
    ]),
  ),

  // 16-50: Generator for variety (Dynamic matrices)
  ...List.generate(35, (index) {
    final filterNum = index + 16;
    final r = 1.0 + ((index % 5) * 0.08);
    final g = 1.0 + (((index + 2) % 5) * 0.07);
    final b = 1.0 + (((index + 4) % 5) * 0.09);
    final offset = (index % 4) * 8.0;

    final categories = ['Beauty', 'Cinematic', 'Vintage', 'Mood', 'Ultra Boost', 'Nature'];
    final selectedCat = categories[index % categories.length];

    return OjasFilter(
      id: filterNum,
      name: 'Filter Studio #$filterNum',
      category: selectedCat,
      icon: Icons.filter_vintage_rounded,
      previewColor: Color((0xFF000000 + (index * 0x1F354A)) | 0xFF000000),
      matrixFilter: ColorFilter.matrix([
        r, 0, 0, 0, offset,
        0, g, 0, 0, offset / 2,
        0, 0, b, 0, offset / 3,
        0, 0, 0, 1, 0,
      ]),
    );
  }),
];

class FilterStoreSheet extends StatefulWidget {
  final int selectedFilterId;
  final Function(OjasFilter selectedFilter) onFilterApplied;

  const FilterStoreSheet({
    super.key,
    required this.selectedFilterId,
    required this.onFilterApplied,
  });

  static void show(
    BuildContext context, {
    required int selectedFilterId,
    required Function(OjasFilter selectedFilter) onFilterApplied,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterStoreSheet(
        selectedFilterId: selectedFilterId,
        onFilterApplied: onFilterApplied,
      ),
    );
  }

  @override
  State<FilterStoreSheet> createState() => _FilterStoreSheetState();
}

class _FilterStoreSheetState extends State<FilterStoreSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  late int _currentId;

  final List<String> _categories = [
    'All',
    'Popular',
    'Ultra Boost',
    'Beauty',
    'Cinematic',
    'Vintage',
    'Mood',
    'Nature',
    'Neon'
  ];

  @override
  void initState() {
    super.initState();
    _currentId = widget.selectedFilterId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase().trim();
    final filteredList = kAllOjasFilters.where((f) {
      final matchesCat = _selectedCategory == 'All' || f.category == _selectedCategory;
      final matchesQuery = query.isEmpty || f.name.toLowerCase().contains(query);
      return matchesCat && matchesQuery;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF13171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters & 4K AI Effects',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${kAllOjasFilters.length} Effects',
                  style: const TextStyle(color: Color(0xFFF5B942), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search 4K Boost, Glow, Cinema filters...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Category Chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF5B942) : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),

          // Grid View of 50 Filters
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final filter = filteredList[index];
                final isSelected = _currentId == filter.id;

                return GestureDetector(
                  onTap: () {
                    setState(() => _currentId = filter.id);
                    widget.onFilterApplied(filter);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF5B942) : Colors.white10,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: filter.previewColor,
                          child: Icon(
                            filter.icon,
                            color: isSelected ? Colors.black : Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          filter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFF5B942) : Colors.white,
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        Text(
                          filter.category,
                          style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
