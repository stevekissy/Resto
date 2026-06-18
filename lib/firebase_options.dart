// firebase_options.dart — projet sankadiokro-manager
// Généré automatiquement — NE PAS MODIFIER MANUELLEMENT
// Config Web récupérée depuis Firebase Console (app sankadiokro-web)
// Config Android depuis google-services.json

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

  // ── Web — configuration app "sankadiokro-web" depuis Firebase Console ──
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDP96Ow__9boFHl5M28pTIHqfKjEoFq4DI',
    appId: '1:54702810896:web:66059d3978fa00b27e6795',
    messagingSenderId: '54702810896',
    projectId: 'sankadiokro-manager',
    authDomain: 'cheery-monstera-c061a0.netlify.app',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
    measurementId: 'G-Z9DY3FL0ZD',
  );

  // ── Android — depuis google-services.json (package: com.sankadiokro.manager) ──
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBn6uvarIeS37QdtW8ERBHoHBaehIjcU6U',
    appId: '1:54702810896:android:5072a1135ac7c67c7e6795',
    messagingSenderId: '54702810896',
    projectId: 'sankadiokro-manager',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
  );

  // ── iOS ──
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBn6uvarIeS37QdtW8ERBHoHBaehIjcU6U',
    appId: '1:54702810896:android:5072a1135ac7c67c7e6795',
    messagingSenderId: '54702810896',
    projectId: 'sankadiokro-manager',
    storageBucket: 'sankadiokro-manager.firebasestorage.app',
    iosBundleId: 'com.sankadiokro.manager',
  );
}
