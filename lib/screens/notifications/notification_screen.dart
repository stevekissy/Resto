import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NotificationScreen — Paramètres et historique des notifications sonores
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
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceLight,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_svc.unreadCount > 0)
            TextButton.icon(
              onPressed: () { _svc.markAllRead(); },
              icon: const Icon(Icons.done_all, color: AppTheme.success, size: 18),
              label: const Text('Tout lire', style: TextStyle(color: AppTheme.success, fontSize: 12)),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.settings, size: 16),
                const SizedBox(width: 6),
                const Text('Paramètres'),
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

// ── Onglet Paramètres ─────────────────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  final NotificationService svc;
  const _SettingsTab({required this.svc});
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  NotificationService get s => widget.svc;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Alerte déblocage audio ──
        if (!s.isAudioUnlocked) ...[
          _AudioUnlockBanner(svc: s),
          const SizedBox(height: 12),
        ],

        // ── Alerte urgence active ──
        if (s.urgentActive) ...[
          _UrgentActiveBanner(svc: s),
          const SizedBox(height: 12),
        ],

        // ── Section activation générale ──
        _SectionHeader('Sons et alertes'),
        GlassCard(
          child: Column(children: [
            _SwitchRow(
              icon: Icons.volume_up,
              iconColor: AppTheme.primary,
              title: 'Activer les sons',
              subtitle: 'Active toutes les sonneries de l\'application',
              value: s.soundEnabled,
              onChanged: (v) async { await s.setSoundEnabled(v); setState(() {}); },
            ),
            const Divider(color: Color(0xFF2A2A5A), height: 1),
            _SwitchRow(
              icon: Icons.repeat,
              iconColor: AppTheme.warning,
              title: 'Répéter les alertes importantes',
              subtitle: 'Commandes urgentes et ruptures de stock (toutes les 10s)',
              value: s.repeatImportant,
              onChanged: (v) async { await s.setRepeatImportant(v); setState(() {}); },
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Sélection de sonnerie ──
        _SectionHeader('Sonnerie par défaut'),
        GlassCard(
          child: Column(children: [
            ...kSoundOptions.map((opt) => _SoundOptionRow(
              opt: opt,
              isSelected: s.selectedSound == opt.id,
              onSelect: () async {
                await s.setSelectedSound(opt.id);
                setState(() {});
              },
              onTest: () => s.testSound(opt.id),
            )),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Volume ──
        _SectionHeader('Volume'),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.volume_down, color: AppTheme.textSecondary, size: 20),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: const Color(0xFF2A2A5A),
                        thumbColor: AppTheme.primary,
                        overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: s.volume,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        onChanged: (v) async {
                          await s.setVolume(v);
                          setState(() {});
                        },
                        onChangeEnd: (_) => s.testSound(),
                      ),
                    ),
                  ),
                  const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
                ]),
                Center(
                  child: Text(
                    '${(s.volume * 100).round()} %',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Catégories ──
        _SectionHeader('Catégories de notifications'),
        GlassCard(
          child: Column(children: [
            _SwitchRow(
              icon: Icons.restaurant,
              iconColor: const Color(0xFFFF7043),
              title: 'Notifications cuisine',
              subtitle: 'Nouvelles commandes, urgences, plats prêts',
              value: s.notifCuisine,
              onChanged: (v) async { await s.setNotifCuisine(v); setState(() {}); },
            ),
            const Divider(color: Color(0xFF2A2A5A), height: 1),
            _SwitchRow(
              icon: Icons.point_of_sale,
              iconColor: const Color(0xFF66BB6A),
              title: 'Notifications caisse',
              subtitle: 'Paiements enregistrés',
              value: s.notifCaisse,
              onChanged: (v) async { await s.setNotifCaisse(v); setState(() {}); },
            ),
            const Divider(color: Color(0xFF2A2A5A), height: 1),
            _SwitchRow(
              icon: Icons.inventory_2,
              iconColor: const Color(0xFFFFCA28),
              title: 'Notifications stock',
              subtitle: 'Stock faible et ruptures',
              value: s.notifStock,
              onChanged: (v) async { await s.setNotifStock(v); setState(() {}); },
            ),
            const Divider(color: Color(0xFF2A2A5A), height: 1),
            _SwitchRow(
              icon: Icons.people,
              iconColor: const Color(0xFF42A5F5),
              title: 'Notifications personnel',
              subtitle: 'Contrats, salaires à payer',
              value: s.notifPersonnel,
              onChanged: (v) async { await s.setNotifPersonnel(v); setState(() {}); },
            ),
            const Divider(color: Color(0xFF2A2A5A), height: 1),
            _SwitchRow(
              icon: Icons.event_note,
              iconColor: const Color(0xFFAB47BC),
              title: 'Notifications réservations',
              subtitle: 'Nouvelles réservations et rappels',
              value: s.notifReservations,
              onChanged: (v) async { await s.setNotifReservations(v); setState(() {}); },
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Tester le son ──
        _SectionHeader('Test sonore'),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Appuyez sur le bouton ci-dessous pour tester la sonnerie sélectionnée.',
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
                    label: const Text('▶  Tester le son', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Onglet Historique ─────────────────────────────────────────────────────

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
          notif: n,
          onRead: () => svc.markRead(n.id),
        );
      },
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────

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
                  child: const Text('Lu', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
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
      default:             return AppTheme.primary;
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)   return 'À l\'instant';
    if (diff.inMinutes < 60)   return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)     return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1)      return 'Hier ${_hm(dt)}';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${_hm(dt)}';
  }

  String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

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
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Autorisation audio requise', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            const Text('Le navigateur bloque l\'audio. Appuyez sur "Activer" pour autoriser les sons.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
          child: const Text('Activer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🚨 Alerte urgente active', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
            SizedBox(height: 2),
            Text('La sonnerie se répète toutes les 10 secondes. Consultez la notification pour l\'arrêter.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primary,
        ),
      ]),
    );
  }
}

class _SoundOptionRow extends StatelessWidget {
  final SoundOption opt;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onTest;
  const _SoundOptionRow({
    required this.opt, required this.isSelected,
    required this.onSelect, required this.onTest,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Radio<bool>(
            value: true,
            groupValue: isSelected,
            onChanged: (_) => onSelect(),
            activeColor: AppTheme.primary,
          ),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(opt.label, style: TextStyle(
              color: isSelected ? AppTheme.primary : Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            )),
            Text(opt.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ])),
          IconButton(
            onPressed: onTest,
            icon: Icon(Icons.play_circle_outline,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              size: 24,
            ),
            tooltip: 'Tester',
          ),
        ]),
      ),
    );
  }
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
      decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}
