import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_provider.dart';
import '../../../sandbox/sandbox_provider.dart';
import '../../../sandbox/sandbox_dashboard_screen.dart';
import '../../../models/client_models.dart';
import '../../../utils/app_theme.dart';
import '../auth/client_auth_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PROFIL CLIENT — Infos, Adresses, Fidélité, Déconnexion
// ═══════════════════════════════════════════════════════════════════════════

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

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
  const _LoyaltySection({required this.client, required this.history, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Text('Programme Fidélité',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF1A237E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                      const Text('Vos points', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${client.loyaltyPoints}',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 28)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Valeur', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '${NumberFormat('#,###', 'fr_FR').format(client.loyaltyPoints * settings.loyaltyPointValue)} F',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 pt = ${settings.loyaltyPointValue} F',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('1 pt par ${settings.loyaltyPointsPerFCFA} F dépensés',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        // Historique points (5 dernières transactions)
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...history.take(5).map((tx) => _LoyaltyTxRow(tx: tx)),
          if (history.length > 5)
            TextButton(
              onPressed: () => _showAllHistory(context, history),
              child: const Text('Voir tout l\'historique', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
        ],
      ],
    );
  }

  void _showAllHistory(BuildContext context, List<LoyaltyTransaction> history) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
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
            const Text('Historique des points',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 16),
            ...history.map((tx) => _LoyaltyTxRow(tx: tx)),
          ],
        ),
      ),
    );
  }
}

class _LoyaltyTxRow extends StatelessWidget {
  final LoyaltyTransaction tx;
  const _LoyaltyTxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isEarn = tx.type == LoyaltyType.earn || tx.type == LoyaltyType.bonus;
    final fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: isEarn ? Colors.amber.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
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
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(fmtDate.format(tx.createdAt),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          Text(
            isEarn ? '+${tx.points} pts' : '-${tx.points} pts',
            style: TextStyle(
              color: isEarn ? Colors.amber : AppTheme.error,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
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
    final provider = context.read<ClientProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: address.isDefault ? AppTheme.primary.withValues(alpha: 0.5) : const Color(0xFF2A2A5A),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (address.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Par défaut',
                            style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(address.address,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
            color: AppTheme.surface,
            itemBuilder: (_) => [
              if (!address.isDefault)
                const PopupMenuItem(value: 'default', child: Text('Définir par défaut', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppTheme.error))),
            ],
            onSelected: (val) async {
              if (val == 'default') {
                await provider.setDefaultAddress(address.id);
              } else if (val == 'delete') {
                await provider.deleteAddress(address.id);
              }
            },
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

  static const _labels = ['Maison', 'Bureau', 'Autre'];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
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
      );
      await context.read<ClientProvider>().addAddress(address);
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
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.security_outlined,
          label: 'Sécurité & Mot de passe',
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.help_outline,
          label: 'Aide & Support',
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.info_outline,
          label: 'À propos',
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () {},
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
