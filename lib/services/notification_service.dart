import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import conditionnel : Web Audio API uniquement sur web
// ignore: uri_does_not_exist
import 'sound_web_stub.dart'
    if (dart.library.js) 'sound_web_impl.dart' as sound_web;

// ═══════════════════════════════════════════════════════════════════════════
//  NotificationService — Sonneries professionnelles pour SANKADIOKRO
//  Singleton — utilisé partout dans l'application sans dépendance Provider
//  Sons générés en temps réel via Web Audio API (0 fichier externe)
//  Persiste les préférences dans SharedPreferences
// ═══════════════════════════════════════════════════════════════════════════

// ── Types d'événements ────────────────────────────────────────────────────

enum NotifEvent {
  nouvelleCommande,
  commandeUrgente,
  commandePrete,
  paiementEnregistre,
  nouvelleReservation,
  reservationAujourdhui,
  reservationDemain,
  contratExpiration,
  salaireAPayer,
  stockFaible,
  ruptureStock,
  notificationSysteme,
  nouvelleCommandeEnLigne,   // Commande reçue depuis l'espace client
}

extension NotifEventX on NotifEvent {
  String get label {
    switch (this) {
      case NotifEvent.nouvelleCommande:      return 'Nouvelle commande en cuisine';
      case NotifEvent.commandeUrgente:       return 'Commande urgente';
      case NotifEvent.commandePrete:         return 'Commande prête à servir';
      case NotifEvent.paiementEnregistre:    return 'Paiement enregistré';
      case NotifEvent.nouvelleReservation:   return 'Nouvelle réservation';
      case NotifEvent.reservationAujourdhui: return 'Réservation prévue aujourd\'hui';
      case NotifEvent.reservationDemain:     return 'Réservation prévue demain';
      case NotifEvent.contratExpiration:     return 'Contrat proche expiration';
      case NotifEvent.salaireAPayer:         return 'Salaire à payer';
      case NotifEvent.stockFaible:           return 'Stock faible';
      case NotifEvent.ruptureStock:          return 'Produit en rupture';
      case NotifEvent.notificationSysteme:   return 'Notification système';
      case NotifEvent.nouvelleCommandeEnLigne: return 'NOUVELLE COMMANDE EN LIGNE';
    }
  }

  String get icon {
    switch (this) {
      case NotifEvent.nouvelleCommande:      return '🍽️';
      case NotifEvent.commandeUrgente:       return '🚨';
      case NotifEvent.commandePrete:         return '✅';
      case NotifEvent.paiementEnregistre:    return '💰';
      case NotifEvent.nouvelleReservation:   return '📅';
      case NotifEvent.reservationAujourdhui: return '📆';
      case NotifEvent.reservationDemain:     return '🗓️';
      case NotifEvent.contratExpiration:     return '📋';
      case NotifEvent.salaireAPayer:         return '👥';
      case NotifEvent.stockFaible:           return '⚠️';
      case NotifEvent.ruptureStock:          return '🚫';
      case NotifEvent.notificationSysteme:   return '🔔';
      case NotifEvent.nouvelleCommandeEnLigne: return '📱';
    }
  }

  // Son par défaut associé à chaque événement
  String get defaultSound {
    switch (this) {
      case NotifEvent.nouvelleCommande:      return 'restaurant';
      case NotifEvent.commandeUrgente:       return 'urgent';
      case NotifEvent.commandePrete:         return 'classic';
      case NotifEvent.paiementEnregistre:    return 'cash';
      case NotifEvent.nouvelleReservation:   return 'restaurant';
      case NotifEvent.reservationAujourdhui: return 'classic';
      case NotifEvent.reservationDemain:     return 'discrete';
      case NotifEvent.contratExpiration:     return 'discrete';
      case NotifEvent.salaireAPayer:         return 'classic';
      case NotifEvent.stockFaible:           return 'discrete';
      case NotifEvent.ruptureStock:          return 'urgent';
      case NotifEvent.notificationSysteme:   return 'classic';
      case NotifEvent.nouvelleCommandeEnLigne: return 'restaurant';
    }
  }

  // Catégorie pour filtrage dans les paramètres
  String get category {
    switch (this) {
      case NotifEvent.nouvelleCommande:
      case NotifEvent.commandeUrgente:
      case NotifEvent.commandePrete:        return 'cuisine';
      case NotifEvent.paiementEnregistre:   return 'caisse';
      case NotifEvent.stockFaible:
      case NotifEvent.ruptureStock:         return 'stock';
      case NotifEvent.salaireAPayer:
      case NotifEvent.contratExpiration:    return 'personnel';
      case NotifEvent.nouvelleReservation:
      case NotifEvent.reservationAujourdhui:
      case NotifEvent.reservationDemain:    return 'reservations';
      case NotifEvent.nouvelleCommandeEnLigne: return 'cuisine';
      default:                              return 'systeme';
    }
  }

