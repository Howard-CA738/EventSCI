import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDER41_wLtHuNa6_vY57iP2fOJJ3Rv01U0',
    appId: '1:333241281155:web:ce8b004cd06b0e465c09b6',
    messagingSenderId: '333241281155',
    projectId: 'eventos-b074e',
    authDomain: 'eventos-b074e.firebaseapp.com',
    storageBucket: 'eventos-b074e.firebasestorage.app',
    measurementId: 'G-KXNQ99KPPJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC3SvP2mB3GO82VJ5wJm15TOT9aDW3xxCU',
    appId: '1:333241281155:android:b3c35e31a785c3015c09b6',
    messagingSenderId: '333241281155',
    projectId: 'eventos-b074e',
    storageBucket: 'eventos-b074e.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDFpA8i-9Xd9fQz7sQBGtT48AxogQ4PgGg',
    appId: '1:333241281155:ios:637fc3f7e18797c55c09b6',
    messagingSenderId: '333241281155',
    projectId: 'eventos-b074e',
    storageBucket: 'eventos-b074e.firebasestorage.app',
    iosBundleId: 'com.eventsci.eventos',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDFpA8i-9Xd9fQz7sQBGtT48AxogQ4PgGg',
    appId: '1:333241281155:ios:d57b1c6ae1ef472f5c09b6',
    messagingSenderId: '333241281155',
    projectId: 'eventos-b074e',
    storageBucket: 'eventos-b074e.firebasestorage.app',
    iosBundleId: 'com.example.eventos',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDER41_wLtHuNa6_vY57iP2fOJJ3Rv01U0',
    appId: '1:333241281155:web:2e6c32b0856959545c09b6',
    messagingSenderId: '333241281155',
    projectId: 'eventos-b074e',
    authDomain: 'eventos-b074e.firebaseapp.com',
    storageBucket: 'eventos-b074e.firebasestorage.app',
    measurementId: 'G-JW0TLD8T60',
  );
}
