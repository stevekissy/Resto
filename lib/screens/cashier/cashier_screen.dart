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
//  Tab 3 : Point de Caisse          (settlementInvoiceGenerated == true)
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
                  text: 'Commandes à encaisser',
                ),
                Tab(
                  icon: Badge(
                    label: Text('$tab2Count'),
                    isLabelVisible: tab2Count > 0,
                    child: const Icon(Icons.receipt_long, size: 16),
                  ),
                  text: 'En attente de règlement',
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
//  Affiche : commande, table, articles, total.
//  Bouton : "Encaisser" → génère facture provisoire → passe en awaiting_payment
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
            Text('Commande #${order.orderNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Table : ${order.tableNumber}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                  const Text('Montant à encaisser', style: TextStyle(color: AppTheme.textSecondary)),
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
            label: const Text('Générer la facture'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await provider.cashoutOrder(order.id);
      // Imprimer la facture d'encaissement provisoire
      final invoiceNumber = PrintService.generateReceiptNumber(order.orderNumber);
      PrintService().printCashoutInvoice(
        order: order,
        cashoutInvoiceNumber: invoiceNumber,
        cashierName: provider.currentUser?.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facture d\'encaissement #${order.orderNumber} générée — En attente de règlement'),
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
                  const Icon(Icons.point_of_sale, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Commandes à encaisser (${orders.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Étape 1 / 2', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Tout est encaissé !',
                    subtitle: 'Aucune commande en attente d\'encaissement.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) => _OrderCard(
                      order: orders[i],
                      fmt: _fmt,
                      onEncaisser: _processing ? null : () => _encaisser(ctx, orders[i], provider),
                    ),
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

// Carte commande Tab 1
class _OrderCard extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final VoidCallback? onEncaisser;

  const _OrderCard({required this.order, required this.fmt, this.onEncaisser});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('#${order.orderNumber}',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.table_restaurant, color: AppTheme.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text('Table ${order.tableNumber}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              // Badge statut commande
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: order.statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(order.statusLabel,
                  style: TextStyle(color: order.statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Articles (lecture seule — PAS de mode paiement ici)
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, color: AppTheme.textSecondary, size: 8),
                    const SizedBox(width: 6),
                    Text('${item.quantity}×  ${item.productName}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                Text('${fmt.format(item.totalPrice)} F',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          )),

          const Divider(color: Color(0xFF2A2A5A), height: 16),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${fmt.format(order.totalAmount)} F CFA',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),

          const SizedBox(height: 10),

          // Bouton Encaisser
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEncaisser,
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Encaisser', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 2 — Factures en attente de règlement (cashStatus == awaiting_payment)
//  Affiche la facture d'encaissement provisoire.
//  Bouton : "Régler" → dialog paiement → règlement définitif
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
          try {
            await provider.settleOrder(
              order.id,
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
            );

            // Imprimer la facture de règlement définitive
            final settlementNumber = PrintService.generateSettlementNumber(order.orderNumber);
            final amountDue = order.totalAmount;
            final change = (amountPaid - amountDue).clamp(0.0, double.infinity);
            PrintService().printSettlementInvoice(
              order: order,
              settlementInvoiceNumber: settlementNumber,
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
              changeAmount: change,
              cashierName: provider.currentUser?.name,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Règlement définitif #${order.orderNumber} enregistré — ${_fmt.format(amountDue)} F CFA'),
                  backgroundColor: AppTheme.success,
                  duration: const Duration(seconds: 4),
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
                  const Icon(Icons.hourglass_top, color: Color(0xFFFF9800), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'En attente de règlement (${orders.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Étape 2 / 2', style: TextStyle(color: Color(0xFFFF9800), fontSize: 11)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                ? const EmptyState(
                    icon: Icons.task_alt,
                    title: 'Aucune facture en attente',
                    subtitle: 'Toutes les factures provisoires ont été réglées.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) => _FactureEnAttenteCard(
                      order: orders[i],
                      fmt: _fmt,
                      onRegler: _processing ? null : () => _regler(context, orders[i], provider),
                      onReimprimer: () {
                        PrintService().printCashoutInvoice(
                          order: orders[i],
                          cashoutInvoiceNumber: orders[i].cashoutInvoiceNumber ?? PrintService.generateReceiptNumber(orders[i].orderNumber),
                          cashierName: provider.currentUser?.name,
                        );
                      },
                    ),
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

// Carte facture en attente Tab 2
class _FactureEnAttenteCard extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final VoidCallback? onRegler;
  final VoidCallback? onReimprimer;

  const _FactureEnAttenteCard({
    required this.order,
    required this.fmt,
    this.onRegler,
    this.onReimprimer,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM HH:mm');
    final cashoutTime = order.cashoutAt != null ? dateFmt.format(order.cashoutAt!) : '--';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('#${order.orderNumber}',
                      style: const TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Text('Table ${order.tableNumber}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('FACTURE PROVISOIRE', style: TextStyle(color: Color(0xFFFF9800), fontSize: 9, fontWeight: FontWeight.w600)),
                  Text('Encaissé le $cashoutTime',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ],
              ),
            ],
          ),

          if (order.cashoutInvoiceNumber != null) ...[
            const SizedBox(height: 4),
            Text('Réf. : ${order.cashoutInvoiceNumber}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
          if (order.cashierName != null) ...[
            Text('Caissier(ère) : ${order.cashierName}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],

          const Divider(color: Color(0xFF2A2A5A), height: 14),

          // Articles
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${item.quantity}×  ${item.productName}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('${fmt.format(item.totalPrice)} F',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          )),

          const Divider(color: Color(0xFF2A2A5A), height: 14),

          // Montant dû
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('MONTANT DÛ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${fmt.format(order.totalAmount)} F CFA',
                style: const TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),

          const SizedBox(height: 10),

          // Boutons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReimprimer,
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
                  onPressed: onRegler,
                  icon: const Icon(Icons.payments, size: 16),
                  label: const Text('Régler', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DIALOG DE RÈGLEMENT — affiché après clic "Régler"
//  Affiche : mode paiement, montant à payer, montant reçu, monnaie rendue
//  Collecte : mode paiement + montant reçu
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

  final List<Map<String, dynamic>> _paymentMethods = [
    {'label': 'Espèces',    'icon': Icons.money,          'color': const Color(0xFF4CAF50)},
    {'label': 'Mobile Money','icon': Icons.phone_android,  'color': const Color(0xFF2196F3)},
    {'label': 'Carte',      'icon': Icons.credit_card,    'color': const Color(0xFF9C27B0)},
    {'label': 'Chèque',     'icon': Icons.receipt,        'color': const Color(0xFFFF9800)},
  ];

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec le montant exact
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
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête coloré
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payments, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('RÈGLEMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Commande #${widget.order.orderNumber}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('Table ${widget.order.tableNumber}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateFmt.format(DateTime.now()),
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(widget.cashierName,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Montant dû
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('MONTANT À PAYER', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        Text('${widget.fmt.format(widget.order.totalAmount)} F CFA',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 20)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mode de paiement
                  const Text('Mode de paiement', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paymentMethods.map((pm) {
                      final isSelected = _paymentMethod == pm['label'];
                      final color = pm['color'] as Color;
                      return InkWell(
                        onTap: () => setState(() => _paymentMethod = pm['label'] as String),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? color : Colors.white24,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(pm['icon'] as IconData, color: isSelected ? color : AppTheme.textSecondary, size: 16),
                              const SizedBox(width: 6),
                              Text(pm['label'] as String,
                                style: TextStyle(
                                  color: isSelected ? color : AppTheme.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                  fontSize: 13,
                                )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Montant reçu
                  const Text('Montant reçu', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      suffixText: 'F CFA',
                      suffixStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A5A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Monnaie rendue
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _change > 0
                        ? AppTheme.success.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _change > 0
                          ? AppTheme.success.withValues(alpha: 0.5)
                          : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _change > 0 ? Icons.arrow_circle_down : Icons.remove_circle_outline,
                              color: _change > 0 ? AppTheme.success : AppTheme.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('Monnaie rendue', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        Text(
                          '${widget.fmt.format(_change)} F CFA',
                          style: TextStyle(
                            color: _change > 0 ? AppTheme.success : AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Avertissement si montant insuffisant (espèces)
                  if (_paymentMethod == 'Espèces' && _amountPaid < widget.order.totalAmount && _amountPaid > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
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

            // Boutons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isValid
                        ? () => widget.onConfirm(_paymentMethod, _amountPaid > 0 ? _amountPaid : widget.order.totalAmount)
                        : null,
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Confirmer le règlement', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 3 — Point de Caisse (settlementInvoiceGenerated == true seulement)
// ════════════════════════════════════════════════════════════════════════════
class _PointCaisseTab extends StatelessWidget {
  const _PointCaisseTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###', 'fr_FR');
    final dateFmt = DateFormat('dd/MM HH:mm');

    // Uniquement les règlements définitifs du jour
    final today = DateTime.now();
    final settled = provider.settledOrders.where((o) =>
      o.createdAt.day == today.day &&
      o.createdAt.month == today.month &&
      o.createdAt.year == today.year
    ).toList()
      ..sort((a, b) => (b.settledAt ?? b.createdAt).compareTo(a.settledAt ?? a.createdAt));

    final totalRevenue = settled.fold(0.0, (s, o) => s + o.totalAmount);
    final revenueByMethod = provider.todayRevenueByPaymentMethod;
    final totalOrders = settled.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Résumé du jour ──
          _SummaryCard(
            totalRevenue: totalRevenue,
            totalOrders: totalOrders,
            fmt: fmt,
          ),

          const SizedBox(height: 16),

          // ── Répartition par mode de paiement ──
          if (revenueByMethod.isNotEmpty) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart, color: AppTheme.primary, size: 16),
                      SizedBox(width: 8),
                      Text('Répartition par mode de paiement',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...revenueByMethod.entries.map((e) {
                    final pct = totalRevenue > 0 ? (e.value / totalRevenue * 100) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              Text('${fmt.format(e.value)} F (${pct.toStringAsFixed(1)}%)',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: totalRevenue > 0 ? e.value / totalRevenue : 0,
                            backgroundColor: Colors.white12,
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Liste des règlements ──
          Row(
            children: [
              const Icon(Icons.history, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Règlements du jour (${settled.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (settled.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long,
              title: 'Aucun règlement aujourd\'hui',
              subtitle: 'Les règlements définitifs apparaîtront ici.',
            )
          else
            ...settled.map((order) => GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Numéro commande
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('#${order.orderNumber}',
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 12),
                        textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Table ${order.tableNumber}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: AppTheme.textSecondary, size: 11),
                            const SizedBox(width: 3),
                            Text(
                              order.settledAt != null ? dateFmt.format(order.settledAt!) : '--',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(width: 8),
                            if (order.paymentMethod != null) ...[
                              const Icon(Icons.payment, color: AppTheme.textSecondary, size: 11),
                              const SizedBox(width: 3),
                              Text(order.paymentMethod!,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ],
                        ),
                        if (order.settlementInvoiceNumber != null)
                          Text(order.settlementInvoiceNumber!,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                      ],
                    ),
                  ),
                  // Montant
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${fmt.format(order.totalAmount)} F',
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('RÉGLÉ', style: TextStyle(color: AppTheme.success, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// Widget résumé point de caisse
class _SummaryCard extends StatelessWidget {
  final double totalRevenue;
  final int totalOrders;
  final NumberFormat fmt;

  const _SummaryCard({required this.totalRevenue, required this.totalOrders, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2196F3).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('POINT DE CAISSE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Aujourd\'hui', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(dateFmt.format(DateTime.now()),
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 16),
          Text(
            '${fmt.format(totalRevenue)} F CFA',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 30, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          const Text('Total des règlements définitifs', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatBadge(label: 'Factures réglées', value: '$totalOrders', icon: Icons.check_circle),
              const SizedBox(width: 16),
              _StatBadge(label: 'Moyenne / facture',
                value: totalOrders > 0 ? '${fmt.format(totalRevenue / totalOrders)} F' : '--',
                icon: Icons.trending_up),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBadge({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
