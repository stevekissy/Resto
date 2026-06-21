import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

// ─── Formateur monétaire ───────────────────────────────────────────────────
final _fmtMoney = NumberFormat('#,###', 'fr_FR');
final _fmtDate  = DateFormat('dd/MM/yyyy', 'fr_FR');

String _money(double v) => '${_fmtMoney.format(v)} F';
String _date(DateTime d) => _fmtDate.format(d);

// ═══════════════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════
class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Fournisseurs', icon: Icon(Icons.business, size: 16)),
                Tab(text: 'Commandes',    icon: Icon(Icons.local_shipping, size: 16)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SuppliersTab(),
                _SupplierOrdersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — FOURNISSEURS
// ═══════════════════════════════════════════════════════════════════════════
class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sups = provider.suppliers; // uniquement actifs

    final isWide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      floatingActionButton: isWide
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSupplierDialog(context, provider),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : FloatingActionButton(
              onPressed: () => _showAddSupplierDialog(context, provider),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: sups.isEmpty
          ? const EmptyState(
              icon: Icons.business,
              title: 'Aucun fournisseur',
              subtitle: 'Ajoutez vos fournisseurs ici',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
              itemCount: sups.length,
              itemBuilder: (context, i) {
                final sup = sups[i];
                final orders = provider.supplierOrders
                    .where((o) => o.supplierId == sup.id)
                    .toList();
                final totalDue = orders
                    .where((o) => o.paymentStatus != SupplierPaymentStatus.paid)
                    .fold<double>(0, (s, o) => s + o.remainingAmount);

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(Icons.business,
                              color: AppTheme.primary, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Infos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sup.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            if (sup.productOrService != null &&
                                sup.productOrService!.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.category,
                                      size: 11,
                                      color: AppTheme.primary),
                                  const SizedBox(width: 3),
                                  Text(sup.productOrService!,
                                      style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            Text(sup.contact,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                            Text(sup.phone,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      // Résumé + bouton supprimer
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${orders.length} cmd(s)',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          if (totalDue > 0)
                            Text('${_money(totalDue)} dû',
                                style: const TextStyle(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () =>
                                _confirmDelete(context, sup, provider),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: AppTheme.error, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ── Dialogue confirmation suppression ─────────────────────────────────
  void _confirmDelete(
      BuildContext context, Supplier sup, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le fournisseur'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'Voulez-vous supprimer '),
              TextSpan(
                text: sup.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                  text: ' ?\n\nSi ce fournisseur a des commandes liées, il '
                      'sera désactivé (non supprimé définitivement) pour '
                      'conserver l\'historique.'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              await provider.deleteOrDeactivateSupplier(sup.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fournisseur "${sup.name}" supprimé/désactivé'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // ── Dialogue ajout fournisseur ─────────────────────────────────────────
  void _showAddSupplierDialog(BuildContext context, AppProvider provider) {
    final nameCtrl           = TextEditingController();
    final contactCtrl        = TextEditingController();
    final phoneCtrl          = TextEditingController();
    final emailCtrl          = TextEditingController();
    final productServiceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter un fournisseur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'Nom de l\'entreprise *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: productServiceCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Produit / Service fourni *',
                  hintText: 'Ex : Poisson, Poulet, Gaz, Emballages…',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contactCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Personne de contact'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'Email (optionnel)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  productServiceCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Le nom et le produit/service sont obligatoires'),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }
              await provider.addSupplier(Supplier(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                contact: contactCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty
                    ? null
                    : emailCtrl.text.trim(),
                productOrService: productServiceCtrl.text.trim(),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — COMMANDES FOURNISSEURS
// ═══════════════════════════════════════════════════════════════════════════
class _SupplierOrdersTab extends StatefulWidget {
  const _SupplierOrdersTab();

  @override
  State<_SupplierOrdersTab> createState() => _SupplierOrdersTabState();
}

class _SupplierOrdersTabState extends State<_SupplierOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _filterController;
  static const _tabs = ['Toutes', 'Non payées', 'Partielles', 'Payées', 'En retard'];

  @override
  void initState() {
    super.initState();
    _filterController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<SupplierOrder> _filtered(AppProvider p, int idx) {
    switch (idx) {
      case 1:  return p.unpaidOrders;
      case 2:  return p.partialOrders;
      case 3:  return p.paidOrders;
      case 4:  return p.overdueOrders;
      default: return p.supplierOrders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Column(
      children: [
        // ── En-tête bouton nouvelle commande ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Commandes (${provider.supplierOrders.length})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddOrderDialog(context, provider),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nouvelle', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        // ── 3 StatCards totaux ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  label: 'Total cmds',
                  value: _money(provider.totalOrdersAmount),
                  color: Colors.white,
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatCard(
                  label: 'Payé',
                  value: _money(provider.totalPaidAmount),
                  color: AppTheme.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatCard(
                  label: 'Reste',
                  value: _money(provider.totalRemainingAmount),
                  color: provider.totalRemainingAmount > 0
                      ? AppTheme.error
                      : AppTheme.success,
                  icon: Icons.money_off,
                ),
              ),
            ],
          ),
        ),
        // ── Filtres par onglet ───────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _filterController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: _tabs
                .map((t) => Tab(
                      child: Text(t,
                          style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
          ),
        ),
        // ── Liste filtrée ────────────────────────────────────────────────
        Expanded(
          child: AnimatedBuilder(
            animation: _filterController,
            builder: (_, __) {
              final list = _filtered(provider, _filterController.index);
              if (list.isEmpty) {
                return const EmptyState(
                    icon: Icons.local_shipping,
                    title: 'Aucune commande');
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _SupplierOrderCard(
                  order: list[i],
                  provider: provider,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Dialogue nouvelle commande ─────────────────────────────────────────
  void _showAddOrderDialog(BuildContext context, AppProvider provider) {
    if (provider.suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ajoutez d\'abord un fournisseur'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    String supplierId   = provider.suppliers.first.id;
    String supplierName = provider.suppliers.first.name;
    String productService =
        provider.suppliers.first.productOrService ?? '';
    final totalCtrl    = TextEditingController();
    final notesCtrl    = TextEditingController();
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouvelle commande fournisseur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: supplierId,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  decoration:
                      const InputDecoration(labelText: 'Fournisseur'),
                  items: provider.suppliers
                      .map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setS(() {
                    supplierId = v!;
                    final s = provider.suppliers
                        .firstWhere((s) => s.id == v);
                    supplierName   = s.name;
                    productService = s.productOrService ?? '';
                  }),
                ),
                if (productService.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.category,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(productService,
                          style: const TextStyle(
                              color: AppTheme.primary, fontSize: 12)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Montant total (F CFA)'),
                ),
                const SizedBox(height: 8),
                // Date échéance
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dueDate != null
                        ? 'Échéance : ${_date(dueDate!)}'
                        : 'Date d\'échéance (optionnel)',
                    style: TextStyle(
                        color: dueDate != null
                            ? AppTheme.warning
                            : AppTheme.textSecondary,
                        fontSize: 13),
                  ),
                  trailing: const Icon(Icons.calendar_today,
                      color: AppTheme.primary, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now()
                          .add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) setS(() => dueDate = picked);
                  },
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final total = double.tryParse(totalCtrl.text);
                if (total != null && total > 0) {
                  await provider.addSupplierOrder(SupplierOrder(
                    id: const Uuid().v4(),
                    supplierId: supplierId,
                    supplierName: supplierName,
                    productOrService: productService.isNotEmpty
                        ? productService
                        : null,
                    items: [],
                    totalAmount: total,
                    dueDate: dueDate,
                    expectedDelivery: dueDate ??
                        DateTime.now().add(const Duration(days: 3)),
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                    createdBy: provider.currentUser?.name,
                    createdAt: DateTime.now(),
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE DE COMMANDE FOURNISSEUR
// ═══════════════════════════════════════════════════════════════════════════
class _SupplierOrderCard extends StatefulWidget {
  final SupplierOrder order;
  final AppProvider provider;

  const _SupplierOrderCard(
      {required this.order, required this.provider});

  @override
  State<_SupplierOrderCard> createState() => _SupplierOrderCardState();
}

class _SupplierOrderCardState extends State<_SupplierOrderCard> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final provider = widget.provider;
    final payments = provider.paymentsForOrder(order.id);

    Color statusColor;
    String statusLabel;
    switch (order.paymentStatus) {
      case SupplierPaymentStatus.paid:
        statusColor = AppTheme.success;
        statusLabel = 'SOLDÉ';
      case SupplierPaymentStatus.partial:
        statusColor = AppTheme.warning;
        statusLabel = 'PARTIEL';
      case SupplierPaymentStatus.unpaid:
        statusColor = AppTheme.error;
        statusLabel = order.isOverdue ? 'EN RETARD' : 'NON PAYÉE';
    }
    if (order.isOverdue && order.paymentStatus != SupplierPaymentStatus.paid) {
      statusColor = const Color(0xFFE91E63);
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.supplierName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    if (order.productOrService != null)
                      Row(
                        children: [
                          const Icon(Icons.category,
                              size: 11, color: AppTheme.primary),
                          const SizedBox(width: 3),
                          Text(order.productOrService!,
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    Text(
                      'Commande du ${_date(order.orderDate)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    if (order.dueDate != null)
                      Text(
                        'Échéance : ${_date(order.dueDate!)}',
                        style: TextStyle(
                          color: order.isOverdue
                              ? const Color(0xFFE91E63)
                              : AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  fontSize: 10),
            ],
          ),
          const SizedBox(height: 12),
          // ── Montants ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _PayRow('Montant total',
                    _money(order.totalAmount), Colors.white),
                _PayRow('Montant payé',
                    _money(order.paidAmount), AppTheme.success),
                _PayRow(
                  'Reste à payer',
                  _money(order.remainingAmount),
                  order.remainingAmount > 0
                      ? AppTheme.error
                      : AppTheme.success,
                ),
                if (order.createdBy != null)
                  _PayRow('Créé par', order.createdBy!,
                      AppTheme.textSecondary),
              ],
            ),
          ),
          // ── Actions ────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            children: [
              // Bouton historique paiements
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showHistory = !_showHistory),
                icon: Icon(
                  _showHistory
                      ? Icons.expand_less
                      : Icons.history,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                label: Text(
                  'Historique (${payments.length})',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              const Spacer(),
              // Bouton ajouter paiement (visible si non soldé)
              if (order.paymentStatus != SupplierPaymentStatus.paid)
                ElevatedButton.icon(
                  onPressed: () =>
                      _showAddPaymentDialog(context, order, provider),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter paiement',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          // ── Historique paiements (accordéon) ──────────────────────────
          if (_showHistory)
            _PaymentHistorySection(payments: payments),
        ],
      ),
    );
  }

  // ── Dialogue ajouter paiement ──────────────────────────────────────────
  void _showAddPaymentDialog(
      BuildContext context, SupplierOrder order, AppProvider provider) {
    final amountCtrl = TextEditingController(
        text: order.remainingAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    String method = 'Espèces';
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Ajouter un paiement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reste à payer affiché
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reste à payer',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      Text(
                        _money(order.remainingAmount),
                        style: const TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Montant payé (F CFA)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: method,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  decoration: const InputDecoration(
                      labelText: 'Mode de paiement'),
                  items: [
                    'Espèces',
                    'Orange Money',
                    'MTN Money',
                    'Wave',
                    'Virement',
                    'Chèque',
                  ]
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setS(() => method = v!),
                ),
                const SizedBox(height: 8),
                // Date du paiement
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Date : ${_date(paymentDate)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.calendar_today,
                      color: AppTheme.primary, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setS(() => paymentDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Note (optionnel)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Montant invalide'),
                        backgroundColor: AppTheme.error),
                  );
                  return;
                }
                if (amount > order.remainingAmount + 0.01) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Montant supérieur au reste à payer (${_money(order.remainingAmount)})'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                  return;
                }
                await provider.addSupplierPayment(
                  supplierOrderId: order.id,
                  supplierId: order.supplierId,
                  amount: amount,
                  paymentMethod: method,
                  paymentDate: paymentDate,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION HISTORIQUE PAIEMENTS (accordéon)
// ═══════════════════════════════════════════════════════════════════════════
class _PaymentHistorySection extends StatelessWidget {
  final List<SupplierPayment> payments;

  const _PaymentHistorySection({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: Text(
            'Aucun paiement enregistré',
            style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique des paiements',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...payments.map((p) => _PaymentHistoryItem(payment: p)),
        ],
      ),
    );
  }
}

class _PaymentHistoryItem extends StatelessWidget {
  final SupplierPayment payment;

  const _PaymentHistoryItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Icône méthode
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.payments_outlined,
                  color: AppTheme.success, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _money(payment.amount),
                      style: const TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        payment.paymentMethod,
                        style: const TextStyle(
                            color: AppTheme.primary, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      _date(payment.paymentDate),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    const Text('•',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(width: 6),
                    Text(
                      payment.createdBy,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                if (payment.note != null && payment.note!.isNotEmpty)
                  Text(
                    payment.note!,
                    style: TextStyle(
                        color: AppTheme.textSecondary
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════
class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PayRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
