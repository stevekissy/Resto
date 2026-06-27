import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

// Importation conditionnelle : dart:js uniquement sur web
// ignore: uri_does_not_exist
import 'tts_web_stub.dart'
    if (dart.library.js) 'tts_web_impl.dart' as tts_web;

// ======================================================================
// ENUMS & SETTINGS
// ======================================================================

enum CoachMode { doux, normal, pression }

/// Configuration persistante de l'assistant vocal cuisine
class KitchenVoiceSettings {
  bool enabled;
  double volume;           // 0.0 – 1.0
  int intervalMinutes;     // 1, 2, 3 ou 5
  CoachMode coachMode;
  double speechRate;       // 0.6 – 1.2 (défaut 0.88 — débit féminin africain naturel)
  String voiceName;        // Nom exact de la voix choisie ('' = auto-sélection)

  KitchenVoiceSettings({
    this.enabled = true,
    this.volume = 1.0,
    this.intervalMinutes = 2,
    this.coachMode = CoachMode.normal,
    this.speechRate = 0.88,
    this.voiceName = '',
  });

  KitchenVoiceSettings copyWith({
    bool? enabled,
    double? volume,
    int? intervalMinutes,
    CoachMode? coachMode,
    double? speechRate,
    String? voiceName,
  }) => KitchenVoiceSettings(
    enabled: enabled ?? this.enabled,
    volume: volume ?? this.volume,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    coachMode: coachMode ?? this.coachMode,
    speechRate: speechRate ?? this.speechRate,
    voiceName: voiceName ?? this.voiceName,
  );
}

