import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAgyuOk27w5yWNPAfZVXImmkJfTsy0cWyI',
    appId: '1:1076759095973:android:6eb79eb65332688646bb4c',
    messagingSenderId: '1076759095973',
    projectId: 'ojas-e8161',
    authDomain: 'ojas-e8161.firebaseapp.com',
    storageBucket: 'ojas-e8161.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAgyuOk27w5yWNPAfZVXImmkJfTsy0cWyI',
    appId: '1:1076759095973:android:6eb79eb65332688646bb4c',
    messagingSenderId: '1076759095973',
    projectId: 'ojas-e8161',
    storageBucket: 'ojas-e8161.firebasestorage.app',
  );

  static const FirebaseOptions ios = web;
  static const FirebaseOptions macos = web;
  static const FirebaseOptions windows = web;
  static const FirebaseOptions linux = web;
}