import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';

// ══════════════════════════════════════════════════════════════
//  POINT D'ENTRÉE — ordre strict :
//  1. WidgetsFlutterBinding
//  2. Firebase.initializeApp()   ← OBLIGATOIRE avant tout accès Auth/Firestore
//  3. Hive, Intl, orientation
//  4. AppProvider(firebaseReady: ...)  ← créé ICI, jamais en variable globale
//  5. checkExistingSession()
//  6. runApp()
// ══════════════════════════════════════════════════════════════
void main() async {
  // ── 1. Binding Flutter ──
  WidgetsFlutterBinding.ensureInitialized();

  // ── 2. Firebase — AVANT tout accès à FirebaseAuth ou Firestore ──
  bool firebaseOk = false;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseOk = true;
    debugPrint('[main] ✅ Firebase initialisé (projet: sankadiokro-manager)');
  } catch (e) {
    firebaseError = e.toString();
    debugPrint('[main] ❌ Firebase ERREUR: $e');
    // L'app continue sans Firebase — mode dégradé avec données demo
  }

  // ── 3. Hive ──
  try {
    await Hive.initFlutter();
    debugPrint('[main] ✅ Hive initialisé');
  } catch (e) {
    debugPrint('[main] ⚠ Hive: $e');
  }

  // ── 4. Intl ──
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (e) {
    debugPrint('[main] ⚠ Intl: $e');
  }

  // ── 5. Orientation ──
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ── 6. Créer AppProvider ICI — APRÈS Firebase.initializeApp() ──
  // JAMAIS en variable globale Dart (serait créé avant main(), avant Firebase)
  final AppProvider provider;
  String? providerError;
  try {
    provider = AppProvider(firebaseReady: firebaseOk);
    debugPrint('[main] ✅ AppProvider créé (firebaseReady=$firebaseOk)');
  } catch (e) {
    // Ce bloc ne devrait jamais être atteint si AppProvider ne lance pas d'exception
    // Mais par sécurité maximale, on crée un provider minimal
    debugPrint('[main] ❌ AppProvider ERREUR: $e');
    providerError = 'AppProvider: $e';
    runApp(_ErrorApp(message: 'Erreur critique AppProvider:\n$e'));
    return;
  }

  // ── 7. Reprise de session si Firebase est prêt ──
  if (firebaseOk) {
    try {
      await provider.checkExistingSession();
      debugPrint('[main] ✅ Session vérifiée');
    } catch (e) {
      debugPrint('[main] ⚠ checkExistingSession: $e');
    }
  }

  // ── 8. Lancer l'app ──
  runApp(SankadiokroApp(
    provider: provider,
    firebaseError: firebaseError,
  ));
}

// ══════════════════════════════════════════════════════════════
//  APPLICATION PRINCIPALE
// ══════════════════════════════════════════════════════════════
class SankadiokroApp extends StatelessWidget {
  final AppProvider provider;
  final String? firebaseError;

  const SankadiokroApp({
    super.key,
    required this.provider,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider.value : utilise l'instance déjà créée dans main()
    // → AUCUN risque de throw dans create() car pas de create() ici
    return ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        title: 'Sankadio Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: LoginScreen(firebaseInitError: firebaseError),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  APP D'ERREUR CRITIQUE (fallback si AppProvider lui-même plante)
// ══════════════════════════════════════════════════════════════
class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Erreur de démarrage',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Relancez l\'application.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
