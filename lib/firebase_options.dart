// firebase_options.dart — généré pour sankadiokro-manager
// Package Android : com.sankadiokro.manager

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // ── Web (même clé API Android en attendant app Web Firebase) ──
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBn6uvarIeS37QdtW8ERBHoHBaehIjcU6U',
    appId: '1:54702810896:android:5072a1135ac7c67c7e6795',
    messagingSenderId: '54702810896',
    projectId: 'sankadiokro-manager',
    authDomain: 'sankadiokro-manager.firebaseapp.com',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
  );

  // ── Android ──
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBn6uvarIeS37QdtW8ERBHoHBaehIjcU6U',
    appId: '1:54702810896:android:5072a1135ac7c67c7e6795',
    messagingSenderId: '54702810896',
    projectId: 'sankadiokro-manager',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
  );

  // ── iOS (optionnel) ──
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBn6uvarIeS37QdtW8ERBHoHBaehIjcU6U',
    appId: '1:54702810896:android:5072a1135ac7c67c7e6795',
    messagingSenderId: '54702810896',
    projectId: 'sankadiokro-manager',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
    iosBundleId: 'com.sankadiokro.manager',
  );
}
