import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import conditionnel : Web Audio API uniquement sur web
// ignore: uri_does_not_exist
import 'sound_web_stub.dart'
    if (dart.library.js) 'sound_web_impl.dart' as sound_web;

// Import conditionnel TTS
// ignore: uri_does_not_exist
import 'tts_web_stub.dart'
    if (dart.library.js) 'tts_web_impl.dart' as tts_web;

// ═══════════════════════════════════════════════════════════════════════════
//  NotificationService v2 — Sonneries + Assistant vocal + Firestore RT
//  Singleton — Sons + TTS + Persistance locale + Firestore par utilisateur
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
  nouvelleCommandeEnLigne,
}

extension NotifEventX on NotifEvent {
  String get label {
    switch (this) {
      case NotifEvent.nouvelleCommande:        return 'Nouvelle commande en cuisine';
      case NotifEvent.commandeUrgente:         return 'Commande urgente';
      case NotifEvent.commandePrete:           return 'Commande prête à servir';
      case NotifEvent.paiementEnregistre:      return 'Paiement enregistré';
      case NotifEvent.nouvelleReservation:     return 'Nouvelle réservation';
      case NotifEvent.reservationAujourdhui:   return 'Réservation prévue aujourd\'hui';
      case NotifEvent.reservationDemain:       return 'Réservation prévue demain';
      case NotifEvent.contratExpiration:       return 'Contrat proche expiration';
      case NotifEvent.salaireAPayer:           return 'Salaire à payer';
      case NotifEvent.stockFaible:             return 'Stock faible';
      case NotifEvent.ruptureStock:            return 'Produit en rupture';
      case NotifEvent.notificationSysteme:     return 'Notification système';
      case NotifEvent.nouvelleCommandeEnLigne: return 'NOUVELLE COMMANDE EN LIGNE';
    }
  }

  String get icon {
    switch (this) {
      case NotifEvent.nouvelleCommande:        return '🍽️';
      case NotifEvent.commandeUrgente:         return '🚨';
      case NotifEvent.commandePrete:           return '✅';
      case NotifEvent.paiementEnregistre:      return '💰';
      case NotifEvent.nouvelleReservation:     return '📅';
      case NotifEvent.reservationAujourdhui:   return '📆';
      case NotifEvent.reservationDemain:       return '🗓️';
      case NotifEvent.contratExpiration:       return '📋';
      case NotifEvent.salaireAPayer:           return '👥';
      case NotifEvent.stockFaible:             return '⚠️';
      case NotifEvent.ruptureStock:            return '🚫';
      case NotifEvent.notificationSysteme:     return '🔔';
      case NotifEvent.nouvelleCommandeEnLigne: return '📱';
    }
  }

  /// Son par défaut associé à chaque événement
  String get defaultSound {
    switch (this) {
      case NotifEvent.nouvelleCommande:        return 'restaurant';
      case NotifEvent.commandeUrgente:         return 'urgent';
      case NotifEvent.commandePrete:           return 'classic';
      case NotifEvent.paiementEnregistre:      return 'cash';
      case NotifEvent.nouvelleReservation:     return 'restaurant';
      case NotifEvent.reservationAujourdhui:   return 'classic';
      case NotifEvent.reservationDemain:       return 'discrete';
      case NotifEvent.contratExpiration:       return 'discrete';
      case NotifEvent.salaireAPayer:           return 'classic';
      case NotifEvent.stockFaible:             return 'discrete';
      case NotifEvent.ruptureStock:            return 'urgent';
      case NotifEvent.notificationSysteme:     return 'classic';
      case NotifEvent.nouvelleCommandeEnLigne: return 'restaurant';
    }
  }

  /// Catégorie pour filtrage
  String get category {
    switch (this) {
      case NotifEvent.nouvelleCommande:
      case NotifEvent.commandeUrgente:
      case NotifEvent.commandePrete:           return 'cuisine';
      case NotifEvent.paiementEnregistre:      return 'caisse';
      case NotifEvent.stockFaible:
      case NotifEvent.ruptureStock:            return 'stock';
      case NotifEvent.salaireAPayer:
      case NotifEvent.contratExpiration:       return 'personnel';
      case NotifEvent.nouvelleReservation:
      case NotifEvent.reservationAujourdhui:
      case NotifEvent.reservationDemain:       return 'reservations';
      case NotifEvent.nouvelleCommandeEnLigne: return 'online';
      default:                                 return 'systeme';
    }
  }

