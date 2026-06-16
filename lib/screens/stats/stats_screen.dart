import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###', 'fr_FR');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          GlassCard(
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            child: Row(
              children: [
                const Icon(Icons.insights, color: AppTheme.primary, size: 24),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statistiques Avancées', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Analyse des performances', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily stats
          const SectionHeader(title: 'Aujourd\'hui', icon: Icons.today),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.3,
            children: [
              StatCard(title: 'Chiffre d\'affaires', value: '${fmt.format(provider.todayRevenue)} F', icon: Icons.payments, color: AppTheme.success),
              StatCard(title: 'Commandes', value: provider.todayOrderCount.toString(), icon: Icons.receipt_long, color: AppTheme.primary),
              StatCard(title: 'Temps moyen prépa', value: '${provider.avgPrepTime.toStringAsFixed(1)} min', icon: Icons.timer, color: const Color(0xFFE91E63)),
              StatCard(title: 'Commandes servies', value: provider.servedOrders.length.toString(), icon: Icons.done_all, color: AppTheme.ready),
            ],
          ),
          const SizedBox(height: 20),

          // Top products
          const SectionHeader(title: 'Top Plats Vendus', icon: Icons.star),
          const SizedBox(height: 12),
          GlassCard(
            child: provider.topProducts.isEmpty
              ? const EmptyState(icon: Icons.restaurant, title: 'Pas encore de ventes')
              : Column(
                  children: provider.topProducts.entries.take(5).toList().asMap().entries.map((e) {
                    final index = e.key;
                    final entry = e.value;
                    final maxVal = provider.topProducts.values.first;
                    final colors = [AppTheme.success, AppTheme.primary, const Color(0xFFE91E63), AppTheme.warning, AppTheme.accent];
                    final color = colors[index % colors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                child: Center(child: Text('${index + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(entry.key, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                              Text('${entry.value} vendus', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxVal > 0 ? entry.value / maxVal : 0,
                              backgroundColor: AppTheme.surfaceLight,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          ),
          const SizedBox(height: 20),

          // Category breakdown
          const SectionHeader(title: 'Chiffre d\'affaires par Catégorie', icon: Icons.pie_chart_outline),
          const SizedBox(height: 12),
          GlassCard(child: _CategoryRevenue(provider: provider, fmt: fmt)),
          const SizedBox(height: 20),

          // AI Predictions
          const SectionHeader(title: 'Prédictions IA', icon: Icons.auto_awesome),
          const SizedBox(height: 12),
          GlassCard(
            border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF9C27B0).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.psychology, color: Color(0xFF9C27B0), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text('Assistant IA Restaurant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                const _AIPrediction(icon: Icons.trending_up, title: 'Heure de forte affluence prévue', value: '12h00 - 14h00 et 19h00 - 21h00', color: AppTheme.primary),
                const _AIPrediction(icon: Icons.inventory, title: 'Stock à réapprovisionner cette semaine', value: 'Poisson Tilapia, Poulet, Tomates', color: AppTheme.warning),
                const _AIPrediction(icon: Icons.restaurant_menu, title: 'Plats à préparer à l\'avance', value: 'Kedjenou, Thiéboudienne', color: AppTheme.success),
                const _AIPrediction(icon: Icons.warning_amber, title: 'Risque de rupture dans 2 jours', value: 'Oignons (stock = 0), Piment', color: AppTheme.error),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Hourly chart
          const SectionHeader(title: 'Commandes par Heure', icon: Icons.schedule),
          const SizedBox(height: 12),
          GlassCard(child: _HourlyChart(provider: provider)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _CategoryRevenue extends StatelessWidget {
  final AppProvider provider;
  final NumberFormat fmt;

  const _CategoryRevenue({required this.provider, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final categoryRevenue = <String, double>{};
    for (final order in provider.orders.where((o) => o.isPaid)) {
      for (final item in order.items) {
        try {
          final product = provider.products.firstWhere((p) => p.id == item.productId);
          categoryRevenue[product.category] = (categoryRevenue[product.category] ?? 0) + item.totalPrice;
        } catch (_) {
          categoryRevenue['Autres'] = (categoryRevenue['Autres'] ?? 0) + item.totalPrice;
        }
      }
    }

    if (categoryRevenue.isEmpty) {
      return const EmptyState(icon: Icons.pie_chart, title: 'Pas encore de données');
    }

    final total = categoryRevenue.values.fold<double>(0, (s, v) => s + v);
    final colors = [AppTheme.primary, AppTheme.success, const Color(0xFFE91E63), AppTheme.warning, AppTheme.accent];
    final entries = categoryRevenue.entries.toList();

    return Column(
      children: entries.asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        final revenue = e.value.value;
        final pct = total > 0 ? revenue / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value.key, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                  Text('${fmt.format(revenue)} F', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  final AppProvider provider;

  const _HourlyChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(24, (h) => provider.orders.where((o) => o.createdAt.hour == h).length);
    final maxCount = hours.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: hours.asMap().entries.where((e) => e.key >= 6 && e.key <= 23).map((e) {
          final h = e.key;
          final count = e.value;
          final pct = maxCount > 0 ? count / maxCount : 0.0;
          final isLunch = h >= 11 && h <= 14;
          final isDinner = h >= 18 && h <= 21;
          final color = isLunch || isDinner ? AppTheme.primary : AppTheme.textSecondary.withValues(alpha: 0.3);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0) Text('$count', style: TextStyle(color: color, fontSize: 8)),
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: pct.clamp(0.05, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${h}h', style: TextStyle(color: AppTheme.textSecondary, fontSize: 7)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AIPrediction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _AIPrediction({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