  bool get isUrgent => this == NotifEvent.commandeUrgente || this == NotifEvent.ruptureStock
      || this == NotifEvent.nouvelleCommandeEnLigne;
}

// ── Entrée dans l'historique ──────────────────────────────────────────────

class AppNotification {
  final String id;
  final NotifEvent event;
  final String message;
  final DateTime dateTime;
  bool isRead;

  AppNotification({
    required this.id,
    required this.event,
    required this.message,
    required this.dateTime,
    this.isRead = false,
  });
}

// ── Sonneries disponibles ─────────────────────────────────────────────────

class SoundOption {
  final String id;
  final String label;
  final String description;
  const SoundOption(this.id, this.label, this.description);
}

const List<SoundOption> kSoundOptions = [
  SoundOption('classic',    'Sonnerie classique',    'Carillon ding-dong professionnel'),
  SoundOption('restaurant', 'Sonnerie restaurant',   'Carillon de bienvenue 7 notes'),
  SoundOption('cash',       'Sonnerie caisse',       'Bip de validation paiement'),
  SoundOption('urgent',     'Sonnerie urgente',      'Alarme insistante répétée'),
  SoundOption('discrete',   'Sonnerie discrète',     'Léger bip doux'),
];

// ═══════════════════════════════════════════════════════════════════════════
//  SERVICE PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  // ── Historique des notifications ──────────────────────────────────────
  final List<AppNotification> _history = [];
  List<AppNotification> get history => List.unmodifiable(_history);
  int get unreadCount => _history.where((n) => !n.isRead).length;

  // ── Paramètres ────────────────────────────────────────────────────────
  bool _soundEnabled        = true;
  bool _repeatImportant     = true;
  bool _notifCuisine        = true;
  bool _notifCaisse         = true;
  bool _notifStock          = true;
  bool _notifPersonnel      = true;
  bool _notifReservations   = true;
  String _selectedSound     = 'classic';
  double _volume            = 0.85;
  bool _audioUnlockAsked    = false;
  bool _urgentActive        = false;
  String? _urgentEventId;

  bool   get soundEnabled      => _soundEnabled;
  bool   get repeatImportant   => _repeatImportant;
  bool   get notifCuisine      => _notifCuisine;
  bool   get notifCaisse       => _notifCaisse;
  bool   get notifStock        => _notifStock;
  bool   get notifPersonnel    => _notifPersonnel;
  bool   get notifReservations => _notifReservations;
  String get selectedSound     => _selectedSound;
  double get volume            => _volume;
  bool   get audioUnlockAsked  => _audioUnlockAsked;
  bool   get urgentActive      => _urgentActive;

  // ── Initialisation ────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled      = prefs.getBool('notif_sound')        ?? true;
      _repeatImportant   = prefs.getBool('notif_repeat')       ?? true;
      _notifCuisine      = prefs.getBool('notif_cuisine')      ?? true;
      _notifCaisse       = prefs.getBool('notif_caisse')       ?? true;
      _notifStock        = prefs.getBool('notif_stock')        ?? true;
      _notifPersonnel    = prefs.getBool('notif_personnel')    ?? true;
      _notifReservations = prefs.getBool('notif_reservations') ?? true;
      _selectedSound     = prefs.getString('notif_sound_type') ?? 'classic';
      _volume            = prefs.getDouble('notif_volume')     ?? 0.85;
      _audioUnlockAsked  = prefs.getBool('notif_audio_asked')  ?? false;
    } catch (e) {
      debugPrint('[NotificationService] _loadPrefs: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_sound',        _soundEnabled);
      await prefs.setBool('notif_repeat',       _repeatImportant);
      await prefs.setBool('notif_cuisine',      _notifCuisine);
      await prefs.setBool('notif_caisse',       _notifCaisse);
      await prefs.setBool('notif_stock',        _notifStock);
      await prefs.setBool('notif_personnel',    _notifPersonnel);
      await prefs.setBool('notif_reservations', _notifReservations);
      await prefs.setString('notif_sound_type', _selectedSound);
      await prefs.setDouble('notif_volume',     _volume);
      await prefs.setBool('notif_audio_asked',  _audioUnlockAsked);
    } catch (e) {
      debugPrint('[NotificationService] _savePrefs: $e');
    }
  }

  // ── Setters (persistés) ───────────────────────────────────────────────

  Future<void> setSoundEnabled(bool v)      async { _soundEnabled = v;      await _savePrefs(); notifyListeners(); }
  Future<void> setRepeatImportant(bool v)   async { _repeatImportant = v;   await _savePrefs(); notifyListeners(); }
  Future<void> setNotifCuisine(bool v)      async { _notifCuisine = v;      await _savePrefs(); notifyListeners(); }
  Future<void> setNotifCaisse(bool v)       async { _notifCaisse = v;       await _savePrefs(); notifyListeners(); }
  Future<void> setNotifStock(bool v)        async { _notifStock = v;        await _savePrefs(); notifyListeners(); }
  Future<void> setNotifPersonnel(bool v)    async { _notifPersonnel = v;    await _savePrefs(); notifyListeners(); }
  Future<void> setNotifReservations(bool v) async { _notifReservations = v; await _savePrefs(); notifyListeners(); }
  Future<void> setSelectedSound(String v)   async { _selectedSound = v;     await _savePrefs(); notifyListeners(); }
  Future<void> setVolume(double v)          async { _volume = v;            await _savePrefs(); notifyListeners(); }

  Future<void> markAudioUnlockAsked() async {
    _audioUnlockAsked = true;
    await _savePrefs();
  }

  // ── Déverrouillage audio (doit être appelé après interaction utilisateur) ──

  void unlockAudio() {
    if (kIsWeb) {
      sound_web.webUnlockAudio();
    }
    _audioUnlockAsked = true;
    _savePrefs();
  }

  bool get isAudioUnlocked => kIsWeb ? sound_web.webAudioUnlocked() : true;

  // ── Jouer un son de test ───────────────────────────────────────────────

  void testSound([String? soundType]) {
    final type = soundType ?? _selectedSound;
    _playRawSound(type, volume: _volume);
  }

  // ── Déclencheur principal ─────────────────────────────────────────────

  void trigger(NotifEvent event, {required String message}) {
    // Ajouter à l'historique
    final notif = AppNotification(
      id: '${event.name}_${DateTime.now().millisecondsSinceEpoch}',
      event: event,
      message: message,
      dateTime: DateTime.now(),
    );
    _history.insert(0, notif);
    // Limiter l'historique à 200 entrées
    if (_history.length > 200) _history.removeRange(200, _history.length);
    notifyListeners();

    // Son si activé
    if (!_soundEnabled) return;
    if (!_isCategoryEnabled(event.category)) return;

    if (event.isUrgent && _repeatImportant) {
      _startUrgentLoop(event, notif.id);
    } else {
      final soundType = event.defaultSound;
      _playRawSound(_selectedSound == 'classic' ? soundType : _selectedSound,
          volume: _volume);
    }
  }

  // ── Mode urgence ──────────────────────────────────────────────────────

  void _startUrgentLoop(NotifEvent event, String notifId) {
    _urgentActive = true;
    _urgentEventId = notifId;
    notifyListeners();
    if (kIsWeb) {
      sound_web.webPlayUrgentLoop('urgent', volume: _volume);
    }
  }

  /// Arrête la sonnerie urgente — à appeler quand l'utilisateur consulte l'alerte
  void stopUrgentLoop() {
    if (!_urgentActive) return;
    _urgentActive = false;
    _urgentEventId = null;
    if (kIsWeb) sound_web.webStopUrgentLoop();
    notifyListeners();
  }

  /// Stoppe la boucle urgente ET marque la notification lue
  void acknowledgeUrgent() {
    if (_urgentEventId != null) {
      markRead(_urgentEventId!);
    }
    stopUrgentLoop();
  }

  // ── Gestion de l'historique ───────────────────────────────────────────

  void markRead(String id) {
    final idx = _history.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _history[idx].isRead = true;
      notifyListeners();
    }
  }

  void markAllRead() {
    for (final n in _history) n.isRead = true;
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  List<AppNotification> get unreadNotifications =>
      _history.where((n) => !n.isRead).toList();

  // ── Internes ──────────────────────────────────────────────────────────

  bool _isCategoryEnabled(String cat) {
    switch (cat) {
      case 'cuisine':      return _notifCuisine;
      case 'caisse':       return _notifCaisse;
      case 'stock':        return _notifStock;
      case 'personnel':    return _notifPersonnel;
      case 'reservations': return _notifReservations;
      default:             return true;
    }
  }

  void _playRawSound(String soundType, {required double volume}) {
    if (kIsWeb) {
      sound_web.webPlaySound(soundType, volume: volume);
    }
    // Android/iOS : sera étendu avec audioplayers si nécessaire
  }
}
