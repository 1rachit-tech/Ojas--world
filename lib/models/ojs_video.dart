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
  });

  final String id;
  final String creator;
  final String caption;
  final String videoUrl;
  final int likes;
  final int comments;
  final int shares;
  final int avatarColor;
}

// TEMPORARY: Replace these public demo URLs with Firebase Storage URLs later.
const temporaryOjsVideos = <OjsVideo>[
  OjsVideo(
    id: 'city-lights',
    creator: 'Maya Chen',
    caption: 'City lights, quiet moments, and a little room to breathe.',
    videoUrl: 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
    avatarColor: 0xffd98b62,
    likes: 24800,
    comments: 642,
    shares: 918,
  ),
  OjsVideo(
    id: 'open-road',
    creator: 'Rohan Mehta',
    caption: 'Taking the long way home. What is your favorite detour?',
    videoUrl: 'https://samplelib.com/lib/preview/mp4/sample-10s.mp4',
    avatarColor: 0xff5d8f8b,
    likes: 18600,
    comments: 381,
    shares: 704,
  ),
  OjsVideo(
    id: 'wild-frame',
    creator: 'Nia Okafor',
    caption: 'A closer look at the little details we usually miss.',
    videoUrl: 'https://samplelib.com/lib/preview/mp4/sample-15s.mp4',
    avatarColor: 0xff7f9272,
    likes: 31200,
    comments: 904,
    shares: 1200,
  ),
  OjsVideo(
    id: 'bright-ideas',
    creator: 'Arjun Rao',
    caption: 'Make space for the idea before you decide what it becomes.',
    videoUrl: 'https://samplelib.com/lib/preview/mp4/sample-20s.mp4',
    avatarColor: 0xffad6f7e,
    likes: 9700,
    comments: 218,
    shares: 306,
  ),
];