// ======================================================================
// TTS SERVICE — Assistante Vocale Africaine Francophone
// - Web   : utilise l'API Web Speech via JS (africanSpeak dans index.html)
// - Mobile: utilise flutter_tts avec pitch/rate africain féminin
// ======================================================================
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  // --- Rappels périodiques ---
  Timer? _reminderTimer;
  bool _remindersActive = false;

  // --- File d'attente vocale ---
  final Queue<String> _speechQueue = Queue<String>();
  bool _isSpeaking = false;

  // --- Compteurs de variation de phrases ---
  int _coachPhraseIndex = 0;
  int _urgencyPhraseIndex = 0;

  // --- Settings exposés ---
  KitchenVoiceSettings settings = KitchenVoiceSettings();

  // --- Dernier message d'erreur audio (navigateur bloqué) ---
  String? lastAudioError;

  // ====================================================================
  // CLÉS SHARED PREFERENCES (persistance état ON/OFF)
  // ====================================================================
  static const _kKitchenEnabled  = 'tts_kitchen_enabled';
  static const _kCashierEnabled  = 'tts_cashier_enabled';
  static const _kSpeechRate      = 'tts_speech_rate';
  static const _kVoiceName       = 'tts_voice_name';
  static const _kPitch           = 'tts_pitch';

  /// Charge l'état persisté depuis SharedPreferences.
  /// À appeler au démarrage de l'application (ou des écrans cuisine/caisse).
  Future<void> loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      settings.enabled     = prefs.getBool(_kKitchenEnabled)    ?? true;
      settings.speechRate  = prefs.getDouble(_kSpeechRate)      ?? 0.88;
      settings.voiceName   = prefs.getString(_kVoiceName)       ?? '';
      _pitch               = prefs.getDouble(_kPitch)           ?? 1.22;
      _cashierEnabledPersisted = prefs.getBool(_kCashierEnabled) ?? false;
      if (kDebugMode) {
        debugPrint('[TTS] État chargé — cuisine: ${settings.enabled}, rate: ${settings.speechRate}, voix: "${settings.voiceName}", caisse: $_cashierEnabledPersisted');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] loadPersistedState erreur: $e');
    }
  }

  // Pitch configurable par l'utilisateur (indépendant du coachMode)
  double _pitch = 1.22;
  double get pitch => _pitch;

  /// Sauvegarde vitesse de parole, nom de voix et pitch.
  Future<void> saveVoiceSettings({
    required double speechRate,
    required String voiceName,
    double? pitch,
  }) async {
    settings.speechRate = speechRate;
    settings.voiceName  = voiceName;
    if (pitch != null) _pitch = pitch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kSpeechRate, speechRate);
      await prefs.setString(_kVoiceName, voiceName);
      await prefs.setDouble(_kPitch, _pitch);
      if (kIsWeb) {
        tts_web.setTTSConfig(voiceName, speechRate, _pitch, settings.volume);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] saveVoiceSettings erreur: $e');
    }
  }

  /// Sauvegarde uniquement le pitch.
  Future<void> savePitch(double pitch) async {
    _pitch = pitch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPitch, pitch);
      if (kIsWeb) {
        tts_web.setTTSConfig(settings.voiceName, settings.speechRate, pitch, settings.volume);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] savePitch erreur: $e');
    }
  }

  /// Sauvegarde l'état cuisine ON/OFF.
  Future<void> saveKitchenEnabled(bool value) async {
    settings.enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kKitchenEnabled, value);
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] saveKitchenEnabled erreur: $e');
    }
  }

  /// Sauvegarde l'état caisse ON/OFF.
  bool _cashierEnabledPersisted = false;
  bool get cashierEnabledPersisted => _cashierEnabledPersisted;

  Future<void> saveCashierEnabled(bool value) async {
    _cashierEnabledPersisted = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCashierEnabled, value);
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] saveCashierEnabled erreur: $e');
    }
  }

  // ====================================================================
  // INITIALISATION
  // ====================================================================
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (kDebugMode) debugPrint('[TTS] Mode Web — voix africaine JS activée');
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        _flutterTts = FlutterTts();

        try { await _flutterTts!.setLanguage('fr-FR'); } catch (_) {}
        try { await _flutterTts!.setSpeechRate(0.82); } catch (_) {}
        try { await _flutterTts!.setVolume(settings.volume); } catch (_) {}
        try { await _flutterTts!.setPitch(1.2); } catch (_) {}

        // Sélection de voix africaine / féminine française
        final dynamic rawVoices = await _flutterTts!.getVoices.catchError((_) => null);
        if (rawVoices != null) {
          final voiceList = rawVoices as List;
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
          selectedVoice ??= voiceList.firstWhere(
            (v) => v is Map && (
              (v['gender'] as String?)?.toLowerCase() == 'female' ||
              (v['name'] as String?)?.toLowerCase().contains('amélie') == true ||
              (v['name'] as String?)?.toLowerCase().contains('amelie') == true ||
              (v['name'] as String?)?.toLowerCase().contains('marie') == true ||
              (v['name'] as String?)?.toLowerCase().contains('claire') == true ||
              (v['name'] as String?)?.toLowerCase().contains('juliette') == true
            ),
            orElse: () => null,
          ) as Map?;
          selectedVoice ??= voiceList.firstWhere(
            (v) => v is Map &&
              (v['locale'] as String?)?.toLowerCase().startsWith('fr') == true &&
              (v['name'] as String?)?.toLowerCase().contains('google') == true,
            orElse: () => null,
          ) as Map?;
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
            } catch (_) {}
          }
        }

        // Callback fin de parole → dépiler la queue
        try {
          _flutterTts!.setCompletionHandler(() {
            _isSpeaking = false;
            _processQueue();
          });
          _flutterTts!.setErrorHandler((msg) {
            _isSpeaking = false;
            _processQueue();
            if (kDebugMode) debugPrint('[TTS] Erreur: $msg');
          });
        } catch (_) {}

        if (kDebugMode) debugPrint('[TTS] Mode Mobile initialisé');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] Erreur init: $e');
    }
  }

  // ====================================================================
  // FILE D'ATTENTE VOCALE
  // ====================================================================

  /// Ajoute un message à la file et déclenche la lecture si possible.
  void enqueue(String text) {
    if (text.trim().isEmpty) return;
    if (!settings.enabled) return;
    _speechQueue.addLast(text.trim());
    _processQueue();
  }

  /// Traite le prochain message de la file si rien n'est en cours.
  void _processQueue() {
    if (_isSpeaking) return;
    if (_speechQueue.isEmpty) return;
    final next = _speechQueue.removeFirst();
    _isSpeaking = true;
    _speakNow(next);
  }

  /// Calcule le pitch effectif : pitch utilisateur si défini, sinon basé sur coachMode.
  double _pitchForMode() {
    // Si pitch a été modifié manuellement (différent de la valeur mode normal), l'utiliser
    return _pitch;
  }

  /// Effectue la parole réelle (sans file).
  Future<void> _speakNow(String text) async {
    if (!_isInitialized) await init();
    try {
      if (kIsWeb) {
        tts_web.africanSpeak(text, settings.speechRate, _pitchForMode(), settings.volume);
        lastAudioError = null; // Succès : effacer toute erreur précédente
        // Sur Web, on ne peut pas détecter la fin → estimation basée sur longueur
        final durationMs = (text.length * 65).clamp(1500, 15000);
        Future.delayed(Duration(milliseconds: durationMs), () {
          _isSpeaking = false;
          _processQueue();
        });
      } else {
        try { await _flutterTts?.setVolume(settings.volume); } catch (_) {}
        await _flutterTts?.speak(text);
        lastAudioError = null;
        // Le handler setCompletionHandler gère la suite sur mobile
      }
    } catch (e) {
      _isSpeaking = false;
      _processQueue();
      lastAudioError = 'Le navigateur a bloqué l\'audio. Cliquez sur la page puis réessayez.';
      if (kDebugMode) debugPrint('[TTS] Erreur _speakNow: $e');
    }
  }

  /// Méthode speak publique — passe par la file d'attente.
  Future<void> speak(String text) async {
    enqueue(text);
  }

  Future<void> stop() async {
    _speechQueue.clear();
    _isSpeaking = false;
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

  /// Annonce immédiate d'une nouvelle commande avec tous les détails.
  Future<void> announceNewOrder(Order order) async {
    final items = order.items.map((item) {
      return '${_numberToWords(item.quantity)} ${item.productName}';
    }).join(', ');

    // Commentaires spéciaux sur les items
    final comments = order.items
        .where((i) => i.specialComment != null && i.specialComment!.isNotEmpty)
        .map((i) => '${i.productName} : ${i.specialComment}')
        .join(', ');

    // Instructions spéciales de la commande globale
    final instructions = (order.specialInstructions != null && order.specialInstructions!.isNotEmpty)
        ? order.specialInstructions!
        : '';

    // Phrase motivante variée — ton ivoirien professionnel
    final motivations = [
      'Allez l\'équipe, on garde le rythme !',
      'C\'est parti cuisine, on fait du bon boulot !',
      'Chaque commande est une fierté, on assure !',
      'On est chauds, l\'équipe est au top !',
      'En avant cuisine, le client attend avec confiance !',
      'On ne lâche pas, c\'est notre force !',
    ];
    final motivation = motivations[_coachPhraseIndex % motivations.length];
    _coachPhraseIndex++;

    String message;
    if (order.isUrgent) {
      message = 'Attention cuisine ! Commande urgente numéro ${order.orderNumber}, table ${order.tableNumber}. '
          'On s\'occupe de ça tout de suite : $items.';
    } else {
      message = 'Nouvelle commande en cuisine, numéro ${order.orderNumber}, table ${order.tableNumber}. '
          'Au menu : $items.';
    }

    if (comments.isNotEmpty) {
      message += ' Attention commentaires : $comments.';
    } else if (instructions.isNotEmpty) {
      message += ' Note : $instructions.';
    }

    message += ' $motivation';
    enqueue(message);
  }

  Future<void> announceOrderReady(Order order) async {
    enqueue(
      'La commande numéro ${order.orderNumber} est prête. '
      'Table ${order.tableNumber}, votre commande peut être servie.',
    );
  }

  Future<void> announceDelay(Order order) async {
    enqueue(
      'Attention, retard signalé ! '
      'La commande de la table ${order.tableNumber} attend depuis ${order.elapsedMinutes} minutes. '
      'Veuillez accélérer la préparation.',
    );
  }

  /// Lecture à la demande d'une commande (bouton Écouter).
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
    enqueue(message);
  }

  // ====================================================================
  // ANNONCE INDIVIDUELLE AVEC PRIORITÉ TEMPORELLE
  // ====================================================================

  /// Annonce une commande en adaptant le ton selon le temps écoulé.
  void _announceOrderWithPriority(Order order) {
    final mins = order.elapsedMinutes;
    final table = 'table ${order.tableNumber}';
    final num = 'numéro ${order.orderNumber}';

    String message;

    if (mins >= 15) {
      // Alerte forte — ton d'urgence maximum
      final alerts = [
        'Urgence cuisine ! Commande $num, $table attend depuis plus de quinze minutes. Intervenez immédiatement !',
        'Alerte cuisine ! $table, commande $num, c\'est critique. Quinze minutes dépassées !',
        'Cuisine, situation critique ! Commande $num table ${order.tableNumber}, quinze minutes et plus. Action immédiate !',
      ];
      message = alerts[_urgencyPhraseIndex % alerts.length];
      _urgencyPhraseIndex++;
    } else if (mins >= 10) {
      // Ton urgent
      final urgents = [
        'Attention cuisine, commande $num, $table dépasse dix minutes. Il faut avancer !',
        'Commande $num, $table, dix minutes au compteur. Accélérez la cadence !',
        'Cuisine, $table dépasse les dix minutes. Commande $num, on accélère s\'il vous plaît !',
      ];
      message = urgents[_urgencyPhraseIndex % urgents.length];
      _urgencyPhraseIndex++;
    } else {
      // Ton normal — 5 minutes
      final normals = [
        'Commande $num, $table en cours. On continue, bon travail.',
        'Rappel commande $num, $table. On maintient le rythme.',
        'Cuisine, commande $num pour $table. C\'est en bonne voie.',
      ];
      message = normals[_coachPhraseIndex % normals.length];
      _coachPhraseIndex++;
    }

    enqueue(message);
  }

  // ====================================================================
  // PHRASES COACH PAR MODE
  // ====================================================================

  // Phrases coach — ton ivoirien professionnel, jeune et chaleureux
  static const _coachDoux = [
    'Merci à toute l\'équipe, vous faites un travail formidable.',
    'Très bien cuisine, on reste concentré et on se fait plaisir.',
    'Beau boulot les amis, chaque commande est une réussite.',
    'L\'équipe cuisine, vous êtes au top. On continue comme ça.',
    'Courage à tous, le service avance bien et les clients sont contents.',
  ];

  static const _coachNormal = [
    'Allez l\'équipe, on garde le rythme, c\'est notre force !',
    'Cuisine en action ! Chaque minute compte, on s\'organise bien.',
    'On reste sur les rails, chaque commande mérite le meilleur.',
    'L\'équipe cuisine, on maintient la cadence, c\'est du bon travail.',
    'Bonne énergie cuisine, on continue sur cette lancée, c\'est ça le RESTAURANT SANKADIOKRO !',
  ];

  static const _coachPression = [
    'Cuisine, on accélère, il y a du monde à table, tout le monde est en attente !',
    'Pas de relâche les amis, les clients attendent. On fonce, c\'est notre moment !',
    'C\'est le coup de feu ! Tout le monde sur le pont, on assure jusqu\'au bout !',
    'Chaque seconde compte, maximum d\'efficacité, on est les meilleurs !',
    'On ne lâche rien, les commandes arrivent. C\'est notre heure de gloire !',
  ];

  String _getCoachPhrase() {
    final List<String> pool;
    switch (settings.coachMode) {
      case CoachMode.doux:
        pool = _coachDoux;
      case CoachMode.pression:
        pool = _coachPression;
      case CoachMode.normal:
        pool = _coachNormal;
    }
    final phrase = pool[_coachPhraseIndex % pool.length];
    _coachPhraseIndex++;
    return phrase;
  }

  // ====================================================================
  // RAPPELS PÉRIODIQUES
  // ====================================================================

  void startPeriodicReminders(AppProvider provider, {int? intervalMinutes}) {
    // Priorité : paramètre > settings
    final interval = intervalMinutes ?? settings.intervalMinutes;
    settings.intervalMinutes = interval;

    // Redémarrage propre si déjà actif avec un autre intervalle
    if (_remindersActive) {
      _reminderTimer?.cancel();
      _reminderTimer = null;
      _remindersActive = false;
    }

    if (!settings.enabled) return;

    _remindersActive = true;
    _reminderTimer = Timer.periodic(Duration(minutes: interval), (_) async {
      if (settings.enabled) {
        await _announceOrderSummary(provider);
      }
    });
    if (kDebugMode) debugPrint('[TTS] Rappels actifs — intervalle: ${interval}min, mode: ${settings.coachMode.name}');
  }

  void stopPeriodicReminders() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _remindersActive = false;
    if (kDebugMode) debugPrint('[TTS] Rappels désactivés');
  }

  /// Redémarre les rappels avec les settings actuels (utile après refresh ou changement de config).
  void restartReminders(AppProvider provider) {
    stopPeriodicReminders();
    if (settings.enabled) {
      startPeriodicReminders(provider);
    }
  }

  bool get isRemindersActive => _remindersActive && settings.enabled;

  Future<void> triggerImmediateReminder(AppProvider provider) async {
    await _announceOrderSummary(provider);
  }

  // ====================================================================
  // RÉSUMÉ PÉRIODIQUE — ANNONCES PAR COMMANDE + COACH
  // ====================================================================

  Future<void> _announceOrderSummary(AppProvider provider) async {
    final activeOrders = [
      ...provider.pendingOrders,
      ...provider.preparingOrders,
      ...provider.readyOrders,
    ];

    // Ne rien dire si aucune commande active
    if (activeOrders.isEmpty) return;

    // Trier par temps écoulé (les plus urgentes en premier)
    activeOrders.sort((a, b) => b.elapsedMinutes.compareTo(a.elapsedMinutes));

    // Annonce de chaque commande avec priorité temporelle
    for (final order in activeOrders) {
      // Seulement si suffisamment de temps écoulé (≥ 5 min) pour éviter le bruit
      if (order.elapsedMinutes >= 5) {
        _announceOrderWithPriority(order);
      }
    }

    // Résumé des commandes en attente (< 5 min)
    final newPending = activeOrders.where((o) =>
      o.elapsedMinutes < 5 && o.status == OrderStatus.pending).toList();
    if (newPending.isNotEmpty) {
      final n = newPending.length;
      enqueue('${_numberToWords(n)} nouvelle${n > 1 ? "s" : ""} commande${n > 1 ? "s" : ""} en attente de préparation.');
    }

    // Commandes prêtes non servies
    final ready = provider.readyOrders;
    if (ready.isNotEmpty) {
      final tables = ready.map((o) => 'table ${o.tableNumber}').join(', ');
      enqueue('${_numberToWords(ready.length)} commande${ready.length > 1 ? "s" : ""} prête${ready.length > 1 ? "s" : ""} à servir : $tables. Veuillez servir !');
    }

    // Phrase coach en fin de cycle
    enqueue(_getCoachPhrase());
  }

  // ====================================================================
  // TEST VOIX
  // ====================================================================

  Future<void> testVoice() async {
    await stop();
    // Appliquer la config vocale avant le test
    if (kIsWeb) {
      tts_web.setTTSConfig(
        settings.voiceName,
        settings.speechRate,
        _pitchForMode(),
        settings.volume,
      );
    }
    enqueue(
      'Bonjour à toute l\'équipe ! '
      'Votre assistante vocale Sankadio est opérationnelle. '
      'Nouvelle commande en cuisine, table quatre. '
      'Allez l\'équipe, on garde le rythme !',
    );
  }

  /// Lit la dernière notification de l'historique NotificationService
  Future<void> readLastNotification(String lastMessage) async {
    await stop();
    if (kIsWeb) {
      tts_web.setTTSConfig(
        settings.voiceName,
        settings.speechRate,
        _pitchForMode(),
        settings.volume,
      );
    }
    enqueue(lastMessage);
  }

  /// Annonce générique d'un événement de notification (pour NotificationService)
  Future<void> announceNotifEvent(String label, String message) async {
    enqueue('$label. $message');
  }

  /// Test voix pour la caisse
  Future<void> testCashierVoice() async {
    await stop();
    if (kIsWeb) {
      tts_web.setTTSConfig(
        settings.voiceName,
        settings.speechRate,
        _pitchForMode(),
        settings.volume,
      );
    }
    enqueue(
      'Bonjour caisse ! '
      'L\'assistante vocale Sankadio est prête. '
      'Bonne journée et bon service à toute l\'équipe !',
    );
  }

  // ====================================================================
  // GETTERS
  // ====================================================================

  bool get isQueueEmpty => _speechQueue.isEmpty && !_isSpeaking;
  int get queueLength => _speechQueue.length + (_isSpeaking ? 1 : 0);

  /// Retourne la liste JSON des voix françaises disponibles (web uniquement).
  /// Format : [{"name":"...", "lang":"..."}]
  String getVoiceListJson() {
    if (kIsWeb) {
      return tts_web.getTTSVoiceList();
    }
    return '[]';
  }

  /// Retourne true si une voix africaine francophone est disponible (web uniquement).
  bool isAfricanVoiceAvailable() {
    if (kIsWeb) {
      return tts_web.isTTSAfricanAvailable();
    }
    return false;
  }

  // ====================================================================
  // UTILITAIRES
  // ====================================================================

  String _numberToWords(int n) {
    const words = {
      1: 'un', 2: 'deux', 3: 'trois', 4: 'quatre', 5: 'cinq',
      6: 'six', 7: 'sept', 8: 'huit', 9: 'neuf', 10: 'dix',
    };
    return words[n] ?? '$n';
  }

  void dispose() {
    stopPeriodicReminders();
    stopCashierReminders();
    _speechQueue.clear();
    if (!kIsWeb) _flutterTts?.stop();
  }

  // ====================================================================
  // ASSISTANT VOCAL CAISSE
  // ====================================================================

  Timer? _cashierReminderTimer;
  bool   _cashierRemindersActive = false;

  /// Annonce une nouvelle facture en attente de règlement
  Future<void> announceNewInvoicePending(int tableNumber, double amount) async {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final fmtAmt = fmt.format(amount);
    enqueue('Nouvelle facture en attente — table $tableNumber — '
        '$fmtAmt francs');
  }

  /// Annonce une facture en attente depuis plus de 2 minutes
  Future<void> announceInvoiceOverdue(int tableNumber, int minutes) async {
    enqueue('Attention — facture table $tableNumber en attente '
        'depuis $minutes minutes');
  }

  /// Annonce qu\'une facture vient d\'être réglée
  Future<void> announceSettled(int tableNumber) async {
    enqueue('Facture réglée — table $tableNumber');
  }

  /// Annonce le montant encaissé
  Future<void> announceAmountCollected(double amount, String paymentMethod) async {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final fmtAmt = fmt.format(amount);
    enqueue('Encaissement de $fmtAmt francs — $paymentMethod');
  }

  /// Démarre les rappels périodiques caisse (toutes les 2 min par défaut).
  /// Idempotent : ne redémarre pas si déjà actif avec le même intervalle.
  void startCashierReminders(AppProvider provider, {int intervalMinutes = 2}) {
    // Si déjà actif avec le même intervalle, ne rien faire
    if (_cashierRemindersActive) return;
    _cashierRemindersActive = true;
    _cashierReminderTimer?.cancel();
    _cashierReminderTimer = Timer.periodic(
        Duration(minutes: intervalMinutes), (_) async {
      if (_cashierRemindersActive) {
        await _announceCashierSummary(provider);
      }
    });
    if (kDebugMode) debugPrint('[TTS Caisse] Rappels démarrés — intervalle: ${intervalMinutes}min');
  }

  /// Arrête les rappels caisse
  void stopCashierReminders() {
    _cashierReminderTimer?.cancel();
    _cashierReminderTimer = null;
    _cashierRemindersActive = false;
    if (kDebugMode) debugPrint('[TTS Caisse] Rappels arrêtés');
  }

  bool get cashierRemindersActive => _cashierRemindersActive;

  Future<void> _announceCashierSummary(AppProvider provider) async {
    final pending = provider.awaitingPaymentOrders;
    if (pending.isEmpty) return;

    final fmt = NumberFormat('#,###', 'fr_FR');

    if (pending.length == 1) {
      final o = pending.first;
      final minutes = o.elapsedMinutes;
      if (minutes >= 2) {
        final orderAmt = fmt.format(o.totalAmount);
        enqueue('Rappel caisse — une facture en attente depuis $minutes minutes — '
            'table ${o.tableNumber} — $orderAmt francs');
      }
    } else {
      // Calculer le total en attente
      double total = pending.fold(0.0, (sum, o) => sum + o.totalAmount);
      final overdue = pending.where((o) => o.elapsedMinutes >= 2).length;
      final totalFmt = fmt.format(total);
      enqueue('Rappel caisse — ${pending.length} factures en attente — '
          '$totalFmt francs au total'
          '${overdue > 0 ? " — $overdue en retard" : ""}');
    }
  }
}
