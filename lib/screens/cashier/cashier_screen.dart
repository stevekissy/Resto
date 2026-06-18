import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CashierScreen — Workflow caisse 2 étapes
//  Tab 1 : Commandes à encaisser   (cashStatus == pending_cashout)
//  Tab 2 : Factures en attente      (cashStatus == awaiting_payment)
//  Tab 3 : Point de Caisse          (design original restauré)
// ════════════════════════════════════════════════════════════════════════════
class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final tab1Count = provider.pendingCashoutOrders.length;
    final tab2Count = provider.awaitingPaymentOrders.length;

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
              isScrollable: true,
              tabs: [
                Tab(
                  icon: Badge(
                    label: Text('$tab1Count'),
                    isLabelVisible: tab1Count > 0,
                    child: const Icon(Icons.point_of_sale, size: 16),
                  ),
                  text: 'Caisse',
                ),
                Tab(
                  icon: Badge(
                    label: Text('$tab2Count'),
                    isLabelVisible: tab2Count > 0,
                    child: const Icon(Icons.receipt_long, size: 16),
                  ),
                  text: 'Factures',
                ),
                const Tab(
                  icon: Icon(Icons.bar_chart, size: 16),
                  text: 'Point de Caisse',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CaisseTab(),
                _FacturesEnAttenteTab(),
                _PointCaisseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 1 — Commandes à encaisser (cashStatus == pending_cashout)
//  Affiche : numéro, table, articles, total UNIQUEMENT
//  Pas de mode de paiement, pas de montant versé à cette étape
//  Bouton "Encaisser" → génère facture provisoire → passe en Tab 2
// ════════════════════════════════════════════════════════════════════════════
class _CaisseTab extends StatefulWidget {
  const _CaisseTab();

  @override
  State<_CaisseTab> createState() => _CaisseTabState();
}

class _CaisseTabState extends State<_CaisseTab> {
  final _fmt = NumberFormat('#,###', 'fr_FR');
  bool _processing = false;

  Future<void> _encaisser(BuildContext context, Order order, AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Générer la facture', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Commande #${order.orderNumber}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Table : ${order.tableNumber}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Montant à encaisser',
                    style: TextStyle(color: AppTheme.textSecondary)),
                  Text('${_fmt.format(order.totalAmount)} F CFA',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Une facture d\'encaissement provisoire sera générée.\nLe règlement définitif se fera à l\'étape suivante.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.receipt_long, size: 16),
            label: const Text('Encaisser'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await provider.cashoutOrder(order.id);
      final invoiceNumber = PrintService.generateReceiptNumber(order.orderNumber);
      PrintService().printCashoutInvoice(
        order: order,
        cashoutInvoiceNumber: invoiceNumber,
        cashierName: provider.currentUser?.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facture #${order.orderNumber} générée — En attente de règlement'),
            backgroundColor: AppTheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final orders = provider.pendingCashoutOrders;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Commandes à encaisser (${orders.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle,
                    title: 'Tout est encaissé !',
                    subtitle: 'Aucune commande en attente de paiement',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) {
                      final order = orders[i];
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête commande
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('#${order.orderNumber} - Table ${order.tableNumber}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                Text('${_fmt.format(order.totalAmount)} F CFA',
                                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Articles uniquement — pas de mode paiement, pas de montant versé
                            ...order.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('${item.quantity}× ${item.productName}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            )),
                            const SizedBox(height: 8),
                            // Bouton Encaisser
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _processing ? null : () => _encaisser(ctx, order, provider),
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('Encaisser', style: TextStyle(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
        if (_processing)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 2 — Factures en attente de règlement (cashStatus == awaiting_payment)
//  Affiche les factures d'encaissement provisoires
//  Bouton "Régler" → dialog avec mode paiement + montant versé + monnaie rendue
//  → génère facture de règlement définitive → comptabilise dans le Point Caisse
// ════════════════════════════════════════════════════════════════════════════
class _FacturesEnAttenteTab extends StatefulWidget {
  const _FacturesEnAttenteTab();

  @override
  State<_FacturesEnAttenteTab> createState() => _FacturesEnAttenteTabState();
}

class _FacturesEnAttenteTabState extends State<_FacturesEnAttenteTab> {
  final _fmt = NumberFormat('#,###', 'fr_FR');
  bool _processing = false;

  Future<void> _regler(BuildContext context, Order order, AppProvider provider) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReglementDialog(
        order: order,
        fmt: _fmt,
        cashierName: provider.currentUser?.name ?? 'Caissier',
        onConfirm: (paymentMethod, amountPaid) async {
          Navigator.pop(ctx);
          setState(() => _processing = true);

          // Variables pour la facture définitive — construites avant settleOrder
          final settlementNumber = PrintService.generateSettlementNumber(order.orderNumber);
          final amountDue = order.totalAmount;
          final change = (amountPaid - amountDue).clamp(0.0, double.infinity);
          final cashierName = provider.currentUser?.name;

          try {
            await provider.settleOrder(
              order.id,
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
            );

            if (mounted) {
              // ── Dialog de succès avec bouton Imprimer la facture définitive ──
              await showDialog(
                context: context,
                barrierDismissible: true,
                builder: (successCtx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                      SizedBox(width: 10),
                      Text('Règlement confirmé', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Résumé du règlement
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Commande', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                Text('#${order.orderNumber} — Table ${order.tableNumber}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Mode paiement', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                Text(paymentMethod,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Montant réglé', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                Text('${_fmt.format(amountDue)} F CFA',
                                  style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 14)),
                              ],
                            ),
                            if (change > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Monnaie rendue', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  Text('${_fmt.format(change)} F CFA',
                                    style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 12)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bouton Imprimer la facture définitive (pleine largeur)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            PrintService().printSettlementInvoice(
                              order: order,
                              settlementInvoiceNumber: settlementNumber,
                              paymentMethod: paymentMethod,
                              amountPaid: amountPaid,
                              changeAmount: change,
                              cashierName: cashierName,
                            );
                          },
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Imprimer la facture définitive',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(successCtx),
                      child: const Text('Fermer', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur règlement : $e'), backgroundColor: Colors.red),
              );
            }
          } finally {
            if (mounted) setState(() => _processing = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final orders = provider.awaitingPaymentOrders;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Text('Factures en attente de règlement (${orders.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                ? const EmptyState(
                    icon: Icons.task_alt,
                    title: 'Aucune facture en attente',
                    subtitle: 'Toutes les factures ont été réglées.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) {
                      final order = orders[i];
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        border: Border.all(
                          color: AppTheme.warning.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('#${order.orderNumber} - Table ${order.tableNumber}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text('EN ATTENTE', style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            if (order.cashoutInvoiceNumber != null) ...[
                              const SizedBox(height: 3),
                              Text('Réf. : ${order.cashoutInvoiceNumber}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            ],
                            const SizedBox(height: 6),
                            // Articles
                            ...order.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('${item.quantity}× ${item.productName}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            )),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Montant dû',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                Text('${_fmt.format(order.totalAmount)} F CFA',
                                  style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      PrintService().printCashoutInvoice(
                                        order: order,
                                        cashoutInvoiceNumber: order.cashoutInvoiceNumber ?? PrintService.generateReceiptNumber(order.orderNumber),
                                        cashierName: provider.currentUser?.name,
                                      );
                                    },
                                    icon: const Icon(Icons.print_outlined, size: 14),
                                    label: const Text('Réimprimer', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondary,
                                      side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: _processing ? null : () => _regler(context, order, provider),
                                    icon: const Icon(Icons.payments, size: 16),
                                    label: const Text('Régler', style: TextStyle(fontWeight: FontWeight.w700)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
        if (_processing)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DIALOG DE RÈGLEMENT — affiché après clic "Régler" (Tab 2)
//  Affiche SEULEMENT à cette étape : mode paiement, montant versé, monnaie rendue
// ════════════════════════════════════════════════════════════════════════════
class _ReglementDialog extends StatefulWidget {
  final Order order;
  final NumberFormat fmt;
  final String cashierName;
  final void Function(String paymentMethod, double amountPaid) onConfirm;

  const _ReglementDialog({
    required this.order,
    required this.fmt,
    required this.cashierName,
    required this.onConfirm,
  });

  @override
  State<_ReglementDialog> createState() => _ReglementDialogState();
}

class _ReglementDialogState extends State<_ReglementDialog> {
  String _paymentMethod = 'Espèces';
  final _amountController = TextEditingController();
  double _amountPaid = 0;

  double get _change => (_amountPaid - widget.order.totalAmount).clamp(0.0, double.infinity);
  bool get _isValid => _amountPaid >= widget.order.totalAmount || _paymentMethod != 'Espèces';

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.order.totalAmount;
    _amountController.text = widget.order.totalAmount.toStringAsFixed(0);
    _amountController.addListener(() {
      final val = double.tryParse(_amountController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
      setState(() => _amountPaid = val);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.payments, color: AppTheme.success),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Règlement', style: TextStyle(color: Colors.white, fontSize: 16)),
              Text('Commande #${widget.order.orderNumber} — Table ${widget.order.tableNumber}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Montant dû
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MONTANT DÛ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('${widget.fmt.format(widget.order.totalAmount)} F CFA',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mode de paiement
            const Text('Mode de paiement', style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Espèces', 'Mobile Money', 'Carte Bancaire', 'Chèque'].map((m) {
                final selected = _paymentMethod == m;
                return ChoiceChip(
                  label: Text(m),
                  selected: selected,
                  onSelected: (_) => setState(() => _paymentMethod = m),
                  selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                  backgroundColor: AppTheme.surfaceLight,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: selected ? AppTheme.primary : Colors.transparent,
                    width: selected ? 1.5 : 0,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Montant versé
            const Text('Montant versé', style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                suffixText: 'F CFA',
                suffixStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2A2A5A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Monnaie rendue
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _change > 0
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _change > 0
                    ? AppTheme.success.withValues(alpha: 0.5)
                    : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monnaie rendue', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('${widget.fmt.format(_change)} F CFA',
                    style: TextStyle(
                      color: _change > 0 ? AppTheme.success : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    )),
                ],
              ),
            ),

            // Avertissement montant insuffisant
            if (_paymentMethod == 'Espèces' && _amountPaid > 0 && _amountPaid < widget.order.totalAmount) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Montant insuffisant (manque ${widget.fmt.format(widget.order.totalAmount - _amountPaid)} F)',
                        style: const TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _isValid
            ? () => widget.onConfirm(_paymentMethod, _amountPaid > 0 ? _amountPaid : widget.order.totalAmount)
            : null,
          icon: const Icon(Icons.check_circle, size: 16),
          label: const Text('Confirmer le règlement', style: TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 3 — Point de Caisse
//  DESIGN ORIGINAL RESTAURÉ — identique au commit 1078c42
//  Comptabilise UNIQUEMENT settlementInvoiceGenerated == true (règlements définitifs)
// ════════════════════════════════════════════════════════════════════════════
class _PointCaisseTab extends StatefulWidget {
  const _PointCaisseTab();

  @override
  State<_PointCaisseTab> createState() => _PointCaisseTabState();
}

class _PointCaisseTabState extends State<_PointCaisseTab> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###', 'fr_FR');
    final today = DateTime.now();

    // UNIQUEMENT les règlements définitifs (settlementInvoiceGenerated == true)
    final todayPaid = provider.orders.where((o) =>
      o.settlementInvoiceGenerated &&
      o.isPaid &&
      o.createdAt.day == today.day &&
      o.createdAt.month == today.month &&
      o.createdAt.year == today.year
    ).toList();

    final totalCash = todayPaid.where((o) => o.paymentMethod == 'Espèces').fold<double>(0, (s, o) => s + o.totalAmount);
    final totalMobile = todayPaid.where((o) => o.paymentMethod != null && o.paymentMethod != 'Espèces' && o.paymentMethod != 'Carte Bancaire').fold<double>(0, (s, o) => s + o.totalAmount);
    final totalCard = todayPaid.where((o) => o.paymentMethod == 'Carte Bancaire').fold<double>(0, (s, o) => s + o.totalAmount);
    final totalCharges = provider.todayTotalCharges;
    final netRevenue = provider.todayRevenue - totalCharges;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // En-tête
          GlassCard(
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            child: Column(
              children: [
                const Text('POINT DE CAISSE DU JOUR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(today),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats en grille
          GridView.count(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
            children: [
              StatCard(title: 'Recette Brute', value: '${fmt.format(provider.todayRevenue)} F', icon: Icons.payments, color: AppTheme.success),
              StatCard(title: 'Charges du Jour', value: '${fmt.format(totalCharges)} F', icon: Icons.money_off, color: AppTheme.error),
              StatCard(title: 'Recette Nette', value: '${fmt.format(netRevenue)} F', icon: Icons.account_balance_wallet, color: netRevenue >= 0 ? AppTheme.primary : AppTheme.error),
              StatCard(title: 'Commandes', value: todayPaid.length.toString(), icon: Icons.receipt_long, color: AppTheme.warning),
            ],
          ),
          const SizedBox(height: 16),
          // Modes de paiement
          GlassCard(
            child: Column(
              children: [
                const SectionHeader(title: 'Détail par Mode de Paiement', icon: Icons.pie_chart_outline),
                const SizedBox(height: 14),
                ...[
                  ['Espèces', totalCash, AppTheme.warning, Icons.money],
                  ['Mobile Money', totalMobile, const Color(0xFF9C27B0), Icons.phone_android],
                  ['Carte Bancaire', totalCard, AppTheme.primary, Icons.credit_card],
                ].map((row) {
                  final total = provider.todayRevenue;
                  final pct = total > 0 ? (row[1] as double) / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(row[3] as IconData, color: row[2] as Color, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(row[0] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                            Text('${fmt.format(row[1])} F', style: TextStyle(color: row[2] as Color, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.surfaceLight,
                            valueColor: AlwaysStoppedAnimation<Color>(row[2] as Color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ===== CHARGES DU JOUR =====
          GlassCard(
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            child: Column(
              children: [
                Row(
                  children: [
                    const SectionHeader(title: 'Charges du Jour', icon: Icons.money_off),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showAddChargeDialog(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add, color: AppTheme.error, size: 14),
                            SizedBox(width: 4),
                            Text('Ajouter', style: TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (provider.todayCharges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucune charge enregistrée aujourd\'hui',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  )
                else ...[
                  ...provider.todayCharges.map((charge) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: AppTheme.error, size: 8),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(charge['label'] as String,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                              if ((charge['note'] as String?)?.isNotEmpty == true)
                                Text(charge['note'] as String,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('${fmt.format(charge['amount'])} F',
                          style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => provider.removeDailyCharge(charge['id'] as String),
                          child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 16),
                        ),
                      ],
                    ),
                  )),
                  const Divider(color: Color(0xFF2A2A5A)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL CHARGES',
                        style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700)),
                      Text('${fmt.format(totalCharges)} F CFA',
                        style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══ RECETTE DE VENTE PAR PRODUIT ════════════════════════════
          _buildRecetteVenteCard(todayPaid, fmt),

          const SizedBox(height: 16),
          // Dernières transactions
          GlassCard(
            child: Column(
              children: [
                const SectionHeader(title: 'Dernières Transactions', icon: Icons.history),
                const SizedBox(height: 12),
                ...todayPaid.take(10).map((o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('#${o.orderNumber} Table ${o.tableNumber}',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                      Text(o.paymentMethod ?? '-',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text('${fmt.format(o.totalAmount)} F',
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                )),
                if (todayPaid.isEmpty)
                  const EmptyState(icon: Icons.receipt, title: 'Aucune transaction aujourd\'hui'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Section Recette de Vente — agrège les articles de toutes les
  //  commandes réglées du jour (produit | qté | prix unitaire | total)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRecetteVenteCard(List<Order> todayPaid, NumberFormat fmt) {
    // Agréger les articles : Map<productName, {qty, unitPrice, total}>
    final Map<String, Map<String, dynamic>> aggregated = {};

    for (final order in todayPaid) {
      for (final item in order.items) {
        final key = item.productName;
        if (aggregated.containsKey(key)) {
          aggregated[key]!['qty'] = (aggregated[key]!['qty'] as int) + item.quantity;
          aggregated[key]!['total'] = (aggregated[key]!['total'] as double) + item.totalPrice;
        } else {
          aggregated[key] = {
            'qty': item.quantity,
            'unitPrice': item.unitPrice,
            'total': item.totalPrice,
          };
        }
      }
    }

    final entries = aggregated.entries.toList()
      ..sort((a, b) => (b.value['total'] as double).compareTo(a.value['total'] as double));

    final grandTotal = entries.fold<double>(0, (s, e) => s + (e.value['total'] as double));

    return GlassCard(
      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      child: Column(
        children: [
          const SectionHeader(title: 'Recette de Vente', icon: Icons.storefront),
          const SizedBox(height: 12),

          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune vente enregistrée aujourd\'hui',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            )
          else ...[
            // En-tête du tableau
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text('Produit',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('Qté',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text('P.U.',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 68,
                    child: Text('Total',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Lignes produits
            ...entries.map((entry) {
              final name = entry.key;
              final qty = entry.value['qty'] as int;
              final unitPrice = entry.value['unitPrice'] as double;
              final total = entry.value['total'] as double;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        name,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$qty',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${fmt.format(unitPrice)} F',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      child: Text(
                        '${fmt.format(total)} F',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Ligne total général
            const Divider(color: Color(0xFF2A2A5A), height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL VENTES',
                  style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 12),
                ),
                Text(
                  '${fmt.format(grandTotal)} F CFA',
                  style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showAddChargeDialog(BuildContext context, AppProvider provider) {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter une charge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Libellé *',
                hintText: 'Ex: Électricité, Salaire, Achat...',
                prefixIcon: Icon(Icons.label_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Montant (F CFA) *',
                prefixIcon: Icon(Icons.money, color: AppTheme.error, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                prefixIcon: Icon(Icons.notes_outlined, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text);
              if (label.isNotEmpty && amount != null && amount > 0) {
                provider.addDailyCharge(label: label, amount: amount, note: noteCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
