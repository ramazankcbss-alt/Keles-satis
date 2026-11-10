// keles-satis Firebase projesi ayarları (google-services.json'dan üretildi).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Keleş Satış yalnızca Android için ayarlandı.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB1rCK_lUftziSDt7zFTQ6P3ttXrkHJ1ZY',
    appId: '1:23261241650:android:1939b0cc94e89feaeb372b',
    messagingSenderId: '23261241650',
    projectId: 'keles-satis',
    storageBucket: 'keles-satis.firebasestorage.app',
  );
}
