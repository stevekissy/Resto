import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/common_widgets.dart';
// URL Strategy — URLs propres sans # pour Netlify
import 'package:flutter_web_plugins/url_strategy.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/client_provider.dart';
import 'sandbox/sandbox_provider.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/client/client_main_screen.dart';
// ignore: unused_import
import 'screens/client/auth/client_auth_screen.dart';
import 'services/firebase_service.dart';
import 'services/client_firebase_service.dart';

// ══════════════════════════════════════════════════════════════════════
//  POINT D'ENTRÉE — ordre strict et garanti :
//
//  1. WidgetsFlutterBinding.ensureInitialized()
//  2. usePathUrlStrategy()          ← URLs propres pour Netlify
//  3. Firebase.initializeApp()      ← OBLIGATOIRE avant tout accès Firebase
//  4. FirebaseAuth.setPersistence(LOCAL)  ← persistance Web localStorage
//  5. Intl + orientation
//  6. AppProvider(firebaseReady: true)
//  7. resolveAuthState()            ← attendre authStateChanges().first
//                                     (pas currentUser synchrone !)
//  8. runApp() avec état auth connu
//
//  POURQUOI resolveAuthState() ?
//  Sur Web, après un refresh navigateur, Firebase Auth recharge le token
//  depuis localStorage de façon ASYNCHRONE (~100-300ms). Si on lit
//  `currentUser` de façon synchrone immédiatement après initializeApp(),
//  il retourne null alors que l'utilisateur est en fait connecté.
//  authStateChanges().first attend que Firebase émette l'état réel.
// ══════════════════════════════════════════════════════════════════════
void main() async {
  // ── 1. Binding Flutter ──
  WidgetsFlutterBinding.ensureInitialized();

  // ── 2. URL Strategy — AVANT runApp() ──
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // ── 3. Firebase init — bloquant, obligatoire ──
  bool firebaseOk = false;
  String? firebaseError;
  final _svc = FirebaseService();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseOk = true;
    debugPrint('[main] ✅ Firebase initialisé — ${kIsWeb ? "WEB" : "ANDROID"}');

    // ── 4. Persistance Web LOCAL — AVANT resolveAuthState() ──
    // Sur Web, force la lecture du token depuis localStorage au prochain accès auth.
    // Sans cela, Firefox/Chrome peuvent perdre la session après refresh.
    await _svc.enableWebPersistence();

  } catch (e, stack) {
    firebaseError = e.toString();
    debugPrint('════════════════════════════════════════════');
    debugPrint('[main] ❌ Firebase INIT FAILED');
    debugPrint('[main]    error : $e');
    debugPrint('[main]    stack : $stack');
    debugPrint('════════════════════════════════════════════');
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

  // ── 5. Intl ──
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (e) {
    debugPrint('[main] ⚠ Intl: $e');
  }

  // ── Orientation ──
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

  // ── 6. AppProvider — créé APRÈS Firebase.initializeApp() ──
  final AppProvider provider;
  try {
    provider = AppProvider(firebaseReady: firebaseOk);
  } catch (e) {
    debugPrint('[main] ❌ AppProvider ERREUR: $e');
    runApp(_ErrorApp(message: 'Erreur critique AppProvider:\n$e'));
    return;
  }

  // ── 7. Résoudre l'état auth — authStateChanges().first ──
  // Cette étape EST LE CŒUR du fix : on attend que Firebase Auth
  // ait restauré la session depuis localStorage avant de lancer l'UI.
  // checkExistingSession() appelle resolveAuthState() en interne.
  bool hasSession = false;
  if (firebaseOk) {
    try {
      hasSession = await provider.checkExistingSession();
      debugPrint('[main] ✅ Auth résolu — session: $hasSession');
    } catch (e) {
      debugPrint('[main] ⚠ checkExistingSession: $e');
    }
  }

  // ── 8. runApp — avec état auth connu et définitif ──
  runApp(SankadiokroApp(
    provider: provider,
    firebaseError: firebaseError,
    hasSession: hasSession,
  ));
}

