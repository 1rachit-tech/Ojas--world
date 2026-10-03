import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide debugPrint;
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'creation/screens/creation_hub_screen.dart';
import 'screens/home_feed_dynamic_screen.dart';
import 'screens/ojs_feed_screen.dart';
import 'screens/ojas_shop_screen.dart';
import 'screens/you_hub_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/creator_profile_screen.dart';
import 'widgets/world_search_delegate.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/home_story_viewer.dart';
import 'widgets/home_comments_sheet.dart';
import 'widgets/super_thanks_modal.dart';
import 'widgets/ojas_smart_video_player.dart';
import 'widgets/ojas_brand_logo.dart';
import 'services/video_engine_service.dart';
import 'services/auth_guard.dart';
import 'services/notification_service.dart';
import 'services/incoming_call_service.dart';
import 'widgets/incoming_call_overlay.dart';
import 'screens/notification_chat_router.dart';
import 'screens/livekit_call_screen.dart';
import 'services/profile_service.dart';
import 'screens/camera_screen.dart';

final GlobalKey<NavigatorState> ojasNavigatorKey = GlobalKey<NavigatorState>();
String? _lastOpenedMessageId;

Future<void> _openNotificationChat(NotificationOpenData data) async {
  final dedupeKey = data.openType == 'call'
      ? 'call_${data.conversationId}_${data.senderId}'
      : data.messageId;
  if (dedupeKey.isNotEmpty && _lastOpenedMessageId == dedupeKey) {
    return;
  }
  _lastOpenedMessageId = dedupeKey;
  final navigator = ojasNavigatorKey.currentState;
  if (navigator == null) {
    return;
  }

  if (data.openType == 'call') {
    IncomingCallService.instance.clear();
    String peerName = 'OJAS User';
    String peerHandle = 'ojas';
    try {
      final profile = await ProfileService.instance.getProfile(data.senderId);
      if (profile != null) {
        if (profile.displayName.trim().isNotEmpty) {
          peerName = profile.displayName.trim();
        }
        if (profile.ojasId.trim().isNotEmpty) {
          peerHandle = profile.ojasId.trim();
        }
      }
    } catch (_) {}
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LiveKitCallScreen(
          conversationId: data.conversationId,
          peerName: peerName,
          peerHandle: peerHandle,
          isVideoCall: data.isVideoCall,
          isIncoming: true,
        ),
      ),
    );
    return;
  }

  navigator.push(
    MaterialPageRoute(
      builder: (_) => NotificationChatRouter(openData: data),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    }

    await NotificationService.instance.initialize();
    IncomingCallService.instance.start();
  } catch (_) {}

  runApp(const OjasApp());

  NotificationService.instance.onNotificationOpened.listen(_openNotificationChat);
  final pendingOpen = NotificationService.instance.consumePendingOpen();
  if (pendingOpen != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openNotificationChat(pendingOpen);
    });
  }
}

class OjasApp extends StatelessWidget {
  const OjasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ojasNavigatorKey,
      title: 'OJAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF111827),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const OjasHomePage(),
    );
  }
}

class OjasHomePage extends StatefulWidget {
  const OjasHomePage({super.key});

  @override
  State<OjasHomePage> createState() => _OjasHomePageState();
}

class _OjasHomePageState extends State<OjasHomePage> {
  int _selectedTab = 0;
  bool _authGateLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void _openReelInOjsFeed() {
    HapticFeedback.mediumImpact();
    setState(() => _selectedTab = 1);
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    HapticFeedback.selectionClick();
    if (index == 2) {
      _requestCreate();
      return;
    }
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    final bool hideAppBar = _selectedTab != 0;
    final bool isOjsDark = _selectedTab == 1;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isOjsDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isOjsDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness:
            isOjsDark ? Brightness.light : Brightness.dark,
      ),
    );

    return PopScope<void>(
      canPop: _selectedTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedTab != 0) {
          setState(() => _selectedTab = 0);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            extendBody: isOjsDark,
            backgroundColor:
                isOjsDark ? Colors.black : const Color(0xFFFAFAFA),
            appBar: hideAppBar
                ? null
                : AppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    titleSpacing: 0,
                    leading: IconButton(
                      tooltip: 'Search & Discover',
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF111827),
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        WorldSearchSheet.show(context);
                      },
                    ),
                    title: const OjasBrandLogo(fontSize: 21),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationsScreen(),
                            ),
                          );
                        },
                        tooltip: 'Notifications',
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF111827),
                              size: 25,
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 14, left: 4),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTab = 4);
                          },
                          child: _buildDynamicUserAvatar(radius: 14),
                        ),
                      ),
                    ],
                  ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth >= 900;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1180 : double.infinity,
                    ),
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        const DynamicHomeScreen(),
                        _buildOjsTab(),
                        const CreationHubScreen(),
                        const OjasShopScreen(),
                        const YouHubScreen(),
                      ],
                    ),
                  ),
                );
              },
            ),
            bottomNavigationBar: _buildMinimalBottomBar(isDark: isOjsDark),
          ),
          if (_authGateLoading) _buildAuthLoadingOverlay(),
          const IncomingCallOverlay(),
        ],
      ),
    );
  }

  Widget _buildDynamicUserAvatar({required double radius}) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF111827),
            child: Text(
              'O',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.85,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF111827),
            backgroundImage: NetworkImage(user.photoURL!),
          );
        }
        String initial = 'U';
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          initial = user.displayName!.trim()[0].toUpperCase();
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF111827),
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.85,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _requestCreate() {
    if (_authGateLoading) return;
    setState(() => _authGateLoading = true);

    requireAuth(
      context,
      () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CameraScreen(audioId: ''),
          ),
        );
      },
      onLoadingChanged: (loading) {
        if (mounted) {
          setState(() => _authGateLoading = loading);
        }
      },
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  Widget _buildAuthLoadingOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x2E000000),
          ),
          Center(
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      'Checking your profile...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOjsTab() {
    return OjsFeedScreen(isActive: _selectedTab == 1);
  }

  Widget _buildMinimalBottomBar({required bool isDark}) {
    final Color bg = isDark ? Colors.black : Colors.white;
    final Color active = isDark ? Colors.white : const Color(0xFF111827);
    final Color inactive =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEEEEEE),
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home',
                  active, inactive),
              _navItem(1, Icons.play_circle_outline, Icons.play_circle_fill,
                  'OJS', active, inactive),
              _navItem(2, Icons.add_box_outlined, Icons.add_box, 'Create',
                  active, inactive),
              _navItem(3, Icons.shopping_bag_outlined, Icons.shopping_bag,
                  'Shop', active, inactive),
              _navItem(4, Icons.person_outline_rounded, Icons.person_rounded,
                  'You', active, inactive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData outlined,
    IconData filled,
    String label,
    Color active,
    Color inactive,
  ) {
    final selected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? filled : outlined,
              color: selected ? active : inactive,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? active : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
