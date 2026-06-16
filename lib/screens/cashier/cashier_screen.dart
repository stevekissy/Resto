import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> with SingleTickerProviderStateMixin {
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
              tabs: const [
                Tab(text: 'Caisse', icon: Icon(Icons.point_of_sale, size: 16)),
                Tab(text: 'Factures', icon: Icon(Icons.receipt, size: 16)),
                Tab(text: 'Point de Caisse', icon: Icon(Icons.bar_chart, size: 16)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CaisseTab(),
                _FacturesTab(),
                _PointCaisseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================== CAISSE TAB ===================
class _CaisseTab extends StatefulWidget {
  const _CaisseTab();

  @override
  State<_CaisseTab> createState() => _CaisseTabState();
}

class _CaisseTabState extends State<_CaisseTab> {
  Order? _selectedOrder;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final unpaidOrders = provider.orders.where((o) =>
      (o.status == OrderStatus.ready || o.status == OrderStatus.served) && !o.isPaid
    ).toList();

    return Row(
      children: [
        // Orders list
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Commandes à encaisser (${unpaidOrders.length})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
              Expanded(
                child: unpaidOrders.isEmpty
                  ? const EmptyState(icon: Icons.check_circle, title: 'Tout est encaissé !', subtitle: 'Aucune commande en attente de paiement')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: unpaidOrders.length,
                      itemBuilder: (ctx, i) {
                        final order = unpaidOrders[i];
                        final isSelected = _selectedOrder?.id == order.id;
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A),
                            width: isSelected ? 2 : 1,
                          ),
                          onTap: () => setState(() => _selectedOrder = order),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('#${order.orderNumber} - Table ${order.tableNumber}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                  Text('${order.totalAmount.toStringAsFixed(0)} F CFA',
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...order.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('${item.quantity}× ${item.productName}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              )),
                              if (isSelected) ...[
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _showPaymentDialog(context, order, provider),
                                  icon: const Icon(Icons.payment, size: 16),
                                  label: const Text('Encaisser'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
        // Selected order detail
        if (_selectedOrder != null)
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(left: BorderSide(color: const Color(0xFF2A2A5A))),
            ),
            child: _OrderDetail(
              order: _selectedOrder!,
              onPay: (method, discount, amountPaid) {
                provider.payOrder(_selectedOrder!.id, method, discount, amountPaid: amountPaid);
                _showInvoice(context, _selectedOrder!, amountPaid);
                setState(() => _selectedOrder = null);
              },
            ),
          ),
      ],
    );
  }

  void _showPaymentDialog(BuildContext context, Order order, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _PaymentDialog(
        order: order,
        onPay: (method, discount, amountPaid) {
          provider.payOrder(order.id, method, discount, amountPaid: amountPaid);
          Navigator.pop(context);
          _showInvoice(context, order, amountPaid);
          setState(() => _selectedOrder = null);
        },
      ),
    );
  }

  void _showInvoice(BuildContext context, Order order, double amountPaid) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => InvoiceScreen(order: order, amountPaid: amountPaid),
    ));
  }
}

// =================== ORDER DETAIL ===================
class _OrderDetail extends StatefulWidget {
  final Order order;
  final Function(String paymentMethod, double discount, double amountPaid) onPay;

  const _OrderDetail({required this.order, required this.onPay});

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  String _paymentMethod = 'Espèces';
  final _discountCtrl = TextEditingController(text: '0');
  final _amountPaidCtrl = TextEditingController(text: '0');
  final _methods = ['Espèces', 'Orange Money', 'MTN Money', 'Wave', 'Carte Bancaire', 'Moov Money'];

  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => (widget.order.subtotal - _discount).clamp(0, double.infinity);
  double get _amountPaid => double.tryParse(_amountPaidCtrl.text) ?? 0;
  double get _change => (_amountPaid - _total).clamp(0, double.infinity);
  bool get _insufficientAmount => _amountPaid > 0 && _amountPaid < _total;

