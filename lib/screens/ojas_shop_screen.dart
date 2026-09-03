import 'package:flutter/material.dart';

/// OJAS Shop
///
/// Lightweight foundation for the future OJAS commerce ecosystem.
///
/// Current version:
/// - Zero backend dependency
/// - Zero Firebase reads
/// - No payment integration
/// - Low memory usage
/// - Pure white minimalist UI
///
/// Future modules can safely connect:
/// - Creator affiliate products
/// - Sponsored products
/// - Creator storefronts
/// - Brand collaborations
/// - Product search
/// - Commission tracking
class OjasShopScreen extends StatefulWidget {
  const OjasShopScreen({super.key});

  @override
  State<OjasShopScreen> createState() => _OjasShopScreenState();
}

class _OjasShopScreenState extends State<OjasShopScreen>
    with AutomaticKeepAliveClientMixin {
  int _selectedCategoryIndex = 0;

  static const List<String> _categories = <String>[
    'For You',
    'Trending',
    'Creator Picks',
    'Fashion',
    'Tech',
    'Art & Culture',
  ];

  static const List<_ShopProduct> _products = <_ShopProduct>[
    _ShopProduct(
      id: 'ojas_001',
      title: 'Handcrafted Vindhya Art',
      creator: 'Local Creator',
      price: 'Coming Soon',
      category: 'Art & Culture',
      icon: Icons.palette_outlined,
    ),
    _ShopProduct(
      id: 'ojas_002',
      title: 'Creator Essentials',
      creator: 'OJAS Picks',
      price: 'Coming Soon',
      category: 'Creator Picks',
      icon: Icons.camera_alt_outlined,
    ),
    _ShopProduct(
      id: 'ojas_003',
      title: 'Modern Lifestyle',
      creator: 'Featured Store',
      price: 'Coming Soon',
      category: 'Trending',
      icon: Icons.auto_awesome_outlined,
    ),
    _ShopProduct(
      id: 'ojas_004',
      title: 'Regional Collection',
      creator: 'Indian Creators',
      price: 'Coming Soon',
      category: 'Art & Culture',
      icon: Icons.storefront_outlined,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  void _openSearch() {
    showSearch<_ShopProduct?>(
      context: context,
      delegate: _ShopSearchDelegate(products: _products),
    );
  }

  void _openCreatorCenter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creator Shop features are coming soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openProduct(_ShopProduct product) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    product.icon,
                    size: 34,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  product.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.creator,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Product details coming soon',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ShopProduct> get _filteredProducts {
    final String selectedCategory =
        _categories[_selectedCategoryIndex];

    if (selectedCategory == 'For You') {
      return _products;
    }

    if (selectedCategory == 'Trending') {
      return _products
          .where(
            (_ShopProduct product) =>
                product.category == 'Trending' ||
                product.category == 'Creator Picks',
          )
          .toList(growable: false);
    }

    return _products
        .where(
          (_ShopProduct product) =>
              product.category == selectedCategory,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final List<_ShopProduct> products = _filteredProducts;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Shop',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _TopActionButton(
                      icon: Icons.search_rounded,
                      onTap: _openSearch,
                    ),
                    const SizedBox(width: 10),
                    _TopActionButton(
                      icon: Icons.storefront_outlined,
                      onTap: _openCreatorCenter,
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: _CreatorEarningsCard(
                  onTap: _openCreatorCenter,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    final bool isSelected =
                        _selectedCategoryIndex == index;

                    return GestureDetector(
                      onTap: () {
                        if (_selectedCategoryIndex == index) {
                          return;
                        }

                        setState(() {
                          _selectedCategoryIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.black
                              : const Color(0xFFF3F3F3),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          _categories[index],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                child: Row(
                  children: <Widget>[
                    Text(
                      _selectedCategoryIndex == 0
                          ? 'Discover products'
                          : _categories[_selectedCategoryIndex],
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${products.length} items',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (products.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyShopState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  32,
                ),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (
                      BuildContext context,
                      int index,
                    ) {
                      final _ShopProduct product =
                          products[index];

                      return RepaintBoundary(
                        child: _ProductCard(
                          product: product,
                          onTap: () => _openProduct(product),
                        ),
                      );
                    },
                    childCount: products.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _CreatorEarningsCard extends StatelessWidget {
  const _CreatorEarningsCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Earn with OJAS Shop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recommend products and earn commission.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  final _ShopProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEAEAEA),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      product.icon,
                      size: 42,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  13,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.creator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF777777),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.price,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyShopState extends StatelessWidget {
  const _EmptyShopState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.storefront_outlined,
              size: 46,
              color: Colors.black,
            ),
            SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'New products will appear here soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF777777),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopProduct {
  const _ShopProduct({
    required this.id,
    required this.title,
    required this.creator,
    required this.price,
    required this.category,
    required this.icon,
  });

  final String id;
  final String title;
  final String creator;
  final String price;
  final String category;
  final IconData icon;
}

class _ShopSearchDelegate extends SearchDelegate<_ShopProduct?> {
  _ShopSearchDelegate({
    required this.products,
  });

  final List<_ShopProduct> products;

  @override
  String get searchFieldLabel => 'Search OJAS Shop';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return theme.copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: Color(0xFF888888),
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) {
      return null;
    }

    return <Widget>[
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () {
        close(context, null);
      },
    );
  }

  List<_ShopProduct> _searchResults() {
    final String normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return products;
    }

    return products.where(
      (_ShopProduct product) {
        return product.title
                .toLowerCase()
                .contains(normalizedQuery) ||
            product.creator
                .toLowerCase()
                .contains(normalizedQuery) ||
            product.category
                .toLowerCase()
                .contains(normalizedQuery);
      },
    ).toList(growable: false);
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResultsList(
      products: _searchResults(),
      onTap: (_ShopProduct product) {
        close(context, product);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _SearchResultsList(
      products: _searchResults(),
      onTap: (_ShopProduct product) {
        close(context, product);
      },
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.products,
    required this.onTap,
  });

  final List<_ShopProduct> products;
  final ValueChanged<_ShopProduct> onTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products found',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF777777),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final _ShopProduct product = products[index];

        return Material(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => onTap(product),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(product.icon),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.creator,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
