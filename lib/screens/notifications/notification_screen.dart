// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NotificationScreen v2 — Paramètres sons + Assistant vocal + Historique
// ═══════════════════════════════════════════════════════════════════════════

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final NotificationService _svc = NotificationService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _svc.addListener(_rebuild);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _svc.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceLight,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_svc.unreadCount > 0)
            TextButton.icon(
              onPressed: () { _svc.markAllRead(); },
              icon: const Icon(Icons.done_all, color: AppTheme.success, size: 18),
              label: const Text('Tout lire',
                  style: TextStyle(color: AppTheme.success, fontSize: 12)),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            const Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.settings, size: 16),
                SizedBox(width: 6),
                Text('Paramètres'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, size: 16),
                const SizedBox(width: 6),
                const Text('Historique'),
                if (_svc.unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  _Badge(_svc.unreadCount),
                ],
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SettingsTab(svc: _svc),
          _HistoryTab(svc: _svc),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Onglet Paramètres
// ══════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatefulWidget {
  final NotificationService svc;
  const _SettingsTab({required this.svc});
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  NotificationService get s => widget.svc;

  // Voix disponibles chargées depuis Web Speech API
  List<Map<String, String>> _voices = [];
  bool _voicesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  void _loadVoices() {
    if (!kIsWeb) return;
    try {
      final json = s.getVoiceListJson();
      final list = jsonDecode(json) as List<dynamic>;
      setState(() {
        _voices = list.map((e) => {
          'name': e['name'] as String? ?? '',
          'lang': e['lang'] as String? ?? '',
        }).toList();
        _voicesLoaded = true;
      });
    } catch (_) {
      _voicesLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Alerte déblocage audio (Web) ──
        if (kIsWeb && !s.isAudioUnlocked) ...[
          _AudioUnlockBanner(svc: s),
          const SizedBox(height: 12),
        ],

        // ── Alerte urgence active ──
        if (s.urgentActive) ...[
          _UrgentActiveBanner(svc: s),
          const SizedBox(height: 12),
        ],

        // ════════════════════════════════════
        // 1. PARAMÈTRES SONS
        // ════════════════════════════════════
        _SectionHeader('1. Paramètres sons'),
        GlassCard(
          child: Column(children: [

            _SwitchRow(
              icon: Icons.volume_up,
              iconColor: AppTheme.primary,
              title: 'Activer tous les sons',
              subtitle: 'Active toutes les sonneries de l\'application',
              value: s.soundEnabled,
              onChanged: (v) async { await s.setSoundEnabled(v); setState(() {}); },
            ),

            const _Divider(),

            // Volume général
            _VolumeRow(
              icon: Icons.volume_up,
              iconColor: AppTheme.primary,
              label: 'Volume général',
              value: s.volume,
              onChanged: (v) async { await s.setVolume(v); setState(() {}); },
              onChangeEnd: (_) => s.testSound(),
            ),

            const _Divider(),

            // Volume sonnerie
            _VolumeRow(
              icon: Icons.notifications_active,
              iconColor: const Color(0xFFFF7043),
              label: 'Volume sonneries',
              value: s.volumeRingtone,
              onChanged: (v) async { await s.setVolumeRingtone(v); setState(() {}); },
              onChangeEnd: (_) => s.testSound(),
            ),

            const _Divider(),

            // Volume vocal
            _VolumeRow(
              icon: Icons.record_voice_over,
              iconColor: const Color(0xFF42A5F5),
              label: 'Volume assistant vocal',
              value: s.volumeVoice,
              onChanged: (v) async { await s.setVolumeVoice(v); setState(() {}); },
              onChangeEnd: (_) {},
            ),

            const _Divider(),

            _SwitchRow(
              icon: Icons.repeat,
              iconColor: AppTheme.warning,
              title: 'Répéter les alertes importantes',
              subtitle: 'Sonnerie + vocal répétés pour urgences et ruptures',
              value: s.repeatImportant,
              onChanged: (v) async { await s.setRepeatImportant(v); setState(() {}); },
            ),

            if (s.repeatImportant) ...[
              const _Divider(),
              // Intervalle de répétition
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timer, color: AppTheme.warning, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Intervalle de répétition',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Durée entre chaque répétition d\'alerte',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ]),
                  ),
                  DropdownButton<int>(
                    value: s.repeatIntervalSec,
                    dropdownColor: AppTheme.surfaceLight,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: kRepeatIntervals.map((sec) => DropdownMenuItem(
                      value: sec,
                      child: Text(intervalLabel(sec)),
                    )).toList(),
                    onChanged: (v) async {
                      if (v != null) { await s.setRepeatIntervalSec(v); setState(() {}); }
                    },
                  ),
                ]),
              ),

              const _Divider(),

              // Durée maximale
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.hourglass_bottom, color: AppTheme.error, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Durée max. répétition',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Arrêt automatique après cette durée',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ]),
                  ),
                  DropdownButton<int>(
                    value: s.maxRepeatDurationSec,
                    dropdownColor: AppTheme.surfaceLight,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: [60, 120, 180, 300, 600].map((sec) => DropdownMenuItem(
                      value: sec,
                      child: Text(intervalLabel(sec)),
                    )).toList(),
                    onChanged: (v) async {
                      if (v != null) { await s.setMaxRepeatDurationSec(v); setState(() {}); }
                    },
                  ),
                ]),
              ),
            ],

            const _Divider(),

            // Bouton arrêter toutes les alertes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { s.stopAllAlerts(); setState(() {}); },
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Arrêter toutes les alertes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ════════════════════════════════════
        // 2. ASSISTANT VOCAL
        // ════════════════════════════════════
        _SectionHeader('2. Assistant vocal'),
        GlassCard(
          child: Column(children: [

            _SwitchRow(
              icon: Icons.record_voice_over,
              iconColor: const Color(0xFF42A5F5),
              title: 'Activer l\'assistant vocal',
              subtitle: 'Lecture vocale des notifications importantes',
              value: s.voiceEnabled,
              onChanged: (v) async { await s.setVoiceEnabled(v); setState(() {}); },
            ),

            if (s.voiceEnabled) ...[
              const _Divider(),

              // Sélection voix
              if (kIsWeb && _voicesLoaded && _voices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.mic, color: Color(0xFF42A5F5), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Voix',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(s.voiceName.isEmpty ? 'Automatique (féminine)' : s.voiceName,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _voices.any((v) => v['name'] == s.voiceName)
                          ? s.voiceName
                          : '',
                      dropdownColor: AppTheme.surfaceLight,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Auto (féminine)'),
                        ),
                        ..._voices.map((v) => DropdownMenuItem(
                          value: v['name']!,
                          child: Text(v['name']!.length > 22
                              ? '${v['name']!.substring(0, 22)}…'
                              : v['name']!),
                        )),
                      ],
                      onChanged: (v) async {
                        if (v != null) { await s.setVoiceName(v); setState(() {}); }
                      },
                    ),
                  ]),
                ),

              const _Divider(),

              // Vitesse de parole
              _VolumeRow(
                icon: Icons.speed,
                iconColor: const Color(0xFF66BB6A),
                label: 'Vitesse de parole',
                value: s.speechRate,
                min: 0.5,
                max: 1.5,
                divisions: 10,
                displayPercent: false,
                displayValue: '${s.speechRate.toStringAsFixed(2)}×',
                onChanged: (v) async { await s.setSpeechRate(v); setState(() {}); },
                onChangeEnd: (_) {},
              ),

              const _Divider(),

              // Pitch / Ton
              _VolumeRow(
                icon: Icons.tune,
                iconColor: const Color(0xFFAB47BC),
                label: 'Ton / Pitch',
                value: s.speechPitch,
                min: 0.8,
                max: 1.6,
                divisions: 8,
                displayPercent: false,
                displayValue: '${s.speechPitch.toStringAsFixed(2)}',
                onChanged: (v) async { await s.setSpeechPitch(v); setState(() {}); },
                onChangeEnd: (_) {},
              ),

              const _Divider(),

              // Boutons test
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        s.unlockAudio();
                        s.testVoice();
                      },
                      icon: const Icon(Icons.play_circle_filled, size: 18),
                      label: const Text('Tester la voix', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => s.readLastNotification(),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Dernière notif', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF66BB6A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 20),

        // ════════════════════════════════════
        // 3. TYPES DE NOTIFICATIONS
        // ════════════════════════════════════
        _SectionHeader('3. Types de notifications'),
        GlassCard(
          child: Column(children: [
            _SwitchRow(
              icon: Icons.phone_android,
              iconColor: const Color(0xFF42A5F5),
              title: 'Commandes en ligne',
              subtitle: 'Nouvelles commandes depuis l\'espace client',
              value: s.notifOnline,
              onChanged: (v) async { await s.setNotifOnline(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.warning_amber,
              iconColor: AppTheme.error,
              title: 'Commandes urgentes',
              subtitle: 'Alertes de commandes prioritaires',
              value: s.notifUrgent,
              onChanged: (v) async { await s.setNotifUrgent(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.restaurant,
              iconColor: const Color(0xFFFF7043),
              title: 'Cuisine',
              subtitle: 'Nouvelles commandes, urgences, plats prêts',
              value: s.notifCuisine,
              onChanged: (v) async { await s.setNotifCuisine(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.point_of_sale,
              iconColor: const Color(0xFF66BB6A),
              title: 'Caisse',
              subtitle: 'Paiements enregistrés et encaissements',
              value: s.notifCaisse,
              onChanged: (v) async { await s.setNotifCaisse(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.inventory_2,
              iconColor: const Color(0xFFFFCA28),
              title: 'Stock faible',
              subtitle: 'Alertes de niveau bas',
              value: s.notifStock,
              onChanged: (v) async { await s.setNotifStock(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.do_not_disturb_on,
              iconColor: AppTheme.error,
              title: 'Rupture de stock',
              subtitle: 'Produits épuisés',
              value: s.notifRupture,
              onChanged: (v) async { await s.setNotifRupture(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.event_note,
              iconColor: const Color(0xFFAB47BC),
              title: 'Réservations',
              subtitle: 'Nouvelles réservations et rappels',
              value: s.notifReservations,
              onChanged: (v) async { await s.setNotifReservations(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.description,
              iconColor: const Color(0xFF42A5F5),
              title: 'Contrats',
              subtitle: 'Contrats approchant l\'expiration',
              value: s.notifContrats,
              onChanged: (v) async { await s.setNotifContrats(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.people,
              iconColor: const Color(0xFF42A5F5),
              title: 'Salaires',
              subtitle: 'Paiements de salaires à effectuer',
              value: s.notifPersonnel,
              onChanged: (v) async { await s.setNotifPersonnel(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.local_shipping,
              iconColor: const Color(0xFF66BB6A),
              title: 'Fournisseurs',
              subtitle: 'Livraisons et bons de commande',
              value: s.notifFournisseurs,
              onChanged: (v) async { await s.setNotifFournisseurs(v); setState(() {}); },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.settings,
              iconColor: AppTheme.textSecondary,
              title: 'Système',
              subtitle: 'Notifications système et mises à jour',
              value: s.notifSysteme,
              onChanged: (v) async { await s.setNotifSysteme(v); setState(() {}); },
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ════════════════════════════════════
        // 4. SONNERIES PAR TYPE
        // ════════════════════════════════════
        _SectionHeader('4. Sonneries par type de notification'),
        ..._buildPerTypeSoundSections(),

        const SizedBox(height: 20),

        // ════════════════════════════════════
        // 5. ALERTES URGENTES
        // ════════════════════════════════════
        _SectionHeader('5. Alertes urgentes'),
        GlassCard(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Les commandes urgentes et ruptures critiques déclenchent une sonnerie répétée + lecture vocale répétée jusqu\'à consultation.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (s.urgentActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.alarm, color: AppTheme.error, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('🚨 Alerte urgente en cours',
                              style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        ElevatedButton(
                          onPressed: () { s.acknowledgeUrgent(); setState(() {}); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Arrêter', style: TextStyle(fontSize: 11)),
                        ),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(children: [
                        Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                        SizedBox(width: 8),
                        Text('Aucune alerte urgente active',
                            style: TextStyle(color: AppTheme.success, fontSize: 12)),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () { s.stopAllAlerts(); setState(() {}); },
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Arrêter toutes les alertes',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ════════════════════════════════════
        // TEST SONORE GLOBAL
        // ════════════════════════════════════
        _SectionHeader('Test sonore rapide'),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text(
                'Testez la sonnerie sélectionnée pour vérifier le volume.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    s.unlockAudio();
                    s.testSound();
                  },
                  icon: const Icon(Icons.play_circle_filled, size: 22),
                  label: const Text('▶  Tester le son',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // Sélection sonnerie par type de notification
  List<Widget> _buildPerTypeSoundSections() {
    final groups = [
      {'label': 'Commandes en ligne', 'event': NotifEvent.nouvelleCommandeEnLigne},
      {'label': 'Commandes urgentes', 'event': NotifEvent.commandeUrgente},
      {'label': 'Commande prête',     'event': NotifEvent.commandePrete},
      {'label': 'Paiement',           'event': NotifEvent.paiementEnregistre},
      {'label': 'Réservation',        'event': NotifEvent.nouvelleReservation},
      {'label': 'Stock faible',       'event': NotifEvent.stockFaible},
      {'label': 'Rupture stock',      'event': NotifEvent.ruptureStock},
      {'label': 'Système',            'event': NotifEvent.notificationSysteme},
    ];

    return groups.map((g) {
      final event     = g['event'] as NotifEvent;
      final label     = g['label'] as String;
      final curSound  = s.getPerTypeSound(event);
      return _PerTypeSoundRow(
        label:       label,
        event:       event,
        curSound:    curSound,
        onSelect:    (sound) async {
          await s.setPerTypeSound(event, sound);
          setState(() {});
        },
        onTest:      (sound) {
          s.unlockAudio();
          s.testSound(sound);
        },
      );
    }).toList();
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Widget : Sélection sonnerie par type
// ══════════════════════════════════════════════════════════════════════════

class _PerTypeSoundRow extends StatelessWidget {
  final String label;
  final NotifEvent event;
  final String curSound;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onTest;

  const _PerTypeSoundRow({
    required this.label,
    required this.event,
    required this.curSound,
    required this.onSelect,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(event.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kSoundOptions.map((opt) {
                final isSelected = curSound == opt.id;
                return GestureDetector(
                  onTap: () => onSelect(opt.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.2)
                          : const Color(0xFF1E1E3A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(opt.label,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          )),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onTest(opt.id),
                        child: Icon(Icons.play_arrow,
                            size: 14,
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Onglet Historique
// ══════════════════════════════════════════════════════════════════════════

class _HistoryTab extends StatelessWidget {
  final NotificationService svc;
  const _HistoryTab({required this.svc});

  @override
  Widget build(BuildContext context) {
    final history = svc.history;
    if (history.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'Aucune notification pour l\'instant',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final n = history[i];
        return _NotifHistoryCard(
          notif:  n,
          onRead: () => svc.markRead(n.id),
        );
      },
    );
  }
}

// ── Carte notification historique ─────────────────────────────────────────

class _NotifHistoryCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onRead;
  const _NotifHistoryCard({required this.notif, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? AppTheme.primary.withValues(alpha: 0.4)
              : const Color(0xFF2A2A5A),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _categoryColor(notif.event.category).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(notif.event.icon, style: const TextStyle(fontSize: 18)),
          ),
        ),
        title: Text(
          notif.message,
          style: TextStyle(
            color: isUnread ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          _formatDateTime(notif.dateTime),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        trailing: isUnread
            ? GestureDetector(
                onTap: onRead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Lu',
                      style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              )
            : const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'cuisine':      return const Color(0xFFFF7043);
      case 'caisse':       return const Color(0xFF66BB6A);
      case 'stock':        return const Color(0xFFFFCA28);
      case 'personnel':    return const Color(0xFF42A5F5);
      case 'reservations': return const Color(0xFFAB47BC);
      case 'online':       return AppTheme.primary;
      default:             return AppTheme.primary;
    }
  }

  String _formatDateTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)  return 'À l\'instant';
    if (diff.inMinutes < 60)  return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)    return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1)     return 'Hier ${_hm(dt)}';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${_hm(dt)}';
  }

  String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

// ── Banners ───────────────────────────────────────────────────────────────

class _AudioUnlockBanner extends StatelessWidget {
  final NotificationService svc;
  const _AudioUnlockBanner({required this.svc});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.volume_off, color: AppTheme.warning, size: 22),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Autorisation audio requise',
                style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 13)),
            SizedBox(height: 2),
            Text('Le navigateur bloque l\'audio. Appuyez sur "Activer" pour autoriser les sons.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => svc.unlockAudio(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warning,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text('Activer les sons',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _UrgentActiveBanner extends StatelessWidget {
  final NotificationService svc;
  const _UrgentActiveBanner({required this.svc});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.alarm, color: AppTheme.error, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🚨 Alerte urgente active',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
            SizedBox(height: 2),
            Text(
              'Sonnerie répétée toutes les ${intervalLabel(svc.repeatIntervalSec)}. '
              'Consultez la notification pour arrêter.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => svc.acknowledgeUrgent(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text('Arrêter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Widgets réutilisables ──────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon, required this.iconColor, required this.title,
    required this.subtitle, required this.value, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ]),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primary),
      ]),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool displayPercent;
  final String? displayValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _VolumeRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions = 9,
    this.displayPercent = true,
    this.displayValue,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final val = displayValue ?? (displayPercent
        ? '${((value - min) / (max - min) * 100).round()} %'
        : value.toStringAsFixed(2));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(val,
                  style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor:   iconColor,
              inactiveTrackColor: const Color(0xFF2A2A5A),
              thumbColor:         iconColor,
              overlayColor:       iconColor.withValues(alpha: 0.2),
              trackHeight:        3,
            ),
            child: Slider(
              value:      value.clamp(min, max),
              min:        min,
              max:        max,
              divisions:  divisions,
              onChanged:  onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Color(0xFF2A2A5A), height: 1, indent: 16, endIndent: 16);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

// ── Indicateur de synchronisation Firestore ──────────────────────────────────
class _SyncStatusBanner extends StatefulWidget {
  final NotificationService svc;
  const _SyncStatusBanner({required this.svc});

  @override
  State<_SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<_SyncStatusBanner> {
  bool _loading = true;
  bool _synced  = false;
  String _msg   = 'Chargement des paramètres…';

  @override
  void initState() {
    super.initState();
    _checkSync();
  }

  Future<void> _checkSync() async {
    setState(() { _loading = true; _msg = 'Chargement des paramètres…'; });
    try {
      await widget.svc.loadFromFirestore();
      if (mounted) {
        setState(() {
          _loading = false;
          _synced  = true;
          _msg     = 'Paramètres synchronisés avec Firestore';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _synced  = false;
          _msg     = 'Synchronisation locale uniquement';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _loading
        ? AppTheme.primary
        : _synced
            ? AppTheme.success
            : AppTheme.warning;

    final icon = _loading
        ? Icons.sync
        : _synced
            ? Icons.cloud_done_outlined
            : Icons.cloud_off_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _loading
              ? SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _msg,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          if (!_loading)
            GestureDetector(
              onTap: _checkSync,
              child: Icon(Icons.refresh, color: color, size: 14),
            ),
        ],
      ),
    );
  }
}
