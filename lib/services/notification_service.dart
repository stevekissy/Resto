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
  DateTime? readAt;    // horodatage de lecture (persisté Firestore)
  DateTime? playedAt;  // horodatage du son joué (persisté Firestore — jamais rejoué)

  AppNotification({
    required this.id,
    required this.event,
    required this.message,
    required this.dateTime,
    this.isRead = false,
    this.readAt,
    this.playedAt,
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

  // ── Catégories de notifications (13 toggles) ─────────────────────────
  bool   _notifOnline         = true;
  bool   _notifUrgent         = true;
  bool   _notifCuisine        = true;
  bool   _notifCaisse         = true;
  bool   _notifStock          = true;
  bool   _notifRupture        = true;   // Rupture stock (séparé de stock faible)
  bool   _notifPersonnel      = true;
  bool   _notifContrats       = true;   // Contrats expiration (séparé des salaires)
  bool   _notifReservations   = true;
  bool   _notifFournisseurs   = true;
  bool   _notifSysteme        = true;

  // ── Sonneries par type ────────────────────────────────────────────────
  final Map<String, String> _perTypeSound = {};

  // ── État audio ────────────────────────────────────────────────────────
  bool   _audioUnlockAsked    = false;
  bool   _urgentActive        = false;
  String? _urgentEventId;
  Timer?  _urgentMaxTimer;

  // ── Listener Firestore notifications temps réel ────────────────────────
  StreamSubscription<QuerySnapshot>? _firestoreListener;
  final Set<String> _knownFirestoreIds = {};
  bool _firestoreListenerActive = false;

  // ── Listener Firestore paramètres temps réel (sync multi-appareils) ──────
  StreamSubscription<DocumentSnapshot>? _settingsListener;
  bool _settingsListenerActive = false;

  // ── Horodatage login admin ────────────────────────────────────────────
  // Enregistré au moment du init() (= connexion admin).
  // Un son n'est joué QUE si notification.createdAt > _adminLoginAt.
  // Les notifications antérieures au login sont chargées silencieusement.
  DateTime? _adminLoginAt;

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
  bool get notifRupture       => _notifRupture;
  bool get notifPersonnel     => _notifPersonnel;
  bool get notifContrats      => _notifContrats;
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
    // Enregistrer l'heure de connexion AVANT de démarrer le listener.
    // Toute notification dont createdAt ≤ _adminLoginAt sera silencieuse.
    _adminLoginAt = DateTime.now();
    _knownFirestoreIds.clear(); // réinitialiser à chaque login

    // ── Chargement prioritaire : Firestore > SharedPreferences ────────────
    // 1. D'abord SharedPreferences (rapide, local)
    await _loadPrefs();
    if (kDebugMode) debugPrint('[SETTINGS_LOADED] SharedPreferences chargé');

    // 2. Ensuite Firestore (prioritaire — écrase SharedPreferences si données existent)
    await loadFromFirestore();

    // 3. Charger l'historique complet (lues + non lues) — sans son
    await _loadHistoryFromFirestore();

    // 4. Démarrer le stream temps réel pour la sync multi-appareils
    _startSettingsStream();

    // 5. Listener temps réel uniquement sur read==false → déclenche les sons
    _startFirestoreListener();
  }

  /// Expose l'heure de connexion (pour debug / tests)
  DateTime? get adminLoginAt => _adminLoginAt;

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
        // Éviter les doublons
        if (_knownFirestoreIds.contains(docId)) continue;
        _knownFirestoreIds.add(docId);

        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        // ── Timestamp de la notification ──────────────────────────────
        // Firestore peut stocker 'createdAt' (nouveau) ou 'created_at' (ancien)
        final notifCreatedAt = _parseFirestoreDate(
          data['createdAt'] ?? data['created_at'],
        );

        // ── Mapper le type Firestore vers NotifEvent ──────────────────
        final eventType = data['type'] as String? ?? 'systeme';
        final message   = data['message'] as String? ?? '';
        final event     = _firestoreTypeToEvent(eventType);

        // ── Lire l'état lu/non lu depuis Firestore ────────────────────
        // 'read' peut valoir true (déjà lu avant ce login) ou false/absent
        // ── Lire read + playedAt depuis Firestore ────────────────────
        // Ces deux champs sont PERSISTANTS entre sessions.
        // read==true    → jamais de son (déjà lue)
        // playedAt!=null → son déjà joué une fois → jamais rejoué
        final alreadyRead   = data['read'] as bool? ?? false;
        final playedAtRaw   = data['playedAt'];
        final alreadyPlayed = playedAtRaw != null;
        final readAtRaw     = data['readAt'];

        // ── Créer la notification locale (toujours, pour l'historique) ─
        final notif = AppNotification(
          id:       docId,
          event:    event,
          message:  message,
          dateTime: notifCreatedAt,
          isRead:   alreadyRead,
          readAt:   readAtRaw  is Timestamp ? readAtRaw.toDate()  : null,
          playedAt: playedAtRaw is Timestamp ? playedAtRaw.toDate() : null,
        );
        _history.insert(0, notif);
        if (_history.length > 200) _history.removeRange(200, _history.length);

        // ── Son : UNIQUEMENT si read==false ET playedAt==null ─────────
        // Règle absolue — indépendante du login / refresh / reconnexion.
        // Une notification lue OU dont le son a déjà été joué → silence total.
        if (!alreadyRead && !alreadyPlayed) {
          _playForEvent(event);
          // Marquer playedAt dans Firestore immédiatement (non-bloquant)
          // → protège contre le rejeu lors d'une reconnexion
          unawaited(_markPlayedInFirestore(docId));
          notif.playedAt = DateTime.now();
        } else {
          if (kDebugMode) {
            debugPrint(
              '[NotifSvc] 🔕 Silencieux : $docId'
              ' | read=$alreadyRead'
              ' | alreadyPlayed=$alreadyPlayed',
            );
          }
        }

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
    // Arrêter aussi le stream des paramètres
    _stopSettingsStream();
  }

  void restartFirestoreListener() {
    stopFirestoreListener();
    _firestoreListenerActive = false;
    // Réinitialiser le timestamp de login et les IDs connus
    // pour que les nouvelles notifications soient correctement filtrées
    _adminLoginAt = DateTime.now();
    _knownFirestoreIds.clear();
    _startFirestoreListener();
  }

  // ── Stream temps réel des paramètres (sync multi-appareils) ──────────────

  void _startSettingsStream() {
    if (_settingsListenerActive) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirebaseAuth.instance.authStateChanges().listen((u) {
        if (u != null && !_settingsListenerActive) _startSettingsStream();
      });
      return;
    }
    _settingsListenerActive = true;
    try {
      _settingsListener = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .snapshots()
          .listen((snap) {
        if (!snap.exists) return;
        _applyFirestoreSettings(snap.data()!);
        if (kDebugMode) debugPrint('[SETTINGS_APPLIED] Stream Firestore → paramètres appliqués');
      }, onError: (e) {
        _settingsListenerActive = false;
        if (kDebugMode) debugPrint('[NotificationService] settingsStream erreur: $e');
      });
    } catch (e) {
      _settingsListenerActive = false;
      if (kDebugMode) debugPrint('[NotificationService] _startSettingsStream: $e');
    }
  }

  void _stopSettingsStream() {
    _settingsListener?.cancel();
    _settingsListener = null;
    _settingsListenerActive = false;
  }

  /// Applique les données Firestore dans les champs locaux + notifie
  void _applyFirestoreSettings(Map<String, dynamic> d) {
    _soundEnabled         = d['sound_enabled']       as bool?   ?? _soundEnabled;
    _volume               = (d['volume']             as num?)?.toDouble() ?? _volume;
    _volumeRingtone       = (d['volume_ringtone']    as num?)?.toDouble() ?? _volumeRingtone;
    _volumeVoice          = (d['volume_voice']       as num?)?.toDouble() ?? _volumeVoice;
    _repeatImportant      = d['repeat_important']    as bool?   ?? _repeatImportant;
    _repeatIntervalSec    = (d['repeat_interval_sec'] as num?)?.toInt() ?? _repeatIntervalSec;
    _maxRepeatDurationSec = (d['max_repeat_duration'] as num?)?.toInt() ?? _maxRepeatDurationSec;
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
    _notifRupture         = d['notif_rupture']       as bool?   ?? _notifRupture;
    _notifPersonnel       = d['notif_personnel']     as bool?   ?? _notifPersonnel;
    _notifContrats        = d['notif_contrats']      as bool?   ?? _notifContrats;
    _notifReservations    = d['notif_reservations']  as bool?   ?? _notifReservations;
    _notifFournisseurs    = d['notif_fournisseurs']  as bool?   ?? _notifFournisseurs;
    _notifSysteme         = d['notif_systeme']       as bool?   ?? _notifSysteme;
    final pts = d['per_type_sounds'] as Map<String, dynamic>?;
    if (pts != null) {
      for (final e in pts.entries) {
        _perTypeSound[e.key] = e.value as String;
      }
    }
    notifyListeners();
  }

  // ── Chargement / Sauvegarde SharedPreferences ─────────────────────────

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Vérifier si des données existent déjà
      final hasData = prefs.containsKey('notif_sound');
      if (!hasData) {
        if (kDebugMode) debugPrint('[SETTINGS_LOADED] SharedPreferences vide — valeurs par défaut');
        return;
      }

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
      _notifRupture        = prefs.getBool('notif_rupture')         ?? true;
      _notifPersonnel      = prefs.getBool('notif_personnel')       ?? true;
      _notifContrats       = prefs.getBool('notif_contrats')        ?? true;
      _notifReservations   = prefs.getBool('notif_reservations')    ?? true;
      _notifFournisseurs   = prefs.getBool('notif_fournisseurs')    ?? true;
      _notifSysteme        = prefs.getBool('notif_systeme')         ?? true;
      _audioUnlockAsked    = prefs.getBool('notif_audio_asked')     ?? false;

      // Sonneries par type
      for (final e in NotifEvent.values) {
        final saved = prefs.getString('notif_sound_${e.name}');
        if (saved != null) _perTypeSound[e.name] = saved;
      }
      if (kDebugMode) debugPrint('[SETTINGS_LOADED] SharedPreferences OK (${_perTypeSound.length} sonneries personnalisées)');
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
      await prefs.setBool('notif_rupture',          _notifRupture);
      await prefs.setBool('notif_personnel',        _notifPersonnel);
      await prefs.setBool('notif_contrats',         _notifContrats);
      await prefs.setBool('notif_reservations',     _notifReservations);
      await prefs.setBool('notif_fournisseurs',     _notifFournisseurs);
      await prefs.setBool('notif_systeme',          _notifSysteme);
      await prefs.setBool('notif_audio_asked',      _audioUnlockAsked);

      for (final e in _perTypeSound.entries) {
        await prefs.setString('notif_sound_${e.key}', e.value);
      }
      if (kDebugMode) debugPrint('[SETTINGS_SAVED] SharedPreferences sauvegardé');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] _savePrefs: $e');
    }
  }

  // ── Persistance Firestore par utilisateur ─────────────────────────────

  Future<void> saveToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('[SETTINGS_SAVED] Firestore ignoré — utilisateur non connecté');
        return;
      }

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
        'notif_rupture':          _notifRupture,
        'notif_personnel':        _notifPersonnel,
        'notif_contrats':         _notifContrats,
        'notif_reservations':     _notifReservations,
        'notif_fournisseurs':     _notifFournisseurs,
        'notif_systeme':          _notifSysteme,
        'per_type_sounds':        _perTypeSound,
        'updated_at':             FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('[SETTINGS_SAVED] Firestore sauvegardé — users/${user.uid}/settings/notifications');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] saveToFirestore ERREUR: $e');
    }
  }

  /// Enregistre un changement dans notification_settings_history
  Future<void> _saveSettingsHistory({
    required String field,
    required dynamic oldValue,
    required dynamic newValue,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final docId = FirebaseFirestore.instance.collection('notification_settings_history').doc().id;
      await FirebaseFirestore.instance.collection('notification_settings_history').doc(docId).set({
        'id':         docId,
        'userId':     user.uid,
        'userName':   user.displayName ?? user.email ?? 'Admin',
        'field':      field,
        'oldValue':   oldValue.toString(),
        'newValue':   newValue.toString(),
        'createdAt':  DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] _saveSettingsHistory: $e');
    }
  }

  // ── Chargement initial de l'historique (lues ET non lues) ───────────────
  // Appelé une fois au démarrage. NE joue AUCUN son.
  // Le listener temps réel (read==false) gère les sons des nouvelles notifs.
  Future<void> _loadHistoryFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final List<AppNotification> loaded = [];
      for (final doc in snap.docs) {
        final docId = doc.id;
        if (_knownFirestoreIds.contains(docId)) continue; // sera ajouté par le listener RT
        _knownFirestoreIds.add(docId);

        final data = doc.data();
        final alreadyRead   = data['read']     as bool? ?? false;
        final playedAtRaw   = data['playedAt'];
        final readAtRaw     = data['readAt'];

        final notifDate = _parseFirestoreDate(data['createdAt'] ?? data['created_at']);
        final eventType = data['type'] as String? ?? 'systeme';
        final message   = data['message'] as String? ?? '';
        final event     = _firestoreTypeToEvent(eventType);

        loaded.add(AppNotification(
          id:       docId,
          event:    event,
          message:  message,
          dateTime: notifDate,
          isRead:   alreadyRead,
          readAt:   readAtRaw  is Timestamp ? readAtRaw.toDate()  : null,
          playedAt: playedAtRaw is Timestamp ? playedAtRaw.toDate() : null,
        ));
        // ⚠️ PAS de son ici — lecture initiale silencieuse
      }

      // Insérer dans l'historique trié par date décroissante
      _history.addAll(loaded);
      _history.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      if (_history.length > 200) _history.removeRange(200, _history.length);

      if (loaded.isNotEmpty) notifyListeners();
      if (kDebugMode) {
        debugPrint('[NotifSvc] 📋 Historique chargé: ${loaded.length} notifs'
            ' (${loaded.where((n) => !n.isRead).length} non lues)');
      }
    } catch (e) {
      // Peut échouer si l'index createdAt n'existe pas — on ignore silencieusement
      if (kDebugMode) debugPrint('[NotifSvc] _loadHistoryFromFirestore ERREUR: $e');
    }
  }

  Future<void> loadFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('[SETTINGS_LOADED] Firestore ignoré — utilisateur non connecté');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (!doc.exists) {
        if (kDebugMode) debugPrint('[SETTINGS_LOADED] Firestore — aucun paramètre sauvegardé, valeurs actuelles conservées');
        return;
      }
      final d = doc.data()!;

      _applyFirestoreSettings(d);

      // Synchroniser aussi dans SharedPreferences
      await _savePrefs();
      if (kDebugMode) debugPrint('[SETTINGS_LOADED] Firestore → paramètres chargés et appliqués');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] loadFromFirestore ERREUR: $e');
    }
  }

  // ── Setters sons ─────────────────────────────────────────────────────
  // Chaque setter : 1) met à jour le champ local
  //                 2) sauvegarde SharedPreferences
  //                 3) sauvegarde Firestore (async, non-bloquant)
  //                 4) enregistre l'historique
  //                 5) notifie les listeners

  Future<void> setSoundEnabled(bool v) async {
    final old = _soundEnabled;
    _soundEnabled = v;
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'sound_enabled', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    final old = _volume;
    _volume = v;
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'volume', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setVolumeRingtone(double v) async {
    final old = _volumeRingtone;
    _volumeRingtone = v;
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'volume_ringtone', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setVolumeVoice(double v) async {
    final old = _volumeVoice;
    _volumeVoice = v;
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, v);
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'volume_voice', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setRepeatImportant(bool v) async {
    final old = _repeatImportant;
    _repeatImportant = v;
    if (!v) stopUrgentLoop();
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'repeat_important', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setRepeatIntervalSec(int v) async {
    final old = _repeatIntervalSec;
    _repeatIntervalSec = v;
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'repeat_interval_sec', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setMaxRepeatDurationSec(int v) async {
    final old = _maxRepeatDurationSec;
    _maxRepeatDurationSec = v;
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'max_repeat_duration', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setSelectedSound(String v) async {
    final old = _selectedSound;
    _selectedSound = v;
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'selected_sound', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setPerTypeSound(NotifEvent event, String sound) async {
    final old = _perTypeSound[event.name] ?? event.defaultSound;
    _perTypeSound[event.name] = sound;
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'sound_${event.name}', oldValue: old, newValue: sound));
    notifyListeners();
  }

  // ── Setters assistant vocal ───────────────────────────────────────────

  Future<void> setVoiceEnabled(bool v) async {
    final old = _voiceEnabled;
    _voiceEnabled = v;
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, _volumeVoice);
    await _savePrefs();
    unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'voice_enabled', oldValue: old, newValue: v));
    notifyListeners();
  }

  Future<void> setVoiceName(String v) async {
    _voiceName = v;
    if (kIsWeb) tts_web.setTTSConfig(v, _speechRate, _speechPitch, _volumeVoice);
    await _savePrefs();
    unawaited(saveToFirestore());
    notifyListeners();
  }

  Future<void> setSpeechRate(double v) async {
    _speechRate = v;
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, v, _speechPitch, _volumeVoice);
    await _savePrefs();
    unawaited(saveToFirestore());
    notifyListeners();
  }

  Future<void> setSpeechPitch(double v) async {
    _speechPitch = v;
    if (kIsWeb) tts_web.setTTSConfig(_voiceName, _speechRate, v, _volumeVoice);
    await _savePrefs();
    unawaited(saveToFirestore());
    notifyListeners();
  }

  Future<void> setSpeechLang(String v) async {
    _voiceLang = v;
    await _savePrefs();
    unawaited(saveToFirestore());
    notifyListeners();
  }

  // ── Setters catégories ────────────────────────────────────────────────

  Future<void> setNotifOnline(bool v) async {
    final old = _notifOnline; _notifOnline = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_online', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifUrgent(bool v) async {
    final old = _notifUrgent; _notifUrgent = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_urgent', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifCuisine(bool v) async {
    final old = _notifCuisine; _notifCuisine = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_cuisine', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifCaisse(bool v) async {
    final old = _notifCaisse; _notifCaisse = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_caisse', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifStock(bool v) async {
    final old = _notifStock; _notifStock = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_stock', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifRupture(bool v) async {
    final old = _notifRupture; _notifRupture = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_rupture', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifPersonnel(bool v) async {
    final old = _notifPersonnel; _notifPersonnel = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_personnel', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifContrats(bool v) async {
    final old = _notifContrats; _notifContrats = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_contrats', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifReservations(bool v) async {
    final old = _notifReservations; _notifReservations = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_reservations', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifFournisseurs(bool v) async {
    final old = _notifFournisseurs; _notifFournisseurs = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_fournisseurs', oldValue: old, newValue: v));
    notifyListeners();
  }
  Future<void> setNotifSysteme(bool v) async {
    final old = _notifSysteme; _notifSysteme = v;
    await _savePrefs(); unawaited(saveToFirestore());
    unawaited(_saveSettingsHistory(field: 'notif_systeme', oldValue: old, newValue: v));
    notifyListeners();
  }

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
      'Bonjour ! L\'assistante vocale du RESTAURANT SANKADIOKRO est opérationnelle. '
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
    if (!_isEventEnabled(event)) return;

    if (event.isUrgent && _repeatImportant) {
      _startUrgentLoop(event, event.name);
    } else {
      final soundType = getPerTypeSound(event);
      _playRawSound(soundType, volume: _volumeRingtone);
    }

    // TTS si activé (voiceEnabled + soundEnabled + volumeVoice > 0)
    if (_voiceEnabled && _soundEnabled && _volumeVoice > 0 && kIsWeb) {
      tts_web.setTTSConfig(_voiceName, _speechRate, _speechPitch, _volumeVoice);
      tts_web.africanSpeak(
        'RESTAURANT SANKADIOKRO. ${event.label}.',
        _speechRate, _speechPitch, _volumeVoice,
      );
    }
  }

  // ── Mode urgence ──────────────────────────────────────────────────────

  void _startUrgentLoop(NotifEvent event, String notifId) {
    _urgentActive   = true;
    _urgentEventId  = notifId;
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
    _urgentMaxTimer?.cancel();
    _urgentMaxTimer  = null;
    if (kIsWeb) sound_web.webStopUrgentLoop();
    notifyListeners();
  }

  /// Arrête tout : sons urgents + TTS + timers (toujours, quelle que soit la config)
  void stopAllAlerts() {
    stopUrgentLoop();
    if (kIsWeb) {
      tts_web.africanStop();
      sound_web.webStopUrgentLoop();
    }
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
      // Persister dans Firestore (non-bloquant)
      unawaited(_markReadInFirestore(id));
    }
  }

  void markAllRead() {
    for (final n in _history) {
      n.isRead = true;
    }
    stopUrgentLoop();
    notifyListeners();
    // Persister TOUS dans Firestore (non-bloquant)
    unawaited(_markAllReadInFirestore());
  }

  /// Marque un document Firestore comme lu (read: true + readAt: serverTimestamp)
  Future<void> _markReadInFirestore(String docId) async {
    try {
      if (_isLocalId(docId)) return; // IDs locaux non persistés
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({
        'read':   true,
        'readAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) debugPrint('[NotifSvc] ✅ Marqué lu Firestore: $docId');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotifSvc] _markReadInFirestore erreur: $e');
    }
  }

  /// Marque playedAt dans Firestore → empêche le rejeu lors d'une reconnexion
  Future<void> _markPlayedInFirestore(String docId) async {
    try {
      if (_isLocalId(docId)) return;
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'playedAt': FieldValue.serverTimestamp()});
      if (kDebugMode) debugPrint('[NotifSvc] 🔔 playedAt enregistré: $docId');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotifSvc] _markPlayedInFirestore erreur: $e');
    }
  }

  /// Retourne true si l'id est un ID local synthétique (pas un vrai doc Firestore)
  /// IDs locaux : "commandeUrgente_1234567890" (contiennent '_' et sont courts)
  bool _isLocalId(String id) => id.contains('_') && id.length < 28;

  /// Marque tous les documents comme lus dans Firestore (WriteBatch)
  Future<void> _markAllReadInFirestore() async {
    try {
      // On marque TOUS les IDs Firestore réels de l'historique
      final fsIds = _history
          .map((n) => n.id)
          .where((id) => !_isLocalId(id))
          .toList();
      if (fsIds.isEmpty) return;

      // WriteBatch par tranches de 450 (limite Firestore : 500)
      const batchSize = 450;
      for (var i = 0; i < fsIds.length; i += batchSize) {
        final chunk = fsIds.skip(i).take(batchSize).toList();
        final batch = FirebaseFirestore.instance.batch();
        final now   = FieldValue.serverTimestamp();
        for (final id in chunk) {
          final ref = FirebaseFirestore.instance
              .collection('notifications')
              .doc(id);
          batch.update(ref, {'read': true, 'readAt': now});
        }
        await batch.commit();
      }
      if (kDebugMode) debugPrint('[NotifSvc] ✅ Tout marqué lu Firestore (${fsIds.length} docs)');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotifSvc] _markAllReadInFirestore erreur: $e');
    }
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
      case 'cuisine':      return _notifCuisine;
      // Stock faible vs rupture : event-level check dans _playForEvent
      case 'stock':        return _notifStock || _notifRupture;
      case 'personnel':    return _notifPersonnel || _notifContrats;
      case 'reservations': return _notifReservations;
      case 'caisse':       return _notifCaisse;
      case 'fournisseurs': return _notifFournisseurs;
      case 'systeme':      return _notifSysteme;
      default:             return true;
    }
  }

  /// Vérifie si l'événement spécifique est activé (granularité fine)
  bool _isEventEnabled(NotifEvent event) {
    switch (event) {
      case NotifEvent.commandeUrgente:
        return _notifUrgent && _notifCuisine;
      case NotifEvent.ruptureStock:
        return _notifRupture;
      case NotifEvent.stockFaible:
        return _notifStock;
      case NotifEvent.contratExpiration:
        return _notifContrats;
      case NotifEvent.salaireAPayer:
        return _notifPersonnel;
      default:
        return _isCategoryEnabled(event.category);
    }
  }

  void _playRawSound(String soundType, {required double volume}) {
    // Guard : sons désactivés ou volume nul = silence total
    if (!_soundEnabled) return;
    if (volume <= 0) return;
    if (kIsWeb) {
      sound_web.webPlaySound(soundType, volume: volume);
    }
  }
}
