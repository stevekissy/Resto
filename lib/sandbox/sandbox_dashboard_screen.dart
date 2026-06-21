// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_models.dart';
import '../utils/app_theme.dart';
import 'sandbox_provider.dart';
import 'sandbox_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SANDBOX DASHBOARD SCREEN — Panneau de contrôle de simulation
// Accessible depuis Profil en mode sandbox
// Permet de progresser manuellement les statuts de commandes
// ═══════════════════════════════════════════════════════════════════════════

class SandboxDashboardScreen extends StatefulWidget {
  const SandboxDashboardScreen({super.key});

  @override
  State<SandboxDashboardScreen> createState() => _SandboxDashboardScreenState();
}

class _SandboxDashboardScreenState extends State<SandboxDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isResetting = false;

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

  Future<void> _resetSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Réinitialiser la session ?',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Toutes les commandes de test seront supprimées et les données revenues à l\'état initial.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réinitialiser',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isResetting = true);
    try {
      await context.read<SandboxProvider>().resetSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session réinitialisée avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.science_rounded, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Tableau de Bord Sandbox',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isResetting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, color: AppTheme.error),
            tooltip: 'Réinitialiser la session',
            onPressed: _isResetting ? null : _resetSession,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7C3AED),
          labelColor: const Color(0xFF7C3AED),
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Commandes'),
            Tab(icon: Icon(Icons.route, size: 18), text: 'Scénarios'),
            Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Session'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrdersControlTab(),
          _ScenariosTab(),
          _SessionInfoTab(),
        ],
      ),
    );
  }
}

// ── Onglet 1 : Contrôle des commandes ────────────────────────────────────────

class _OrdersControlTab extends StatelessWidget {
  const _OrdersControlTab();

  @override
  Widget build(BuildContext context) {
    final sbProvider = context.watch<SandboxProvider>();
    final activeOrders = sbProvider.activeOrders;

    if (activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                color: AppTheme.textSecondary, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Aucune commande en cours',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez une commande depuis le Menu\npuis revenez ici pour la faire progresser.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeOrders.length,
      itemBuilder: (ctx, i) => _OrderControlCard(order: activeOrders[i]),
    );
  }
}

class _OrderControlCard extends StatefulWidget {
  final ClientOrder order;
  const _OrderControlCard({required this.order});

  @override
  State<_OrderControlCard> createState() => _OrderControlCardState();
}

class _OrderControlCardState extends State<_OrderControlCard> {
  bool _advancing = false;
  bool _simDeposit = false;

  Future<void> _advance() async {
    setState(() => _advancing = true);
    try {
      final result = await context
          .read<SandboxProvider>()
          .advanceOrderStatus(widget.order.id);
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(result.icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Statut → ${result.label}'),
              ],
            ),
            backgroundColor: result.color,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Future<void> _simulateDeposit() async {
    setState(() => _simDeposit = true);
    try {
      await context
          .read<SandboxProvider>()
          .simulateDepositPayment(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement acompte simulé avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _simDeposit = false);
    }
  }

  Future<void> _simulateFullDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Livraison express ?',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Simuler la livraison complète en une seule étape (passage à travers tous les statuts).',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simuler',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await context
        .read<SandboxProvider>()
        .simulateFullDelivery(widget.order.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livraison simulée ! Commande livrée.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = order.status.color;
    final canAdvance = order.status != ClientOrderStatus.delivered &&
        order.status != ClientOrderStatus.cancelled;
    final needsDeposit = order.paymentStatus == ClientPaymentStatus.pending &&
        order.paymentMethod != ClientPaymentMethod.cashOnDelivery;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(order.status.icon, color: statusColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber ?? order.id.substring(0, 10),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${order.items.length} article(s) — '
                        '${order.grandTotal.toStringAsFixed(0)} F',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Barre de progression compacte
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: _MiniStepProgress(status: order.status),
          ),
          // Boutons d'action
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                if (needsDeposit) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: _simDeposit
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.payment, size: 16),
                      label: const Text('Simuler paiement acompte'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warning,
                        side:
                            BorderSide(color: AppTheme.warning.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _simDeposit ? null : _simulateDeposit,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _advancing
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(order.status.icon, size: 16),
                        label: Text(
                          _advancing
                              ? 'Avancement...'
                              : _nextStatusLabel(order.status),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAdvance
                              ? statusColor
                              : AppTheme.textSecondary.withValues(alpha: 0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: canAdvance && !_advancing ? _advance : null,
                      ),
                    ),
                    if (order.orderType == OrderType.delivery &&
                        canAdvance) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9C27B0),
                          side: const BorderSide(
                              color: Color(0xFF9C27B0), width: 0.8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        onPressed: _simulateFullDelivery,
                        child: const Text(
                          '⚡ Express',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nextStatusLabel(ClientOrderStatus status) {
    switch (status) {
      case ClientOrderStatus.pending:    return '→ Valider';
      case ClientOrderStatus.confirmed:  return '→ En préparation';
      case ClientOrderStatus.preparing:  return '→ Prête';
      case ClientOrderStatus.ready:      return '→ En livraison';
      case ClientOrderStatus.delivering: return '→ Livrée';
      default: return 'Terminée';
    }
  }
}

// ── Mini progress bar ───────────────────────────────────────────────────────

class _MiniStepProgress extends StatelessWidget {
  final ClientOrderStatus status;
  const _MiniStepProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final statuses = [
      ClientOrderStatus.pending,
      ClientOrderStatus.confirmed,
      ClientOrderStatus.preparing,
      ClientOrderStatus.ready,
      ClientOrderStatus.delivering,
      ClientOrderStatus.delivered,
    ];
    final currentStep = status.step;

    return Row(
      children: List.generate(statuses.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connecteur
          final stepIdx = (i + 1) ~/ 2;
          final isDone = currentStep >= stepIdx;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone
                  ? AppTheme.primary.withValues(alpha: 0.6)
                  : AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
          );
        }
        // Cercle
        final stepIdx = i ~/ 2;
        final s = statuses[stepIdx];
        final isDone = currentStep >= stepIdx;
        final isCurrent = currentStep == stepIdx;
        return Container(
          width: isCurrent ? 20 : 14,
          height: isCurrent ? 20 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? s.color : AppTheme.surfaceLight,
            border: isCurrent
                ? Border.all(color: s.color, width: 2)
                : null,
          ),
          child: isDone
              ? Icon(
                  isCurrent ? s.icon : Icons.check,
                  color: Colors.white,
                  size: isCurrent ? 12 : 8,
                )
              : null,
        );
      }),
    );
  }
}

