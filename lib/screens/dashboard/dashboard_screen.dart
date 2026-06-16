import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###', 'fr_FR');
    final decFmt = NumberFormat('#,###.0', 'fr_FR');

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(provider),
              const SizedBox(height: 20),

              // Live Clock
              _buildLiveClock(),
              const SizedBox(height: 20),

              // Stats Grid
              const SectionHeader(title: 'Suivi des Commandes', icon: Icons.track_changes),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                children: [
                  StatCard(
                    title: 'En attente',
                    value: provider.pendingOrders.length.toString(),
                    icon: Icons.hourglass_empty,
                    color: AppTheme.pending,
                    subtitle: 'LIVE',
                  ),
                  StatCard(
                    title: 'En préparation',
                    value: provider.preparingOrders.length.toString(),
                    icon: Icons.restaurant,
                    color: AppTheme.preparing,
                    subtitle: 'LIVE',
                  ),
                  StatCard(
                    title: 'Prêtes',
                    value: provider.readyOrders.length.toString(),
                    icon: Icons.check_circle_outline,
                    color: AppTheme.ready,
                    subtitle: 'LIVE',
                  ),
                  StatCard(
                    title: 'Servies',
                    value: provider.servedOrders.length.toString(),
                    icon: Icons.done_all,
                    color: const Color(0xFF2196F3),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Revenue & Perf
              const SectionHeader(title: 'Performance du Jour', icon: Icons.bar_chart),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                children: [
                  StatCard(
                    title: 'Chiffre d\'affaires',
                    value: '${fmt.format(provider.todayRevenue)} F',
                    icon: Icons.payments_outlined,
                    color: AppTheme.success,
                    subtitle: 'Aujourd\'hui',
                  ),
                  StatCard(
                    title: 'Commandes totales',
                    value: provider.todayOrderCount.toString(),
                    icon: Icons.receipt_long,
                    color: AppTheme.primary,
                    subtitle: 'Aujourd\'hui',
                  ),
                  StatCard(
                    title: 'Temps moyen',
                    value: '${decFmt.format(provider.avgPrepTime)} min',
                    icon: Icons.timer_outlined,
                    color: const Color(0xFFE91E63),
                    subtitle: 'Préparation',
                  ),
                  StatCard(
                    title: 'Alertes stock',
                    value: (provider.lowStockItems.length + provider.outOfStockItems.length).toString(),
                    icon: Icons.warning_amber_outlined,
                    color: AppTheme.error,
                    subtitle: 'À vérifier',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active Orders
              if (provider.pendingOrders.isNotEmpty || provider.preparingOrders.isNotEmpty) ...[
                const SectionHeader(title: 'Commandes Actives', icon: Icons.list_alt),
                const SizedBox(height: 12),
                ...provider.orders
                  .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
                  .take(5)
                  .map((order) => _OrderCard(order: order, provider: provider)),
              ],

              // Stock alerts
              if (provider.lowStockItems.isNotEmpty || provider.outOfStockItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: 'Alertes Stock', icon: Icons.warning_amber),
                const SizedBox(height: 12),
                ...provider.outOfStockItems.map((s) => _StockAlert(item: s, isOut: true)),
                ...provider.lowStockItems.map((s) => _StockAlert(item: s, isOut: false)),
              ],

              // Top Products
              const SizedBox(height: 20),
              const SectionHeader(title: 'Top Produits', icon: Icons.star_outlined),
              const SizedBox(height: 12),
              _buildTopProducts(provider),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SANKADIOKRO', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
                Text('Bienvenue, ${provider.currentUser?.name ?? ""}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.success.withValues(alpha: 0.4))),
            child: const Row(
              children: [
                Icon(Icons.circle, color: AppTheme.success, size: 8),
                SizedBox(width: 6),
                Text('En ligne', style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveClock() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('HH:mm:ss').format(_now),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF00E676), letterSpacing: 2),
              ),
              Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_now), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.access_time, color: Color(0xFF00E676), size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(AppProvider provider) {
    final tops = provider.topProducts;
    if (tops.isEmpty) {
      return const GlassCard(child: EmptyState(icon: Icons.restaurant_menu, title: 'Aucun plat vendu aujourd\'hui'));
    }
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: tops.entries.take(5).map((e) {
          final percent = tops.values.first > 0 ? e.value / tops.values.first : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    Text('${e.value} vendus', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final AppProvider provider;

  const _OrderCard({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isLate = order.elapsedMinutes > 20;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(
        color: isLate ? AppTheme.error.withValues(alpha: 0.5) : order.statusColor.withValues(alpha: 0.3),
        width: 1,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: order.statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text('#${order.orderNumber}', style: TextStyle(color: order.statusColor, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Table ${order.tableNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (order.isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('URGENT', style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                Text('${order.items.length} article(s) • ${order.elapsedMinutes} min',
                  style: TextStyle(color: isLate ? AppTheme.error : AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          StatusBadge(label: order.statusLabel, color: order.statusColor),
        ],
      ),
    );
  }
}

class _StockAlert extends StatelessWidget {
  final StockItem item;
  final bool isOut;

  const _StockAlert({required this.item, required this.isOut});

  @override
  Widget build(BuildContext context) {
    final color = isOut ? AppTheme.error : AppTheme.warning;
    final label = isOut ? 'RUPTURE' : 'STOCK FAIBLE';
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(isOut ? Icons.cancel : Icons.warning_amber, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${item.currentQuantity} ${item.unit} restant(s)', style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
