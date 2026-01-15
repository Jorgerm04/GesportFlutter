import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TU-API-KEY',
    appId: '1:123456789:web:abc123',
    messagingSenderId: '123456789',
    projectId: 'tu-proyecto-id',
    authDomain: 'tu-proyecto-id.firebaseapp.com',
    storageBucket: 'tu-proyecto-id.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TU-API-KEY-ANDROID',
    appId: '1:123456789:android:abc123',
    messagingSenderId: '123456789',
    projectId: 'tu-proyecto-id',
    storageBucket: 'tu-proyecto-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TU-API-KEY-IOS',
    appId: '1:123456789:ios:abc123',
    messagingSenderId: '123456789',
    projectId: 'tu-proyecto-id',
    storageBucket: 'tu-proyecto-id.appspot.com',
    iosBundleId: 'com.ejemplo.tuapp',
  );
}