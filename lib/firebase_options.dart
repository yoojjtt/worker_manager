import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('이 플랫폼은 지원되지 않습니다.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDGqvx1N7Bb7eWThCaj-CjgLyvW0iXbp-0',
    appId: '1:369094271595:android:2e00e94b1eb0a04855472e',
    messagingSenderId: '369094271595',
    projectId: 'linker-worker-manager',
    storageBucket: 'linker-worker-manager.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD4pi6BWiCJ47tbcbv8abvGTEdSYJ-FkzI',
    appId: '1:369094271595:ios:84180adfd052d35e55472e',
    messagingSenderId: '369094271595',
    projectId: 'linker-worker-manager',
    storageBucket: 'linker-worker-manager.firebasestorage.app',
    iosBundleId: 'com.linkerlab.workermanager',
  );
}
