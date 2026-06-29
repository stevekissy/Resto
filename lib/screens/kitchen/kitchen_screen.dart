import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/tts_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  // ── Filtre cuisine : statuts valides (jamais 'waiting', jamais vide) ──
  static const _activeKitchenStatuses = {'pending', 'preparing', 'ready'};

  late Timer _timer;
  final TtsService _tts = TtsService();
  final Set<String> _announcedOrders = {};

  @override
  void initState() {
    super.initState();
    _tts.init();
    // NOTE : le Timer parent est supprimé — chaque _KitchenOrderCard
    // a son propre Timer.periodic pour son chronomètre.
    // Un Timer ici forçait setState() chaque seconde sur le parent,
    // ce qui reconstruisait toutes les cartes et pouvait interrompre les taps.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Tick lent (30s) uniquement pour forcer la vérification TTS
      if (mounted && _tts.isRemindersActive) setState(() {});
    });

    // Charger l'état persisté PUIS configurer les callbacks
    _tts.loadPersistedState().then((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();

      // Annonce immédiate de chaque nouvelle commande
      provider.onNewOrder = (order) {
        if (!_tts.settings.enabled) return;
        if (!_announcedOrders.contains(order.id)) {
          _announcedOrders.add(order.id);
          _tts.announceNewOrder(order);
        }
      };

      provider.onOrderDelayed = (order) {
        if (_tts.settings.enabled) _tts.announceDelay(order);
      };

      // Reprendre les rappels si l'assistant était ON avant le refresh
      if (_tts.settings.enabled) {
        _tts.startPeriodicReminders(provider);
      }
      if (mounted) setState(() {}); // Rafraîchir le bouton ON/OFF
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    // NE PAS arrêter les rappels si l'utilisateur a choisi ON —
    // l'état est persisté et sera relancé à la prochaine ouverture
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // ── LOG DEBUG : afficher toutes les commandes reçues dans le stream ──
    final allOrders = provider.orders;
    if (kDebugMode) {
      debugPrint('[CUISINE v3] Stream reçu : ${allOrders.length} commandes total');
      for (final o in allOrders) {
        final ks = o.kitchenStatus ?? 'null';
        final inKitchen = o.sentToKitchen && _activeKitchenStatuses.contains(ks);
        debugPrint(
          '[CUISINE v3] ${inKitchen ? "✅" : "❌"} id=${o.id.substring(0, 12)}… '
          'sentToKitchen=${o.sentToKitchen} ks=$ks '
          'isOnline=${o.isOnlineOrder} hasKitchenItems=${o.hasKitchenItems} '
          'items=${o.items.length} status=${o.status.name}',
        );
      }
    }

    // ── FIX v5 : filtre UNIFIÉ RENFORCÉ — commandes POS + online ──────────
    //
    // Après sendToKitchen() (set merge:true), les commandes online ont :
    //   status = 0 (OrderStatus.pending)
    //   orderStatus = 'pending'
    //   kitchenStatus = 'pending'
    //   sentToKitchen = true
    //   hasKitchenItems = true (persisté Firestore)
    //   items[].itemType = 'menu' | 'cambuse'
    //
    // RÈGLE (A) : sentToKitchen==true + kitchenStatus in {pending,preparing,ready}
    //   → Commandes online envoyées en cuisine (et POS si sentToKitchen activé)
    //   → NE PAS filtrer sur hasKitchenItems ici : la commande a été
    //     explicitement envoyée en cuisine par un admin — elle doit apparaître.
    //
    // RÈGLE (B) : sentToKitchen==false + status in {pending,preparing} + hasKitchenItems
    //   → Commandes POS classiques (jamais passées par le workflow admin online)

    final onlineInKitchen = allOrders.where((o) {
      // (A) Explicitement envoyée en cuisine — confiance totale dans kitchenStatus
      if (!o.sentToKitchen) return false;
      final ks = o.kitchenStatus ?? '';
      // Vérifier que kitchenStatus est un statut actif cuisine
      if (!_activeKitchenStatuses.contains(ks)) return false;
      // Exclure seulement si on est certain que c'est cambuse-only ET qu'il y a des items parsés
      // (items.isEmpty peut arriver si le parsing a échoué — dans ce cas on inclut quand même)
      if (o.items.isNotEmpty && o.isCambuseOnly) return false;
      return true;
    }).toList();

    // ── (B) Commandes POS classiques — sentToKitchen==false ───────────────
    // RÈGLE STRICTE : les commandes online NE PASSENT JAMAIS par cette règle.
    // Une commande online ne doit apparaître en cuisine QUE via la RÈGLE (A),
    // c'est-à-dire après approbation admin explicite (sentToKitchen=true).
    // Sans ce guard, une commande online pending avec hasKitchenItems=true
    // arriverait en cuisine AVANT toute validation admin.
    final posActive = allOrders.where((o) {
      if (o.sentToKitchen) return false;       // déjà dans onlineInKitchen (RÈGLE A)
      if (o.isOnlineOrder)  return false;       // FIX : online → RÈGLE (A) uniquement
      if (o.status == OrderStatus.cancelled) return false;
      if (!o.hasKitchenItems) return false;    // exclure cambuse-only POS
      return o.status == OrderStatus.pending || o.status == OrderStatus.preparing;
    }).toList();

    final activeOrders = [...onlineInKitchen, ...posActive]
      ..sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });

    final readyOrders = provider.readyOrders;

    // ── Bandeau debug ─────────────────────────────────────────────────────
    final onlineTotal  = allOrders.where((o) => o.isOnlineOrder).length;
    final onlineSent   = allOrders.where((o) => o.sentToKitchen).length;
    final onlineKitchenIds = onlineInKitchen.map((o) => '${o.id.substring(0,8)}(${o.kitchenStatus})').join(', ');
    // Diagnostic : sentToKitchen mais kitchenStatus hors range
    final sentButFiltered = allOrders.where((o) {
      if (!o.sentToKitchen) return false;
      final ks = o.kitchenStatus ?? '';
      return !_activeKitchenStatuses.contains(ks);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          _KitchenHeader(
            provider: provider,
            tts: _tts,
            onSettingsChanged: () => setState(() {}),
          ),
          // ── Bandeau debug stream (visible pour diagnostic) ────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color(0xFF0D1B2A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔎 Stream : ${allOrders.length} total · $onlineTotal online · $onlineSent sentToKitchen · ${onlineInKitchen.length} actives cuisine  [v28/06-16:00]',
                  style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 10, fontFamily: 'monospace'),
                ),
                if (onlineInKitchen.isNotEmpty)
                  Text(
                    '✅ En cuisine : $onlineKitchenIds…',
                    style: const TextStyle(color: Color(0xFF81C784), fontSize: 10, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (onlineInKitchen.isEmpty && onlineSent > 0)
                  Text(
                    '⚠ $onlineSent sentToKitchen mais 0 actif — kitchenStatus: ${allOrders.where((o) => o.sentToKitchen).map((o) => o.kitchenStatus ?? "null").join(",")}',
                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 10, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (sentButFiltered.isNotEmpty)
                  Text(
                    '🚫 Filtrés (ks hors range) : ${sentButFiltered.map((o) => "${o.id.substring(0,8)}…=${o.kitchenStatus}").join(", ")}',
                    style: const TextStyle(color: Color(0xFFEF5350), fontSize: 10, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            child: activeOrders.isEmpty && readyOrders.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant,
                  title: 'Aucune commande active',
                  subtitle: 'En attente de nouvelles commandes...',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeOrders.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.fire_truck, color: AppTheme.preparing, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Commandes Actives (${activeOrders.length})',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Remplacement GridView → LayoutBuilder + Wrap
                        // Raison : GridView impose childAspectRatio qui clippe les boutons
                        // quand la carte dépasse la hauteur prévue.
                        // Wrap + largeur fixe = cartes à hauteur naturelle, boutons toujours visibles.
                        LayoutBuilder(builder: (ctx, constraints) {
                          final cardW = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            // ValueKey(order.id) garantit que Flutter conserve
                            // le State de chaque carte même si la liste change.
                            // Sans Key, Flutter peut recréer les cartes au rebuild
                            // parent et interrompre un tap en cours.
                            children: activeOrders.map((o) => SizedBox(
                              key: ValueKey('card-${o.id}'),
                              width: cardW,
                              child: _KitchenOrderCard(
                                key: ValueKey('kitchen-card-${o.id}'),
                                order: o,
                                provider: provider,
                                tts: _tts,
                              ),
                            )).toList(),
                          );
                        }),
                      ],
                      if (readyOrders.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.ready, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Prêtes à servir (${readyOrders.length})',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...readyOrders.map((o) => _ReadyOrderCard(order: o, provider: provider)),
                      ],
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// HEADER CUISINE
// ======================================================================

class _KitchenHeader extends StatefulWidget {
  final AppProvider provider;
  final TtsService tts;
  final VoidCallback onSettingsChanged;

  const _KitchenHeader({
    required this.provider,
    required this.tts,
    required this.onSettingsChanged,
  });

  @override
  State<_KitchenHeader> createState() => _KitchenHeaderState();
}

class _KitchenHeaderState extends State<_KitchenHeader> {

  void _openVoiceSettings() {
    showDialog(
      context: context,
      builder: (ctx) => _KitchenVoiceSettingsDialog(
        tts: widget.tts,
        provider: widget.provider,
        onChanged: () {
          setState(() {});
          widget.onSettingsChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersOn = widget.tts.isRemindersActive;
    final settings = widget.tts.settings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A5A))),
      ),
      child: Column(
        children: [
          // Ligne 1 : Titre + stats + boutons
          Row(
            children: [
              const Icon(Icons.restaurant, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ÉCRAN CUISINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'SANKADIOKRO',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _StatBubble(
                    value: widget.provider.pendingOrders.length.toString(),
                    label: 'Attente',
                    color: AppTheme.pending,
                  ),
                  const SizedBox(width: 8),
                  _StatBubble(
                    value: widget.provider.preparingOrders.length.toString(),
                    label: 'Prépa',
                    color: AppTheme.preparing,
                  ),
                  const SizedBox(width: 8),
                  _StatBubble(
                    value: widget.provider.readyOrders.length.toString(),
                    label: 'Prêt',
                    color: AppTheme.ready,
                  ),
                  const SizedBox(width: 8),
                  // Bouton rappel immédiat
                  GestureDetector(
                    onTap: () => widget.tts.triggerImmediateReminder(widget.provider),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                      ),
                      child: const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Bouton settings vocal
                  GestureDetector(
                    onTap: _openVoiceSettings,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.settings_voice, color: AppTheme.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Ligne 2 : Statut rappels + toggle + mode coach badge
          Row(
            children: [
              Icon(
                Icons.timer,
                color: remindersOn ? AppTheme.success : AppTheme.textSecondary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                remindersOn
                  ? 'Rappels actifs (${settings.intervalMinutes} min • ${_coachLabel(settings.coachMode)})'
                  : 'Rappels vocaux inactifs',
                style: TextStyle(
                  color: remindersOn ? AppTheme.success : AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  if (remindersOn) {
                    widget.tts.stopPeriodicReminders();
                    widget.tts.stop();
                    await widget.tts.saveKitchenEnabled(false);
                  } else {
                    await widget.tts.saveKitchenEnabled(true);
                    widget.tts.startPeriodicReminders(widget.provider);
                  }
                  setState(() {});
                  widget.onSettingsChanged();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: remindersOn
                        ? AppTheme.error.withValues(alpha: 0.15)
                        : AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: remindersOn
                          ? AppTheme.error.withValues(alpha: 0.4)
                          : AppTheme.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    remindersOn ? 'Désactiver' : 'Activer',
                    style: TextStyle(
                      color: remindersOn ? AppTheme.error : AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _coachLabel(CoachMode mode) {
    switch (mode) {
      case CoachMode.doux: return 'doux';
      case CoachMode.normal: return 'normal';
      case CoachMode.pression: return 'pression';
    }
  }
}

// ======================================================================
// DIALOG SETTINGS VOCAL CUISINE
// ======================================================================

class _KitchenVoiceSettingsDialog extends StatefulWidget {
  final TtsService tts;
  final AppProvider provider;
  final VoidCallback onChanged;

  const _KitchenVoiceSettingsDialog({
    required this.tts,
    required this.provider,
    required this.onChanged,
  });

  @override
  State<_KitchenVoiceSettingsDialog> createState() =>
      _KitchenVoiceSettingsDialogState();
}

class _KitchenVoiceSettingsDialogState
    extends State<_KitchenVoiceSettingsDialog> {
  late bool _enabled;
  late double _volume;
  late int _intervalMinutes;
  late CoachMode _coachMode;
  late double _speechRate;
  late String _voiceName;

  // Voix disponibles (chargées depuis JS au démarrage du dialog)
  List<Map<String, String>> _availableVoices = [];
  bool _africanAvailable = false;
  bool _voicesLoaded = false;

  @override
  void initState() {
    super.initState();
    final s = widget.tts.settings;
    _enabled         = s.enabled;
    _volume          = s.volume;
    _intervalMinutes = s.intervalMinutes;
    _coachMode       = s.coachMode;
    _speechRate      = s.speechRate;
    _voiceName       = s.voiceName;

    // Charger la liste des voix après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVoices();
    });
  }

  void _loadVoices() {
    try {
      // Appel au service TTS via sa méthode publique
      final raw = widget.tts.getVoiceListJson();
      final jsonList = jsonDecode(raw) as List<dynamic>;
      final voices = jsonList.map((e) {
        final m = e as Map<String, dynamic>;
        return <String, String>{
          'name': m['name']?.toString() ?? '',
          'lang': m['lang']?.toString() ?? '',
        };
      }).where((v) => v['name']!.isNotEmpty).toList();

      setState(() {
        _availableVoices = voices;
        _africanAvailable = widget.tts.isAfricanVoiceAvailable();
        _voicesLoaded = true;
      });
    } catch (e) {
      setState(() {
        _voicesLoaded = true;
      });
    }
  }

  void _apply() {
    widget.tts.settings.volume          = _volume;
    widget.tts.settings.intervalMinutes = _intervalMinutes;
    widget.tts.settings.coachMode       = _coachMode;
    // Sauvegarder et appliquer le nouvel état enabled
    widget.tts.saveKitchenEnabled(_enabled);
    // Sauvegarder la config vocale (speechRate + voiceName) → écrit en prefs + appelle setTTSConfig JS
    widget.tts.saveVoiceSettings(
      speechRate: _speechRate,
      voiceName: _voiceName,
    );
    // Redémarrer les rappels avec les nouveaux paramètres
    widget.tts.restartReminders(widget.provider);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              Row(
                children: [
                  const Icon(Icons.settings_voice, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Assistant Vocal Cuisine',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Activé / Désactivé ──
              _SettingsRow(
                icon: Icons.power_settings_new,
                label: 'Assistant vocal',
                child: Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() { _enabled = v; _apply(); }),
                  activeThumbColor: AppTheme.success,
                  activeTrackColor: AppTheme.success.withValues(alpha: 0.5),
                ),
              ),
              const _SettingsDivider(),

              // ── Volume ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_up, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'Volume',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        '${(_volume * 100).round()}%',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primary,
                      inactiveTrackColor: AppTheme.primary.withValues(alpha: 0.2),
                      thumbColor: AppTheme.primary,
                      overlayColor: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: (v) => setState(() { _volume = v; _apply(); }),
                    ),
                  ),
                ],
              ),
              const _SettingsDivider(),

              // ── Intervalle de relance ──
              const _SettingsLabel(icon: Icons.timer, label: 'Intervalle de relance'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [1, 2, 3, 5].map((min) {
                  final selected = _intervalMinutes == min;
                  return GestureDetector(
                    onTap: () => setState(() { _intervalMinutes = min; _apply(); }),
                    child: Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withValues(alpha: 0.25)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : const Color(0xFF2A2A5A),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$min',
                            style: TextStyle(
                              color: selected ? AppTheme.primary : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'min',
                            style: TextStyle(
                              color: selected ? AppTheme.primary : AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const _SettingsDivider(),

              // ── Mode coach ──
              const _SettingsLabel(icon: Icons.sports, label: 'Mode coach'),
              const SizedBox(height: 10),
              Column(
                children: [
                  _CoachModeOption(
                    mode: CoachMode.doux,
                    selected: _coachMode == CoachMode.doux,
                    label: 'Doux',
                    subtitle: 'Encouragements calmes et bienveillants',
                    icon: Icons.favorite_border,
                    color: AppTheme.success,
                    onTap: () => setState(() { _coachMode = CoachMode.doux; _apply(); }),
                  ),
                  const SizedBox(height: 8),
                  _CoachModeOption(
                    mode: CoachMode.normal,
                    selected: _coachMode == CoachMode.normal,
                    label: 'Normal',
                    subtitle: 'Ton professionnel et motivant',
                    icon: Icons.equalizer,
                    color: AppTheme.primary,
                    onTap: () => setState(() { _coachMode = CoachMode.normal; _apply(); }),
                  ),
                  const SizedBox(height: 8),
                  _CoachModeOption(
                    mode: CoachMode.pression,
                    selected: _coachMode == CoachMode.pression,
                    label: 'Pression',
                    subtitle: 'Alertes fortes pour les coups de feu',
                    icon: Icons.local_fire_department,
                    color: AppTheme.error,
                    onTap: () => setState(() { _coachMode = CoachMode.pression; _apply(); }),
                  ),
                ],
              ),
              const _SettingsDivider(),

              // ══════════════════════════════════════════
              // ── Section Voix ──
              // ══════════════════════════════════════════

              // Bannière voix africaine non disponible
              if (_voicesLoaded && !_africanAvailable)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1A00),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.6)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Voix africaine native non disponible sur ce navigateur, voix féminine française utilisée.',
                          style: TextStyle(
                            color: Color(0xFFFFB74D),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Vitesse de parole
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'Vitesse de parole',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        _speechRate < 0.75
                            ? 'Lente'
                            : _speechRate > 1.0
                                ? 'Rapide'
                                : 'Normale',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primary,
                      inactiveTrackColor: AppTheme.primary.withValues(alpha: 0.2),
                      thumbColor: AppTheme.primary,
                      overlayColor: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: _speechRate,
                      min: 0.6,
                      max: 1.2,
                      divisions: 6,
                      onChanged: (v) => setState(() {
                        _speechRate = double.parse(v.toStringAsFixed(2));
                        _apply();
                      }),
                    ),
                  ),
                  // Étiquettes min/max
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Douce', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        Text('Dynamique', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Choix de la voix
              const _SettingsLabel(icon: Icons.record_voice_over, label: 'Choisir la voix'),
              const SizedBox(height: 10),
              if (!_voicesLoaded)
                const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                )
              else if (_availableVoices.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A5A)),
                  ),
                  child: const Text(
                    'Aucune voix française détectée dans ce navigateur.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                )
              else
                // Option "Auto" + liste des voix
                Column(
                  children: [
                    // Option auto
                    _VoiceChip(
                      label: 'Auto (meilleure voix féminine)',
                      sublabel: _africanAvailable ? 'Voix africaine détectée ✓' : 'Voix fr-FR',
                      selected: _voiceName == '',
                      isAfrican: _africanAvailable,
                      onTap: () => setState(() { _voiceName = ''; _apply(); }),
                    ),
                    const SizedBox(height: 6),
                    // Liste des voix disponibles
                    ..._availableVoices.map((v) {
                      final name = v['name']!;
                      final lang = v['lang'] ?? '';
                      final isAfrican = lang.startsWith('fr-CI') ||
                          lang.startsWith('fr-SN') || lang.startsWith('fr-CM') ||
                          lang.startsWith('fr-MG') || lang.startsWith('fr-BF') ||
                          lang.startsWith('fr-ML') || lang.startsWith('fr-GN') ||
                          lang.startsWith('fr-TG') || lang.startsWith('fr-BJ') ||
                          lang.startsWith('fr-CD');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _VoiceChip(
                          label: name,
                          sublabel: lang,
                          selected: _voiceName == name,
                          isAfrican: isAfrican,
                          onTap: () => setState(() { _voiceName = name; _apply(); }),
                        ),
                      );
                    }),
                  ],
                ),

              const SizedBox(height: 20),

              // ── Bouton test voix ──
              GestureDetector(
                onTap: () {
                  widget.tts.testVoice();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.mic, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Test vocal lancé…'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.record_voice_over, color: AppTheme.primary, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Tester la voix',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Bouton fermer ──
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A5A)),
                  ),
                  child: const Center(
                    child: Text(
                      'Fermer',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widgets helpers pour le dialog settings

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _SettingsRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const Spacer(),
        child,
      ],
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingsLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      height: 1,
      color: const Color(0xFF2A2A5A),
    );
  }
}

class _CoachModeOption extends StatelessWidget {
  final CoachMode mode;
  final bool selected;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CoachModeOption({
    required this.mode,
    required this.selected,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : const Color(0xFF2A2A5A),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? color : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// VOICE CHIP — item de sélection dans la liste des voix
// ======================================================================

class _VoiceChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final bool isAfrican;
  final VoidCallback onTap;

  const _VoiceChip({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.isAfrican,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isAfrican
        ? const Color(0xFF4CAF50)
        : selected
            ? AppTheme.primary
            : const Color(0xFF2A2A5A);
    final bgColor = selected
        ? (isAfrican
            ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
            : AppTheme.primary.withValues(alpha: 0.15))
        : AppTheme.surfaceLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              isAfrican ? Icons.public : Icons.mic_none,
              color: isAfrican
                  ? const Color(0xFF4CAF50)
                  : selected
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? (isAfrican ? const Color(0xFF4CAF50) : AppTheme.primary)
                          : Colors.white,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  if (sublabel.isNotEmpty)
                    Text(
                      sublabel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: isAfrican ? const Color(0xFF4CAF50) : AppTheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// STAT BUBBLE
// ======================================================================

class _StatBubble extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBubble({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          Text(label, style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

// ======================================================================
// KITCHEN ORDER CARD  — v4 : timer isolé dans _KitchenTimerWidget
// La carte est StatelessWidget → ZÉRO rebuild toutes les secondes.
// Seul _KitchenTimerWidget se rebuilde (timer 1s isolé).
// Boutons : ElevatedButton natifs Flutter, context direct, pas de Builder.
// ======================================================================

// ── Fonction libre (pas de this) : action Firestore ───────────────────
Future<void> _kitchenDoAction(
  BuildContext ctx,
  AppProvider provider,
  TtsService tts,
  Order order,
  OrderStatus nextStatus,
) async {
  final orderId = order.id;
  final ks = order.kitchenStatus ?? '';

  debugPrint('');
  debugPrint('╔══════════════════════════════════════════════════════╗');
  debugPrint('║  CLIC CUISINE orderId=${orderId.substring(0, 12)}…');
  debugPrint('║  kitchenStatus=$ks  nextStatus=${nextStatus.name}');
  debugPrint('║  user=${provider.currentUser?.email ?? "NULL"}');
  debugPrint('╚══════════════════════════════════════════════════════╝');

  try {
    await provider.updateKitchenStatus(orderId, nextStatus);
    debugPrint('✅ ACTION OK orderId=$orderId → ${nextStatus.name}');
    if (nextStatus == OrderStatus.ready) {
      tts.announceOrderReady(order);
    }
  } catch (e) {
    debugPrint('❌ ERREUR CUISINE: $e');
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
    }
  }
}

// ── Widget chronomètre isolé ─────────────────────────────────────────
// Seul ce widget se rebuilde chaque seconde — la carte reste stable.
class _KitchenTimerWidget extends StatefulWidget {
  final Order order;
  final List<OrderItem> kitchenItems;
  final List<Product> products;

  const _KitchenTimerWidget({
    required this.order,
    required this.kitchenItems,
    required this.products,
  });

  @override
  State<_KitchenTimerWidget> createState() => _KitchenTimerWidgetState();
}

class _KitchenTimerWidgetState extends State<_KitchenTimerWidget> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.order.createdAt);
    final mins    = elapsed.inMinutes;
    final secs    = elapsed.inSeconds % 60;
    final isLate  = mins >= 20;

    final maxCookTime = widget.kitchenItems.isEmpty ? 20.0
        : widget.kitchenItems.fold<double>(0, (m, i) {
            final p = widget.products.firstWhere(
              (p) => p.id == i.productId,
              orElse: () => Product(id:'',name:'',category:'',price:0,prepTime:20),
            );
            return p.prepTime > m ? p.prepTime.toDouble() : m;
          });
    final remainingMins = (maxCookTime - mins).clamp(0, maxCookTime.toInt());
    final progressValue = (mins / maxCookTime).clamp(0.0, 1.0);

    final Color timerColor = isLate ? AppTheme.error
        : mins >= 15 ? AppTheme.warning : AppTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: timerColor.withValues(alpha: 0.08),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.timer, color: timerColor, size: 13),
                const SizedBox(width: 3),
                Text(
                  '${mins.toString().padLeft(2,'0')}:${secs.toString().padLeft(2,'0')}',
                  style: TextStyle(color: timerColor,
                      fontWeight: FontWeight.w900, fontSize: 16,
                      fontFamily: 'monospace'),
                ),
                if (isLate)
                  Text('  ⚠ RETARD',
                      style: TextStyle(color: timerColor,
                          fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              Text('~${remainingMins}min',
                  style: TextStyle(color: timerColor,
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte cuisine — StatelessWidget (pas de timer ici) ────────────────
class _KitchenOrderCard extends StatelessWidget {
  final Order order;
  final AppProvider provider;
  final TtsService tts;

  const _KitchenOrderCard({
    super.key,
    required this.order,
    required this.provider,
    required this.tts,
  });

  String get _exactTime {
    final t = order.createdAt;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _confirmCancel(BuildContext ctx) {
    final role = provider.currentUser?.role;
    final canCancel = role == UserRole.kitchen || role == UserRole.admin ||
                      role == UserRole.manager;
    if (!canCancel) {
      debugPrint('[CUISINE] ⛔ REFUSÉ — role=$role');
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(role == null
            ? 'Session expirée — reconnectez-vous'
            : 'Action réservée à la cuisine (rôle: ${role.name})'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Annuler la commande ?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Commande #${order.orderNumber} sera annulée.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Non', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(dCtx);
              debugPrint('👉 CLIC ANNULER CONFIRMÉ #${order.orderNumber}');
              _kitchenDoAction(ctx, provider, tts, order, OrderStatus.cancelled);
            },
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Statut courant ──────────────────────────────────────────────────
    final String ks       = order.kitchenStatus ?? '';
    final bool   isOnline = order.isOnlineOrder;

    final bool isPending = isOnline
        ? (ks == 'pending' || ks == 'waiting' || ks == 'sent_to_kitchen' || ks.isEmpty)
        : (order.status == OrderStatus.pending);

    final bool isPreparing = isOnline
        ? (ks == 'preparing')
        : (order.status == OrderStatus.preparing);

    final bool isReady = isOnline
        ? (ks == 'ready')
        : (order.status == OrderStatus.ready);

    final kitchenItems = order.items.where((i) => i.isKitchenItem).toList();

    // Couleur de bordure statique (pas de timer)
    final bool isUrgent = order.isUrgent;
    final borderColor = isUrgent ? AppTheme.warning
        : order.statusColor.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isUrgent ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── HEADER ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: order.statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#${order.orderNumber}',
                            style: TextStyle(color: order.statusColor,
                                fontWeight: FontWeight.w900, fontSize: 17)),
                          if (order.isOnlineOrder) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3F51B5).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.6)),
                              ),
                              child: const Text('📱 EN LIGNE',
                                  style: TextStyle(color: Color(0xFF7986CB),
                                      fontSize: 8, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        (order.isOnlineOrder && (order.clientName?.isNotEmpty ?? false))
                            ? order.clientName!
                            : order.tableLabel,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      if (order.isOnlineOrder && (order.clientPhone?.isNotEmpty ?? false))
                        Row(children: [
                          const Icon(Icons.phone_outlined, size: 9, color: Color(0xFF7986CB)),
                          const SizedBox(width: 2),
                          Text(order.clientPhone!,
                              style: const TextStyle(color: Color(0xFF7986CB),
                                  fontSize: 9, fontWeight: FontWeight.w600)),
                        ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (order.isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.error, borderRadius: BorderRadius.circular(6)),
                        child: const Text('🚨 URGENT',
                            style: TextStyle(color: Colors.white,
                                fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    const SizedBox(height: 2),
                    Text('à $_exactTime',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                    const SizedBox(height: 2),
                    StatusBadge(label: order.statusLabel, color: order.statusColor, fontSize: 9),
                    if (order.isOnlineOrder) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.isTakeaway ? '🏃 Emporter'
                            : order.isDelivery ? '🚗 Livraison' : '🍽️ Sur place',
                        style: TextStyle(
                          color: order.isTakeaway ? AppTheme.success
                              : order.isDelivery ? const Color(0xFFF57C00)
                              : const Color(0xFF42A5F5),
                          fontSize: 8, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── TIMER — widget isolé, seul lui se rebuilde chaque seconde ──
          _KitchenTimerWidget(
            order: order,
            kitchenItems: kitchenItems,
            products: provider.products,
          ),

          // ── ARTICLES ─────────────────────────────────────────────────
          ...kitchenItems.take(4).map((item) => _KitchenItemRow(
            item: item,
            onChangeQty: (newQty) => provider
                .updateOrderItemQuantity(order.id, item.productId, newQty),
          )),

          if (kitchenItems.length > 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text('+${kitchenItems.length - 4} article(s) supplémentaire(s)',
                  style: const TextStyle(color: AppTheme.textSecondary,
                      fontSize: 10, fontStyle: FontStyle.italic)),
            ),

          if (order.specialInstructions != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: AppTheme.warning.withValues(alpha: 0.08),
              child: Text('📝 ${order.specialInstructions}',
                  style: const TextStyle(color: AppTheme.warning,
                      fontSize: 10, fontStyle: FontStyle.italic)),
            ),

          const SizedBox(height: 6),

          // ── BOUTONS ACTION ─────────────────────────────────────────────
          // StatelessWidget → build() n'est appelé QUE sur changement Firestore,
          // jamais par le timer 1s → les taps ne sont JAMAIS interrompus.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isPending)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Commencer',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        debugPrint('👉 CLIC COMMENCER #${order.orderNumber}');
                        _kitchenDoAction(context, provider, tts, order, OrderStatus.preparing);
                      },
                    ),
                  )
                else if (isPreparing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('✓ Prêt !',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        debugPrint('👉 CLIC PRET #${order.orderNumber}');
                        _kitchenDoAction(context, provider, tts, order, OrderStatus.ready);
                      },
                    ),
                  )
                else if (isReady)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.restaurant_menu, size: 16),
                      label: const Text('✓ Servie',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        debugPrint('👉 CLIC SERVIE #${order.orderNumber}');
                        _kitchenDoAction(context, provider, tts, order, OrderStatus.served);
                      },
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        debugPrint('[CUISINE] État inconnu: ks=$ks status=${order.status.name}');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('État: ks=$ks | status=${order.status.name}'),
                          backgroundColor: Colors.grey.shade700,
                        ));
                      },
                      child: Text('? ${ks.isEmpty ? order.status.name : ks}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.record_voice_over, size: 13),
                        label: const Text('Écouter',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          debugPrint('👉 CLIC ECOUTER #${order.orderNumber}');
                          tts.announceOrder(order);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 13),
                        label: const Text('Annuler',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          debugPrint('👉 CLIC ANNULER #${order.orderNumber}');
                          _confirmCancel(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget quantité éditable (cuisine) ────────────────────────────────────
class _KitchenEditableQty extends StatefulWidget {
  final int quantity;
  final void Function(int newQty) onChanged;

  const _KitchenEditableQty({
    required this.quantity,
    required this.onChanged,
  });

  @override
  State<_KitchenEditableQty> createState() => _KitchenEditableQtyState();
}

class _KitchenEditableQtyState extends State<_KitchenEditableQty> {
  bool _editing = false;
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.quantity}');
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(_KitchenEditableQty old) {
    super.didUpdateWidget(old);
    if (!_editing && old.quantity != widget.quantity) {
      _ctrl.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _ctrl.text = '${widget.quantity}';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  void _commit() {
    final raw = int.tryParse(_ctrl.text.trim());
    final newVal = (raw == null || raw <= 0) ? 1 : raw;
    setState(() {
      _editing = false;
      _ctrl.text = '$newVal';
    });
    if (newVal != widget.quantity) widget.onChanged(newVal);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 36,
        height: 26,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFF1E2640),
          ),
          onSubmitted: (_) => _commit(),
        ),
      );
    }
    return GestureDetector(
      onTap: _startEdit,
      child: SizedBox(
        width: 28,
        child: Text(
          '${widget.quantity}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// KITCHEN ITEM ROW  — liste compacte sans GestureDetector pour quantité
// ======================================================================

class _KitchenItemRow extends StatelessWidget {
  final OrderItem item;
  final Function(int) onChangeQty;

  const _KitchenItemRow({required this.item, required this.onChangeQty});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600)),
                if (item.specialComment != null)
                  Text('💬 ${item.specialComment}',
                      style: const TextStyle(color: AppTheme.warning,
                          fontSize: 9, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          // Contrôles quantité — GestureDetector (fiable sur Web sans Material ancêtre)
          GestureDetector(
            onTap: () {
              debugPrint('👉 CLIC MOINS qty ${item.quantity} → ${item.quantity - 1}');
              onChangeQty(item.quantity - 1);
            },
            child: Container(
              width: 22, height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.remove, size: 12, color: AppTheme.error),
            ),
          ),
          _KitchenEditableQty(
            quantity: item.quantity,
            onChanged: onChangeQty,
          ),
          GestureDetector(
            onTap: () {
              debugPrint('👉 CLIC PLUS qty ${item.quantity} → ${item.quantity + 1}');
              onChangeQty(item.quantity + 1);
            },
            child: Container(
              width: 22, height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.add, size: 12, color: AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// READY ORDER CARD
// ======================================================================

class _ReadyOrderCard extends StatelessWidget {
  final Order order;
  final AppProvider provider;

  const _ReadyOrderCard({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: AppTheme.ready.withValues(alpha: 0.5), width: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.ready.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.ready, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${order.orderNumber} - ${order.tableLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${order.items.where((i) => !i.isCambuse).fold(0, (s, i) => s + i.quantity)} articles',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text(
                'PRÊTE!',
                style: TextStyle(
                  color: AppTheme.ready,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () {
                  debugPrint('👉 CLIC SERVIE (prête) #${order.orderNumber}');
                  provider.updateKitchenStatus(order.id, OrderStatus.served);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ready,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Servie', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
