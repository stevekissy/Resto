import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CashierScreen — Caisse Sankadio Manager
//  UN SEUL module caisse — design identique admin/manager/cashier
//  Tab 1 : Commandes à encaisser   (cashStatus == pending_cashout)
//  Tab 2 : Factures en attente     (cashStatus == awaiting_payment)
//  Tab 3 : Point de Caisse         (paymentStatus=paid + settlementStatus=completed)
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
          // ── TABS ────────────────────────────────────────────────────
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
//  TAB 1 — Commandes à encaisser
//  Affiche : numéro, table, articles, total
//  Bouton "Encaisser" → facture provisoire → Tab 2
// ════════════════════════════════════════════════════════════════════════════
class _CaisseTab extends StatefulWidget {
  const _CaisseTab();

  @override
  State<_CaisseTab> createState() => _CaisseTabState();
}

class _CaisseTabState extends State<_CaisseTab> {
  final _fmt = NumberFormat('#,###', 'fr_FR');
  bool _processing = false;

  Future<void> _encaisser(
      BuildContext context, Order order, AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Générer la facture',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Commande #${order.orderNumber}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text('Table : ${order.tableNumber}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Montant à encaisser',
                      style:
                          TextStyle(color: AppTheme.textSecondary)),
                  Text('${_fmt.format(order.totalAmount)} F CFA',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Une facture d\'encaissement provisoire sera générée.\nLe règlement définitif se fera à l\'étape suivante.',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.receipt_long, size: 16),
            label: const Text('Encaisser'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _processing = true);
    try {
      // cashoutOrder() retourne le numéro généré ET sauvegardé en Firestore.
      // On utilise ce même numéro pour le PDF — pas de double génération.
      final invoiceNumber = await provider.cashoutOrder(order.id);
      PrintService().printCashoutInvoice(
        order: order,
        cashoutInvoiceNumber: invoiceNumber,
        cashierName: provider.currentUser?.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Facture d\'encaissement générée — En attente de règlement'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red));
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
                  const Icon(Icons.receipt_long,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Commandes à encaisser (${orders.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle,
                      title: 'Tout est encaissé !',
                      subtitle:
                          'Aucune commande en attente de paiement',
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) {
                        final order = orders[i];
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '#${order.orderNumber} - Table ${order.tableNumber}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                  Text(
                                      '${_fmt.format(order.totalAmount)} F CFA',
                                      style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...order.items.map((item) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 2),
                                    child: Text(
                                        '${item.quantity}× ${item.productName}',
                                        style: const TextStyle(
                                            color:
                                                AppTheme.textSecondary,
                                            fontSize: 12)),
                                  )),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _processing
                                      ? null
                                      : () => _encaisser(
                                          ctx, order, provider),
                                  icon: const Icon(
                                      Icons.receipt_long,
                                      size: 16),
                                  label: const Text('Encaisser',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets
                                        .symmetric(vertical: 10),
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
//  TAB 2 — Factures en attente de règlement
//  Bouton "Réimprimer" + bouton "Régler" → _ReglementDialog
// ════════════════════════════════════════════════════════════════════════════
class _FacturesEnAttenteTab extends StatefulWidget {
  const _FacturesEnAttenteTab();

  @override
  State<_FacturesEnAttenteTab> createState() =>
      _FacturesEnAttenteTabState();
}

class _FacturesEnAttenteTabState extends State<_FacturesEnAttenteTab> {
  final _fmt = NumberFormat('#,###', 'fr_FR');
  bool _processing = false;

  Future<void> _regler(
      BuildContext context, Order order, AppProvider provider) async {
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
          try {
            await provider.settleOrder(
              order.id,
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
            );
            final settlementNumber =
                PrintService.generateSettlementNumber(order.orderNumber);
            final amountDue = order.totalAmount;
            final change =
                (amountPaid - amountDue).clamp(0.0, double.infinity);
            final cashierName = provider.currentUser?.name;
            // Impression automatique
            PrintService().printSettlementInvoice(
              order: order,
              settlementInvoiceNumber: settlementNumber,
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
              changeAmount: change,
              cashierName: cashierName,
            );
            if (mounted) {
              // ── Dialog de succès avec bouton Imprimer facture définitive ──
              await showDialog(
                context: context,
                builder: (dctx) => _ReglementSuccessDialog(
                  order: order,
                  settlementNumber: settlementNumber,
                  paymentMethod: paymentMethod,
                  amountPaid: amountPaid,
                  changeAmount: change,
                  cashierName: cashierName,
                  fmt: _fmt,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Erreur règlement : $e'),
                  backgroundColor: Colors.red));
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
                  const Icon(Icons.hourglass_top,
                      color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Text(
                      'Factures en attente de règlement (${orders.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) {
                        final order = orders[i];
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          border: Border.all(
                            color:
                                AppTheme.warning.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // En-tête
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '#${order.orderNumber} - Table ${order.tableNumber}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(5),
                                    ),
                                    child: const Text('EN ATTENTE',
                                        style: TextStyle(
                                            color: AppTheme.warning,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w700)),
                                  ),
                                ],
                              ),
                              if (order.cashoutInvoiceNumber !=
                                  null) ...[
                                const SizedBox(height: 3),
                                Text(
                                    'Réf. : ${order.cashoutInvoiceNumber}',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10)),
                              ],
                              const SizedBox(height: 6),
                              // Articles
                              ...order.items.map((item) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 2),
                                    child: Text(
                                        '${item.quantity}× ${item.productName}',
                                        style: const TextStyle(
                                            color:
                                                AppTheme.textSecondary,
                                            fontSize: 12)),
                                  )),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Montant dû',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12)),
                                  Text(
                                      '${_fmt.format(order.totalAmount)} F CFA',
                                      style: const TextStyle(
                                          color: AppTheme.warning,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Boutons Réimprimer + Régler
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        PrintService()
                                            .printCashoutInvoice(
                                          order: order,
                                          cashoutInvoiceNumber: order
                                                  .cashoutInvoiceNumber ??
                                              PrintService
                                                  .generateReceiptNumber(
                                                      order.orderNumber),
                                          cashierName: provider
                                              .currentUser?.name,
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.print_outlined,
                                          size: 14),
                                      label: const Text('Réimprimer',
                                          style:
                                              TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppTheme.textSecondary,
                                        side: BorderSide(
                                            color: AppTheme.textSecondary
                                                .withValues(alpha: 0.4)),
                                        padding: const EdgeInsets
                                            .symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: _processing
                                          ? null
                                          : () => _regler(
                                              context, order, provider),
                                      icon: const Icon(Icons.payments,
                                          size: 16),
                                      label: const Text('Régler',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.w700)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.success,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets
                                            .symmetric(vertical: 10),
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
//  DIALOG SUCCÈS RÈGLEMENT — bouton "Imprimer la facture définitive"
// ════════════════════════════════════════════════════════════════════════════
class _ReglementSuccessDialog extends StatelessWidget {
  final Order order;
  final String settlementNumber;
  final String paymentMethod;
  final double amountPaid;
  final double changeAmount;
  final String? cashierName;
  final NumberFormat fmt;

  const _ReglementSuccessDialog({
    required this.order,
    required this.settlementNumber,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    required this.cashierName,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Règlement confirmé',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Commande #${order.orderNumber}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Récapitulatif
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _Row('N° Facture', settlementNumber),
                _Row('Table', 'Table ${order.tableNumber}'),
                _Row('Mode paiement', paymentMethod),
                _Row('Montant réglé', '${fmt.format(order.totalAmount)} F CFA'),
                _Row('Montant versé', '${fmt.format(amountPaid)} F CFA'),
                _Row('Monnaie rendue', '${fmt.format(changeAmount)} F CFA',
                    valueColor: changeAmount > 0 ? AppTheme.success : null),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bouton Imprimer la facture définitive
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                PrintService().printSettlementInvoice(
                  order: order,
                  settlementInvoiceNumber: settlementNumber,
                  paymentMethod: paymentMethod,
                  amountPaid: amountPaid,
                  changeAmount: changeAmount,
                  cashierName: cashierName,
                );
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Imprimer la facture définitive',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'La facture s\'ouvrira dans une nouvelle fenêtre pour impression ou téléchargement PDF.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _Row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          )),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DIALOG RÈGLEMENT — 1 seule phase
//  Montant dû | Mode paiement | Montant versé | Monnaie rendue
//  Bouton "Confirmer le règlement"
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

  double get _change =>
      (_amountPaid - widget.order.totalAmount).clamp(0.0, double.infinity);
  bool get _isValid =>
      _amountPaid >= widget.order.totalAmount ||
      _paymentMethod != 'Espèces';

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.order.totalAmount;
    _amountController.text =
        widget.order.totalAmount.toStringAsFixed(0);
    _amountController.addListener(() {
      final val = double.tryParse(_amountController.text
              .replaceAll(' ', '')
              .replaceAll(',', '.')) ??
          0;
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.payments, color: AppTheme.success),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Règlement',
                  style:
                      TextStyle(color: Colors.white, fontSize: 16)),
              Text(
                  'Commande #${widget.order.orderNumber} — Table ${widget.order.tableNumber}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
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
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MONTANT DÛ',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  Text(
                      '${widget.fmt.format(widget.order.totalAmount)} F CFA',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Mode de paiement
            const Text('Mode de paiement',
                style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Espèces',
                'Mobile Money',
                'Carte Bancaire',
                'Chèque'
              ].map((m) {
                final selected = _paymentMethod == m;
                return ChoiceChip(
                  label: Text(m),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _paymentMethod = m),
                  selectedColor:
                      AppTheme.primary.withValues(alpha: 0.25),
                  backgroundColor: AppTheme.surfaceLight,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppTheme.primary
                        : Colors.transparent,
                    width: selected ? 1.5 : 0,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Montant versé
            const Text('Montant versé',
                style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                suffixText: 'F CFA',
                suffixStyle:
                    const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF2A2A5A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppTheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
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
                  const Text('Monnaie rendue',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  Text('${widget.fmt.format(_change)} F CFA',
                      style: TextStyle(
                        color: _change > 0
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      )),
                ],
              ),
            ),
            // Avertissement montant insuffisant
            if (_paymentMethod == 'Espèces' &&
                _amountPaid > 0 &&
                _amountPaid < widget.order.totalAmount) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Montant insuffisant (manque ${widget.fmt.format(widget.order.totalAmount - _amountPaid)} F)',
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 11),
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
          child: const Text('Annuler',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _isValid
              ? () => widget.onConfirm(
                  _paymentMethod,
                  _amountPaid > 0
                      ? _amountPaid
                      : widget.order.totalAmount)
              : null,
          icon: const Icon(Icons.check_circle, size: 16),
          label: const Text('Confirmer le règlement',
              style: TextStyle(fontWeight: FontWeight.w700)),
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
//  Cartes : Recette Brute | Charges du Jour | Recette Nette | Commandes
//  Détail par Mode de Paiement + Charges + Dernières Transactions
//  Filtre : settlementInvoiceGenerated == true uniquement
// ════════════════════════════════════════════════════════════════════════════
class _PointCaisseTab extends StatefulWidget {
  const _PointCaisseTab();

  @override
  State<_PointCaisseTab> createState() => _PointCaisseTabState();
}

class _PointCaisseTabState extends State<_PointCaisseTab> {
  bool _showRecetteVente = false;
  DateTime _recetteDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###', 'fr_FR');
    final today = DateTime.now();

    // Uniquement les règlements définitifs du jour
    // Filtre sur settledAt (date du règlement) et non createdAt (date de commande)
    final todayPaid = provider.orders
        .where((o) {
          if (!o.settlementInvoiceGenerated || !o.isPaid) return false;
          final settled = o.settledAt;
          if (settled == null) return false;
          return settled.day == today.day &&
              settled.month == today.month &&
              settled.year == today.year;
        })
        .toList();

    final totalCash = todayPaid
        .where((o) => o.paymentMethod == 'Espèces')
        .fold<double>(0, (s, o) => s + o.totalAmount);
    final totalMobile = todayPaid
        .where((o) =>
            o.paymentMethod != null &&
            o.paymentMethod != 'Espèces' &&
            o.paymentMethod != 'Carte Bancaire')
        .fold<double>(0, (s, o) => s + o.totalAmount);
    final totalCard = todayPaid
        .where((o) => o.paymentMethod == 'Carte Bancaire')
        .fold<double>(0, (s, o) => s + o.totalAmount);
    final totalCharges = provider.todayTotalCharges;
    final netRevenue = provider.todayRevenue - totalCharges;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // En-tête
          GlassCard(
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            child: Column(
              children: [
                const Text('POINT DE CAISSE DU JOUR',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(today),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Grille 4 cartes
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              StatCard(
                  title: 'Recette Brute',
                  value: '${fmt.format(provider.todayRevenue)} F',
                  icon: Icons.payments,
                  color: AppTheme.success),
              StatCard(
                  title: 'Charges du Jour',
                  value: '${fmt.format(totalCharges)} F',
                  icon: Icons.money_off,
                  color: AppTheme.error),
              StatCard(
                  title: 'Recette Nette',
                  value: '${fmt.format(netRevenue)} F',
                  icon: Icons.account_balance_wallet,
                  color: netRevenue >= 0
                      ? AppTheme.primary
                      : AppTheme.error),
              StatCard(
                  title: 'Commandes',
                  value: todayPaid.length.toString(),
                  icon: Icons.receipt_long,
                  color: AppTheme.warning),
            ],
          ),
          const SizedBox(height: 16),
          // Détail par Mode de Paiement
          GlassCard(
            child: Column(
              children: [
                const SectionHeader(
                    title: 'Détail par Mode de Paiement',
                    icon: Icons.pie_chart_outline),
                const SizedBox(height: 14),
                ...[
                  ['Espèces', totalCash, AppTheme.warning, Icons.money],
                  [
                    'Mobile Money',
                    totalMobile,
                    const Color(0xFF9C27B0),
                    Icons.phone_android
                  ],
                  [
                    'Carte Bancaire',
                    totalCard,
                    AppTheme.primary,
                    Icons.credit_card
                  ],
                ].map((row) {
                  final total = provider.todayRevenue;
                  final pct =
                      total > 0 ? (row[1] as double) / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(row[3] as IconData,
                                color: row[2] as Color, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(row[0] as String,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13))),
                            Text('${fmt.format(row[1])} F',
                                style: TextStyle(
                                    color: row[2] as Color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.surfaceLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                row[2] as Color),
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
          // ── Recette de Vente ──────────────────────────────────────────────
          GlassCard(
            border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.4)),
            child: Column(
              children: [
                Row(
                  children: [
                    const SectionHeader(title: 'Recette de Vente', icon: Icons.bar_chart),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _showRecetteVente = !_showRecetteVente),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(_showRecetteVente ? Icons.expand_less : Icons.expand_more,
                                color: const Color(0xFF42A5F5), size: 14),
                            const SizedBox(width: 4),
                            Text(_showRecetteVente ? 'Masquer' : 'Afficher',
                                style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showRecetteVente) ...[
                  const SizedBox(height: 10),
                  // Filtre date
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Text(DateFormat('dd/MM/yyyy', 'fr_FR').format(_recetteDate),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _recetteDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.primary,
                                  surface: AppTheme.surface,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setState(() => _recetteDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.edit_calendar, color: AppTheme.primary, size: 13),
                              SizedBox(width: 4),
                              Text('Changer', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RecetteVenteTable(
                    orders: provider.orders,
                    filterDate: _recetteDate,
                    fmt: fmt,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Charges du Jour
          GlassCard(
            border: Border.all(
                color: AppTheme.error.withValues(alpha: 0.3)),
            child: Column(
              children: [
                Row(
                  children: [
                    const SectionHeader(
                        title: 'Charges du Jour',
                        icon: Icons.money_off),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          _showAddChargeDialog(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.error
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add,
                                color: AppTheme.error, size: 14),
                            SizedBox(width: 4),
                            Text('Ajouter',
                                style: TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
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
                    child: Text(
                        'Aucune charge enregistrée aujourd\'hui',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12)),
                  )
                else ...[
                  ...provider.todayCharges.map((charge) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.circle,
                                color: AppTheme.error, size: 8),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(charge['label'] as String,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13)),
                                  if ((charge['note'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    Text(charge['note'] as String,
                                        style: const TextStyle(
                                            color:
                                                AppTheme.textSecondary,
                                            fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('${fmt.format(charge['amount'])} F',
                                style: const TextStyle(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => provider.removeDailyCharge(
                                  charge['id'] as String),
                              child: const Icon(Icons.close,
                                  color: AppTheme.textSecondary,
                                  size: 16),
                            ),
                          ],
                        ),
                      )),
                  const Divider(color: Color(0xFF2A2A5A)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL CHARGES',
                          style: TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w700)),
                      Text('${fmt.format(totalCharges)} F CFA',
                          style: const TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Dernières Transactions
          GlassCard(
            child: Column(
              children: [
                const SectionHeader(
                    title: 'Dernières Transactions',
                    icon: Icons.history),
                const SizedBox(height: 12),
                ...todayPaid.take(10).map((o) => Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '#${o.orderNumber} Table ${o.tableNumber}',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12)),
                          Text(o.paymentMethod ?? '-',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          Text('${fmt.format(o.totalAmount)} F',
                              style: const TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ],
                      ),
                    )),
                if (todayPaid.isEmpty)
                  const EmptyState(
                      icon: Icons.receipt,
                      title: 'Aucune transaction aujourd\'hui'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChargeDialog(
      BuildContext context, AppProvider provider) {
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
                prefixIcon:
                    Icon(Icons.label_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Montant (F CFA) *',
                prefixIcon: Icon(Icons.money,
                    color: AppTheme.error, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                prefixIcon:
                    Icon(Icons.notes_outlined, size: 18),
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
              final amount =
                  double.tryParse(amountCtrl.text);
              if (label.isNotEmpty &&
                  amount != null &&
                  amount > 0) {
                provider.addDailyCharge(
                    label: label,
                    amount: amount,
                    note: noteCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Recette de Vente — tableau produits vendus
//  Filtre : paymentStatus=paid + settlementStatus=completed
// ════════════════════════════════════════════════════════════════════════════
class _RecetteVenteTable extends StatelessWidget {
  final List<Order> orders;
  final DateTime filterDate;
  final NumberFormat fmt;

  const _RecetteVenteTable({
    required this.orders,
    required this.filterDate,
    required this.fmt,
  });

  List<Order> get _filteredOrders {
    return orders.where((o) {
      if (o.paymentStatus != 'paid') return false;
      if (o.settlementStatus != 'completed') return false;
      final settled = o.settledAt;
      if (settled == null) return false;
      return settled.day == filterDate.day &&
          settled.month == filterDate.month &&
          settled.year == filterDate.year;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final paid = _filteredOrders;

    if (paid.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('Aucune vente pour cette date.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ),
      );
    }

    // Agréger par produit
    final Map<String, _ProductStat> stats = {};
    for (final order in paid) {
      for (final item in order.items) {
        final key = item.productName;
        if (stats.containsKey(key)) {
          stats[key]!.quantity += item.quantity;
          stats[key]!.totalAmount += item.totalPrice;
          stats[key]!.orderCount++;
        } else {
          stats[key] = _ProductStat(
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalAmount: item.totalPrice,
            orderCount: 1,
          );
        }
      }
    }

    final rows = stats.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final grandTotal = rows.fold<double>(0, (s, r) => s + r.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête tableau
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Expanded(flex: 4, child: Text('Produit', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
              SizedBox(width: 4),
              Expanded(flex: 1, child: Text('Qté', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('P.U', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('Total', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('Cmds', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Lignes produits
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(flex: 4, child: Text(r.productName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Expanded(flex: 1, child: Text('${r.quantity}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('${fmt.format(r.unitPrice)} F', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('${fmt.format(r.totalAmount)} F', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('${r.orderCount}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), textAlign: TextAlign.center)),
            ],
          ),
        )),
        const Divider(color: Color(0xFF2A2A5A)),
        // Total général
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${paid.length} commande(s) réglée(s)',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            Text('TOTAL : ${fmt.format(grandTotal)} F CFA',
                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w900, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        // Bouton Imprimer / Export PDF
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _printRecetteVente(rows, grandTotal, paid.length),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Imprimer / Export PDF', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  void _printRecetteVente(List<_ProductStat> rows, double grandTotal, int nbOrders) {
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(filterDate);
    final rowsHtml = rows.map((r) => '''
      <tr>
        <td style="padding:5px 8px; text-align:left;">${_esc(r.productName)}</td>
        <td style="padding:5px 8px; text-align:center;">${r.quantity}</td>
        <td style="padding:5px 8px; text-align:right;">${fmt.format(r.unitPrice)} F</td>
        <td style="padding:5px 8px; text-align:right; font-weight:600; color:#5C6BC0;">${fmt.format(r.totalAmount)} F</td>
        <td style="padding:5px 8px; text-align:center; color:#888;">${r.orderCount}</td>
      </tr>''').join();

    final html = '''
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<title>Recette de Vente — $dateStr</title>
<style>
  body { font-family: Arial, sans-serif; margin: 20px; color: #222; }
  h1 { font-size: 18px; color: #1a237e; margin-bottom: 4px; }
  .sub { color: #555; font-size: 13px; margin-bottom: 16px; }
  table { width: 100%; border-collapse: collapse; }
  thead th { background: #1a237e; color: #fff; padding: 8px; font-size: 12px; }
  tbody tr:nth-child(even) { background: #f5f5f5; }
  tfoot td { font-weight: bold; background: #e8eaf6; padding: 8px; }
  @media print { button { display:none; } }
</style></head>
<body>
  <h1>RECETTE DE VENTE — RESTAURANT SANKADIOKRO</h1>
  <div class="sub">Date : $dateStr &nbsp;|&nbsp; $nbOrders commande(s) réglée(s)</div>
  <table>
    <thead><tr><th style="text-align:left">Produit</th><th>Qté</th><th style="text-align:right">P.U</th><th style="text-align:right">Total</th><th>Cmds</th></tr></thead>
    <tbody>$rowsHtml</tbody>
    <tfoot><tr><td colspan="3"><strong>TOTAL GÉNÉRAL</strong></td><td style="text-align:right; font-size:15px; color:#2E7D32;"><strong>${fmt.format(grandTotal)} F CFA</strong></td><td></td></tr></tfoot>
  </table>
  <br/>
  <button onclick="window.print()" style="padding:10px 24px; background:#1a237e; color:#fff; border:none; border-radius:6px; cursor:pointer; font-size:14px;">Imprimer / Télécharger PDF</button>
</body></html>''';

    PrintService.openHtmlInNewTab(html);
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class _ProductStat {
  final String productName;
  int quantity;
  final double unitPrice;
  double totalAmount;
  int orderCount;

  _ProductStat({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.orderCount,
  });
}
