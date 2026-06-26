import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

// Import conditionnel : dart:js uniquement sur web
// ignore: uri_does_not_exist
import '../../services/print_web_stub.dart'
    if (dart.library.js) '../../services/print_web_impl.dart' as print_web;

// ═════════════════════════════════════════════════════════════════════════════
//  CambuseInventoryTab — Onglet Inventaire du module Cambuse
//  Logique identique à InventoryTab (stock cuisine) mais sur collections
//  cambuse_inventory_sessions / cambuse_inventory_items (séparées).
// ═════════════════════════════════════════════════════════════════════════════

class CambuseInventoryTab extends StatefulWidget {
  const CambuseInventoryTab({super.key});

  @override
  State<CambuseInventoryTab> createState() => _CambuseInventoryTabState();
}

class _CambuseInventoryTabState extends State<CambuseInventoryTab> {
  List<CambuseInventorySession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    try {
      final sessions =
          await context.read<AppProvider>().fetchCambuseInventorySessions();
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Créer une nouvelle session ──────────────────────────────────────────────
  Future<void> _createSession() async {
    final provider = context.read<AppProvider>();
    if (provider.cambuseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune boisson dans la cambuse à inventorier'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    final siteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.playlist_add_check, color: Color(0xFF42A5F5), size: 22),
            SizedBox(width: 8),
            Text('Nouvel inventaire Cambuse'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.liquor, color: Color(0xFF42A5F5), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${provider.cambuseItems.length} boisson(s) seront inventoriées',
                    style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: siteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Site / Point de vente',
                hintText: 'Ex: Bar principal',
                prefixIcon: Icon(Icons.storefront_outlined,
                    color: Color(0xFF42A5F5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Démarrer'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final session = await provider.createCambuseInventorySession(
          site: siteCtrl.text.trim().isEmpty
              ? 'Cambuse'
              : siteCtrl.text.trim(),
        );
        if (mounted) {
          _loadSessions();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _CambuseInventorySessionScreen(session: session),
            ),
          ).then((_) => _loadSessions());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  // ── Supprimer une session ───────────────────────────────────────────────────
  Future<void> _deleteSession(CambuseInventorySession session) async {
    if (session.status == CambuseInventoryStatus.inProgress) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Terminez ou annulez la session avant de la supprimer'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Supprimer cette session ?'),
        content: Text(
            'Session du ${_fmtDate(session.date)} — ${session.site}',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context
          .read<AppProvider>()
          .deleteCambuseInventorySession(session.id);
      _loadSessions();
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── En-tête ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A5A))),
            ),
            child: Row(
              children: [
                const Icon(Icons.playlist_add_check,
                    color: Color(0xFF42A5F5), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventaires Cambuse',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text('Contrôle physique des boissons',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _createSession,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouvel inventaire',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ],
            ),
          ),

          // ── Liste sessions ────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                    ? const EmptyState(
                        icon: Icons.playlist_add_check,
                        title: 'Aucune session d\'inventaire',
                        subtitle:
                            'Créez votre premier inventaire Cambuse',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSessions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _sessions.length,
                          itemBuilder: (ctx, i) => _CambuseSessionCard(
                            session: _sessions[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    _CambuseInventorySessionScreen(
                                        session: _sessions[i]),
                              ),
                            ).then((_) => _loadSessions()),
                            onDelete: () =>
                                _deleteSession(_sessions[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Carte de session dans la liste
// ═════════════════════════════════════════════════════════════════════════════

class _CambuseSessionCard extends StatelessWidget {
  final CambuseInventorySession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CambuseSessionCard(
      {required this.session,
      required this.onTap,
      required this.onDelete});

  Color get _statusColor {
    switch (session.status) {
      case CambuseInventoryStatus.inProgress:
        return AppTheme.warning;
      case CambuseInventoryStatus.completed:
        return AppTheme.success;
      case CambuseInventoryStatus.cancelled:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = session.date;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
        ' ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: _statusColor.withValues(alpha: 0.35)),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.playlist_add_check,
                    color: _statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    Text(
                        session.site.isEmpty
                            ? 'Cambuse'
                            : session.site,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12)),
                    Text(
                        'Responsable : ${session.responsibleName}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(
                      label: session.status.label,
                      color: _statusColor,
                      fontSize: 10),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline,
                        color: AppTheme.error, size: 16),
                  ),
                ],
              ),
            ],
          ),
          if (session.status == CambuseInventoryStatus.completed) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF2A2A5A)),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatPill(
                    label: '${session.totalProducts}',
                    sub: 'Boissons',
                    color: const Color(0xFF42A5F5)),
                const SizedBox(width: 8),
                _StatPill(
                    label: '${session.totalCounted}',
                    sub: 'Comptées',
                    color: AppTheme.success),
                const SizedBox(width: 8),
                _StatPill(
                    label: '${session.totalMissing}',
                    sub: 'Manquantes',
                    color: AppTheme.error),
                const SizedBox(width: 8),
                _StatPill(
                    label: '${session.totalSurplus}',
                    sub: 'Surplus',
                    color: AppTheme.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;

  const _StatPill(
      {required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          Text(sub,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Écran de saisie d'une session d'inventaire Cambuse
// ═════════════════════════════════════════════════════════════════════════════

class _CambuseInventorySessionScreen extends StatefulWidget {
  final CambuseInventorySession session;

  const _CambuseInventorySessionScreen({required this.session});

  @override
  State<_CambuseInventorySessionScreen> createState() =>
      _CambuseInventorySessionScreenState();
}

class _CambuseInventorySessionScreenState
    extends State<_CambuseInventorySessionScreen> {
  List<CambuseInventoryItem> _items = [];
  bool _loading = true;
  String _filterStatus   = 'all';
  String _filterCategory = 'Tous';
  String _searchQuery    = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await context
          .read<AppProvider>()
          .fetchCambuseInventoryItems(widget.session.id);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Getters filtres ─────────────────────────────────────────────────────────
  List<String> get _categories {
    final cats = _items.map((i) => i.category).toSet().toList()..sort();
    return ['Tous', ...cats];
  }

  List<CambuseInventoryItem> get _filtered {
    var list = List<CambuseInventoryItem>.from(_items);

    if (_filterCategory != 'Tous') {
      list = list.where((i) => i.category == _filterCategory).toList();
    }
    switch (_filterStatus) {
      case 'compliant':
        list = list
            .where((i) =>
                i.status == CambuseInventoryItemStatus.compliant)
            .toList();
        break;
      case 'missing':
        list = list
            .where((i) =>
                i.status == CambuseInventoryItemStatus.missing)
            .toList();
        break;
      case 'surplus':
        list = list
            .where((i) =>
                i.status == CambuseInventoryItemStatus.surplus)
            .toList();
        break;
      case 'not_counted':
        list = list.where((i) => i.countedQty == null).toList();
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((i) =>
              i.cambuseItemName.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  int get _countedCount =>
      _items.where((i) => i.countedQty != null).length;
  int get _missingCount => _items
      .where((i) => i.status == CambuseInventoryItemStatus.missing)
      .length;
  int get _surplusCount => _items
      .where((i) => i.status == CambuseInventoryItemStatus.surplus)
      .length;
  int get _compliantCount => _items
      .where((i) => i.status == CambuseInventoryItemStatus.compliant)
      .length;

  // ── Terminer la session ────────────────────────────────────────────────────
  Future<void> _completeSession() async {
    final provider = context.read<AppProvider>();
    final role = provider.currentUser?.role;
    final canValidate =
        role == UserRole.admin || role == UserRole.manager;

    if (!canValidate) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Seul un admin ou manager peut terminer l\'inventaire'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    final uncounted = _items.where((i) => i.countedQty == null).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppTheme.success, size: 22),
            SizedBox(width: 8),
            Text('Terminer l\'inventaire Cambuse ?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (uncounted > 0)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$uncounted boisson${uncounted > 1 ? 's' : ''} non comptée${uncounted > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppTheme.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            _SummaryRow(
                label: 'Total boissons',
                value: '${_items.length}',
                color: const Color(0xFF42A5F5)),
            _SummaryRow(
                label: 'Comptées',
                value: '$_countedCount',
                color: AppTheme.success),
            _SummaryRow(
                label: 'Conformes',
                value: '$_compliantCount',
                color: AppTheme.success),
            _SummaryRow(
                label: 'Manquantes',
                value: '$_missingCount',
                color: AppTheme.error),
            _SummaryRow(
                label: 'Surplus',
                value: '$_surplusCount',
                color: AppTheme.warning),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Terminer'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.completeCambuseInventorySession(
          widget.session.id, _items);
      setState(
          () => widget.session.status = CambuseInventoryStatus.completed);
      if (mounted) _proposeCorrections();
    }
  }

  // ── Proposer corrections ───────────────────────────────────────────────────
  Future<void> _proposeCorrections() async {
    final itemsWithGap =
        _items.where((i) => i.countedQty != null && i.gap != 0).toList();
    if (itemsWithGap.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inventaire terminé — aucun écart à corriger'),
          backgroundColor: AppTheme.success,
        ));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sync_alt, color: Color(0xFF42A5F5), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text('Corriger les écarts Cambuse ?',
                  style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${itemsWithGap.length} boisson${itemsWithGap.length > 1 ? 's' : ''} ont un écart.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Cette action va modifier les quantités en cambuse et créer des mouvements de traçabilité. Opération irréversible.',
                style:
                    TextStyle(color: AppTheme.warning, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Plus tard')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Appliquer corrections'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<AppProvider>().applyCambuseInventoryCorrections(
              sessionId: widget.session.id,
              items: _items,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Corrections appliquées à la Cambuse'),
            backgroundColor: AppTheme.success,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  // ── Impression PDF ─────────────────────────────────────────────────────────
  void _printReport() {
    print_web.webOpenPrintWindow(_buildReportHtml());
  }

  String _buildReportHtml() {
    final d = widget.session.date;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    // Grouper par catégorie pour le rapport
    final byCategory = <String, List<CambuseInventoryItem>>{};
    for (final item in _items) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }
    final categories = byCategory.keys.toList()..sort();

    final tableRows = StringBuffer();
    for (final cat in categories) {
      // Ligne d'en-tête de catégorie
      tableRows.write('''
      <tr style="background:#E8EAF6">
        <td colspan="8" style="font-weight:bold;color:#1a237e;padding:6px 8px;font-size:11px">
          🍺 ${_escHtml(cat)}
        </td>
      </tr>''');

      for (final item in byCategory[cat]!) {
        final gapStr = item.countedQty == null
            ? '—'
            : (item.gap >= 0
                ? '+${item.gap}'
                : '${item.gap}');
        final gapValueStr = item.countedQty == null
            ? '—'
            : '${item.gapValue.toStringAsFixed(0)} F';
        final statusLabel = item.status.label;
        String statusColor = '#888888';
        if (item.status == CambuseInventoryItemStatus.compliant)
          statusColor = '#4CAF50';
        else if (item.status == CambuseInventoryItemStatus.missing)
          statusColor = '#f44336';
        else if (item.status == CambuseInventoryItemStatus.surplus)
          statusColor = '#FF9800';

        tableRows.write('''
        <tr>
          <td>${_escHtml(item.cambuseItemName)}</td>
          <td>${_escHtml(item.category)}</td>
          <td>${_escHtml(item.unit)}</td>
          <td style="text-align:right">${item.theoreticalQty}</td>
          <td style="text-align:right">${item.countedQty ?? '—'}</td>
          <td style="text-align:right;font-weight:bold;color:${item.gap != 0 ? (item.gap < 0 ? '#f44336' : '#FF9800') : '#4CAF50'}">$gapStr</td>
          <td style="text-align:right;color:#666">$gapValueStr</td>
          <td style="text-align:center;color:$statusColor;font-weight:bold">$statusLabel</td>
          <td>${_escHtml(item.comment)}</td>
        </tr>''');
      }
    }

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>Rapport Inventaire Cambuse — $dateStr</title>
<style>
  body { font-family: Arial, sans-serif; margin: 0; padding: 20px; color: #222; font-size: 11px; }
  .header { text-align: center; margin-bottom: 20px; border-bottom: 2px solid #1565C0; padding-bottom: 12px; }
  .header h1 { margin: 0 0 4px; font-size: 20px; color: #1565C0; letter-spacing: 2px; }
  .header h2 { margin: 0 0 4px; font-size: 14px; color: #444; font-weight: normal; }
  .header p  { margin: 2px 0; color: #666; font-size: 11px; }
  .meta { display: flex; gap: 24px; margin-bottom: 14px; padding: 10px 14px; background: #f5f5f5; border-radius: 6px; }
  .meta div { flex: 1; }
  .meta label { font-size: 10px; color: #888; display: block; }
  .meta span  { font-weight: bold; color: #222; font-size: 12px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
  th { background: #1565C0; color: white; padding: 7px 6px; font-size: 10px; text-align: left; }
  td { padding: 5px 6px; border-bottom: 1px solid #eee; vertical-align: top; }
  tr:nth-child(even) td { background: #fafafa; }
  .summary { display: flex; gap: 14px; margin-bottom: 20px; }
  .summary .box { flex: 1; text-align: center; padding: 10px; border-radius: 6px; }
  .summary .box .num { font-size: 22px; font-weight: bold; display: block; }
  .summary .box .lbl { font-size: 10px; color: #666; }
  .box-blue   { background: #E3F2FD; }
  .box-green  { background: #E8F5E9; }
  .box-red    { background: #FFEBEE; }
  .box-orange { background: #FFF3E0; }
  .box-grey   { background: #F5F5F5; }
  .signatures { display: flex; gap: 40px; margin-top: 30px; }
  .sig { flex: 1; border-top: 1px solid #999; padding-top: 6px; text-align: center; font-size: 10px; color: #555; }
  @media print { button { display: none !important; } }
</style>
</head>
<body>
<div class="header">
  <h1>🍺 SANKADIOKRO — CAMBUSE</h1>
  <h2>Rapport d'inventaire Cambuse</h2>
  <p>Date : $dateStr &nbsp;|&nbsp; Site : ${_escHtml(widget.session.site)}</p>
  <p>Responsable : ${_escHtml(widget.session.responsibleName)}</p>
</div>

<div class="meta">
  <div><label>SESSION</label><span>${widget.session.id.substring(0, 8).toUpperCase()}</span></div>
  <div><label>DATE</label><span>$dateStr</span></div>
  <div><label>STATUT</label><span>${widget.session.status.label.toUpperCase()}</span></div>
  <div><label>RESPONSABLE</label><span>${_escHtml(widget.session.responsibleName)}</span></div>
</div>

<div class="summary">
  <div class="box box-blue">   <span class="num">${_items.length}</span><span class="lbl">Total boissons</span></div>
  <div class="box box-green">  <span class="num">$_compliantCount</span><span class="lbl">Conformes</span></div>
  <div class="box box-grey">   <span class="num">${_items.where((i) => i.countedQty == null).length}</span><span class="lbl">Non comptées</span></div>
  <div class="box box-red">    <span class="num">$_missingCount</span><span class="lbl">Manquantes</span></div>
  <div class="box box-orange"> <span class="num">$_surplusCount</span><span class="lbl">Surplus</span></div>
</div>

<table>
<thead>
  <tr>
    <th>Boisson</th>
    <th>Catégorie</th>
    <th>Unité</th>
    <th>Stock théorique</th>
    <th>Qté comptée</th>
    <th>Écart (unités)</th>
    <th>Valeur écart</th>
    <th>Statut</th>
    <th>Remarque</th>
  </tr>
</thead>
<tbody>
$tableRows
</tbody>
</table>

<div class="signatures">
  <div class="sig">Signature du responsable<br><br><br>${_escHtml(widget.session.responsibleName)}</div>
  <div class="sig">Signature du manager<br><br><br>_______________________</div>
</div>

<div style="text-align:center; margin-top:30px">
  <button onclick="window.print()"
    style="background:#1565C0;color:white;border:none;padding:10px 28px;border-radius:6px;font-size:13px;cursor:pointer">
    🖨️ Imprimer / Télécharger PDF
  </button>
</div>
</body>
</html>''';
  }

  String _escHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── Build principal ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isCompleted =
        widget.session.status == CambuseInventoryStatus.completed;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventaire Cambuse',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(widget.session.site,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          // PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: Color(0xFF42A5F5)),
            tooltip: 'Imprimer rapport PDF',
            onPressed: _printReport,
          ),
          // Terminer
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _completeSession,
                icon: const Icon(Icons.check_circle_outline,
                    size: 16, color: AppTheme.success),
                label: const Text('Terminer',
                    style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  backgroundColor:
                      AppTheme.success.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Résumé progression ────────────────────────────────────
          if (!_loading)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: AppTheme.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      _MiniStat(
                          label: '${_items.length}',
                          sub: 'Total',
                          color: const Color(0xFF42A5F5)),
                      const SizedBox(width: 6),
                      _MiniStat(
                          label: '$_countedCount',
                          sub: 'Comptées',
                          color: const Color(0xFF42A5F5)),
                      const SizedBox(width: 6),
                      _MiniStat(
                          label: '$_compliantCount',
                          sub: 'Conformes',
                          color: AppTheme.success),
                      const SizedBox(width: 6),
                      _MiniStat(
                          label: '$_missingCount',
                          sub: 'Manquantes',
                          color: AppTheme.error),
                      const SizedBox(width: 6),
                      _MiniStat(
                          label: '$_surplusCount',
                          sub: 'Surplus',
                          color: AppTheme.warning),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _items.isEmpty
                          ? 0
                          : _countedCount / _items.length,
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF42A5F5)),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),

          // ── Filtres ───────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une boisson…',
                    prefixIcon: const Icon(Icons.search,
                        color: AppTheme.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppTheme.textSecondary, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FChip(
                          label: 'Tous',
                          selected: _filterStatus == 'all',
                          onTap: () =>
                              setState(() => _filterStatus = 'all'),
                          color: const Color(0xFF42A5F5)),
                      const SizedBox(width: 6),
                      _FChip(
                          label: 'Conformes',
                          selected: _filterStatus == 'compliant',
                          onTap: () => setState(
                              () => _filterStatus = 'compliant'),
                          color: AppTheme.success),
                      const SizedBox(width: 6),
                      _FChip(
                          label: 'Manquantes',
                          selected: _filterStatus == 'missing',
                          onTap: () =>
                              setState(() => _filterStatus = 'missing'),
                          color: AppTheme.error),
                      const SizedBox(width: 6),
                      _FChip(
                          label: 'Surplus',
                          selected: _filterStatus == 'surplus',
                          onTap: () =>
                              setState(() => _filterStatus = 'surplus'),
                          color: AppTheme.warning),
                      const SizedBox(width: 6),
                      _FChip(
                          label: 'Non comptées',
                          selected: _filterStatus == 'not_counted',
                          onTap: () => setState(
                              () => _filterStatus = 'not_counted'),
                          color: AppTheme.textSecondary),
                      if (_categories.length > 2) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                            width: 1,
                            height: 22,
                            child: VerticalDivider(
                                color: Color(0xFF2A2A5A))),
                        const SizedBox(width: 10),
                        ..._categories.map((cat) => Padding(
                              padding:
                                  const EdgeInsets.only(right: 6),
                              child: _FChip(
                                label: cat,
                                selected: _filterCategory == cat,
                                onTap: () => setState(
                                    () => _filterCategory = cat),
                                color: const Color(0xFF42A5F5),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF2A2A5A)),

          // ── Liste articles ────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Aucune boisson trouvée',
                        subtitle: 'Modifiez les filtres',
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) =>
                            _CambuseInventoryLineCard(
                          item: _filtered[i],
                          readOnly: isCompleted,
                          onSaved: (updated) {
                            final idx = _items.indexWhere(
                                (x) => x.id == updated.id);
                            if (idx >= 0) {
                              setState(() {
                                _items[idx].countedQty =
                                    updated.countedQty;
                                _items[idx].comment =
                                    updated.comment;
                              });
                            }
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini stat ─────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;

  const _MiniStat(
      {required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            Text(sub,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ─── Chip filtre ───────────────────────────────────────────────────────────────
class _FChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : const Color(0xFF2A2A5A)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Résumé row ────────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Carte de ligne d'inventaire Cambuse (saisie quantité réelle)
// ═════════════════════════════════════════════════════════════════════════════

class _CambuseInventoryLineCard extends StatefulWidget {
  final CambuseInventoryItem item;
  final bool readOnly;
  final ValueChanged<CambuseInventoryItem> onSaved;

  const _CambuseInventoryLineCard({
    required this.item,
    required this.readOnly,
    required this.onSaved,
  });

  @override
  State<_CambuseInventoryLineCard> createState() =>
      _CambuseInventoryLineCardState();
}

class _CambuseInventoryLineCardState
    extends State<_CambuseInventoryLineCard> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _commentCtrl;
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.item.countedQty?.toString() ?? '',
    );
    _commentCtrl =
        TextEditingController(text: widget.item.comment);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.item.status) {
      case CambuseInventoryItemStatus.notCounted:
        return AppTheme.textSecondary;
      case CambuseInventoryItemStatus.compliant:
        return AppTheme.success;
      case CambuseInventoryItemStatus.missing:
        return AppTheme.error;
      case CambuseInventoryItemStatus.surplus:
        return AppTheme.warning;
    }
  }

  Future<void> _save() async {
    final raw = _qtyCtrl.text.replaceAll(',', '.').trim();
    final counted = int.tryParse(raw);
    if (counted == null || counted < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entrez un nombre entier valide (≥ 0)'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      widget.item.countedQty = counted;
      widget.item.comment = _commentCtrl.text;
      await context
          .read<AppProvider>()
          .saveCambuseInventoryLine(widget.item);
      widget.onSaved(widget.item);
      if (mounted) {
        setState(() {
          _saving = false;
          _expanded = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.item.cambuseItemName} — ligne validée'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isCounted = item.countedQty != null;
    final gap = isCounted ? item.gap : null;
    final gapStr = gap == null
        ? '—'
        : (gap >= 0 ? '+$gap' : '$gap');
    final gapValueStr = gap == null
        ? ''
        : ' (${item.gapValue.toStringAsFixed(0)} F CFA)';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCounted
              ? _statusColor.withValues(alpha: 0.45)
              : const Color(0xFF2A2A5A),
          width: isCounted ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Ligne principale ────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.readOnly
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Icône statut
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color:
                          _statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCounted
                          ? (item.status ==
                                  CambuseInventoryItemStatus
                                      .compliant
                              ? Icons.check_circle
                              : Icons.swap_horiz)
                          : Icons.radio_button_unchecked,
                      color: _statusColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Infos boisson
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.cambuseItemName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.category} • ${item.unit}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11),
                        ),
                        if (item.unitCost > 0)
                          Text(
                            '${item.unitCost.toStringAsFixed(0)} F CFA / unité',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Colonnes chiffres
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Théo: ${item.theoreticalQty}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10),
                      ),
                      if (isCounted)
                        Text(
                          'Compté: ${item.countedQty}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      if (isCounted)
                        Text(
                          'Écart: $gapStr$gapValueStr',
                          style: TextStyle(
                            color: gap == 0
                                ? AppTheme.success
                                : (gap! < 0
                                    ? AppTheme.error
                                    : AppTheme.warning),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Badge + expand
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        label: item.status.label,
                        color: _statusColor,
                        fontSize: 9,
                      ),
                      if (!widget.readOnly) ...[
                        const SizedBox(height: 4),
                        Icon(
                          _expanded
                              ? Icons.expand_less
                              : Icons.edit_outlined,
                          color: AppTheme.textSecondary,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Zone saisie dépliable ─────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded && !widget.readOnly
                ? Container(
                    padding:
                        const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        const Divider(
                            height: 1,
                            color: Color(0xFF2A2A5A)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            // Champ quantité (entier pour boissons)
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _qtyCtrl,
                                keyboardType:
                                    TextInputType.number,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14),
                                decoration: InputDecoration(
                                  labelText:
                                      'Quantité comptée *',
                                  suffixText: item.unit,
                                  suffixStyle: const TextStyle(
                                      color:
                                          Color(0xFF42A5F5),
                                      fontSize: 12),
                                  prefixIcon: const Icon(
                                      Icons.liquor,
                                      color:
                                          Color(0xFF42A5F5),
                                      size: 18),
                                  contentPadding:
                                      const EdgeInsets
                                          .symmetric(
                                              vertical: 10,
                                              horizontal: 12),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Champ commentaire / remarque
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _commentCtrl,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12),
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Remarque',
                                  prefixIcon: Icon(
                                      Icons.notes,
                                      color: AppTheme
                                          .textSecondary,
                                      size: 16),
                                  contentPadding:
                                      EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 12),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color:
                                                Colors.white))
                                : const Icon(Icons.check,
                                    size: 16),
                            label: Text(_saving
                                ? 'Enregistrement…'
                                : 'Valider la ligne'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF42A5F5),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          9)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
