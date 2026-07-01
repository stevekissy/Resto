// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NotificationScreen v3 — Non lues · Historique · Paramètres sons
//  Règle absolue : son joué UNE SEULE FOIS (read==false && playedAt==null)
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
    _tabs = TabController(length: 3, vsync: this);
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
    final unread = _svc.unreadCount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.notifications_outlined, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Notifications',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              _UnreadBadge(unread),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        // ── Bouton "Tout lire" toujours visible dans la AppBar ──
        actions: [
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  final count = unread;
                  await _svc.markAllRead();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.done_all, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text('$count notification${count > 1 ? 's' : ''} marquée${count > 1 ? 's' : ''} comme lue${count > 1 ? 's' : ''}'),
                    ]),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 3),
                  ));
                },
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Tout lire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.success),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.mark_email_unread_outlined, size: 15),
                const SizedBox(width: 5),
                const Text('Non lues'),
                if (unread > 0) ...[
                  const SizedBox(width: 5),
                  _UnreadBadge(unread, small: true),
                ],
              ]),
            ),
            const Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, size: 15),
                SizedBox(width: 5),
                Text('Historique'),
              ]),
            ),
            const Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.tune, size: 15),
                SizedBox(width: 5),
                Text('Sons'),
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _UnreadTab(svc: _svc),
          _HistoryTab(svc: _svc),
          _SettingsTab(svc: _svc),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Onglet 1 — Non lues
// ══════════════════════════════════════════════════════════════════════════

class _UnreadTab extends StatelessWidget {
  final NotificationService svc;
  const _UnreadTab({required this.svc});

