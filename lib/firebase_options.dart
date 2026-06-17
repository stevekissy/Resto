// firebase_options.dart — généré pour le projet sankadiokro-manager
// À compléter avec les vraies clés Web depuis Firebase Console
// (en attendant google-services.json)

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
      default:
        return web;
    }
  }

  // ── Config Web ── (à remplacer avec les vraies clés depuis Firebase Console)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: 'REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'sankadiokro-manager',
    authDomain: 'sankadiokro-manager.firebaseapp.com',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
  );

  // ── Config Android ── (à remplacer avec google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'sankadiokro-manager',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
  );

  // ── Config iOS ──
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'sankadiokro-manager',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
    iosBundleId: 'com.sankadiomanager.manage',
  );
}
