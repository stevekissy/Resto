import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_provider.dart';
import '../../../sandbox/client_provider_proxy.dart';
import '../../../models/client_models.dart';
import '../../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// COMMANDES CLIENT — Liste + Suivi en temps réel étape par étape
// ═══════════════════════════════════════════════════════════════════════════

class ClientOrdersScreen extends StatefulWidget {
  final VoidCallback? onGoHome;
  const ClientOrdersScreen({super.key, this.onGoHome});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen>
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
    final provider = ClientProviderProxy.watch(context);
    final active = provider.activeOrders;
    final history = provider.orders
        .where((o) =>
            o.status == ClientOrderStatus.delivered ||
            o.status == ClientOrderStatus.cancelled)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          tooltip: 'Retour à l\'accueil',
          onPressed: widget.onGoHome,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            tooltip: 'Accueil',
            onPressed: widget.onGoHome,
          ),
        ],
        title: const Text('Mes Commandes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('En cours'),
                  if (active.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${active.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet EN COURS
          active.isEmpty
              ? const _EmptyOrders(message: 'Aucune commande en cours', icon: Icons.delivery_dining)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                  itemCount: active.length,
                  itemBuilder: (ctx, i) => _OrderTrackingCard(order: active[i]),
                ),
          // Onglet HISTORIQUE
          history.isEmpty
              ? const _EmptyOrders(message: 'Aucune commande terminée', icon: Icons.history)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                  itemCount: history.length,
                  itemBuilder: (ctx, i) => _OrderHistoryCard(order: history[i]),
                ),
        ],
      ),
    );
  }
}

// ── Carte suivi commande active ───────────────────────────────────────────────

class _OrderTrackingCard extends StatelessWidget {
  final ClientOrder order;
  const _OrderTrackingCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final status = order.status;
    final isCancellable = status == ClientOrderStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: status.color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(status.icon, color: status.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.orderNumber ?? 'Commande',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(status.label,
                          style: TextStyle(color: status.color, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmt.format(order.grandTotal)} F',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(order.orderType.label,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Progression par étapes
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _StepProgress(status: status),
          ),

          // Détails articles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              order.items.map((i) => '${i.quantity}× ${i.productName}').join(' • '),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Livreur (si en livraison)
          if (order.status == ClientOrderStatus.delivering &&
              order.deliveryPersonName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining, color: Color(0xFF9C27B0), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Livreur',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          Text(order.deliveryPersonName!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (order.deliveryPersonPhone != null)
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone, color: Color(0xFF9C27B0), size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOrderDetails(context, order),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Détails', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (isCancellable) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmCancel(context, order),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Annuler', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, ClientOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OrderDetailSheet(order: order),
    );
  }

  void _confirmCancel(BuildContext context, ClientOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Annuler la commande', style: TextStyle(color: Colors.white)),
        content: const Text('Voulez-vous vraiment annuler cette commande ?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ClientProviderProxy.read(context).cancelOrder(order.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Commande annulée'),
                  backgroundColor: AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}

// ── Progression étapes ────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final ClientOrderStatus status;
  const _StepProgress({required this.status});