  @override
  Widget build(BuildContext context) {
    final unread = svc.history.where((n) => !n.isRead).toList();

    // ── Bannière alerte urgente active ────────────────────────────────
    return Column(
      children: [
        if (svc.urgentActive)
          _UrgentBanner(svc: svc),

        if (kIsWeb && !svc.isAudioUnlocked)
          _AudioUnlockBanner(svc: svc),

        // ── Bouton "Tout lire" proéminent si non lues ─────────────────
        if (unread.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _MarkAllReadButton(
              count: unread.length,
              onTap: () async => svc.markAllRead(),
            ),
          ),

        // ── Liste ou état vide ────────────────────────────────────────
        Expanded(
          child: unread.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.check_circle_outline,
                            color: AppTheme.success, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text('Tout est lu !',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Aucune notification en attente',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
                  itemCount: unread.length,
                  itemBuilder: (ctx, i) => _NotifCard(
                    notif: unread[i],
                    onRead: () => svc.markRead(unread[i].id),
                    highlight: true,
                  ),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Onglet 2 — Historique
// ══════════════════════════════════════════════════════════════════════════

class _HistoryTab extends StatefulWidget {
  final NotificationService svc;
  const _HistoryTab({required this.svc});
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String _catFilter = 'all';

  static const _cats = [
    ('all',          'Toutes',     Icons.list_alt),
    ('online',       'En ligne',   Icons.phone_android),
    ('cuisine',      'Cuisine',    Icons.restaurant),
    ('caisse',       'Caisse',     Icons.point_of_sale),
    ('reservations', 'Réservations', Icons.event),
    ('stock',        'Stock',      Icons.inventory_2),
    ('systeme',      'Système',    Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final all = widget.svc.history;
    final filtered = _catFilter == 'all'
        ? all
        : all.where((n) => n.event.category == _catFilter).toList();

    return Column(
      children: [
        // ── Filtres catégories ────────────────────────────────────────
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            children: _cats.map((c) {
              final (id, label, icon) = c;
              final count = id == 'all'
                  ? all.length
                  : all.where((n) => n.event.category == id).length;
              final isSelected = _catFilter == id;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _catFilter = id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.6)
                            : const Color(0xFF2A2A5A),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon,
                          size: 12,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          )),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.25)
                                : AppTheme.textSecondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$count',
                              style: TextStyle(
                                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Liste historique ──────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: _catFilter == 'all'
                        ? 'Aucune notification'
                        : 'Aucune notification dans cette catégorie',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 30),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _NotifCard(
                    notif: filtered[i],
                    onRead: () => widget.svc.markRead(filtered[i].id),
                    highlight: false,
                  ),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Onglet 3 — Paramètres sons
// ══════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatefulWidget {
  final NotificationService svc;
  const _SettingsTab({required this.svc});
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  NotificationService get s => widget.svc;

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

        // ── Bannière urgence ──────────────────────────────────────────
        if (s.urgentActive) ...[
          _UrgentBanner(svc: s),
          const SizedBox(height: 12),
        ],

        // ── Bannière déblocage audio ──────────────────────────────────
        if (kIsWeb && !s.isAudioUnlocked) ...[
          _AudioUnlockBanner(svc: s),
          const SizedBox(height: 12),
        ],

        // ════════════════════════════════════════════════════════════
        // A. SONS GÉNÉRAUX
        // ════════════════════════════════════════════════════════════
        const _SectionHeader(icon: Icons.volume_up, title: 'Sons généraux'),
        _SettingsCard(children: [

          _SwitchRow(
            icon: Icons.volume_up,
            iconColor: AppTheme.primary,
            title: 'Activer tous les sons',
            subtitle: 'Active toutes les sonneries de l\'application',
            value: s.soundEnabled,
            onChanged: (v) async { await s.setSoundEnabled(v); setState(() {}); },
          ),

          const _Divider(),

          _VolumeRow(
            icon: Icons.notifications_active,
            iconColor: const Color(0xFFFF7043),
            label: 'Volume sonneries',
            value: s.volumeRingtone,
            onChanged: (v) async { await s.setVolumeRingtone(v); setState(() {}); },
            onChangeEnd: (_) => s.testSound(),
          ),

          const _Divider(),

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
            title: 'Répéter les alertes urgentes',
            subtitle: 'Sonnerie répétée pour urgences et ruptures critiques',
            value: s.repeatImportant,
            onChanged: (v) async { await s.setRepeatImportant(v); setState(() {}); },
          ),

          if (s.repeatImportant) ...[
            const _Divider(),
            _DropdownRow<int>(
              icon: Icons.timer,
              iconColor: AppTheme.warning,
              title: 'Intervalle répétition',
              subtitle: 'Durée entre chaque sonnerie',
              value: s.repeatIntervalSec,
              items: kRepeatIntervals,
              labelBuilder: intervalLabel,
              onChanged: (v) async { if (v != null) { await s.setRepeatIntervalSec(v); setState(() {}); } },
            ),
            const _Divider(),
            _DropdownRow<int>(
              icon: Icons.hourglass_bottom,
              iconColor: AppTheme.error,
              title: 'Durée max. répétition',
              subtitle: 'Arrêt automatique après cette durée',
              value: s.maxRepeatDurationSec,
              items: const [60, 120, 180, 300, 600],
              labelBuilder: intervalLabel,
              onChanged: (v) async { if (v != null) { await s.setMaxRepeatDurationSec(v); setState(() {}); } },
            ),
          ],

          const _Divider(),

          // ── Test sonore ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () { s.unlockAudio(); s.testSound(); },
                icon: const Icon(Icons.play_circle_filled, size: 18),
                label: const Text('▶  Tester le son', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          // ── Arrêter toutes les alertes ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { s.stopAllAlerts(); setState(() {}); },
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Arrêter toutes les alertes', style: TextStyle(fontWeight: FontWeight.w600)),
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

        const SizedBox(height: 20),

        // ════════════════════════════════════════════════════════════
        // B. ASSISTANT VOCAL
        // ════════════════════════════════════════════════════════════
        const _SectionHeader(icon: Icons.record_voice_over, title: 'Assistant vocal'),
        _SettingsCard(children: [

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

            if (kIsWeb && _voicesLoaded && _voices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      const Text('Voix', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        s.voiceName.isEmpty ? 'Automatique (féminine)' : s.voiceName,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _voices.any((v) => v['name'] == s.voiceName) ? s.voiceName : '',
                    dropdownColor: AppTheme.surfaceLight,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Auto (féminine)')),
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

            _VolumeRow(
              icon: Icons.speed,
              iconColor: const Color(0xFF66BB6A),
              label: 'Vitesse de parole',
              value: s.speechRate,
              min: 0.5, max: 1.5, divisions: 10,
              displayPercent: false,
              displayValue: '${s.speechRate.toStringAsFixed(2)}×',
              onChanged: (v) async { await s.setSpeechRate(v); setState(() {}); },
              onChangeEnd: (_) {},
            ),

            const _Divider(),

            _VolumeRow(
              icon: Icons.tune,
              iconColor: const Color(0xFFAB47BC),
              label: 'Ton / Pitch',
              value: s.speechPitch,
              min: 0.8, max: 1.6, divisions: 8,
              displayPercent: false,
              displayValue: s.speechPitch.toStringAsFixed(2),
              onChanged: (v) async { await s.setSpeechPitch(v); setState(() {}); },
              onChangeEnd: (_) {},
            ),

            const _Divider(),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { s.unlockAudio(); s.testVoice(); },
                    icon: const Icon(Icons.play_circle_filled, size: 16),
                    label: const Text('Tester la voix', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => s.readLastNotification(),
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Dernière notif', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66BB6A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ]),

        const SizedBox(height: 20),

        // ════════════════════════════════════════════════════════════
        // C. TYPES DE NOTIFICATIONS
        // ════════════════════════════════════════════════════════════
        const _SectionHeader(icon: Icons.notifications, title: 'Types de notifications'),
        _SettingsCard(children: [
          _SwitchRow(icon: Icons.phone_android,    iconColor: AppTheme.primary,
              title: 'Commandes en ligne',    subtitle: 'Nouvelles commandes depuis l\'espace client',
              value: s.notifOnline,   onChanged: (v) async { await s.setNotifOnline(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.warning_amber,   iconColor: AppTheme.error,
              title: 'Commandes urgentes',   subtitle: 'Alertes de commandes prioritaires',
              value: s.notifUrgent,   onChanged: (v) async { await s.setNotifUrgent(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.restaurant,      iconColor: const Color(0xFFFF7043),
              title: 'Cuisine',              subtitle: 'Nouvelles commandes, urgences, plats prêts',
              value: s.notifCuisine,  onChanged: (v) async { await s.setNotifCuisine(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.point_of_sale,   iconColor: const Color(0xFF66BB6A),
              title: 'Caisse',               subtitle: 'Paiements enregistrés et encaissements',
              value: s.notifCaisse,   onChanged: (v) async { await s.setNotifCaisse(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.inventory_2,     iconColor: const Color(0xFFFFCA28),
              title: 'Stock faible',         subtitle: 'Alertes de niveau bas',
              value: s.notifStock,    onChanged: (v) async { await s.setNotifStock(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.do_not_disturb_on, iconColor: AppTheme.error,
              title: 'Rupture de stock',     subtitle: 'Produits épuisés',
              value: s.notifRupture,  onChanged: (v) async { await s.setNotifRupture(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.event_note,      iconColor: const Color(0xFFAB47BC),
              title: 'Réservations',         subtitle: 'Nouvelles réservations et rappels',
              value: s.notifReservations, onChanged: (v) async { await s.setNotifReservations(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.description,     iconColor: const Color(0xFF42A5F5),
              title: 'Contrats',             subtitle: 'Contrats approchant l\'expiration',
              value: s.notifContrats,  onChanged: (v) async { await s.setNotifContrats(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.people,          iconColor: const Color(0xFF42A5F5),
              title: 'Salaires',             subtitle: 'Paiements de salaires à effectuer',
              value: s.notifPersonnel, onChanged: (v) async { await s.setNotifPersonnel(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.local_shipping,  iconColor: const Color(0xFF66BB6A),
              title: 'Fournisseurs',         subtitle: 'Livraisons et bons de commande',
              value: s.notifFournisseurs, onChanged: (v) async { await s.setNotifFournisseurs(v); setState(() {}); }),
          const _Divider(),
          _SwitchRow(icon: Icons.settings,        iconColor: AppTheme.textSecondary,
              title: 'Système',              subtitle: 'Notifications système et mises à jour',
              value: s.notifSysteme,   onChanged: (v) async { await s.setNotifSysteme(v); setState(() {}); }),
        ]),

        const SizedBox(height: 20),

        // ════════════════════════════════════════════════════════════
        // D. SONNERIES PAR TYPE
        // ════════════════════════════════════════════════════════════
        const _SectionHeader(icon: Icons.music_note, title: 'Sonneries par type'),
        ..._buildPerTypeSounds(),

        const SizedBox(height: 30),
      ],
    );
  }

  List<Widget> _buildPerTypeSounds() {
    final groups = [
      ('Commandes en ligne', NotifEvent.nouvelleCommandeEnLigne),
      ('Commandes urgentes', NotifEvent.commandeUrgente),
      ('Commande prête',     NotifEvent.commandePrete),
      ('Paiement',           NotifEvent.paiementEnregistre),
      ('Réservation',        NotifEvent.nouvelleReservation),
      ('Stock faible',       NotifEvent.stockFaible),
      ('Rupture stock',      NotifEvent.ruptureStock),
      ('Système',            NotifEvent.notificationSysteme),
    ];
    return groups.map((g) {
      final (label, event) = g;
      final curSound = s.getPerTypeSound(event);
      return _PerTypeSoundRow(
        label: label,
        event: event,
        curSound: curSound,
        onSelect: (sound) async { await s.setPerTypeSound(event, sound); setState(() {}); },
        onTest: (sound) { s.unlockAudio(); s.testSound(sound); },
      );
    }).toList();
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Carte notification universelle
// ══════════════════════════════════════════════════════════════════════════

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onRead;
  final bool highlight; // true = onglet "Non lues" (mise en évidence plus forte)

  const _NotifCard({required this.notif, required this.onRead, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    final catColor = _catColor(notif.event.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread
            ? catColor.withValues(alpha: highlight ? 0.07 : 0.04)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? catColor.withValues(alpha: highlight ? 0.5 : 0.3)
              : const Color(0xFF2A2A5A),
          width: isUnread && highlight ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icône catégorie ────────────────────────────────────
            Container(
              width: 38, height: 38,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(notif.event.icon, style: const TextStyle(fontSize: 17)),
              ),
            ),

            // ── Contenu ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre de l'événement
                  Row(children: [
                    Expanded(
                      child: Text(
                        notif.event.label,
                        style: TextStyle(
                          color: isUnread ? catColor : AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    // Indicateur "non lu"
                    if (isUnread)
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: catColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  // Message
                  Text(
                    notif.message,
                    style: TextStyle(
                      color: isUnread ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Horodatage + bouton Lu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDt(notif.dateTime),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                      if (isUnread)
                        GestureDetector(
                          onTap: onRead,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: catColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check, size: 11, color: catColor),
                              const SizedBox(width: 4),
                              Text('Marquer lu',
                                  style: TextStyle(
                                      color: catColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        )
                      else
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle, color: AppTheme.success, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            notif.readAt != null ? _formatDt(notif.readAt!) : 'Lu',
                            style: const TextStyle(color: AppTheme.success, fontSize: 10),
                          ),
                        ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'online':       return AppTheme.primary;
      case 'cuisine':      return const Color(0xFFFF7043);
      case 'caisse':       return const Color(0xFF66BB6A);
      case 'stock':        return const Color(0xFFFFCA28);
      case 'personnel':    return const Color(0xFF42A5F5);
      case 'reservations': return const Color(0xFFAB47BC);
      default:             return AppTheme.textSecondary;
    }
  }

  String _formatDt(DateTime dt) => formatDurationHuman(dt);
}

// ── Bouton "Marquer tout comme lu" proéminent ────────────────────────────

class _MarkAllReadButton extends StatelessWidget {
  final int count;
  final Future<void> Function() onTap;
  const _MarkAllReadButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Tout marquer comme lu ($count)',
              style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget sonnerie par type ──────────────────────────────────────────────

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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(event.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: kSoundOptions.map((opt) {
                final isSelected = curSound == opt.id;
                return GestureDetector(
                  onTap: () => onSelect(opt.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : const Color(0xFF1E1E3A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        opt.label,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () => onTest(opt.id),
                        child: Icon(Icons.play_arrow,
                            size: 13,
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

// ── Bannières ─────────────────────────────────────────────────────────────

class _UrgentBanner extends StatelessWidget {
  final NotificationService svc;
  const _UrgentBanner({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.alarm, color: AppTheme.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🚨 Alerte urgente active',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(
              'Sonnerie répétée toutes les ${intervalLabel(svc.repeatIntervalSec)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => svc.acknowledgeUrgent(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Arrêter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _AudioUnlockBanner extends StatelessWidget {
  final NotificationService svc;
  const _AudioUnlockBanner({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.volume_off, color: AppTheme.warning, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Autorisation audio requise',
                style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 12)),
            SizedBox(height: 2),
            Text('Le navigateur bloque l\'audio. Appuyez pour autoriser.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => svc.unlockAudio(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warning,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Activer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Widgets réutilisables ─────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;
  final bool small;
  const _UnreadBadge(this.count, {this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7, vertical: small ? 1 : 3),
      decoration: BoxDecoration(
        color: AppTheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
            color: Colors.white,
            fontSize: small ? 9 : 11,
            fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Row(children: [
        Icon(icon, size: 13, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ]),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon, required this.iconColor, required this.title,
    required this.subtitle, required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primary,
          activeTrackColor: AppTheme.primary.withValues(alpha: 0.3),
        ),
      ]),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double value;
  final double min, max;
  final int divisions;
  final bool displayPercent;
  final String? displayValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _VolumeRow({
    required this.icon, required this.iconColor, required this.label,
    required this.value,
    this.min = 0.0, this.max = 1.0, this.divisions = 9,
    this.displayPercent = true, this.displayValue,
    required this.onChanged, required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final val = displayValue ?? (displayPercent
        ? '${((value - min) / (max - min) * 100).round()} %'
        : value.toStringAsFixed(2));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(val, style: TextStyle(
                color: iconColor, fontSize: 11, fontWeight: FontWeight.w700)),
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
            value:       value.clamp(min, max),
            min:         min,
            max:         max,
            divisions:   divisions,
            onChanged:   onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ]),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  const _DropdownRow({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.items,
    required this.labelBuilder, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
          ]),
        ),
        DropdownButton<T>(
          value: value,
          dropdownColor: AppTheme.surfaceLight,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: items.map((i) => DropdownMenuItem<T>(
            value: i,
            child: Text(labelBuilder(i)),
          )).toList(),
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Color(0xFF2A2A5A), height: 1, indent: 14, endIndent: 14);
}
