import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'Commandes', icon: Icon(Icons.local_shipping, size: 16)),
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

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierDialog(context, provider),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: provider.suppliers.isEmpty
        ? const EmptyState(icon: Icons.business, title: 'Aucun fournisseur', subtitle: 'Ajoutez vos fournisseurs ici')
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.suppliers.length,
            itemBuilder: (context, i) {
              final sup = provider.suppliers[i];
              final orders = provider.supplierOrders.where((o) => o.supplierId == sup.id).toList();
              final totalPending = orders.where((o) => o.paymentStatus != SupplierPaymentStatus.paid).fold<double>(0, (s, o) => s + o.remainingAmount);
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Icon(Icons.business, color: AppTheme.primary, size: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sup.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(sup.contact, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          Text(sup.phone, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${orders.length} cmd(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        if (totalPending > 0)
                          Text('${NumberFormat('#,###', 'fr_FR').format(totalPending)} F dû',
                            style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _showAddSupplierDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter un fournisseur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom de l\'entreprise')),
            const SizedBox(height: 8),
            TextField(controller: contactCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Personne de contact')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Téléphone')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Email (optionnel)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                provider.addSupplier(Supplier(
                  id: const Uuid().v4(),
                  name: nameCtrl.text,
                  contact: contactCtrl.text,
                  phone: phoneCtrl.text,
                  email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _SupplierOrdersTab extends StatelessWidget {
  const _SupplierOrdersTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Column(
      children: [
        // Header with "Nouvelle Commande" button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Commandes Fournisseurs (${provider.supplierOrders.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddOrderDialog(context, provider),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nouvelle Commande', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        // Summary cards
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: StatCard(
                title: 'En attente',
                value: provider.supplierOrders.where((o) => o.paymentStatus == SupplierPaymentStatus.pending).length.toString(),
                icon: Icons.hourglass_empty,
                color: AppTheme.warning,
              )),
              const SizedBox(width: 10),
              Expanded(child: StatCard(
                title: 'Reste à payer',
                value: '${fmt.format(provider.supplierOrders.fold<double>(0, (s, o) => s + o.remainingAmount))} F',
                icon: Icons.money_off,
                color: AppTheme.error,
              )),
            ],
          ),
        ),
        Expanded(
            child: provider.supplierOrders.isEmpty
              ? const EmptyState(icon: Icons.local_shipping, title: 'Aucune commande fournisseur')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: provider.supplierOrders.length,
                  itemBuilder: (context, i) => _SupplierOrderCard(
                    order: provider.supplierOrders[i],
                    provider: provider,
                  ),
                ),
          ),
        ],
      );
  }

  void _showAddOrderDialog(BuildContext context, AppProvider provider) {
    if (provider.suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez d\'abord un fournisseur'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    String supplierId = provider.suppliers.first.id;
    String supplierName = provider.suppliers.first.name;
    final totalCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

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
                  decoration: const InputDecoration(labelText: 'Fournisseur'),
                  items: provider.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => setS(() {
                    supplierId = v!;
                    supplierName = provider.suppliers.firstWhere((s) => s.id == v).name;
                  }),
                ),
                const SizedBox(height: 8),
                TextField(controller: totalCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Montant total (F CFA)')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Notes (optionnel)'), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final total = double.tryParse(totalCtrl.text);
                if (total != null && total > 0) {
                  provider.addSupplierOrder(SupplierOrder(
                    id: const Uuid().v4(),
                    supplierId: supplierId,
                    supplierName: supplierName,
                    items: [],
                    totalAmount: total,
                    notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                    expectedDelivery: DateTime.now().add(const Duration(days: 3)),
                  ));
                  Navigator.pop(ctx);
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

class _SupplierOrderCard extends StatelessWidget {
  final SupplierOrder order;
  final AppProvider provider;

  const _SupplierOrderCard({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    Color statusColor;
    String statusLabel;

    switch (order.paymentStatus) {
      case SupplierPaymentStatus.paid:
        statusColor = AppTheme.success;
        statusLabel = 'SOLDÉ';
        break;
      case SupplierPaymentStatus.partial:
        statusColor = AppTheme.warning;
        statusLabel = 'PARTIEL';
        break;
      case SupplierPaymentStatus.pending:
        statusColor = AppTheme.error;
        statusLabel = 'EN ATTENTE';
        break;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_shipping, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.supplierName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Commandé le ${_formatDate(order.orderDate)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    if (order.expectedDelivery != null)
                      Text('Livraison prévue: ${_formatDate(order.expectedDelivery!)}', style: const TextStyle(color: AppTheme.primary, fontSize: 11)),
                  ],
                ),
              ),
              StatusBadge(label: statusLabel, color: statusColor, fontSize: 10),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                _PayRow('Montant total', '${fmt.format(order.totalAmount)} F CFA', Colors.white),
                _PayRow('Montant payé', '${fmt.format(order.paidAmount)} F CFA', AppTheme.success),
                _PayRow('Reste à payer', '${fmt.format(order.remainingAmount)} F CFA', order.remainingAmount > 0 ? AppTheme.error : AppTheme.success),
                if (order.paymentMethod.isNotEmpty) _PayRow('Mode de paiement', order.paymentMethod, AppTheme.textSecondary),
              ],
            ),
          ),
          if (order.paymentStatus != SupplierPaymentStatus.paid) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(context, order, provider),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Payer', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, SupplierOrder order, AppProvider provider) {
    final amountCtrl = TextEditingController(text: order.remainingAmount.toStringAsFixed(0));
    String method = 'Espèces';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Enregistrer un paiement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Montant payé')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: method,
                style: const TextStyle(color: Colors.white),
                dropdownColor: AppTheme.cardBg,
                decoration: const InputDecoration(labelText: 'Mode de paiement'),
                items: ['Espèces', 'Orange Money', 'MTN Money', 'Wave', 'Virement'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setS(() => method = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (amount != null && amount > 0) {
                  provider.updateSupplierOrderPayment(order.id, amount, method);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

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
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
