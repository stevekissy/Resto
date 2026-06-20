import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/ai_analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StatsScreen — Statistiques + Assistant IA Restaurant (données Firestore)
// ─────────────────────────────────────────────────────────────────────────────
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
          // ── Header ──────────────────────────────────────────────────────
          GlassCard(
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            child: const Row(
              children: [
                Icon(Icons.insights, color: AppTheme.primary, size: 24),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statistiques Avancées',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Analyse des performances',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats du jour ────────────────────────────────────────────────
          const SectionHeader(title: 'Aujourd\'hui', icon: Icons.today),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.3,
            children: [
              StatCard(title: 'Chiffre d\'affaires', value: '${fmt.format(provider.todayRevenue)} F',
                  icon: Icons.payments, color: AppTheme.success),
              StatCard(title: 'Commandes', value: provider.todayOrderCount.toString(),
                  icon: Icons.receipt_long, color: AppTheme.primary),
              StatCard(title: 'Temps moyen prépa', value: '${provider.avgPrepTime.toStringAsFixed(1)} min',
                  icon: Icons.timer, color: const Color(0xFFE91E63)),
              StatCard(title: 'Commandes servies', value: provider.servedOrders.length.toString(),
                  icon: Icons.done_all, color: AppTheme.ready),
            ],
          ),
          const SizedBox(height: 20),

          // ── Top plats ────────────────────────────────────────────────────
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
                    final colors = [AppTheme.success, AppTheme.primary, const Color(0xFFE91E63),
                        AppTheme.warning, AppTheme.accent];
                    final color = colors[index % colors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Center(
                                  child: Text('${index + 1}',
                                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(entry.key,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                              Text('${entry.value} vendus',
                                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
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

          // ── CA par catégorie ─────────────────────────────────────────────
          const SectionHeader(title: 'Chiffre d\'affaires par Catégorie', icon: Icons.pie_chart_outline),
          const SizedBox(height: 12),
          GlassCard(child: _CategoryRevenue(provider: provider, fmt: fmt)),
          const SizedBox(height: 20),

          // ── Assistant IA (données Firestore réelles) ─────────────────────
          const SectionHeader(title: 'Assistant IA Restaurant', icon: Icons.psychology),
          const SizedBox(height: 12),
          _AiAssistantPanel(provider: provider),
          const SizedBox(height: 20),

          // ── Commandes par heure ──────────────────────────────────────────
          const SectionHeader(title: 'Commandes par Heure', icon: Icons.schedule),
          const SizedBox(height: 12),
          GlassCard(child: _HourlyChart(provider: provider)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Assistant IA Panel — FutureBuilder déclenché à chaque rebuild du parent
// ─────────────────────────────────────────────────────────────────────────────
class _AiAssistantPanel extends StatefulWidget {
  final AppProvider provider;
  const _AiAssistantPanel({required this.provider});

  @override
  State<_AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<_AiAssistantPanel> {
  Future<AiAnalysisResult>? _future;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _triggerAnalysis();
  }

  void _triggerAnalysis() {
    _lastRefresh = DateTime.now();
    _future = AiAnalyticsService().compute(
      liveOrders:   widget.provider.orders,
      stockItems:   widget.provider.stockItems,
      products:     widget.provider.products,
      dailyCharges: widget.provider.dailyCharges,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fmt   = NumberFormat('#,###', 'fr_FR');
    final fmtDt = DateFormat('HH:mm', 'fr_FR');

    return FutureBuilder<AiAnalysisResult>(
      future: _future,
      builder: (ctx, snap) {
        // ── Loading ──────────────────────────────────────────────────
        if (snap.connectionState == ConnectionState.waiting) {
          return GlassCard(
            border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF9C27B0), strokeWidth: 2),
                  SizedBox(height: 12),
                  Text('Analyse Firestore en cours…',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        // ── Erreur ──────────────────────────────────────────────────
        if (snap.hasError) {
          return GlassCard(
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 32),
                  const SizedBox(height: 8),
                  Text('Impossible de charger l\'analyse',
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${snap.error}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _triggerAnalysis,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Réessayer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final r = snap.data!;

        return Column(
          children: [
            // ── En-tête + bouton refresh ─────────────────────────────
            GlassCard(
              border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.psychology, color: Color(0xFF9C27B0), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assistant IA Restaurant',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('Analyse basée sur vos données réelles',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: _triggerAnalysis,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.refresh, color: Color(0xFF9C27B0), size: 16),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_lastRefresh != null)
                            Text(fmtDt.format(_lastRefresh!),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                  // ── Résumé du jour ────────────────────────────────
                  if (r.dailySummary.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.2)),
                      ),
                      child: Text(r.dailySummary,
                          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── KPI étendus ─────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(text: 'Indicateurs financiers', icon: Icons.bar_chart),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.8,
                    children: [
                      _KpiTile(label: 'CA Semaine', value: '${fmt.format(r.kpi.revenueWeek)} F',
                          icon: Icons.calendar_view_week, color: AppTheme.primary),
                      _KpiTile(label: 'CA Mois', value: '${fmt.format(r.kpi.revenueMonth)} F',
                          icon: Icons.calendar_month, color: const Color(0xFFE91E63)),
                      _KpiTile(label: 'Recette brute', value: '${fmt.format(r.kpi.grossRevenue)} F',
                          icon: Icons.payments, color: AppTheme.success),
                      _KpiTile(label: 'Charges', value: '${fmt.format(r.kpi.totalCharges)} F',
                          icon: Icons.money_off, color: AppTheme.warning),
                      _KpiTile(label: 'Recette nette', value: '${fmt.format(r.kpi.netRevenue)} F',
                          icon: Icons.account_balance_wallet,
                          color: r.kpi.netRevenue >= 0 ? AppTheme.success : AppTheme.error),
                      _KpiTile(
                          label: 'Annulées',
                          value: r.kpi.ordersCancelledToday.toString(),
                          icon: Icons.cancel_outlined,
                          color: r.kpi.ordersCancelledToday > 0 ? AppTheme.error : AppTheme.textSecondary),
                    ],
                  ),
                  // Tendance hebdomadaire
                  if (r.kpi.revenueWeek > 0 || r.kpi.revenueToday > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (r.kpi.revenueVsLastWeekPct >= 0 ? AppTheme.success : AppTheme.error)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (r.kpi.revenueVsLastWeekPct >= 0 ? AppTheme.success : AppTheme.error)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            r.kpi.revenueVsLastWeekPct >= 0
                                ? Icons.trending_up : Icons.trending_down,
                            color: r.kpi.revenueVsLastWeekPct >= 0 ? AppTheme.success : AppTheme.error,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            r.kpi.revenueVsLastWeekPct == 0
                                ? 'Stable vs semaine dernière'
                                : '${r.kpi.revenueVsLastWeekPct > 0 ? '+' : ''}${r.kpi.revenueVsLastWeekPct.toStringAsFixed(0)} % vs semaine dernière',
                            style: TextStyle(
                              color: r.kpi.revenueVsLastWeekPct >= 0 ? AppTheme.success : AppTheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Modes de paiement
                  if (r.kpi.revenueByPayment.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const _SectionLabel(text: 'Modes de paiement du jour', icon: Icons.credit_card),
                    const SizedBox(height: 8),
                    ...r.kpi.revenueByPayment.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, color: AppTheme.primary, size: 8),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                          Text('${fmt.format(e.value)} F',
                              style: const TextStyle(color: AppTheme.primary,
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Alertes ─────────────────────────────────────────────
            if (r.alerts.isNotEmpty) ...[
              GlassCard(
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'Alertes importantes', icon: Icons.warning_amber_rounded,
                        color: AppTheme.warning),
                    const SizedBox(height: 10),
                    ...r.alerts.map((a) => _AlertRow(alert: a)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Recommandations ──────────────────────────────────────
            if (r.recommendations.isNotEmpty) ...[
              GlassCard(
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'Recommandations', icon: Icons.lightbulb_outline,
                        color: AppTheme.success),
                    const SizedBox(height: 10),
                    ...r.recommendations.map((rec) => _RecRow(rec: rec)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Prédictions ──────────────────────────────────────────
            GlassCard(
              border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.25)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(text: 'Prévisions', icon: Icons.auto_awesome,
                      color: Color(0xFF9C27B0)),
                  const SizedBox(height: 10),
                  ...r.predictions.map((p) => _PredRow(pred: p)),
                  if (r.predictions.isEmpty)
                    const _PredRow(
                      pred: AiPrediction(
                        title: 'Prévisions',
                        value: 'Données insuffisantes pour prédiction fiable.',
                        hasEnoughData: false,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Stock intelligent ────────────────────────────────────
            GlassCard(
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(text: 'Stock intelligent', icon: Icons.inventory_2_outlined,
                      color: AppTheme.warning),
                  const SizedBox(height: 10),
                  if (r.stockInsights.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Tous les stocks sont dans les normes.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    )
                  else
                    ...r.stockInsights.take(8).map((s) => _StockRow(insight: s)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Cuisine ──────────────────────────────────────────────
            GlassCard(
              border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.25)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(text: 'Performance Cuisine', icon: Icons.restaurant,
                      color: Color(0xFFE65100)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _KitchenTile(
                        label: 'Temps moyen',
                        value: r.kitchenInsight.avgPrepMinutes == 0
                            ? '—'
                            : '${r.kitchenInsight.avgPrepMinutes.toStringAsFixed(0)} min',
                        icon: Icons.timer,
                        color: r.kitchenInsight.avgPrepMinutes == 0
                            ? AppTheme.textSecondary
                            : r.kitchenInsight.avgPrepMinutes < 18
                                ? AppTheme.success
                                : AppTheme.warning,
                      ),
                      const SizedBox(width: 10),
                      _KitchenTile(
                        label: 'Commandes en retard',
                        value: r.kitchenInsight.lateOrdersCount.toString(),
                        icon: Icons.hourglass_bottom,
                        color: r.kitchenInsight.lateOrdersCount == 0
                            ? AppTheme.success : AppTheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.speed, color: Color(0xFFE65100), size: 16),
                        const SizedBox(width: 8),
                        Text('Performance : ', style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                        Text(r.kitchenInsight.performanceLabel,
                            style: TextStyle(
                              color: _perfColor(r.kitchenInsight.performanceLabel),
                              fontWeight: FontWeight.w700, fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  if (r.kitchenInsight.slowestDishes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.slow_motion_video, color: AppTheme.warning, size: 14),
                        const SizedBox(width: 6),
                        const Text('Plats lents : ', style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                        Expanded(child: Text(r.kitchenInsight.slowestDishes.join(', '),
                            style: const TextStyle(color: AppTheme.warning, fontSize: 11))),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Actions prioritaires ─────────────────────────────────
            if (r.alerts.any((a) => a.severity == AlertSeverity.critical) ||
                r.stockInsights.any((s) => s.type == StockInsightType.critical)) ...[
              const SizedBox(height: 12),
              GlassCard(
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'Actions prioritaires', icon: Icons.priority_high,
                        color: AppTheme.error),
                    const SizedBox(height: 10),
                    ...r.alerts
                        .where((a) => a.severity == AlertSeverity.critical)
                        .map((a) => _ActionRow(title: a.title, detail: a.detail)),
                    ...r.stockInsights
                        .where((s) => s.type == StockInsightType.critical)
                        .map((s) => _ActionRow(
                          title: 'Commander : ${s.itemName}',
                          detail: 'Stock épuisé (${s.currentQty} ${s.unit}). '
                              '${s.recommendedQty != null ? "Recommandé : ~${s.recommendedQty!.toStringAsFixed(0)} ${s.unit}." : ""}',
                        )),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Color _perfColor(String label) {
    if (label.contains('Excellent')) return AppTheme.success;
    if (label.contains('Bonne'))     return const Color(0xFF8BC34A);
    if (label.contains('améliorer')) return AppTheme.warning;
    if (label.contains('Lente'))     return AppTheme.error;
    return AppTheme.textSecondary;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets secondaires
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  const _SectionLabel({required this.text, required this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Row(
      children: [
        Icon(icon, color: c, size: 15),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiTile({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final AiAlert alert;
  const _AlertRow({required this.alert});
  @override
  Widget build(BuildContext context) {
    final Color c;
    final IconData ic;
    switch (alert.severity) {
      case AlertSeverity.critical:
        c = AppTheme.error; ic = Icons.error_outline;
      case AlertSeverity.warning:
        c = AppTheme.warning; ic = Icons.warning_amber_rounded;
      case AlertSeverity.info:
        c = AppTheme.primary; ic = Icons.info_outline;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(ic, color: c, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(alert.detail, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecRow extends StatelessWidget {
  final AiRecommendation rec;
  const _RecRow({required this.rec});
  @override
  Widget build(BuildContext context) {
    final Map<String, Color> catColors = {
      'stock':   AppTheme.warning,
      'ventes':  AppTheme.primary,
      'cuisine': const Color(0xFFE65100),
      'caisse':  AppTheme.success,
      'service': const Color(0xFF00838F),
    };
    final color = catColors[rec.category] ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.lightbulb_outline, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(rec.detail,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredRow extends StatelessWidget {
  final AiPrediction pred;
  const _PredRow({required this.pred});
  @override
  Widget build(BuildContext context) {
    final color = pred.hasEnoughData ? const Color(0xFF9C27B0) : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(pred.hasEnoughData ? Icons.auto_awesome : Icons.hourglass_empty,
                color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pred.title,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text(pred.value,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final StockInsight insight;
  const _StockRow({required this.insight});
  @override
  Widget build(BuildContext context) {
    final Color c;
    final IconData ic;
    final String tag;
    switch (insight.type) {
      case StockInsightType.critical:
        c = AppTheme.error; ic = Icons.remove_circle_outline; tag = 'RUPTURE';
      case StockInsightType.nearAlert:
        c = AppTheme.warning; ic = Icons.warning_amber_rounded; tag = 'BAS';
      case StockInsightType.orderSoon:
        c = AppTheme.primary; ic = Icons.shopping_cart_outlined; tag = '< 7 JOURS';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ic, color: c, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.itemName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                Text('Stock actuel : ${insight.currentQty} ${insight.unit}'
                    ' (seuil : ${insight.minQty} ${insight.unit})',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.withValues(alpha: 0.4)),
            ),
            child: Text(tag, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _KitchenTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KitchenTile({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String title;
  final String detail;
  const _ActionRow({required this.title, required this.detail});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.priority_high, color: AppTheme.error, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(detail, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CategoryRevenue (inchangé)
// ─────────────────────────────────────────────────────────────────────────────
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
    final total  = categoryRevenue.values.fold<double>(0, (s, v) => s + v);
    final colors = [AppTheme.primary, AppTheme.success, const Color(0xFFE91E63),
        AppTheme.warning, AppTheme.accent];
    final entries = categoryRevenue.entries.toList();
    return Column(
      children: entries.asMap().entries.map((e) {
        final color   = colors[e.key % colors.length];
        final revenue = e.value.value;
        final pct     = total > 0 ? revenue / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value.key,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                  Text('${fmt.format(revenue)} F',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)} %',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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

// ─────────────────────────────────────────────────────────────────────────────
//  _HourlyChart (inchangé)
// ─────────────────────────────────────────────────────────────────────────────
class _HourlyChart extends StatelessWidget {
  final AppProvider provider;
  const _HourlyChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(24,
        (h) => provider.orders.where((o) => o.createdAt.hour == h).length);
    final maxCount = hours.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: hours.asMap().entries
            .where((e) => e.key >= 6 && e.key <= 23)
            .map((e) {
          final h = e.key;
          final count = e.value;
          final pct = maxCount > 0 ? count / maxCount : 0.0;
          final isLunch  = h >= 11 && h <= 14;
          final isDinner = h >= 18 && h <= 21;
          final color = isLunch || isDinner
              ? AppTheme.primary
              : AppTheme.textSecondary.withValues(alpha: 0.3);
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
                      child: Container(decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(3))),
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