  static const _steps = [
    (ClientOrderStatus.pending,   'Reçue',      Icons.hourglass_empty),
    (ClientOrderStatus.confirmed, 'Validée',    Icons.check_circle_outline),
    (ClientOrderStatus.preparing, 'Préparation',Icons.restaurant),
    (ClientOrderStatus.ready,     'Prête',      Icons.done_all),
    (ClientOrderStatus.delivering,'Livraison',  Icons.delivery_dining),
    (ClientOrderStatus.delivered, 'Livrée',     Icons.home),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == ClientOrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: AppTheme.error),
            SizedBox(width: 10),
            Text('Commande annulée', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final currentStep = status.step;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barre linéaire globale
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / 5,
            backgroundColor: AppTheme.surfaceLight,
            valueColor: AlwaysStoppedAnimation(status.color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 14),
        // Étapes individuelles
        Row(
          children: _steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isDone = idx <= currentStep;
            final isCurrent = idx == currentStep;

            return Expanded(
              child: Column(
                children: [
                  // Cercle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isCurrent ? 32 : 26,
                    height: isCurrent ? 32 : 26,
                    decoration: BoxDecoration(
                      color: isDone ? status.color : AppTheme.surfaceLight,
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(color: status.color.withValues(alpha: 0.4), width: 3)
                          : null,
                      boxShadow: isCurrent
                          ? [BoxShadow(color: status.color.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Icon(
                      step.$3,
                      color: isDone ? Colors.white : AppTheme.textSecondary,
                      size: isCurrent ? 16 : 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.$2,
                    style: TextStyle(
                      color: isDone ? status.color : AppTheme.textSecondary,
                      fontSize: 9,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Carte historique ──────────────────────────────────────────────────────────

class _OrderHistoryCard extends StatelessWidget {
  final ClientOrder order;
  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final fmtDate = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    final isDelivered = order.status == ClientOrderStatus.delivered;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.cardBg,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _OrderDetailSheet(order: order),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A5A)),
        ),
        child: Row(
          children: [
            // Icône statut
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: order.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(order.status.icon, color: order.status.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderNumber ?? 'Commande',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                    order.items.map((i) => '${i.quantity}× ${i.productName}').join(', '),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(fmtDate.format(order.createdAt),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${fmt.format(order.grandTotal)} F',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: order.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(order.status.label,
                      style: TextStyle(color: order.status.color, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                if (isDelivered && order.loyaltyPointsEarned > 0) ...[
                  const SizedBox(height: 4),
                  Text('+${order.loyaltyPointsEarned} pts',
                      style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Détail commande (bottom sheet) ────────────────────────────────────────────

class _OrderDetailSheet extends StatelessWidget {
  final ClientOrder order;
  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final fmtDate = DateFormat('dd/MM HH:mm', 'fr_FR');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          // Poignée
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Titre
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(order.status.icon, color: order.status.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber ?? 'Commande',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(fmtDate.format(order.createdAt),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: order.status.color.withValues(alpha: 0.4)),
                ),
                child: Text(order.status.label,
                    style: TextStyle(color: order.status.color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A5A)),
          const SizedBox(height: 16),

          // Articles
          const Text('Articles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('${item.quantity}',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 13))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item.productName,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),
                Text('${fmt.format(item.totalPrice)} F',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          )),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2A2A5A)),
          const SizedBox(height: 12),

          // Totaux
          _DetailRow('Sous-total', '${fmt.format(order.totalAmount)} F'),
          if (order.deliveryFee > 0)
            _DetailRow('Livraison', '${fmt.format(order.deliveryFee)} F'),
          const SizedBox(height: 6),
          _DetailRow('Total', '${fmt.format(order.grandTotal)} F', bold: true, valueColor: AppTheme.primary),
          if (order.depositAmount > 0) ...[
            const SizedBox(height: 4),
            _DetailRow('Acompte payé', '${fmt.format(order.depositAmount)} F', valueColor: AppTheme.success),
            _DetailRow('Reste à payer', '${fmt.format(order.remainingAmount)} F', valueColor: AppTheme.warning),
          ],

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A5A)),
          const SizedBox(height: 12),

          // Paiement & Livraison
          _DetailRow('Paiement', '${order.paymentMethod.icon} ${order.paymentMethod.label}'),
          _DetailRow('Type', order.orderType.label),
          if (order.deliveryAddress != null)
            _DetailRow('Adresse', order.deliveryAddress!.address),
          if (order.loyaltyPointsEarned > 0)
            _DetailRow('Points gagnés', '+${order.loyaltyPointsEarned} points', valueColor: Colors.amber),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? valueColor;
  const _DetailRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: bold ? Colors.white : AppTheme.textSecondary,
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
              )),
          Text(value,
              style: TextStyle(
                color: valueColor ?? (bold ? AppTheme.primary : Colors.white),
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

// ── Vide ──────────────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyOrders({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 64),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Vos commandes apparaîtront ici',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