// ══════════════════════════════════════════════════════════════════════
//  APPLICATION PRINCIPALE
//  hasSession = true  → affiche directement MainScreen (pas de flash login)
//  hasSession = false → affiche LoginScreen
// ══════════════════════════════════════════════════════════════════════
class SankadiokroApp extends StatelessWidget {
  final AppProvider provider;
  final String? firebaseError;
  final bool hasSession;

  const SankadiokroApp({
    super.key,
    required this.provider,
    required this.hasSession,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider<ClientProvider>(create: (_) => ClientProvider()),
        ChangeNotifierProvider<SandboxProvider>(create: (_) => SandboxProvider()),
      ],
      child: MaterialApp(
        title: 'Sankadio Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // Pas de routes nommées pour éviter les conflits avec Netlify.
        // L'écran initial est déterminé par hasSession (calculé AVANT runApp).
        home: _AuthGate(
          firebaseError: firebaseError,
          hasSession: hasSession,
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

// ══════════════════════════════════════════════════════════════════════
//  AUTH GATE — Écran racine qui route selon l'état de session
//
//  Logique :
//  • hasSession = true  → MainScreen directement (session restaurée)
//  • hasSession = false → LoginScreen
//
//  De plus, écoute FirebaseAuth.authStateChanges() pour réagir aux
//  connexions/déconnexions PENDANT la session (ex: expiration token).
//  IMPORTANT : ne jamais déclencher signOut() ici — laisser Firebase
//  gérer la session naturellement.
// ══════════════════════════════════════════════════════════════════════
class _AuthGate extends StatefulWidget {
  final String? firebaseError;
  final bool hasSession;

  const _AuthGate({this.firebaseError, required this.hasSession});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  // Null = en cours de résolution (ne devrait pas arriver ici car
  // main() a déjà attendu resolveAuthState, mais sécurité supplémentaire)
  // true = connecté, false = déconnecté
  late bool? _authenticated;
  StreamSubscription<User?>? _authSub;



  @override
  void initState() {
    super.initState();
    // État initial connu depuis main() — pas de flash
    _authenticated = widget.hasSession;

    // Écouter les changements d'état auth ULTÉRIEURS (ex: token expiré,
    // logout explicite par l'utilisateur) SANS toucher à l'état initial.
    // ─── LOG DIAGNOSTIC ────────────────────────────────────────────────
    debugPrint('════════════════════════════════════════════════════════');
    debugPrint('[DIAG][main.dart:214] _AuthGate.initState()');
    debugPrint('[DIAG][main.dart:214]   hasSession initial = ${widget.hasSession}');
    debugPrint('[DIAG][main.dart:214]   _authenticated initial = $_authenticated');
    debugPrint('════════════════════════════════════════════════════════');
    // ───────────────────────────────────────────────────────────────────

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;

      final provider = context.read<AppProvider>();
      final wasAuthenticated = _authenticated;

      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('[DIAG][main.dart:223] authStateChanges EVENT');
      debugPrint('[DIAG][main.dart:223]   user = ${user?.email ?? "NULL"}');
      debugPrint('[DIAG][main.dart:223]   uid  = ${user?.uid  ?? "NULL"}');
      debugPrint('[DIAG][main.dart:223]   wasAuthenticated = $wasAuthenticated');
      debugPrint('[DIAG][main.dart:223]   currentUser Provider = ${provider.currentUser?.name ?? "NULL"}');
      debugPrint('════════════════════════════════════════════════════════');
      // ────────────────────────────────────────────────────────────────

      if (user != null && wasAuthenticated == false) {
        // Connexion détectée (ex: depuis LoginScreen)
        debugPrint('[AuthGate] Connexion détectée: ${user.email}');
        debugPrint('[DIAG][main.dart:232] ▶ setState(_authenticated = true) — AFFICHE MainScreen');
        setState(() => _authenticated = true);
      } else if (user == null && wasAuthenticated == true) {
        // Déconnexion RÉELLE détectée (logout explicite ou token expiré)
        debugPrint('[AuthGate] Déconnexion détectée');
        debugPrint('[DIAG][main.dart:237] ▶▶▶ REDIRECTION LOGIN DÉCLENCHÉE PAR : main.dart — _AuthGateState.initState (listener authStateChanges) — ligne 237');
        debugPrint('[DIAG][main.dart:237]   CAUSE : user == null reçu alors que wasAuthenticated == true');
        provider.clearSessionLocally();
        setState(() => _authenticated = false);
      } else {
        // ─── LOG DIAGNOSTIC ───────────────────────────────────────────
        debugPrint('[DIAG][main.dart:242] authStateChanges ignoré (pas de changement d\'état)');
        debugPrint('[DIAG][main.dart:242]   user=${user?.email ?? "null"} wasAuth=$wasAuthenticated → aucune action');
        // ──────────────────────────────────────────────────────────────
      }
      // Si wasAuthenticated == true et user != null → rien (session stable)
      // Si wasAuthenticated == false et user == null → rien (pas connecté)
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cas improbable mais sécurisé : état encore inconnu → spinner
    if (_authenticated == null) {
      return const _SplashScreen();
    }

    if (_authenticated == true) {
      // Session restaurée → détecter le rôle (client vs staff)
      return _RoleRouter(
        firebaseError: widget.firebaseError,
        onRoleResolved: (role) {},
      );
    }

    // Aucune session → afficher l'Espace Client par défaut.
    // Le bouton "Passer en mode gestion" ouvre LoginScreen sans connexion auto.
    return ClientMainScreen(
      showManagementButton: true,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ROLE ROUTER — Détecte si l'utilisateur connecté est un client ou un
//  membre du staff, puis route vers ClientMainScreen ou MainScreen.
//
//  Logique :
//  • Vérifie si l'UID existe dans la collection Firestore `clients`
//  • Si oui → ClientMainScreen (avec initialisation du ClientProvider)
//  • Si non → MainScreen (interface de gestion)
//
//  Non bloquant : si la détection échoue (réseau KO), route vers staff.
// ══════════════════════════════════════════════════════════════════════
class _RoleRouter extends StatefulWidget {
  final String? firebaseError;
  final void Function(String role)? onRoleResolved;
  const _RoleRouter({this.firebaseError, this.onRoleResolved});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  // null = en cours de détection
  String? _role;
  bool _clientInitialized = false;

  @override
  void initState() {
    super.initState();
    _detectRole();
  }

  Future<void> _detectRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _role = 'staff');
        return;
      }
      final isClient = await ClientFirebaseService().isClientUser(uid);
      if (mounted) {
        setState(() => _role = isClient ? 'client' : 'staff');
        widget.onRoleResolved?.call(_role!);
        if (isClient) {
          _initClient(uid);
        }
      }
    } catch (e) {
      debugPrint('[RoleRouter] Erreur détection rôle: $e → fallback staff');
      if (mounted) setState(() => _role = 'staff');
    }
  }

  Future<void> _initClient(String uid) async {
    try {
      await context.read<ClientProvider>().init(uid);
      if (mounted) setState(() => _clientInitialized = true);
    } catch (e) {
      debugPrint('[RoleRouter] Erreur init ClientProvider: $e');
      if (mounted) setState(() => _clientInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      // Détection en cours
      return const _SplashScreen();
    }
    if (_role == 'client') {
      if (!_clientInitialized) {
        return const _SplashScreen();
      }
      return const ClientMainScreen();
    }
    // Staff
    return const MainScreen();
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SPLASH SCREEN — Affiché pendant la vérification de session
//  (ne devrait quasiment jamais apparaître car main() attend d'abord)
// ══════════════════════════════════════════════════════════════════════
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF2196F3),
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo officiel avec animation de scale
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const SankaLogo(size: 120),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Nom du restaurant
                    const Text(
                      'SANKADIOKRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Système Professionnel de Gestion Restaurant',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    // Indicateur de chargement
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vérification de la session...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  APP D'ERREUR CRITIQUE
// ══════════════════════════════════════════════════════════════════════
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