  bool get isUrgent =>
      this == NotifEvent.commandeUrgente ||
      this == NotifEvent.ruptureStock ||
      this == NotifEvent.nouvelleCommandeEnLigne;
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
  SoundOption('classic',    'Sonnerie classique',  'Carillon ding-dong professionnel'),
  SoundOption('restaurant', 'Sonnerie restaurant', 'Carillon de bienvenue 7 notes'),
  SoundOption('cash',       'Sonnerie caisse',     'Bip de validation paiement'),
  SoundOption('urgent',     'Sonnerie urgente',    'Alarme insistante répétée'),
  SoundOption('discrete',   'Sonnerie discrète',   'Léger bip doux'),
];

/// Intervalles de répétition disponibles (en secondes)
const List<int> kRepeatIntervals = [10, 30, 60, 120, 300];

String intervalLabel(int seconds) {
  if (seconds < 60)  return '${seconds}s';
  if (seconds == 60) return '1 min';
  if (seconds < 60)  return '${seconds}s';
  final m = seconds ~/ 60;
  return '$m min';
}

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

  // ── Paramètres Sons ───────────────────────────────────────────────────
  bool   _soundEnabled        = true;
  double _volume              = 0.85;   // Volume général
  double _volumeRingtone      = 0.85;   // Volume sonnerie
  double _volumeVoice         = 0.80;   // Volume assistant vocal
  bool   _repeatImportant     = true;
  int    _repeatIntervalSec   = 30;     // 10 | 30 | 60 | 120 | 300
  int    _maxRepeatDurationSec = 300;   // 5 minutes par défaut
  String _selectedSound       = 'classic';

  // ── Paramètres Assistant Vocal ────────────────────────────────────────
  bool   _voiceEnabled        = false;
  String _voiceName           = '';     // Nom voix sélectionnée ('' = auto)
  double _speechRate          = 0.88;
  double _speechPitch         = 1.2;   // Ton / pitch
  String _voiceLang           = 'fr-FR';

  // ── Catégories de notifications (11 toggles) ─────────────────────────
  bool   _notifOnline         = true;
  bool   _notifUrgent         = true;
  bool   _notifCuisine        = true;
  bool   _notifCaisse         = true;
  bool   _notifStock          = true;
  bool   _notifPersonnel      = true;
  bool   _notifReservations   = true;
  bool   _notifFournisseurs   = true;
  bool   _notifSysteme        = true;

  // ── Sonneries par type ────────────────────────────────────────────────
  final Map<String, String> _perTypeSound = {};

  // ── État audio ────────────────────────────────────────────────────────
  bool   _audioUnlockAsked    = false;
  bool   _urgentActive        = false;
  String? _urgentEventId;
  DateTime? _urgentStartTime;
  Timer?  _urgentMaxTimer;

  // ── Listener Firestore temps réel ─────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _firestoreListener;
  final Set<String> _knownFirestoreIds = {};
  bool _firestoreListenerActive = false;

  // ── Getters sons ──────────────────────────────────────────────────────
  bool   get soundEnabled         => _soundEnabled;
  double get volume               => _volume;
  double get volumeRingtone       => _volumeRingtone;
  double get volumeVoice          => _volumeVoice;
  bool   get repeatImportant      => _repeatImportant;
  int    get repeatIntervalSec    => _repeatIntervalSec;
  int    get maxRepeatDurationSec => _maxRepeatDurationSec;
  String get selectedSound        => _selectedSound;

  // ── Getters assistant vocal ───────────────────────────────────────────
  bool   get voiceEnabled         => _voiceEnabled;
  String get voiceName            => _voiceName;
  double get speechRate           => _speechRate;
  double get speechPitch          => _speechPitch;
  String get voiceLang            => _voiceLang;

  // ── Getters catégories ────────────────────────────────────────────────
  bool get notifOnline        => _notifOnline;
  bool get notifUrgent        => _notifUrgent;
  bool get notifCuisine       => _notifCuisine;
  bool get notifCaisse        => _notifCaisse;
  bool get notifStock         => _notifStock;
  bool get notifPersonnel     => _notifPersonnel;
  bool get notifReservations  => _notifReservations;
  bool get notifFournisseurs  => _notifFournisseurs;
  bool get notifSysteme       => _notifSysteme;

  // ── Getters état ──────────────────────────────────────────────────────
  bool get audioUnlockAsked   => _audioUnlockAsked;
  bool get urgentActive       => _urgentActive;

  String getPerTypeSound(NotifEvent event) =>
      _perTypeSound[event.name] ?? event.defaultSound;

  // ── Initialisation ────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadPrefs();
    _startFirestoreListener();
  }

  // ── Listener Firestore temps réel ─────────────────────────────────────

  void _startFirestoreListener() {
    if (_firestoreListenerActive) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Réessayer quand l'utilisateur se connecte
      FirebaseAuth.instance.authStateChanges().listen((u) {
        if (u != null && !_firestoreListenerActive) {
          _startFirestoreListener();
        }
      });
      return;
    }
    _firestoreListenerActive = true;
    try {
      _firestoreListener = FirebaseFirestore.instance
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen(_onFirestoreSnapshot, onError: (e) {
        if (kDebugMode) debugPrint('[NotificationService] Listener erreur: $e');
        _firestoreListenerActive = false;
      });
    } catch (e) {
      _firestoreListenerActive = false;
      if (kDebugMode) debugPrint('[NotificationService] _startFirestoreListener: $e');
    }
  }

  void _onFirestoreSnapshot(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final docId = change.doc.id;
        // Éviter les doublons lors de l'initialisation du listener
        if (_knownFirestoreIds.contains(docId)) continue;
        _knownFirestoreIds.add(docId);

        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        // Mapper le type Firestore vers NotifEvent
        final eventType = data['type'] as String? ?? 'systeme';
        final message   = data['message'] as String? ?? '';
        final event     = _firestoreTypeToEvent(eventType);

        // Créer la notification locale
        final notif = AppNotification(
          id:       docId,
          event:    event,
          message:  message,
          dateTime: _parseFirestoreDate(data['created_at']),
          isRead:   false,
        );
        _history.insert(0, notif);
        if (_history.length > 200) _history.removeRange(200, _history.length);

        // Déclencher son + vocal
        _playForEvent(event);
        notifyListeners();
      }
    }
  }

  NotifEvent _firestoreTypeToEvent(String type) {
    switch (type) {
      case 'new_online_order':
      case 'online_order':           return NotifEvent.nouvelleCommandeEnLigne;
      case 'urgent':
      case 'order_urgent':           return NotifEvent.commandeUrgente;
      case 'order_ready':
      case 'order_preparing':
      case 'order_confirmed':        return NotifEvent.commandePrete;
      case 'payment':
      case 'order_settled':          return NotifEvent.paiementEnregistre;
      case 'reservation':            return NotifEvent.nouvelleReservation;
      case 'contract':               return NotifEvent.contratExpiration;
      case 'salary':                 return NotifEvent.salaireAPayer;
      case 'stock_low':              return NotifEvent.stockFaible;
      case 'stock_out':              return NotifEvent.ruptureStock;
      case 'system':                 return NotifEvent.notificationSysteme;
      default:                       return NotifEvent.notificationSysteme;
    }
  }

  DateTime _parseFirestoreDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    return DateTime.now();
  }

  void stopFirestoreListener() {
    _firestoreListener?.cancel();
    _firestoreListener = null;
    _firestoreListenerActive = false;
  }

  void restartFirestoreListener() {
    stopFirestoreListener();
    _firestoreListenerActive = false;
    _startFirestoreListener();
  }

  // ── Chargement / Sauvegarde SharedPreferences ─────────────────────────

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Sons
      _soundEnabled        = prefs.getBool('notif_sound')          ?? true;
      _volume              = prefs.getDouble('notif_volume')        ?? 0.85;
      _volumeRingtone      = prefs.getDouble('notif_vol_ring')      ?? 0.85;
      _volumeVoice         = prefs.getDouble('notif_vol_voice')     ?? 0.80;
      _repeatImportant     = prefs.getBool('notif_repeat')          ?? true;
      _repeatIntervalSec   = prefs.getInt('notif_repeat_interval')  ?? 30;
      _maxRepeatDurationSec= prefs.getInt('notif_max_repeat')       ?? 300;
      _selectedSound       = prefs.getString('notif_sound_type')    ?? 'classic';

      // Assistant vocal
      _voiceEnabled        = prefs.getBool('notif_voice_enabled')   ?? false;
      _voiceName           = prefs.getString('notif_voice_name')    ?? '';
      _speechRate          = prefs.getDouble('notif_speech_rate')   ?? 0.88;
      _speechPitch         = prefs.getDouble('notif_speech_pitch')  ?? 1.2;
      _voiceLang           = prefs.getString('notif_voice_lang')    ?? 'fr-FR';

      // Catégories
      _notifOnline         = prefs.getBool('notif_online')          ?? true;
      _notifUrgent         = prefs.getBool('notif_urgent')          ?? true;
      _notifCuisine        = prefs.getBool('notif_cuisine')         ?? true;
      _notifCaisse         = prefs.getBool('notif_caisse')          ?? true;
      _notifStock          = prefs.getBool('notif_stock')           ?? true;
      _notifPersonnel      = prefs.getBool('notif_personnel')       ?? true;
      _notifReservations   = prefs.getBool('notif_reservations')    ?? true;
      _notifFournisseurs   = prefs.getBool('notif_fournisseurs')    ?? true;
      _notifSysteme        = prefs.getBool('notif_systeme')         ?? true;
      _audioUnlockAsked    = prefs.getBool('notif_audio_asked')     ?? false;

      // Sonneries par type
      for (final e in NotifEvent.values) {
        final saved = prefs.getString('notif_sound_${e.name}');
        if (saved != null) _perTypeSound[e.name] = saved;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] _loadPrefs: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('notif_sound',           _soundEnabled);
      await prefs.setDouble('notif_volume',         _volume);
      await prefs.setDouble('notif_vol_ring',       _volumeRingtone);
      await prefs.setDouble('notif_vol_voice',      _volumeVoice);
      await prefs.setBool('notif_repeat',           _repeatImportant);
      await prefs.setInt('notif_repeat_interval',   _repeatIntervalSec);
      await prefs.setInt('notif_max_repeat',        _maxRepeatDurationSec);
      await prefs.setString('notif_sound_type',     _selectedSound);

      await prefs.setBool('notif_voice_enabled',    _voiceEnabled);
      await prefs.setString('notif_voice_name',     _voiceName);
      await prefs.setDouble('notif_speech_rate',    _speechRate);
      await prefs.setDouble('notif_speech_pitch',   _speechPitch);
      await prefs.setString('notif_voice_lang',     _voiceLang);

      await prefs.setBool('notif_online',           _notifOnline);
      await prefs.setBool('notif_urgent',           _notifUrgent);
      await prefs.setBool('notif_cuisine',          _notifCuisine);
      await prefs.setBool('notif_caisse',           _notifCaisse);
      await prefs.setBool('notif_stock',            _notifStock);
      await prefs.setBool('notif_personnel',        _notifPersonnel);
      await prefs.setBool('notif_reservations',     _notifReservations);
      await prefs.setBool('notif_fournisseurs',     _notifFournisseurs);
      await prefs.setBool('notif_systeme',          _notifSysteme);
      await prefs.setBool('notif_audio_asked',      _audioUnlockAsked);

      for (final e in _perTypeSound.entries) {
        await prefs.setString('notif_sound_${e.key}', e.value);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] _savePrefs: $e');
    }
  }

  // ── Persistance Firestore par utilisateur ─────────────────────────────

  Future<void> saveToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set({
        'sound_enabled':          _soundEnabled,
        'volume':                 _volume,
        'volume_ringtone':        _volumeRingtone,
        'volume_voice':           _volumeVoice,
        'repeat_important':       _repeatImportant,
        'repeat_interval_sec':    _repeatIntervalSec,
        'max_repeat_duration':    _maxRepeatDurationSec,
        'selected_sound':         _selectedSound,
        'voice_enabled':          _voiceEnabled,
        'voice_name':             _voiceName,
        'speech_rate':            _speechRate,
        'speech_pitch':           _speechPitch,
        'voice_lang':             _voiceLang,
        'notif_online':           _notifOnline,
        'notif_urgent':           _notifUrgent,
        'notif_cuisine':          _notifCuisine,
        'notif_caisse':           _notifCaisse,
        'notif_stock':            _notifStock,
        'notif_personnel':        _notifPersonnel,
        'notif_reservations':     _notifReservations,
        'notif_fournisseurs':     _notifFournisseurs,
        'notif_systeme':          _notifSysteme,
        'per_type_sounds':        _perTypeSound,
        'updated_at':             FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] saveToFirestore: $e');
    }
  }

  Future<void> loadFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (!doc.exists) return;
      final d = doc.data()!;

      _soundEnabled         = d['sound_enabled']       as bool?   ?? _soundEnabled;
      _volume               = (d['volume']             as num?)?.toDouble() ?? _volume;
      _volumeRingtone       = (d['volume_ringtone']    as num?)?.toDouble() ?? _volumeRingtone;
      _volumeVoice          = (d['volume_voice']       as num?)?.toDouble() ?? _volumeVoice;
      _repeatImportant      = d['repeat_important']    as bool?   ?? _repeatImportant;
      _repeatIntervalSec    = d['repeat_interval_sec'] as int?    ?? _repeatIntervalSec;
      _maxRepeatDurationSec = d['max_repeat_duration'] as int?    ?? _maxRepeatDurationSec;
      _selectedSound        = d['selected_sound']      as String? ?? _selectedSound;
      _voiceEnabled         = d['voice_enabled']       as bool?   ?? _voiceEnabled;
      _voiceName            = d['voice_name']          as String? ?? _voiceName;
      _speechRate           = (d['speech_rate']        as num?)?.toDouble() ?? _speechRate;
      _speechPitch          = (d['speech_pitch']       as num?)?.toDouble() ?? _speechPitch;
      _voiceLang            = d['voice_lang']          as String? ?? _voiceLang;
      _notifOnline          = d['notif_online']        as bool?   ?? _notifOnline;
      _notifUrgent          = d['notif_urgent']        as bool?   ?? _notifUrgent;
      _notifCuisine         = d['notif_cuisine']       as bool?   ?? _notifCuisine;
      _notifCaisse          = d['notif_caisse']        as bool?   ?? _notifCaisse;
      _notifStock           = d['notif_stock']         as bool?   ?? _notifStock;
      _notifPersonnel       = d['notif_personnel']     as bool?   ?? _notifPersonnel;
      _notifReservations    = d['notif_reservations']  as bool?   ?? _notifReservations;
      _notifFournisseurs    = d['notif_fournisseurs']  as bool?   ?? _notifFournisseurs;
      _notifSysteme         = d['notif_systeme']       as bool?   ?? _notifSysteme;

      final pts = d['per_type_sounds'] as Map<String, dynamic>?;
      if (pts != null) {
        for (final e in pts.entries) {
          _perTypeSound[e.key] = e.value as String;
        }
      }

      // Synchroniser aussi dans SharedPreferences
      await _savePrefs();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] loadFromFirestore: $e');
    }
  }

  // ── Setters sons ──────────────────────────────────────────────────────

  Future<void> setSoundEnabled(bool v) async {
    _soundEnabled = v;
    await _savePrefs(); notifyListeners();
  }

  Future<void> setVolume(double v) async {
    _volume = v;
    await _savePrefs(); notifyListeners();
  }

  Future<void> setVolumeRingtone(double v) async {
    _volumeRingtone = v;
    await _savePrefs(); notifyListeners();
  }

  Future<void> setVolumeVoice(double v) async {
    _volumeVoice = v;
    // Appliquer immédiatement au TTS
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, v);
    await _savePrefs(); notifyListeners();
  }

  Future<void> setRepeatImportant(bool v) async {
    _repeatImportant = v;
    if (!v) stopUrgentLoop();
    await _savePrefs(); notifyListeners();
  }

  Future<void> setRepeatIntervalSec(int v) async {
    _repeatIntervalSec = v;
    await _savePrefs(); notifyListeners();
  }

  Future<void> setMaxRepeatDurationSec(int v) async {
    _maxRepeatDurationSec = v;
    await _savePrefs(); notifyListeners();
  }

  Future<void> setSelectedSound(String v) async {
    _selectedSound = v;
    await _savePrefs(); notifyListeners();
  }

  Future<void> setPerTypeSound(NotifEvent event, String sound) async {
    _perTypeSound[event.name] = sound;
    await _savePrefs(); notifyListeners();
  }

  // ── Setters assistant vocal ───────────────────────────────────────────

  Future<void> setVoiceEnabled(bool v) async {
    _voiceEnabled = v;
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, _volumeVoice);
    await _savePrefs(); notifyListeners();
  }

  Future<void> setVoiceName(String v) async {
    _voiceName = v;
    if (kIsWeb) tts_web.setTTSConfig(v, _speechRate, _speechPitch, _volumeVoice);
    await _savePrefs(); notifyListeners();
  }

  Future<void> setSpeechRate(double v) async {
    _speechRate = v;
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, v, _speechPitch, _volumeVoice);
    await _savePrefs(); notifyListeners();
  }

  Future<void> setSpeechPitch(double v) async {
    _speechPitch = v;
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, _speechRate, v, _volumeVoice);
    await _savePrefs(); notifyListeners();
  }

  Future<void> setSpeechLang(String v) async {
    _voiceLang = v;
    await _savePrefs(); notifyListeners();
  }

  // ── Setters catégories ────────────────────────────────────────────────

  Future<void> setNotifOnline(bool v)       async { _notifOnline = v;       await _savePrefs(); notifyListeners(); }
  Future<void> setNotifUrgent(bool v)       async { _notifUrgent = v;       await _savePrefs(); notifyListeners(); }
  Future<void> setNotifCuisine(bool v)      async { _notifCuisine = v;      await _savePrefs(); notifyListeners(); }
  Future<void> setNotifCaisse(bool v)       async { _notifCaisse = v;       await _savePrefs(); notifyListeners(); }
  Future<void> setNotifStock(bool v)        async { _notifStock = v;        await _savePrefs(); notifyListeners(); }
  Future<void> setNotifPersonnel(bool v)    async { _notifPersonnel = v;    await _savePrefs(); notifyListeners(); }
  Future<void> setNotifReservations(bool v) async { _notifReservations = v; await _savePrefs(); notifyListeners(); }
  Future<void> setNotifFournisseurs(bool v) async { _notifFournisseurs = v; await _savePrefs(); notifyListeners(); }
  Future<void> setNotifSysteme(bool v)      async { _notifSysteme = v;      await _savePrefs(); notifyListeners(); }

  Future<void> markAudioUnlockAsked() async {
    _audioUnlockAsked = true;
    await _savePrefs();
  }

  // ── Déverrouillage audio ──────────────────────────────────────────────

  void unlockAudio() {
    if (kIsWeb) sound_web.webUnlockAudio();
    _audioUnlockAsked = true;
    _savePrefs();
    notifyListeners();
  }

  bool get isAudioUnlocked => kIsWeb ? sound_web.webAudioUnlocked() : true;

  // ── Test sonore ───────────────────────────────────────────────────────

  void testSound([String? soundType]) {
    final type = soundType ?? _selectedSound;
    _playRawSound(type, volume: _volumeRingtone);
  }

  // ── Test vocal ────────────────────────────────────────────────────────

  void testVoice() {
    if (!kIsWeb) return;
    tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, _volumeVoice);
    tts_web.africanSpeak(
      'Bonjour ! L\'assistante vocale Sankadio est opérationnelle. '
      'Nouvelle commande en cuisine, table quatre. '
      'Allez l\'équipe, on garde le rythme !',
      _speechRate, _speechPitch, _volumeVoice,
    );
  }

  /// Lit vocalement la dernière notification de l'historique
  void readLastNotification() {
    if (!_voiceEnabled || !kIsWeb) return;
    if (_history.isEmpty) return;
    final last = _history.first;
    tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, _volumeVoice);
    tts_web.africanSpeak(
      '${last.event.label}. ${last.message}',
      _speechRate, _speechPitch, _volumeVoice,
    );
  }

  // ── Déclencheur principal ─────────────────────────────────────────────

  void trigger(NotifEvent event, {required String message}) {
    final notif = AppNotification(
      id:       '${event.name}_${DateTime.now().millisecondsSinceEpoch}',
      event:    event,
      message:  message,
      dateTime: DateTime.now(),
    );
    _history.insert(0, notif);
    if (_history.length > 200) _history.removeRange(200, _history.length);
    notifyListeners();

    _playForEvent(event);
  }

  void _playForEvent(NotifEvent event) {
    if (!_soundEnabled) return;
    if (!_isCategoryEnabled(event.category)) return;

    if (event.isUrgent && _repeatImportant) {
      _startUrgentLoop(event, event.name);
    } else {
      final soundType = getPerTypeSound(event);
      _playRawSound(soundType, volume: _volumeRingtone);
    }

    // TTS si activé
    if (_voiceEnabled && kIsWeb) {
      tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, _volumeVoice);
      tts_web.africanSpeak(
        '${event.label}.',
        _speechRate, _speechPitch, _volumeVoice,
      );
    }
  }

  // ── Mode urgence ──────────────────────────────────────────────────────

  void _startUrgentLoop(NotifEvent event, String notifId) {
    _urgentActive   = true;
    _urgentEventId  = notifId;
    _urgentStartTime = DateTime.now();
    notifyListeners();

    if (kIsWeb) {
      sound_web.webPlayUrgentLoop(
        getPerTypeSound(event),
        volume:     _volumeRingtone,
        intervalMs: _repeatIntervalSec * 1000,
      );
    }

    // Timer arrêt automatique après durée max
    _urgentMaxTimer?.cancel();
    _urgentMaxTimer = Timer(Duration(seconds: _maxRepeatDurationSec), () {
      if (_urgentActive) stopUrgentLoop();
    });
  }

  void stopUrgentLoop() {
    if (!_urgentActive) return;
    _urgentActive    = false;
    _urgentEventId   = null;
    _urgentStartTime = null;
    _urgentMaxTimer?.cancel();
    _urgentMaxTimer  = null;
    if (kIsWeb) sound_web.webStopUrgentLoop();
    notifyListeners();
  }

  /// Arrête tout : sons urgents + TTS + timers
  void stopAllAlerts() {
    stopUrgentLoop();
    if (kIsWeb) tts_web.africanStop();
    notifyListeners();
  }

  /// Stoppe la boucle urgente ET marque la notification lue
  void acknowledgeUrgent() {
    if (_urgentEventId != null) markRead(_urgentEventId!);
    stopUrgentLoop();
  }

  // ── Gestion de l'historique ───────────────────────────────────────────

  void markRead(String id) {
    final idx = _history.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _history[idx].isRead = true;
      // Si c'était l'alerte urgente, stopper la boucle
      if (id == _urgentEventId) stopUrgentLoop();
      notifyListeners();
    }
  }

  void markAllRead() {
    for (final n in _history) n.isRead = true;
    stopUrgentLoop();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  List<AppNotification> get unreadNotifications =>
      _history.where((n) => !n.isRead).toList();

  // ── Retourne la liste des voix FR disponibles (Web) ───────────────────

  String getVoiceListJson() {
    if (kIsWeb) return tts_web.getTTSVoiceList();
    return '[]';
  }

  // ── Internes ──────────────────────────────────────────────────────────

  bool _isCategoryEnabled(String cat) {
    switch (cat) {
      case 'online':       return _notifOnline;
      case 'cuisine':      return _notifCuisine && _notifUrgent;
      case 'caisse':       return _notifCaisse;
      case 'stock':        return _notifStock;
      case 'personnel':    return _notifPersonnel;
      case 'reservations': return _notifReservations;
      case 'fournisseurs': return _notifFournisseurs;
      case 'systeme':      return _notifSysteme;
      default:             return true;
    }
  }

  void _playRawSound(String soundType, {required double volume}) {
    if (kIsWeb) {
      sound_web.webPlaySound(soundType, volume: volume);
    }
  }
}
