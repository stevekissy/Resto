import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../providers/client_provider.dart';
import '../../../sandbox/sandbox_provider.dart';
import '../../../sandbox/sandbox_dashboard_screen.dart';
import '../../../models/client_models.dart';
import '../../../utils/app_theme.dart';
import '../auth/client_auth_screen.dart';
import 'client_notifications_screen.dart';
import 'client_referral_screen.dart';
import 'client_security_screen.dart';
import 'client_support_screen.dart';
import 'client_about_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PROFIL CLIENT — Infos, Adresses, Fidélité, Déconnexion
// ═══════════════════════════════════════════════════════════════════════════

class ClientProfileScreen extends StatelessWidget {
  final VoidCallback? onGoHome;
  const ClientProfileScreen({super.key, this.onGoHome});

  @override
  Widget build(BuildContext context) {
    // Détection automatique du mode sandbox
    final sbProvider = context.watch<SandboxProvider>();
    final isSandbox = sbProvider.isSandboxActive;

    final ClientUser? client;
    final List<LoyaltyTransaction> loyaltyHistory;
    final List<DeliveryAddress> addresses;
    final OnlineOrderSettings settings;

    if (isSandbox) {
      client = sbProvider.client;
      loyaltyHistory = sbProvider.loyaltyHistory;
      addresses = sbProvider.addresses;
      settings = sbProvider.settings;
    } else {
      final provider = context.watch<ClientProvider>();
      client = provider.client;
      loyaltyHistory = provider.loyaltyHistory;
      addresses = provider.addresses;
      settings = provider.settings;
    }
    if (client == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // AppBar gradient
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              tooltip: 'Retour à l\'accueil',
              onPressed: onGoHome,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined, color: Colors.white),
                tooltip: 'Accueil',
                onPressed: onGoHome,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF1A1A2E)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: Center(
                            child: Text(client!.initials,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(client!.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(client.email,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                              if (client.phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(client.phone,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showEditProfile(context, client!),
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text('Mon Profil',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPIs
                  _StatsRow(client: client!, settings: settings),
                  const SizedBox(height: 20),

                  // Bouton Tableau de bord Sandbox (uniquement en mode sandbox)
                  if (isSandbox) ..._buildSandboxControls(context),


                  // Programme fidélité
                  _LoyaltySection(client: client!, history: loyaltyHistory, settings: settings),
                  const SizedBox(height: 20),

                  // Adresses
                  _AddressSection(addresses: addresses),
                  const SizedBox(height: 20),

                  // Menu profil
                  _ProfileMenu(client: client!),
                  const SizedBox(height: 20),

                  // Bouton déconnexion / quitter sandbox
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => isSandbox
                          ? _confirmExitSandbox(context)
                          : _confirmLogout(context),
                      icon: Icon(
                        isSandbox ? Icons.science_rounded : Icons.logout,
                        color: isSandbox ? const Color(0xFF7C3AED) : AppTheme.error,
                      ),
                      label: Text(
                        isSandbox ? 'Quitter le mode Sandbox' : 'Déconnexion',
                        style: TextStyle(
                          color: isSandbox ? const Color(0xFF7C3AED) : AppTheme.error,
                          fontSize: 15, fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isSandbox ? const Color(0xFF7C3AED) : AppTheme.error,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSandboxControls(BuildContext context) {
    return [
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SandboxDashboardScreen()),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_rounded,
                    color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tableau de Bord Sandbox',
                      style: TextStyle(
                        color: Color(0xFF7C3AED),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Progresser les statuts, simuler paiements et livraisons',
                      style: TextStyle(
                        color: Color(0xFF9D6EF5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF7C3AED), size: 20),
            ],
          ),
        ),
      ),
    ];
  }

  void _confirmExitSandbox(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.science_rounded, color: Color(0xFF7C3AED), size: 22),
            SizedBox(width: 10),
            Text('Quitter le Sandbox ?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'La session de test sera terminée. Toutes les données sandbox seront effacées.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Continuer le test',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () async {
              Navigator.pop(ctx);
              await ctx.read<SandboxProvider>().exitSandbox();
              if (ctx.mounted) {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const ClientAuthScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Quitter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context, ClientUser client) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditProfileSheet(client: client),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text('Voulez-vous vous déconnecter ?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ClientProvider>().logout();
              if (ctx.mounted) {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ClientAuthScreen()),
                  (_) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final ClientUser client;
  final OnlineOrderSettings settings;
  const _StatsRow({required this.client, required this.settings});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final pointValue = client.loyaltyPoints * settings.loyaltyPointValue;
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon: Icons.receipt_long, color: AppTheme.primary,
          value: '${client.totalOrders}', label: 'Commandes',
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          icon: Icons.account_balance_wallet_outlined, color: AppTheme.success,
          value: '${fmt.format(client.totalSpent)} F', label: 'Dépensé',
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          icon: Icons.stars, color: Colors.amber,
          value: '${client.loyaltyPoints} pts', label: '≈ ${fmt.format(pointValue)} F',
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Section Fidélité ──────────────────────────────────────────────────────────

class _LoyaltySection extends StatelessWidget {
  final ClientUser client;
  final List<LoyaltyTransaction> history;
  final OnlineOrderSettings settings;
  const _LoyaltySection(
      {required this.client, required this.history, required this.settings});

  int get _pointsEarned => history
      .where((t) =>
          t.type == LoyaltyType.earn || t.type == LoyaltyType.bonus)
      .fold(0, (s, t) => s + t.points);

  int get _pointsUsed => history
      .where((t) => t.type == LoyaltyType.redeem)
      .fold(0, (s, t) => s + t.points);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final pointValue = client.loyaltyPoints * settings.loyaltyPointValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Programme Fidélité',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
            // Conditions d'utilisation
            TextButton(
              onPressed: () => _showConditions(context),
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2)),
              child: const Text('Conditions',
                  style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Carte de fidélité cliquable → ouvre l'historique complet
        GestureDetector(
          onTap: () => _showAllHistory(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vos points',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text('${client.loyaltyPoints}',
                            style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w900,
                                fontSize: 28)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Valeur',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(
                          '${fmt.format(pointValue)} F',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 10),
                // Points gagnés / utilisés résumé
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('+$_pointsEarned pts',
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          const Text('Gagnés',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.2)),
                    Expanded(
                      child: Column(
                        children: [
                          Text('-$_pointsUsed pts',
                              style: TextStyle(
                                  color: AppTheme.error
                                      .withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          const Text('Utilisés',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.2)),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                              '${fmt.format(settings.loyaltyPointValue)} F',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                          const Text('/ point',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 pt = ${settings.loyaltyPointValue} F',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                    const Row(
                      children: [
                        Text('Voir l\'historique',
                            style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios,
                            color: Colors.amber, size: 10),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 5 dernières transactions — chaque ligne est cliquable
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...history
              .take(5)
              .map((tx) => _LoyaltyTxRow(
                    tx: tx,
                    pointValue: settings.loyaltyPointValue,
                    onTap: () => _showTxDetail(context, tx),
                  )),
          if (history.length > 5)
            TextButton(
              onPressed: () => _showAllHistory(context),
              child: const Text('Voir tout l\'historique',
                  style: TextStyle(
                      color: AppTheme.primary, fontSize: 13)),
            ),
        ],
      ],
    );
  }

  // ── Historique complet ──────────────────────────────────────────────────

  void _showAllHistory(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:
                      AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Historique des points',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 8),
            // Résumé global
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('${client.loyaltyPoints}',
                          style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                      const Text('Solde actuel',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('+$_pointsEarned',
                          style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const Text('Total gagné',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('-$_pointsUsed',
                          style: TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const Text('Total utilisé',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                          '${fmt.format(client.loyaltyPoints * settings.loyaltyPointValue)} F',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const Text('Valeur',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Aucune transaction',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14)),
                ),
              )
            else
              ...history.map((tx) => _LoyaltyTxRow(
                    tx: tx,
                    pointValue: settings.loyaltyPointValue,
                    onTap: () {
                      Navigator.pop(ctx);
                      Future.delayed(
                        const Duration(milliseconds: 200),
                        () => _showTxDetail(ctx, tx),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }

  // ── Détail d'une transaction ────────────────────────────────────────────

  void _showTxDetail(BuildContext context, LoyaltyTransaction tx) {
    final isEarn =
        tx.type == LoyaltyType.earn || tx.type == LoyaltyType.bonus;
    final fmt = NumberFormat('#,###', 'fr_FR');
    final fmtDate = DateFormat('EEEE dd MMMM yyyy à HH:mm', 'fr_FR');
    final valueF = tx.points * settings.loyaltyPointValue;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:
                      AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isEarn
                        ? Colors.amber.withValues(alpha: 0.15)
                        : AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isEarn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isEarn ? Colors.amber : AppTheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEarn ? 'Points gagnés' : 'Points utilisés',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16),
                      ),
                      Text(
                        fmtDate.format(tx.createdAt),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.stars,
              iconColor: isEarn ? Colors.amber : AppTheme.error,
              label: isEarn ? 'Points gagnés' : 'Points utilisés',
              value:
                  '${isEarn ? '+' : '-'}${tx.points} pts',
              valueColor: isEarn ? Colors.amber : AppTheme.error,
            ),
            _DetailRow(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: Colors.white70,
              label: 'Valeur équivalente',
              value: '${fmt.format(valueF)} F',
            ),
            _DetailRow(
              icon: Icons.description_outlined,
              iconColor: Colors.white70,
              label: 'Description',
              value: tx.description,
            ),
            _DetailRow(
              icon: Icons.info_outline,
              iconColor: Colors.white70,
              label: 'Type',
              value: tx.type == LoyaltyType.earn
                  ? 'Gain sur commande'
                  : tx.type == LoyaltyType.bonus
                      ? 'Bonus fidélité'
                      : 'Utilisation',
            ),
            if (tx.orderId != null)
              _DetailRow(
                icon: Icons.receipt_long_outlined,
                iconColor: AppTheme.primary,
                label: 'Commande liée',
                value: '#${tx.orderId}',
                valueColor: AppTheme.primary,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Conditions d'utilisation ────────────────────────────────────────────

  void _showConditions(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.stars, color: Colors.amber, size: 22),
                  SizedBox(width: 10),
                  Text('Conditions du Programme Fidélité',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 20),
              _ConditionItem(
                title: 'Gain de points',
                text:
                    'Vous gagnez 1 point de fidélité pour chaque ${fmt.format(settings.loyaltyPointsPerFCFA)} F dépensés sur vos commandes validées.',
              ),
              _ConditionItem(
                title: 'Valeur des points',
                text:
                    '1 point vaut ${settings.loyaltyPointValue} F. Vous pouvez utiliser vos points pour réduire le montant de vos prochaines commandes.',
              ),
              _ConditionItem(
                title: 'Utilisation',
                text:
                    'Les points peuvent être utilisés lors du paiement en caisse ou en sélectionnant l\'option lors du passage de commande en ligne.',
              ),
              _ConditionItem(
                title: 'Expiration',
                text:
                    'Les points de fidélité sont valables 12 mois après leur acquisition. Passé ce délai, ils sont automatiquement supprimés.',
              ),
              _ConditionItem(
                title: 'Commandes éligibles',
                text:
                    'Seules les commandes entièrement payées et livrées génèrent des points. Les commandes annulées ou remboursées ne donnent pas droit aux points.',
              ),
              _ConditionItem(
                title: 'Non-cumulable',
                text:
                    'Les points ne sont pas cumulables avec d\'autres offres promotionnelles, sauf mention contraire.',
              ),
              _ConditionItem(
                title: 'Modification des conditions',
                text:
                    'Restaurant Sankadiokro se réserve le droit de modifier les conditions du programme fidélité à tout moment, avec notification préalable.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionItem extends StatelessWidget {
  final String title;
  final String text;
  const _ConditionItem({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: valueColor ?? Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyTxRow extends StatelessWidget {
  final LoyaltyTransaction tx;
  final int pointValue;
  final VoidCallback? onTap;
  const _LoyaltyTxRow(
      {required this.tx, required this.pointValue, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEarn =
        tx.type == LoyaltyType.earn || tx.type == LoyaltyType.bonus;
    final fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');
    final fmt = NumberFormat('#,###', 'fr_FR');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF2A2A5A).withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isEarn
                    ? Colors.amber.withValues(alpha: 0.15)
                    : AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEarn ? Icons.add : Icons.remove,
                color: isEarn ? Colors.amber : AppTheme.error,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.description,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Text(fmtDate.format(tx.createdAt),
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10)),
                      const SizedBox(width: 6),
                      Text(
                        '≈ ${fmt.format(tx.points * pointValue)} F',
                        style: TextStyle(
                            color: isEarn
                                ? Colors.amber.withValues(alpha: 0.7)
                                : AppTheme.error.withValues(alpha: 0.7),
                            fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isEarn ? '+${tx.points} pts' : '-${tx.points} pts',
                  style: TextStyle(
                    color: isEarn ? Colors.amber : AppTheme.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Adresses ──────────────────────────────────────────────────────────

class _AddressSection extends StatelessWidget {
  final List<DeliveryAddress> addresses;
  const _AddressSection({required this.addresses});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Mes Adresses',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            TextButton.icon(
              onPressed: () => _showAddAddressDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (addresses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A5A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_off_outlined, color: AppTheme.textSecondary),
                SizedBox(width: 12),
                Text('Aucune adresse enregistrée',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          )
        else
          ...addresses.map((addr) => _AddressCard(address: addr)),
      ],
    );
  }

  void _showAddAddressDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddAddressSheet(),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final DeliveryAddress address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    // Use sandbox-aware provider
    final isSandbox = context.read<SandboxProvider>().isSandboxActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: address.isDefault
              ? AppTheme.primary.withValues(alpha: 0.5)
              : const Color(0xFF2A2A5A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(address.icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(address.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    if (address.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Par défaut',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(address.address,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (address.details != null &&
                    address.details!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(address.details!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                if (address.latitude != null) ...[
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Icon(Icons.my_location, color: Color(0xFF4CAF50), size: 10),
                      SizedBox(width: 4),
                      Text('Géolocalisée',
                          style: TextStyle(
                              color: Color(0xFF4CAF50), fontSize: 9)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppTheme.textSecondary, size: 20),
            color: AppTheme.surface,
            itemBuilder: (_) => [
              if (!address.isDefault)
                const PopupMenuItem(
                    value: 'default',
                    child: Text('Définir par défaut',
                        style: TextStyle(color: Colors.white))),
              const PopupMenuItem(
                  value: 'edit',
                  child: Text('Modifier',
                      style: TextStyle(color: Colors.white))),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: AppTheme.error))),
            ],
            onSelected: (val) async {
              if (val == 'default') {
                if (isSandbox) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Mode sandbox — action simulée'),
                    behavior: SnackBarBehavior.floating,
                  ));
                } else {
                  await context
                      .read<ClientProvider>()
                      .setDefaultAddress(address.id);
                }
              } else if (val == 'edit') {
                _showEditAddress(context, address, isSandbox);
              } else if (val == 'delete') {
                _confirmDelete(context, address, isSandbox);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditAddress(
      BuildContext context, DeliveryAddress address, bool isSandbox) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditAddressSheet(address: address),
    );
  }

  void _confirmDelete(
      BuildContext context, DeliveryAddress address, bool isSandbox) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'adresse',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
            'Supprimer "${address.label} — ${address.address}" ?',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              if (isSandbox) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Mode sandbox — adresse supprimée (simulé)'),
                  behavior: SnackBarBehavior.floating,
                ));
              } else {
                await context
                    .read<ClientProvider>()
                    .deleteAddress(address.id);
              }
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Ajouter une adresse ───────────────────────────────────────────────────────

class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet();

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  String _label = 'Maison';
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLocating = false;
  double? _lat;
  double? _lng;

  static const _labels = ['Maison', 'Bureau', 'Autre'];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Activez la localisation sur votre appareil'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permission de localisation refusée définitivement'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_addressCtrl.text.isEmpty) {
          _addressCtrl.text =
              'Position GPS (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position GPS obtenue'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'obtenir la position : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Nouvelle adresse',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 20),
              // Type
              const Text('Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: _labels.map((l) {
                  final isSelected = l == _label;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _label = l),
                      child: Container(
                        margin: EdgeInsets.only(right: l != _labels.last ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A),
                          ),
                        ),
                        child: Text(l,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              fontSize: 13,
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Géolocalisation
              GestureDetector(
                onTap: _isLocating ? null : _getLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: _lat != null
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _lat != null
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                          : AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isLocating)
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2),
                        )
                      else
                        Icon(
                          _lat != null ? Icons.my_location : Icons.location_searching,
                          color: _lat != null ? const Color(0xFF4CAF50) : AppTheme.primary,
                          size: 18,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _lat != null
                            ? 'Position GPS obtenue ✓'
                            : 'Utiliser ma position actuelle (GPS)',
                        style: TextStyle(
                          color: _lat != null ? const Color(0xFF4CAF50) : AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Adresse
              TextFormField(
                controller: _addressCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Adresse complète *',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.textSecondary),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Adresse obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Détails (optionnel)',
                  prefixIcon: Icon(Icons.info_outline, color: AppTheme.textSecondary),
                  hintText: 'Bâtiment, étage, code…',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer l\'adresse'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final address = DeliveryAddress(
        id: '',
        label: _label,
        address: _addressCtrl.text.trim(),
        details: _detailsCtrl.text.trim().isNotEmpty ? _detailsCtrl.text.trim() : null,
        latitude: _lat,
        longitude: _lng,
      );
      await context.read<ClientProvider>().addAddress(address);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Modifier une adresse existante ───────────────────────────────────────────

class _EditAddressSheet extends StatefulWidget {
  final DeliveryAddress address;
  const _EditAddressSheet({required this.address});

  @override
  State<_EditAddressSheet> createState() => _EditAddressSheetState();
}

class _EditAddressSheetState extends State<_EditAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _label;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _detailsCtrl;
  bool _isLoading = false;
  bool _isLocating = false;
  double? _lat;
  double? _lng;

  static const _labels = ['Maison', 'Bureau', 'Autre'];

  @override
  void initState() {
    super.initState();
    _label = _labels.contains(widget.address.label)
        ? widget.address.label
        : 'Autre';
    _addressCtrl = TextEditingController(text: widget.address.address);
    _detailsCtrl =
        TextEditingController(text: widget.address.details ?? '');
    _lat = widget.address.latitude;
    _lng = widget.address.longitude;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Activez la localisation sur votre appareil'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Permission de localisation refusée définitivement'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position GPS mise à jour ✓'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'obtenir la position : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Modifier l\'adresse',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 20),
              // Type
              const Text('Type',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: _labels.map((l) {
                  final isSelected = l == _label;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _label = l),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: l != _labels.last ? 8 : 0),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : const Color(0xFF2A2A5A),
                          ),
                        ),
                        child: Text(l,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 13,
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // GPS
              GestureDetector(
                onTap: _isLocating ? null : _getLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: _lat != null
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _lat != null
                          ? const Color(0xFF4CAF50)
                              .withValues(alpha: 0.5)
                          : AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isLocating)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2),
                        )
                      else
                        Icon(
                          _lat != null
                              ? Icons.my_location
                              : Icons.location_searching,
                          color: _lat != null
                              ? const Color(0xFF4CAF50)
                              : AppTheme.primary,
                          size: 18,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _lat != null
                            ? 'Position GPS active (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})'
                            : 'Mettre à jour ma position GPS',
                        style: TextStyle(
                          color: _lat != null
                              ? const Color(0xFF4CAF50)
                              : AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Adresse
              TextFormField(
                controller: _addressCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Adresse complète *',
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: AppTheme.textSecondary),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Adresse obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Détails (optionnel)',
                  prefixIcon: Icon(Icons.info_outline,
                      color: AppTheme.textSecondary),
                  hintText: 'Bâtiment, étage, code…',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer les modifications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final isSandbox =
          context.read<SandboxProvider>().isSandboxActive;
      if (isSandbox) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mode sandbox — adresse modifiée (simulé)'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final updated = DeliveryAddress(
        id: widget.address.id,
        label: _label,
        address: _addressCtrl.text.trim(),
        details: _detailsCtrl.text.trim().isNotEmpty
            ? _detailsCtrl.text.trim()
            : null,
        isDefault: widget.address.isDefault,
        latitude: _lat,
        longitude: _lng,
      );
      await context.read<ClientProvider>().updateAddress(updated);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Menu profil ───────────────────────────────────────────────────────────────

class _ProfileMenu extends StatelessWidget {
  final ClientUser client;
  const _ProfileMenu({required this.client});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MenuItem(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ClientNotificationsScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.card_giftcard_outlined,
          label: 'Parrainage & Bonus',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: const Text('+50 pts', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientReferralScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.security_outlined,
          label: 'Sécurité & Mot de passe',
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientSecurityScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.help_outline,
          label: 'Aide & Support',
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientSupportScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.info_outline,
          label: 'À propos',
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientAboutScreen()),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        tileColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: trailing,
      ),
    );
  }
}

// ── Modifier le profil ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final ClientUser client;
  const _EditProfileSheet({required this.client});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.client.name);
    _phoneCtrl = TextEditingController(text: widget.client.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Modifier mon profil',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await context.read<ClientProvider>().updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
