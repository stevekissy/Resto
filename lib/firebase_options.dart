// firebase_options.dart — projet sankadiokro-manager
// IMPORTANT : Web utilise un appId format "web:" différent de Android "android:"
// Si vous n'avez pas d'app Web dans Firebase Console, laissez le appId web vide
// et l'initialisation utilisera le projet sans app web dédiée.

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

  // ── Web ──
  // NOTE: Si vous n'avez pas encore ajouté une app Web dans Firebase Console,
  // utilisez les mêmes clés que Android — Firebase accepte ça pour le preview web.
  // L'appId web aura le format "1:XXXXX:web:XXXXX" une fois créé dans Firebase Console.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBn6uvarIeS37QdtW8ERBHoHBaehIjcU6U',
    // appId web correct — format "1:PROJECT_NUMBER:web:HASH"
    // Si pas d'app web dans Firebase Console, utiliser le même que android est toléré
    // pour le preview uniquement. Pour la production, créer une app Web dans Firebase Console.
    appId: '1:54702810896:web:0000000000000000',
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
