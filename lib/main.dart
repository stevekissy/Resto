import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/app_provider.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  // Capturer TOUTES les erreurs pour éviter le crash silencieux
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Gestion des erreurs Flutter non-catchées
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // Ne pas laisser crasher l'app — juste logger
      debugPrint('[FlutterError] ${details.exception}');
      debugPrint('[FlutterError] ${details.stack}');
    };

    // Init Hive avec try/catch
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('[Hive] Erreur init: $e');
    }

    // Init formats de date français
    try {
      await initializeDateFormatting('fr_FR', null);
    } catch (e) {
      debugPrint('[Intl] Erreur init: $e');
    }

    // Orientation
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('[SystemChrome] Erreur orientation: $e');
    }

    // Style barre de statut
    try {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    } catch (e) {
      debugPrint('[SystemChrome] Erreur UI: $e');
    }

    runApp(const SankadiokroApp());
  }, (error, stackTrace) {
    // Erreur dans une zone asynchrone — logger sans crasher
    debugPrint('[ZoneError] $error');
    debugPrint('[ZoneStack] $stackTrace');
  });
}

class SankadiokroApp extends StatelessWidget {
  const SankadiokroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'Sankadio Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
        // Gestionnaire d'erreurs dans le widget tree
        builder: (context, child) {
          // Intercepter les erreurs de rendu
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Scaffold(
              backgroundColor: const Color(0xFF0A0A0A),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Une erreur est survenue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Veuillez redémarrer l\'application',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // Forcer un redémarrage de l'app
                          SystemNavigator.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                        ),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          };

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
