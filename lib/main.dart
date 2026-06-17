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

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exception}');
    };

    // ── Firebase ──
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('[Firebase] Initialisé ✅');
      // Reprise de session APRÈS init Firebase — safe
      await _appProvider.checkExistingSession();
    } catch (e) {
      debugPrint('[Firebase] Erreur init: $e');
    }

    // ── Hive ──
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('[Hive] $e');
    }

    // ── Intl ──
    try {
      await initializeDateFormatting('fr_FR', null);
    } catch (e) {
      debugPrint('[Intl] $e');
    }

    // ── Orientation ──
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('[Orientation] $e');
    }

    // ── Status bar ──
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    runApp(const SankadiokroApp());
  }, (error, stack) {
    debugPrint('[ZoneError] $error');
  });
}

// Provider instancié une seule fois, en dehors du widget tree
final _appProvider = AppProvider();

class SankadiokroApp extends StatelessWidget {
  const SankadiokroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appProvider,
      child: MaterialApp(
        title: 'Sankadio Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}
