class OjsVideo {
  const OjsVideo({
    required this.id,
    required this.creator,
    required this.caption,
    required this.videoUrl,
    required this.avatarColor,
    required this.likes,
    required this.comments,
    required this.shares,
    String? title,
    int? commentsCount,
    this.tags = const [],
    this.products = const [],
    this.isVerified = false,
    this.viralScore = 0.0,
    this.shopItemIds = const [],
  }) : title = title ?? caption,
        commentsCount = commentsCount ?? comments;

  final String id;
  final String creator;
  final String caption;
  final String videoUrl;
  final int likes;
  final int comments;
  final int shares;
  final int avatarColor;

  // Compatibility & High-Performance Extensions
  final String title;
  final int commentsCount;
  final List<String> tags;
  final List<Map<String, dynamic>> products;
  final bool isVerified;
  final double viralScore;
  final List<String> shopItemIds;
}

// TEMPORARY: Replace these public demo URLs with Firebase Storage URLs later.
const temporaryOjsVideos = <OjsVideo>[
  OjsVideo(
    id: 'city-lights',
    creator: 'Maya Chen',
    caption: 'City lights, quiet moments, and a little room to breathe.',
    videoUrl:
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    avatarColor: 0xffd98b62,
    likes: 24800,
    comments: 642,
    shares: 918,
    tags: ['#Vibe', '#City', '#OJAS'],
    isVerified: true,
    products: [
      {
        'name': 'Creator Mic & Setup Kit',
        'price': '1,499',
        'url': 'https://amazon.in',
      },
    ],
  ),
  OjsVideo(
    id: 'open-road',
    creator: 'Rohan Mehta',
    caption: 'Taking the long way home. What is your favorite detour?',
    videoUrl:
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    avatarColor: 0xff5d8f8b,
    likes: 18600,
    comments: 381,
    shares: 704,
    tags: ['#Travel', '#RoadTrip'],
    isVerified: true,
  ),
  OjsVideo(
    id: 'wild-frame',
    creator: 'Nia Okafor',
    caption: 'A closer look at the little details we usually miss.',
    videoUrl:
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    avatarColor: 0xff7f9272,
    likes: 31200,
    comments: 904,
    shares: 1200,
    tags: ['#Cinematic', '#Nature'],
    isVerified: true,
    products: [
      {
        'name': 'Macro Lens Kit for Mobile',
        'price': '799',
        'url': 'https://amazon.in',
      },
    ],
  ),
  OjsVideo(
    id: 'bright-ideas',
    creator: 'Arjun Rao',
    caption: 'Make space for the idea before you decide what it becomes.',
    videoUrl:
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    avatarColor: 0xffad6f7e,
    likes: 9700,
    comments: 218,
    shares: 306,
    tags: ['#Motivation', '#Ideas'],
    isVerified: false,
  ),
];
