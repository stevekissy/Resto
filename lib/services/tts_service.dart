import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

// Importation conditionnelle : dart:js uniquement sur web
// ignore: uri_does_not_exist
import 'tts_web_stub.dart'
    if (dart.library.js) 'tts_web_impl.dart' as tts_web;

/// Service TTS — Assistante Vocale Africaine Francophone
/// - Web   : utilise l'API Web Speech via JS (africanSpeak dans index.html)
/// - Mobile: utilise flutter_tts avec pitch/rate africain féminin
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  Timer? _reminderTimer;
  bool _remindersActive = false;

  // ====================================================================
  // INITIALISATION
  // ====================================================================
  Future<void> init() async {
    if (_isInitialized) return;
    // Marquer comme initialisé dès le début pour éviter les boucles
    _isInitialized = true;
    try {
      if (kIsWeb) {
        // Sur web, le script JS dans index.html gère tout
        await Future.delayed(const Duration(milliseconds: 500));
        if (kDebugMode) debugPrint('[TTS] Mode Web — voix africaine JS activée');
      } else {
        // ===== ANDROID / MOBILE =====
        // Délai de sécurité pour laisser l'app se stabiliser
        await Future.delayed(const Duration(milliseconds: 300));
        
        _flutterTts = FlutterTts();

        // Langue française avec gestion d'erreur
        try { await _flutterTts!.setLanguage('fr-FR'); } catch (_) {}

        // Paramètres voix féminine africaine : débit naturel, ton chaud
        try { await _flutterTts!.setSpeechRate(0.82); } catch (_) {}
        try { await _flutterTts!.setVolume(1.0); } catch (_) {}
        try { await _flutterTts!.setPitch(1.2); } catch (_) {}


        // Chercher une voix africaine francophone (non bloquant)
        final dynamic rawVoices = await _flutterTts!.getVoices.catchError((_) => null);
        final voices = rawVoices;
        if (voices != null) {
          final voiceList = voices as List;

          // Priorité 1 : voix africaines par code locale
          final africanLocales = [
            'fr-ci', 'fr-sn', 'fr-cm', 'fr-mg', 'fr-bf',
            'fr-ml', 'fr-gn', 'fr-tg', 'fr-bj', 'fr-cd',
          ];

          Map? selectedVoice;
          for (final locale in africanLocales) {
            selectedVoice = voiceList.firstWhere(
              (v) => v is Map &&
                ((v['locale'] as String?)?.toLowerCase().startsWith(locale) == true ||
                 (v['name'] as String?)?.toLowerCase().contains(locale) == true),
              orElse: () => null,
            ) as Map?;
            if (selectedVoice != null) break;
          }

          // Priorité 2 : voix féminine fr-FR par genre ou nom
          selectedVoice ??= voiceList.firstWhere(
            (v) => v is Map && (
              (v['gender'] as String?)?.toLowerCase() == 'female' ||
              (v['name'] as String?)?.toLowerCase().contains('amélie') == true ||
              (v['name'] as String?)?.toLowerCase().contains('amelie') == true ||
              (v['name'] as String?)?.toLowerCase().contains('marie') == true ||
              (v['name'] as String?)?.toLowerCase().contains('claire') == true ||
              (v['name'] as String?)?.toLowerCase().contains('juliette') == true ||
              (v['name'] as String?)?.toLowerCase().contains('céline') == true ||
              (v['name'] as String?)?.toLowerCase().contains('celine') == true ||
              (v['name'] as String?)?.toLowerCase().contains('manon') == true ||
              (v['name'] as String?)?.toLowerCase().contains('audrey') == true
            ),
            orElse: () => null,
          ) as Map?;

          // Priorité 3 : première voix Google fr-FR
          selectedVoice ??= voiceList.firstWhere(
            (v) => v is Map &&
              (v['locale'] as String?)?.toLowerCase().startsWith('fr') == true &&
              (v['name'] as String?)?.toLowerCase().contains('google') == true,
            orElse: () => null,
          ) as Map?;

          // Priorité 4 : toute voix fr-*
          selectedVoice ??= voiceList.firstWhere(
            (v) => v is Map &&
              (v['locale'] as String?)?.toLowerCase().startsWith('fr') == true,
            orElse: () => null,
          ) as Map?;

          if (selectedVoice != null) {
            try {
              await _flutterTts!.setVoice({
                'name': selectedVoice['name'] as String,
                'locale': selectedVoice['locale'] as String,
              });
              if (kDebugMode) {
                debugPrint('[TTS] Voix: ${selectedVoice['name']} (${selectedVoice['locale']})');
              }
            } catch (_) {}
          }
        }

        try {
          _flutterTts!.setErrorHandler((msg) {
            if (kDebugMode) debugPrint('[TTS] Erreur: $msg');
          });
        } catch (_) {}

        if (kDebugMode) debugPrint('[TTS] Mode Mobile initialisé');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] Erreur init: $e');
      _isInitialized = true;
    }
  }

  // ====================================================================
  // PAROLE — Méthode principale
  // ====================================================================
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    if (text.trim().isEmpty) return;

    try {
      if (kIsWeb) {
        // Appel à la fonction JS africanSpeak via le stub/impl conditionnel
        tts_web.africanSpeak(text, 0.82, 1.2, 1.0);
      } else {
        await _flutterTts?.stop();
        await Future.delayed(const Duration(milliseconds: 100));
        await _flutterTts?.speak(text);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] Erreur speak: $e');
    }
  }

  Future<void> stop() async {
    try {
      if (kIsWeb) {
        tts_web.africanStop();
      } else {
        await _flutterTts?.stop();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] Erreur stop: $e');
    }
  }

  // ====================================================================
  // ANNONCES CUISINE
  // ====================================================================
  Future<void> announceNewOrder(Order order) async {
    final items = order.items.map((item) {
      return '${_numberToWords(item.quantity)} ${item.productName}';
    }).join(', ');

    final String message;
    if (order.isUrgent) {
      message = 'Attention ! Commande prioritaire urgente pour la table numéro ${order.tableNumber}. '
          'Préparez immédiatement : $items. Merci !';
    } else {
      message = 'Nouvelle commande reçue. Table numéro ${order.tableNumber}. '
          'Au menu : $items. Veuillez démarrer la préparation, merci.';
    }
    await speak(message);
  }

  Future<void> announceOrderReady(Order order) async {
    await speak(
      'La commande numéro ${order.orderNumber} est prête. '
      'Table ${order.tableNumber}, votre commande peut être servie. Merci.',
    );
  }

  Future<void> announceDelay(Order order) async {
    await speak(
      'Attention, retard signalé ! '
      'La commande de la table numéro ${order.tableNumber} attend depuis ${order.elapsedMinutes} minutes. '
      'Veuillez accélérer la préparation. Merci.',
    );
  }

  Future<void> announceOrder(Order order) async {
    final items = order.items.map((item) {
      return '${_numberToWords(item.quantity)} ${item.productName}';
    }).join(', puis ');

    String message = 'Commande numéro ${order.orderNumber}, table ${order.tableNumber}. '
        'Contenu : $items.';
    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
      message += ' Instructions spéciales : ${order.specialInstructions}.';
    }
    if (order.isUrgent) message = 'Commande urgente ! $message';
    await speak(message);
  }

  // ====================================================================
  // RAPPELS PÉRIODIQUES (toutes les N minutes)
  // ====================================================================
  void startPeriodicReminders(AppProvider provider, {int intervalMinutes = 5}) {
    if (_remindersActive) return;
    _remindersActive = true;
    _reminderTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) async {
      await _announceOrderSummary(provider);
    });
    if (kDebugMode) debugPrint('[TTS] Rappels actifs — intervalle: ${intervalMinutes}min');
  }

  void stopPeriodicReminders() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _remindersActive = false;
    if (kDebugMode) debugPrint('[TTS] Rappels désactivés');
  }

  bool get isRemindersActive => _remindersActive;

  Future<void> triggerImmediateReminder(AppProvider provider) async {
    await _announceOrderSummary(provider);
  }

  Future<void> _announceOrderSummary(AppProvider provider) async {
    final pending   = provider.pendingOrders;
    final preparing = provider.preparingOrders;
    final ready     = provider.readyOrders;

    if (pending.isEmpty && preparing.isEmpty && ready.isEmpty) return;

    final parts = <String>[];

    if (pending.isNotEmpty) {
      final n = pending.length;
      parts.add('${_numberToWords(n)} commande${n > 1 ? "s" : ""} en attente de préparation');
    }
    if (preparing.isNotEmpty) {
      final n = preparing.length;
      parts.add('${_numberToWords(n)} commande${n > 1 ? "s" : ""} en cours de préparation');
      final delayed = preparing.where((o) => o.elapsedMinutes >= 25).toList();
      if (delayed.isNotEmpty) {
        parts.add('dont ${_numberToWords(delayed.length)} en retard');
      }
    }
    if (ready.isNotEmpty) {
      final n = ready.length;
      final tables = ready.map((o) => 'table ${o.tableNumber}').join(', ');
      parts.add('${_numberToWords(n)} commande${n > 1 ? "s" : ""} prête${n > 1 ? "s" : ""} à servir : $tables');
    }

    if (parts.isEmpty) return;

    final fin = ready.isNotEmpty
        ? 'Merci de servir les tables en attente !'
        : 'Bon courage à toute l equipe !';

    final message = 'Récapitulatif des commandes : ${parts.join(". ")}. $fin';
    await speak(message);
  }

  // ====================================================================
  // UTILITAIRES
  // ====================================================================
  String _numberToWords(int n) {
    const words = {
      1: 'une', 2: 'deux', 3: 'trois', 4: 'quatre', 5: 'cinq',
      6: 'six', 7: 'sept', 8: 'huit', 9: 'neuf', 10: 'dix',
    };
    return words[n] ?? '$n';
  }

  void dispose() {
    stopPeriodicReminders();
    if (!kIsWeb) _flutterTts?.stop();
  }
}