// ── Onglet 2 : Scénarios ─────────────────────────────────────────────────────

class _ScenariosTab extends StatelessWidget {
  const _ScenariosTab();

  @override
  Widget build(BuildContext context) {
    final completed = context.watch<SandboxProvider>().completedScenarios;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: SandboxData.scenarios.length,
      itemBuilder: (ctx, i) {
        final scenario = SandboxData.scenarios[i];
        final isDone = completed.contains(scenario.id);
        final color = Color(scenario.color);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone
                  ? AppTheme.success.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.25),
            ),
          ),
          child: Theme(
            data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppTheme.success.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_circle,
                          color: AppTheme.success, size: 22)
                      : Text(scenario.icon,
                          style: const TextStyle(fontSize: 20)),
                ),
              ),
              title: Text(
                scenario.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '~${scenario.estimatedMinutes} min',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isDone)
                    const Text(
                      '✓ Complété',
                      style: TextStyle(
                          color: AppTheme.success, fontSize: 10),
                    ),
                ],
              ),
              iconColor: color,
              collapsedIconColor: AppTheme.textSecondary,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scenario.description,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(scenario.steps.length, (j) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20, height: 20,
                                margin: const EdgeInsets.only(right: 10, top: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withValues(alpha: 0.15),
                                ),
                                child: Center(
                                  child: Text(
                                    '${j + 1}',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  scenario.steps[j],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      if (!isDone)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.check_circle_outline,
                                color: color, size: 16),
                            label: Text(
                              'Marquer comme complété',
                              style: TextStyle(
                                  color: color, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: color.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                            ),
                            onPressed: () {
                              context
                                  .read<SandboxProvider>()
                                  .markScenarioCompleted(scenario.id);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Onglet 3 : Informations de session ──────────────────────────────────────

class _SessionInfoTab extends StatelessWidget {
  const _SessionInfoTab();

  @override
  Widget build(BuildContext context) {
    final sbProvider = context.watch<SandboxProvider>();
    final client = sbProvider.client;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé session
          _SectionCard(
            title: 'Résumé de la session',
            icon: Icons.analytics_outlined,
            iconColor: AppTheme.primary,
            children: [
              _InfoRow('Commandes créées',
                  '${sbProvider.ordersCreatedInSession}'),
              _InfoRow('Scénarios complétés',
                  '${sbProvider.completedScenarios.length}/${SandboxData.scenarios.length}'),
              _InfoRow('Articles en panier', '${sbProvider.cartCount}'),
              _InfoRow('Total panier',
                  '${sbProvider.cartTotal.toStringAsFixed(0)} F'),
            ],
          ),
          const SizedBox(height: 14),
          // Compte démo
          _SectionCard(
            title: 'Compte de démonstration',
            icon: Icons.person_outline,
            iconColor: const Color(0xFF7C3AED),
            children: [
              _InfoRow('Nom', client?.name ?? '-'),
              _InfoRow('Email', client?.email ?? '-'),
              _InfoRow('Points fidélité', '${client?.loyaltyPoints ?? 0}'),
              _InfoRow('Total commandes', '${client?.totalOrders ?? 0}'),
              _InfoRow('Total dépensé',
                  '${client?.totalSpent.toStringAsFixed(0) ?? 0} F'),
            ],
          ),
          const SizedBox(height: 14),
          // Données sandbox
          _SectionCard(
            title: 'Données sandbox disponibles',
            icon: Icons.inventory_2_outlined,
            iconColor: AppTheme.success,
            children: [
              _InfoRow('Produits', '${SandboxData.products.length}'),
              _InfoRow(
                  'Catégories',
                  SandboxData.products
                      .map((p) => p.category)
                      .toSet()
                      .length
                      .toString()),
              _InfoRow('Promotions', '${SandboxData.promotions.length}'),
              _InfoRow('Adresses', '${SandboxData.addresses.length}'),
              _InfoRow('Scénarios', '${SandboxData.scenarios.length}'),
              _InfoRow('Historique fidélité',
                  '${SandboxData.loyaltyHistory.length} transactions'),
            ],
          ),
          const SizedBox(height: 14),
          // Avertissement
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode Sandbox actif',
                        style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toutes les opérations sont simulées en mémoire. '
                        'Aucune donnée n\'est envoyée à Firebase ou à '
                        'la base de données de production.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF2A2A5A), height: 1),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
