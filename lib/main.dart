import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
// URL Strategy — active les URL propres (/dashboard au lieu de /#/dashboard)
// Disponible nativement dans Flutter Web (flutter/services)
import 'package:flutter_web_plugins/url_strategy.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';

// ══════════════════════════════════════════════════════════════
//  POINT D'ENTRÉE — ordre strict :
//  1. WidgetsFlutterBinding
//  2. usePathUrlStrategy()   ← URLs propres sans # pour Netlify
//  3. Firebase.initializeApp()
//  4. Intl, orientation
//  5. AppProvider(firebaseReady: ...)
//  6. checkExistingSession()
//  7. runApp()
// ══════════════════════════════════════════════════════════════
void main() async {
  // ── 1. Binding Flutter ──
  WidgetsFlutterBinding.ensureInitialized();

  // ── 2. URL Strategy — AVANT runApp(), après ensureInitialized() ──
  // Supprime le '#' des URLs sur Flutter Web : /login au lieu de /#/login
  // OBLIGATOIRE pour que Netlify _redirects fonctionne correctement
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // ── 3. Firebase — OBLIGATOIRE : sans Firebase l'app ne peut pas fonctionner ──
  // Si Firebase échoue, on affiche l'erreur exacte (plus de silence) pour diagnostic
  bool firebaseOk = false;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseOk = true;
    debugPrint('[main] ✅ Firebase initialisé (projet: sankadiokro-manager)');
    debugPrint('[main]    platform: ${kIsWeb ? "WEB" : "ANDROID/iOS"}');
    debugPrint('[main]    authDomain: sankadiokro-manager.firebaseapp.com');
    debugPrint('[main]    projectId: sankadiokro-manager');
  } catch (e, stack) {
    firebaseError = e.toString();
    // ⚠️ ERREUR FIREBASE — affichée clairement pour diagnostic
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('[main] ❌ Firebase INIT FAILED');
    debugPrint('[main]    platform : ${kIsWeb ? "WEB" : "ANDROID/iOS"}');
    debugPrint('[main]    error    : $e');
    debugPrint('[main]    stack    : $stack');
    debugPrint('═══════════════════════════════════════════════');
    // Afficher l'écran d'erreur immédiatement — pas de mode dégradé silencieux
    runApp(_ErrorApp(
      message: 'Firebase init failed\n\n'
          'Platform: ${kIsWeb ? "Web" : "Android/iOS"}\n\n'
          'Erreur: $e\n\n'
          'Si vous voyez "duplicate-app" : rechargez la page.\n'
          'Si vous voyez "network" : vérifiez la connexion.\n'
          'Si vous voyez "invalid-api-key" : vérifiez firebase_options.dart.',
    ));
    return;
  }

  // ── 4. Intl ──
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (e) {
    debugPrint('[main] ⚠ Intl: $e');
  }

  // ── 6. Orientation ──
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

  // ── 7. Créer AppProvider ICI — APRÈS Firebase.initializeApp() ──
  final AppProvider provider;
  try {
    provider = AppProvider(firebaseReady: firebaseOk);
    debugPrint('[main] ✅ AppProvider créé (firebaseReady=$firebaseOk)');
  } catch (e) {
    debugPrint('[main] ❌ AppProvider ERREUR: $e');
    runApp(_ErrorApp(message: 'Erreur critique AppProvider:\n$e'));
    return;
  }

  // ── 8. Reprise de session si Firebase est prêt ──
  if (firebaseOk) {
    try {
      await provider.checkExistingSession();
      debugPrint('[main] ✅ Session vérifiée');
    } catch (e) {
      debugPrint('[main] ⚠ checkExistingSession: $e');
    }
  }

  // ── 9. Lancer l'app ──
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
    return ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        title: 'Sankadio Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // ── Routes nommées — résout les 404 après navigation ──
        // Toutes les routes inconnues reviennent à LoginScreen
        // Le _redirects Netlify renvoie toujours index.html
        // Flutter prend ensuite le relais avec ces routes
        initialRoute: '/',
        routes: {
          '/': (context) => LoginScreen(firebaseInitError: firebaseError),
          '/login': (context) => LoginScreen(firebaseInitError: firebaseError),
          '/home': (context) => const _HomeRedirect(),
        },
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => LoginScreen(firebaseInitError: firebaseError),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        ),
      ),
    );
  }
}

// ── Redirect helper : si l'utilisateur est déjà connecté, va à MainScreen ──
class _HomeRedirect extends StatefulWidget {
  const _HomeRedirect();

  @override
  State<_HomeRedirect> createState() => _HomeRedirectState();
}

class _HomeRedirectState extends State<_HomeRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  void _redirect() {
    final provider = context.read<AppProvider>();
    if (provider.currentUser != null) {
      // Utilisateur connecté → MainScreen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/dashboard',
        (_) => false,
      );
    } else {
      // Non connecté → Login
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A1A),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  APP D'ERREUR CRITIQUE
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