  @override
  void dispose() {
    _discountCtrl.dispose();
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final order = widget.order;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Facture d\'Encaissement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('#${order.orderNumber} - Table ${order.tableNumber}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          // Articles
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A5A))),
            child: Column(
              children: [
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${item.quantity}× ${item.productName}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                      Text('${fmt.format(item.totalPrice)} F', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
                const Divider(color: Color(0xFF2A2A5A)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sous-total', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Text('${fmt.format(order.subtotal)} F', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Remise
          TextField(
            controller: _discountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Remise (F CFA)',
              prefixIcon: Icon(Icons.discount_outlined, color: AppTheme.warning, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          // Moyen de paiement
          const Text('Moyen de paiement', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _methods.map((m) => GestureDetector(
              onTap: () => setState(() => _paymentMethod = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _paymentMethod == m ? AppTheme.primary : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _paymentMethod == m ? AppTheme.primary : const Color(0xFF2A2A5A)),
                ),
                child: Text(m, style: TextStyle(color: _paymentMethod == m ? Colors.white : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),
          // Total à payer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL À PAYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${fmt.format(_total)} F CFA', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Montant versé
          TextField(
            controller: _amountPaidCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Montant versé (F CFA)',
              prefixIcon: const Icon(Icons.payments_outlined, color: AppTheme.success, size: 18),
              errorText: _insufficientAmount ? 'Montant insuffisant' : null,
            ),
          ),
          const SizedBox(height: 10),
          // Monnaie rendue
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _insufficientAmount
                ? AppTheme.error.withValues(alpha: 0.15)
                : AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _insufficientAmount
                ? AppTheme.error.withValues(alpha: 0.4)
                : AppTheme.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(
                    _insufficientAmount ? Icons.warning_amber_rounded : Icons.change_circle_outlined,
                    color: _insufficientAmount ? AppTheme.error : AppTheme.success,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _insufficientAmount ? 'MANQUE' : 'MONNAIE RENDUE',
                    style: TextStyle(
                      color: _insufficientAmount ? AppTheme.error : AppTheme.success,
                      fontWeight: FontWeight.w700, fontSize: 13,
                    ),
                  ),
                ]),
                Text(
                  _amountPaid == 0
                    ? '— F CFA'
                    : _insufficientAmount
                      ? '-${fmt.format(_total - _amountPaid)} F CFA'
                      : '${fmt.format(_change)} F CFA',
                  style: TextStyle(
                    color: _insufficientAmount ? AppTheme.error : AppTheme.success,
                    fontWeight: FontWeight.w900, fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Encaisser',
            icon: Icons.check_circle,
            isFullWidth: true,
            color: _insufficientAmount ? AppTheme.textSecondary : AppTheme.success,
            onPressed: _insufficientAmount
              ? null
              : () => widget.onPay(_paymentMethod, _discount, _amountPaid),
          ),
        ],
      ),
    );
  }
}

// =================== PAYMENT DIALOG ===================
class _PaymentDialog extends StatefulWidget {
  final Order order;
  final Function(String, double, double) onPay;

  const _PaymentDialog({required this.order, required this.onPay});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _method = 'Espèces';
  final _discountCtrl = TextEditingController(text: '0');
  final _amountPaidCtrl = TextEditingController(text: '0');
  final _methods = ['Espèces', 'Orange Money', 'MTN Money', 'Wave', 'Carte Bancaire'];

  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => (widget.order.subtotal - _discount).clamp(0, double.infinity);
  double get _amountPaid => double.tryParse(_amountPaidCtrl.text) ?? 0;
  double get _change => (_amountPaid - _total).clamp(0, double.infinity);
  bool get _insufficient => _amountPaid > 0 && _amountPaid < _total;

  @override
  void dispose() {
    _discountCtrl.dispose();
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return AlertDialog(
      title: Text('Paiement #${widget.order.orderNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sous-total: ${fmt.format(widget.order.subtotal)} F CFA',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            const SizedBox(height: 12),
            TextField(
              controller: _discountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Remise (F CFA)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _method,
              style: const TextStyle(color: Colors.white),
              dropdownColor: AppTheme.cardBg,
              decoration: const InputDecoration(labelText: 'Moyen de paiement'),
              items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _method = v!),
            ),
            const SizedBox(height: 12),
            // Total
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('${fmt.format(_total)} F CFA',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Montant versé
            TextField(
              controller: _amountPaidCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Montant versé (F CFA)',
                prefixIcon: const Icon(Icons.payments_outlined, color: AppTheme.success, size: 18),
                errorText: _insufficient ? 'Montant insuffisant' : null,
              ),
            ),
            const SizedBox(height: 10),
            // Monnaie rendue
            if (_amountPaid > 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _insufficient ? AppTheme.error.withValues(alpha: 0.15) : AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _insufficient ? AppTheme.error : AppTheme.success),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _insufficient ? 'MANQUE' : 'MONNAIE RENDUE',
                      style: TextStyle(color: _insufficient ? AppTheme.error : AppTheme.success, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _insufficient
                        ? '-${fmt.format(_total - _amountPaid)} F CFA'
                        : '${fmt.format(_change)} F CFA',
                      style: TextStyle(
                        color: _insufficient ? AppTheme.error : AppTheme.success,
                        fontWeight: FontWeight.w900, fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _insufficient ? null : () => widget.onPay(_method, _discount, _amountPaid),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

// =================== INVOICE SCREEN ===================
class InvoiceScreen extends StatelessWidget {
  final Order order;
  final double amountPaid;

  const InvoiceScreen({super.key, required this.order, this.amountPaid = 0});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
    final change = (amountPaid - order.totalAmount).clamp(0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: Text('Facture #${order.orderNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Impression en cours...'), backgroundColor: AppTheme.success),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partage de la facture...'), backgroundColor: AppTheme.primary),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              child: Column(
                children: [
                  // Header
                  Column(
                    children: [
                      const Text('SANKADIOKRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3)),
                      const Text('Restaurant Africain', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(height: 2, color: AppTheme.primary),
                      const SizedBox(height: 10),
                      const Text('FACTURE D\'ENCAISSEMENT', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Infos commande
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        _InvoiceRow('N° Commande:', '#${order.orderNumber}'),
                        _InvoiceRow('Table:', order.tableNumber),
                        _InvoiceRow('Date:', dateStr),
                        if (order.serverName != null) _InvoiceRow('Serveur:', order.serverName!),
                        if (order.paymentMethod != null) _InvoiceRow('Paiement:', order.paymentMethod!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Entête articles
                  const Row(
                    children: [
                      Expanded(flex: 5, child: Text('Article', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
                      Expanded(flex: 3, child: Text('Prix', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const Divider(color: Color(0xFF2A2A5A), height: 12),
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: Text(item.productName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                        Expanded(flex: 2, child: Text('×${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                        Expanded(flex: 3, child: Text('${fmt.format(item.totalPrice)} F', textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  )),
                  const Divider(color: Color(0xFF2A2A5A)),
                  _TotalRow('Sous-total', '${fmt.format(order.subtotal)} F CFA', bold: false),
                  if (order.discount > 0) _TotalRow('Remise', '-${fmt.format(order.discount)} F CFA', bold: false, color: AppTheme.warning),
                  _TotalRow('TOTAL', '${fmt.format(order.totalAmount)} F CFA', bold: true, color: AppTheme.primary),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF2A2A5A)),
                  // Montant versé / Monnaie rendue
                  if (amountPaid > 0) ...[
                    _TotalRow('Montant versé', '${fmt.format(amountPaid)} F CFA', bold: false, color: AppTheme.success),
                    _TotalRow('Monnaie rendue', '${fmt.format(change)} F CFA', bold: true, color: change > 0 ? AppTheme.warning : AppTheme.textSecondary),
                    const SizedBox(height: 8),
                  ],
                  Container(height: 2, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text('Merci pour votre visite !', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                  const Text('À bientôt chez SANKADIOKRO', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Imprimer Facture d\'Encaissement',
              icon: Icons.print,
              isFullWidth: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Impression sur imprimante Epson...'), backgroundColor: AppTheme.success),
                );
              },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Imprimer Facture de Règlement',
              icon: Icons.receipt_long,
              isFullWidth: true,
              color: AppTheme.warning,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Impression facture de règlement...'), backgroundColor: AppTheme.warning),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String label;
  final String value;

  const _InvoiceRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TotalRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: bold ? Colors.white : AppTheme.textSecondary, fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

// =================== FACTURES TAB ===================
class _FacturesTab extends StatelessWidget {
  const _FacturesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final paidOrders = provider.orders.where((o) => o.isPaid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final fmt = NumberFormat('#,###', 'fr_FR');

    return paidOrders.isEmpty
      ? const EmptyState(icon: Icons.receipt, title: 'Aucune facture', subtitle: 'Les factures encaissées apparaîtront ici')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: paidOrders.length,
          itemBuilder: (context, i) {
            final order = paidOrders[i];
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => InvoiceScreen(order: order, amountPaid: order.amountPaid),
              )),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.receipt, color: AppTheme.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${order.orderNumber} - Table ${order.tableNumber}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        if (order.paymentMethod != null)
                          Text(order.paymentMethod!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${fmt.format(order.totalAmount)} F', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 15)),
                      const Icon(Icons.print, color: AppTheme.primary, size: 16),
                    ],
                  ),
                ],
              ),
            );
          },
        );
  }
}

// =================== POINT DE CAISSE TAB ===================
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
    final todayPaid = provider.orders.where((o) => o.isPaid && o.createdAt.day == today.day && o.createdAt.month == today.month).toList();
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
                    child: Text('Aucune charge enregistrée aujourd\'hui', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
                              Text(charge['label'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                              if ((charge['note'] as String?)?.isNotEmpty == true)
                                Text(charge['note'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('${fmt.format(charge['amount'])} F', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
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
                      const Text('TOTAL CHARGES', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700)),
                      Text('${fmt.format(totalCharges)} F CFA', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
                      Text('#${o.orderNumber} Table ${o.tableNumber}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                      Text(o.paymentMethod ?? '-', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text('${fmt.format(o.totalAmount)} F', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 12)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
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
