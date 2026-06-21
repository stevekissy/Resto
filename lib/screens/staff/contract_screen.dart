import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';

// ══════════════════════════════════════════════════════════════════════
//  CONTRACT SCREEN — Gestion des contrats employés
//  Intégré comme onglet "Contrats" dans StaffScreen
// ══════════════════════════════════════════════════════════════════════

class ContractTab extends StatefulWidget {
  const ContractTab({super.key});

  @override
  State<ContractTab> createState() => _ContractTabState();
}

class _ContractTabState extends State<ContractTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _filterStatus = 'Tous';

  final _statusFilters = ['Tous', 'Actif', 'Bientôt expiré', 'Expiré', 'Renouvelé', 'Non renouvelé'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final alerts = provider.contractAlerts.where((a) => !a.isRead).toList();

    return Scaffold(
      body: Column(
        children: [
          // ── Bandeau alertes ──────────────────────────────────────────
          if (alerts.isNotEmpty) _AlertBanner(alerts: alerts),

          // ── Sous-onglets ─────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(text: 'Contrats', icon: const Icon(Icons.description, size: 14)),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 14),
                      const SizedBox(width: 4),
                      const Text('Historique'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Corps ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ContractListTab(
                  searchQuery: _searchQuery,
                  filterStatus: _filterStatus,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onFilterChanged: (v) => setState(() => _filterStatus = v),
                  statusFilters: _statusFilters,
                ),
                const _HistoryTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = MediaQuery.of(context).size.width >= 600;
          return isWide
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddContractDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau contrat'),
                  backgroundColor: AppTheme.primary,
                )
              : FloatingActionButton(
                  onPressed: () => _showAddContractDialog(context, provider),
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.add),
                );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── Dialog Ajouter contrat ───────────────────────────────────────────
  void _showAddContractDialog(BuildContext context, AppProvider provider) {
    final employees = provider.users.where((u) => u.isActive).toList();
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun employé actif trouvé.'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _ContractFormDialog(
        employees: employees,
        onSave: (contract) async {
          try {
            await provider.addContract(contract);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contrat ajouté avec succès.'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
        createdBy: provider.currentUser?.name ?? 'Inconnu',
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  LISTE DES CONTRATS
// ══════════════════════════════════════════════════════════════════════
class _ContractListTab extends StatelessWidget {
  final String searchQuery;
  final String filterStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final List<String> statusFilters;

  const _ContractListTab({
    required this.searchQuery,
    required this.filterStatus,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.statusFilters,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    var contracts = provider.contracts;

    // Filtre statut
    if (filterStatus != 'Tous') {
      contracts = contracts.where((c) {
        final lbl = c.computedStatus.label;
        return lbl == filterStatus;
      }).toList();
    }

    // Recherche
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      contracts = contracts.where((c) =>
        c.employeeName.toLowerCase().contains(q) ||
        c.poste.toLowerCase().contains(q) ||
        c.type.label.toLowerCase().contains(q)
      ).toList();
    }

    // Tri : alertes d'abord, puis alphabétique
    contracts.sort((a, b) {
      final sa = a.computedStatus.index;
      final sb = b.computedStatus.index;
      if (sa != sb) return sa.compareTo(sb);
      return a.employeeName.compareTo(b.employeeName);
    });

    return Column(
      children: [
        // ── Statistiques rapides ───────────────────────────────────────
        _ContractStats(contracts: provider.contracts),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              // ── Recherche ──────────────────────────────────────────
              TextField(
                onChanged: onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher par employé, poste, type…',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 16),
                          onPressed: () => onSearchChanged(''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),

              // ── Filtres statut ─────────────────────────────────────
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: statusFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final f = statusFilters[i];
                    final selected = filterStatus == f;
                    return GestureDetector(
                      onTap: () => onFilterChanged(f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? AppTheme.primary : const Color(0xFF2A2A5A)),
                        ),
                        child: Text(f, style: TextStyle(
                          color: selected ? AppTheme.primary : AppTheme.textSecondary,
                          fontSize: 10, fontWeight: FontWeight.w600,
                        )),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Liste ──────────────────────────────────────────────────────
        Expanded(
          child: contracts.isEmpty
              ? EmptyState(
                  icon: Icons.description_outlined,
                  title: searchQuery.isNotEmpty
                      ? 'Aucun résultat pour "$searchQuery"'
                      : provider.contracts.isEmpty
                          ? 'Aucun contrat enregistré'
                          : 'Aucun contrat dans cette catégorie',
                  subtitle: null,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
                  itemCount: contracts.length,
                  itemBuilder: (context, i) => _ContractCard(contract: contracts[i]),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  STATISTIQUES RAPIDES
// ══════════════════════════════════════════════════════════════════════
class _ContractStats extends StatelessWidget {
  final List<EmployeeContract> contracts;
  const _ContractStats({required this.contracts});

  @override
  Widget build(BuildContext context) {
    final actifs   = contracts.where((c) => c.computedStatus == ContractStatus.actif).length;
    final alertes  = contracts.where((c) => c.computedStatus == ContractStatus.bientotExpire).length;
    final expires  = contracts.where((c) => c.computedStatus == ContractStatus.expire).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _StatChip(label: 'Total', value: contracts.length.toString(), color: AppTheme.primary),
          const SizedBox(width: 6),
          _StatChip(label: 'Actifs', value: actifs.toString(), color: AppTheme.success),
          const SizedBox(width: 6),
          _StatChip(label: '⚠ Alertes', value: alertes.toString(), color: AppTheme.warning),
          const SizedBox(width: 6),
          _StatChip(label: 'Expirés', value: expires.toString(), color: AppTheme.error),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  CARTE CONTRAT
// ══════════════════════════════════════════════════════════════════════
class _ContractCard extends StatelessWidget {
  final EmployeeContract contract;
  const _ContractCard({required this.contract});

  @override
  Widget build(BuildContext context) {
    final status = contract.computedStatus;
    final color  = status.color;
    final days   = contract.daysLeft;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      onTap: () => _showDetailDialog(context),
      child: Column(
        children: [
          // ── Ligne 1 : employé + badge ──────────────────────────────
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    contract.employeeName.isNotEmpty ? contract.employeeName[0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contract.employeeName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${contract.poste} · ${contract.site}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              StatusBadge(label: status.label, color: color, fontSize: 9),
            ],
          ),
          const SizedBox(height: 8),

          // ── Ligne 2 : infos contrat ────────────────────────────────
          Row(
            children: [
              _InfoPill(icon: Icons.work_outline, text: contract.type.label, color: AppTheme.primary),
              const SizedBox(width: 6),
              _InfoPill(
                icon: Icons.attach_money,
                text: '${NumberFormat('#,###', 'fr_FR').format(contract.salary)} F',
                color: AppTheme.success,
              ),
              if (days != null) ...[
                const SizedBox(width: 6),
                _InfoPill(
                  icon: days < 0 ? Icons.cancel : Icons.event,
                  text: days < 0
                      ? 'Expiré (${-days}j)'
                      : days == 0
                          ? 'Expire aujourd\'hui'
                          : '$days j restants',
                  color: color,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // ── Ligne 3 : dates ────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.calendar_today, size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('Début: ${dateFmt.format(contract.startDate)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              if (contract.endDate != null) ...[
                const Text(' → ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text('Fin: ${dateFmt.format(contract.endDate!)}',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ] else
                const Text(' · CDI (sans date de fin)',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),

          // ── Commentaire ────────────────────────────────────────────
          if (contract.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.comment_outlined, size: 11, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(contract.comment,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // ── Actions rapides ────────────────────────────────────────
          Row(
            children: [
              _ActionBtn(icon: Icons.edit_outlined, label: 'Modifier',
                  color: AppTheme.primary, onTap: () => _showDetailDialog(context)),
              const SizedBox(width: 6),
              if (status == ContractStatus.bientotExpire || status == ContractStatus.expire)
                _ActionBtn(icon: Icons.autorenew, label: 'Renouveler',
                    color: AppTheme.success, onTap: () => _showRenewDialog(context)),
              if (status == ContractStatus.bientotExpire || status == ContractStatus.expire) ...[
                const SizedBox(width: 6),
                _ActionBtn(icon: Icons.cancel_outlined, label: 'Non renouvelé',
                    color: AppTheme.error, onTap: () => _showDeclineDialog(context)),
              ],
              const Spacer(),
              _ActionBtn(icon: Icons.picture_as_pdf_outlined, label: 'PDF',
                  color: AppTheme.warning, onTap: () => _printContract(context)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ContractDetailDialog(contract: contract),
    );
  }

  void _showRenewDialog(BuildContext context) {
    final provider = context.read<AppProvider>();
    DateTime? newEnd = contract.endDate?.add(const Duration(days: 365));
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.autorenew, color: Colors.green),
            SizedBox(width: 8),
            Text('Renouveler le contrat'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Employé : ${contract.employeeName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, color: AppTheme.primary),
                title: Text(newEnd != null
                    ? 'Nouvelle date de fin : ${DateFormat('dd/MM/yyyy').format(newEnd!)}'
                    : 'Sélectionner une date'),
                trailing: const Icon(Icons.edit, size: 16),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: newEnd ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (d != null) setS(() => newEnd = d);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Décision / Commentaire',
                  prefixIcon: Icon(Icons.comment, color: AppTheme.primary),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: newEnd == null ? null : () async {
                Navigator.pop(ctx);
                await provider.renewContract(
                  contract: contract,
                  newEndDate: newEnd!,
                  decision: commentCtrl.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contrat renouvelé.'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Confirmer renouvellement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeclineDialog(BuildContext context) {
    final provider = context.read<AppProvider>();
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.cancel, color: Colors.red),
          SizedBox(width: 8),
          Text('Non renouvellement'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Confirmer la décision de ne pas renouveler\nle contrat de ${contract.employeeName} ?',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif / Commentaire',
                prefixIcon: Icon(Icons.comment, color: AppTheme.primary),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await provider.declineRenewal(
                contract: contract,
                decision: commentCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Décision enregistrée.'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _printContract(BuildContext context) {
    PrintService().printContract(contract: contract);
  }
}

// ── Widgets utilitaires carte ──────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoPill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  DIALOG DÉTAIL / MODIFICATION
// ══════════════════════════════════════════════════════════════════════
class _ContractDetailDialog extends StatefulWidget {
  final EmployeeContract contract;
  const _ContractDetailDialog({required this.contract});

  @override
  State<_ContractDetailDialog> createState() => _ContractDetailDialogState();
}

class _ContractDetailDialogState extends State<_ContractDetailDialog> {
  late TextEditingController _posteCtrl;
  late TextEditingController _siteCtrl;
  late TextEditingController _salaryCtrl;
  late TextEditingController _commentCtrl;
  late ContractType _type;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _editing = false;
  bool _loading = false;
  List<ContractHistory> _history = [];

  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _posteCtrl   = TextEditingController(text: c.poste);
    _siteCtrl    = TextEditingController(text: c.site);
    _salaryCtrl  = TextEditingController(text: c.salary.toStringAsFixed(0));
    _commentCtrl = TextEditingController(text: c.comment);
    _type = c.type;
    _startDate = c.startDate;
    _endDate   = c.endDate;
    _loadHistory();
  }

  @override
  void dispose() {
    _posteCtrl.dispose(); _siteCtrl.dispose();
    _salaryCtrl.dispose(); _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final provider = context.read<AppProvider>();
    try {
      final h = await provider.fetchContractHistory(widget.contract.id);
      if (mounted) setState(() => _history = h);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final c = widget.contract;
    final status = c.computedStatus;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, color: status.color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.employeeName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(c.type.label,
                            style: TextStyle(color: status.color, fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusBadge(label: status.label, color: status.color),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_editing ? Icons.close : Icons.edit, color: AppTheme.primary, size: 18),
                    onPressed: () => setState(() => _editing = !_editing),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // ── Corps ────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_editing) ...[
                      // Formulaire de modification
                      DropdownButtonFormField<ContractType>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Type de contrat', isDense: true),
                        items: ContractType.values.map((t) =>
                          DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _type = v); },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _DateField(
                            label: 'Date de début',
                            date: _startDate,
                            onPick: (d) => setState(() => _startDate = d),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _DateField(
                            label: 'Date de fin',
                            date: _endDate,
                            onPick: (d) => setState(() => _endDate = d),
                            canClear: true,
                            onClear: () => setState(() => _endDate = null),
                          )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _posteCtrl,
                          decoration: const InputDecoration(labelText: 'Poste', isDense: true)),
                      const SizedBox(height: 10),
                      TextField(controller: _siteCtrl,
                          decoration: const InputDecoration(labelText: "Site d'affectation", isDense: true)),
                      const SizedBox(height: 10),
                      TextField(controller: _salaryCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Salaire (F CFA)', isDense: true)),
                      const SizedBox(height: 10),
                      TextField(controller: _commentCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Commentaire', isDense: true)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _loading
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save, size: 16),
                              label: const Text('Enregistrer'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              onPressed: _loading ? null : () async {
                                setState(() => _loading = true);
                                final updated = widget.contract
                                  ..type       = _type
                                  ..startDate  = _startDate
                                  ..endDate    = _endDate
                                  ..poste      = _posteCtrl.text.trim()
                                  ..site       = _siteCtrl.text.trim()
                                  ..salary     = double.tryParse(_salaryCtrl.text.trim()) ?? widget.contract.salary
                                  ..comment    = _commentCtrl.text.trim();
                                await provider.updateContract(updated);
                                if (mounted) {
                                  setState(() { _loading = false; _editing = false; });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Contrat mis à jour.'), backgroundColor: Colors.green),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                            label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                            onPressed: () => _confirmDelete(context, provider),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Affichage lecture seule
                      _DetailRow('Type', c.type.label),
                      _DetailRow('Poste', c.poste),
                      _DetailRow("Site d'affectation", c.site),
                      _DetailRow('Salaire', '${NumberFormat('#,###', 'fr_FR').format(c.salary)} F CFA'),
                      _DetailRow('Date de début', _dateFmt.format(c.startDate)),
                      _DetailRow('Date de fin', c.endDate != null ? _dateFmt.format(c.endDate!) : 'Indéterminée (CDI)'),
                      if (c.daysLeft != null)
                        _DetailRow('Jours restants', c.daysLeft! < 0 ? 'Expiré (${-c.daysLeft!} j)' : '${c.daysLeft} j'),
                      if (c.comment.isNotEmpty) _DetailRow('Commentaire', c.comment),
                      _DetailRow('Créé par', c.createdBy),
                      _DetailRow('Date création', _dateFmt.format(c.createdAt)),
                    ],

                    // ── Historique ─────────────────────────────────
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Historique', style: TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 6),
                      ..._history.take(5).map((h) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(_actionIcon(h.action), color: _actionColor(h.action), size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              '${_actionLabel(h.action)} — ${h.responsable}',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            )),
                            Text(_dateFmt.format(h.date),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),

            // ── Pied ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Imprimer PDF'),
                      onPressed: () {
                        Navigator.pop(context);
                        PrintService().printContract(contract: c);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce contrat ?'),
        content: Text('Confirmer la suppression du contrat de ${widget.contract.employeeName} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteContract(widget.contract.id);
              if (context.mounted) {
                Navigator.pop(context); // ferme confirm
                Navigator.pop(context); // ferme detail
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contrat supprimé.'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  IconData  _actionIcon(String a)  => a == 'renewed' ? Icons.autorenew : a == 'not_renewed' ? Icons.cancel : a == 'comment' ? Icons.comment : Icons.edit;
  Color     _actionColor(String a) => a == 'renewed' ? Colors.green : a == 'not_renewed' ? Colors.red : AppTheme.primary;
  String    _actionLabel(String a) => a == 'renewed' ? 'Renouvelé' : a == 'not_renewed' ? 'Non renouvelé' : a == 'comment' ? 'Commentaire ajouté' : 'Modifié';
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text('$label :', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  DIALOG DATE PICKER CHAMP
// ══════════════════════════════════════════════════════════════════════
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPick;
  final bool canClear;
  final VoidCallback? onClear;
  const _DateField({required this.label, this.date, required this.onPick, this.canClear = false, this.onClear});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2040),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2A5A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppTheme.primary, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                  Text(date != null ? fmt.format(date!) : 'Choisir',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (canClear && date != null)
              GestureDetector(onTap: onClear,
                  child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 13)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  DIALOG AJOUT NOUVEAU CONTRAT
// ══════════════════════════════════════════════════════════════════════
class _ContractFormDialog extends StatefulWidget {
  final List<AppUser> employees;
  final Future<void> Function(EmployeeContract) onSave;
  final String createdBy;
  const _ContractFormDialog({required this.employees, required this.onSave, required this.createdBy});

  @override
  State<_ContractFormDialog> createState() => _ContractFormDialogState();
}

class _ContractFormDialogState extends State<_ContractFormDialog> {
  AppUser? _selectedEmployee;
  ContractType _type = ContractType.cdd;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final _posteCtrl   = TextEditingController();
  final _siteCtrl    = TextEditingController(text: 'Yopougon Millionnaire');
  final _salaryCtrl  = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _posteCtrl.dispose(); _siteCtrl.dispose();
    _salaryCtrl.dispose(); _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Nouveau contrat',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                IconButton(icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
              ],
            ),
          ),

          // ── Formulaire ──────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Sélection employé
                  DropdownButtonFormField<AppUser>(
                    value: _selectedEmployee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Employé *',
                      prefixIcon: Icon(Icons.person, color: AppTheme.primary),
                      isDense: true,
                    ),
                    items: widget.employees.map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(u.name, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (u) {
                      setState(() {
                        _selectedEmployee = u;
                        if (u != null && _posteCtrl.text.isEmpty) {
                          _posteCtrl.text = u.roleLabel;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Type contrat
                  DropdownButtonFormField<ContractType>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type de contrat *',
                      prefixIcon: Icon(Icons.work_outline, color: AppTheme.primary),
                      isDense: true,
                    ),
                    items: ContractType.values.map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _type = v); },
                  ),
                  const SizedBox(height: 10),

                  // Dates
                  Row(
                    children: [
                      Expanded(child: _DateField(
                        label: 'Date de début *',
                        date: _startDate,
                        onPick: (d) => setState(() => _startDate = d),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _DateField(
                        label: 'Date de fin',
                        date: _endDate,
                        onPick: (d) => setState(() => _endDate = d),
                        canClear: true,
                        onClear: () => setState(() => _endDate = null),
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(controller: _posteCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Poste *',
                          prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primary),
                          isDense: true)),
                  const SizedBox(height: 10),

                  TextField(controller: _siteCtrl,
                      decoration: const InputDecoration(
                          labelText: "Site d'affectation",
                          prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primary),
                          isDense: true)),
                  const SizedBox(height: 10),

                  TextField(controller: _salaryCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Salaire mensuel (F CFA) *',
                          prefixIcon: Icon(Icons.attach_money, color: AppTheme.primary),
                          isDense: true)),
                  const SizedBox(height: 10),

                  TextField(controller: _commentCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Commentaire',
                          prefixIcon: Icon(Icons.comment_outlined, color: AppTheme.primary),
                          isDense: true)),
                ],
              ),
            ),
          ),

          // ── Actions ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                const Spacer(),
                ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedEmployee == null || _posteCtrl.text.trim().isEmpty || _salaryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de remplir tous les champs obligatoires (*)'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _loading = true);
    final contract = EmployeeContract(
      id: '',
      employeeId:   _selectedEmployee!.id,
      employeeName: _selectedEmployee!.name,
      type:       _type,
      startDate:  _startDate,
      endDate:    _endDate,
      salary:     double.tryParse(_salaryCtrl.text.trim()) ?? 0,
      poste:      _posteCtrl.text.trim(),
      site:       _siteCtrl.text.trim(),
      comment:    _commentCtrl.text.trim(),
      createdBy:  widget.createdBy,
    );

    await widget.onSave(contract);
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ONGLET HISTORIQUE
// ══════════════════════════════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final contracts = provider.contracts;

    // Tous les contrats non actifs (renouvelés, non renouvelés, expirés)
    final archived = contracts.where((c) =>
      c.status == ContractStatus.renouvele ||
      c.status == ContractStatus.nonRenouvele ||
      c.computedStatus == ContractStatus.expire
    ).toList()
      ..sort((a, b) => (b.endDate ?? b.startDate).compareTo(a.endDate ?? a.startDate));

    if (archived.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Aucun historique disponible',
        subtitle: null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
      itemCount: archived.length,
      itemBuilder: (context, i) {
        final c = archived[i];
        final dateFmt = DateFormat('dd/MM/yyyy');
        final color = c.computedStatus.color;
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  c.status == ContractStatus.renouvele ? Icons.autorenew :
                  c.status == ContractStatus.nonRenouvele ? Icons.cancel_outlined :
                  Icons.event_busy,
                  color: color, size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.employeeName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${c.poste} · ${c.type.label}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    if (c.endDate != null)
                      Text('Fin : ${dateFmt.format(c.endDate!)}',
                          style: TextStyle(color: color, fontSize: 11)),
                    if (c.comment.isNotEmpty)
                      Text(c.comment,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              StatusBadge(label: c.status.label, color: color, fontSize: 9),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  BANDEAU ALERTES
// ══════════════════════════════════════════════════════════════════════
class _AlertBanner extends StatelessWidget {
  final List<ContractAlert> alerts;
  const _AlertBanner({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    // Alerte la plus urgente en premier
    final top = alerts.reduce((a, b) => a.daysLeft < b.daysLeft ? a : b);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alerts.length == 1
                  ? top.message
                  : '${alerts.length} contrats nécessitent votre attention. ${top.message}',
              style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () {
              for (final a in alerts) { provider.markAlertRead(a.id); }
            },
            child: const Icon(Icons.close, color: Color(0xFFFF9800), size: 16),
          ),
        ],
      ),
    );
  }
}
