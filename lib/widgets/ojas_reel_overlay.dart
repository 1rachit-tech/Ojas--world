import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ojas_shop_sheet.dart';

class OjasReelOverlay extends StatelessWidget {
  final String creatorName;
  final String description;
  final String musicTitle;
  final int likes;
  final int comments;
  final bool hasProducts;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final bool isLiked;

  const OjasReelOverlay({
    super.key,
    required this.creatorName,
    required this.description,
    required this.musicTitle,
    required this.likes,
    required this.comments,
    this.hasProducts = false,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left Side: Creator Info & Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Creator Name & Follow Button
                        Row(
                          children: [
                            Text(
                              '@$creatorName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Follow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Video Description
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Music Ticker
                        Row(
                          children: [
                            const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              musicTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Right Side: Action Buttons (Like, Comment, Share, Shop)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 🛍️ SHOP BUTTON (Zero Server Cost E-commerce)
                      if (hasProducts)
                        _buildActionButton(
                          icon: Icons.shopping_bag_rounded,
                          label: 'Shop',
                          color: const Color(0xFFF5B942), // Premium Gold
                          onTap: () {
                            HapticFeedback.lightImpact();
                            // Dummy products list to show earning potential
                            OjasShopSheet.show(context, products: [
                              {
                                'name': 'Acoustic Guitar - Bagheli Folk Edition',
                                'price': '4,500',
                                'url': 'https://amazon.in/dp/dummy1'
                              },
                              {
                                'name': 'Premium Studio Mic (Low Budget)',
                                'price': '1,200',
                                'url': 'https://amazon.in/dp/dummy2'
                              }
                            ]);
                          },
                        ),
                      
                      _buildActionButton(
                        icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        label: '$likes',
                        color: isLiked ? const Color(0xFFEF4444) : Colors.white,
                        onTap: onLike,
                      ),
                      
                      _buildActionButton(
                        icon: Icons.mode_comment_outlined,
                        label: '$comments',
                        color: Colors.white,
                        onTap: onComment,
                      ),
                      
                      _buildActionButton(
                        icon: Icons.reply_rounded,
                        label: 'Share',
                        color: Colors.white,
                        onTap: onShare,
                      ),
                      
                      const SizedBox(height: 10),
                      // Spinning Record / Audio Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 8),
                          image: const DecorationImage(
                            image: NetworkImage('https://picsum.photos/100'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 34,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
