import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_provider.dart';
import '../../../sandbox/client_provider_proxy.dart';
import '../../../models/client_models.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/product_image_widget.dart';
import '../menu/client_menu_screen.dart';
import '../orders/client_orders_screen.dart';
// ═══════════════════════════════════════════════════════════════════════════
// ACCUEIL CLIENT — Dashboard + Promotions + Accès rapide
// ═══════════════════════════════════════════════════════════════════════════

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = ClientProviderProxy.watch(context);
    final client = provider.client;

    if (client == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final fmtMoney = NumberFormat('#,###', 'fr_FR');
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Bonjour' : (now.hour < 18 ? 'Bon après-midi' : 'Bonsoir');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1A1A2E)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$greeting,', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                                  Text(client.name.split(' ').first,
                                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            // Avatar
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Center(child: Text(client.initials,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Points fidélité mini-badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text('${client.loyaltyPoints} points fidélité',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text('SANKADIOKRO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── KPIs ─────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _KpiCard(
                        label: 'Commandes',
                        value: client.totalOrders.toString(),
                        icon: Icons.receipt_long,
                        color: AppTheme.primary,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _KpiCard(
                        label: 'Total dépensé',
                        value: '${fmtMoney.format(client.totalSpent)} F',
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppTheme.success,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _KpiCard(
                        label: 'Points',
                        value: '${client.loyaltyPoints}',
                        icon: Icons.stars,
                        color: Colors.amber,
                      )),
                    ],
                  ),

                  // ── Bannières actives ─────────────────────────────────────
                  if (provider.visibleBanners.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    ...provider.visibleBanners.map((b) => _BannerCard(banner: b)),
                  ],

                  // ── Commandes actives ─────────────────────────────────────
                  if (provider.activeOrders.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle(title: 'Commandes en cours', icon: Icons.delivery_dining, onMore: () => _goToOrders(context)),
                    const SizedBox(height: 10),
                    ...provider.activeOrders.take(2).map((o) => _ActiveOrderCard(order: o)),
                  ],

                  // ── Accès rapide ──────────────────────────────────────────
                  const SizedBox(height: 20),
                  const _SectionTitle(title: 'Commandes rapides', icon: Icons.bolt),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _QuickAction(
                        icon: Icons.delivery_dining,
                        label: 'Commander\nen livraison',
                        color: AppTheme.primary,
                        onTap: () => _openMenu(context, OrderType.delivery),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickAction(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Commander\nà emporter',
                        color: AppTheme.success,
                        onTap: () => _openMenu(context, OrderType.takeaway),
                      )),
                    ],
                  ),

                  // ── Promotions ────────────────────────────────────────────
                  if (provider.promotions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Offres du moment', icon: Icons.local_offer),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.promotions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) => _PromoCard(promo: provider.promotions[i]),
                      ),
                    ),
                  ],

                  // ── Menu populaire ────────────────────────────────────────
                  if (provider.products.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle(title: 'Notre menu', icon: Icons.restaurant_menu, onMore: () => _goToMenu(context)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.products.take(8).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) {
                          final p = provider.products[i];
                          return _ProductMiniCard(
                            product: p,
                            onAdd: () => provider.addToCart(p),
                          );
                        },
                      ),
                    ),
                  ],

                  // ── Programme fidélité ────────────────────────────────────
                  const SizedBox(height: 20),
                  _LoyaltyCard(client: client, settings: provider.settings),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMenu(BuildContext context, OrderType type) {
    ClientProviderProxy.read(context).setOrderType(type);
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClientMenuScreen(
          onGoHome: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _goToMenu(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClientMenuScreen(
          onGoHome: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _goToOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClientOrdersScreen(
          onGoHome: () => Navigator.pop(ctx),
        ),
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onMore;
  const _SectionTitle({required this.title, required this.icon, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            child: const Text('Voir tout', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final ClientOrder order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
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
                Text(order.orderNumber ?? 'Commande', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(status.label, style: TextStyle(color: status.color, fontSize: 12)),
              ],
            ),
          ),
          // Barre de progression
          _OrderProgressBar(status: status),
        ],
      ),
    );
  }
}

class _OrderProgressBar extends StatelessWidget {
  final ClientOrderStatus status;
  const _OrderProgressBar({required this.status});

  @override
  Widget build(BuildContext context) {
    final step = status.step;
    if (step < 0) return const SizedBox.shrink();
    final maxStep = 5;
    final progress = step / maxStep;
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation(status.color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 3),
          Text('${(progress * 100).toInt()}%', style: TextStyle(color: status.color, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Promotion promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.3), AppTheme.cardBg],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(promo.valueLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const SizedBox(height: 10),
          Text(promo.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), maxLines: 2),
          const Spacer(),
          Text(promo.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ProductMiniCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onAdd;
  const _ProductMiniCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final fmtMoney = NumberFormat('#,###', 'fr_FR');
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductImage(
            imageUrl: product.imageUrl,
            height: 60,
            borderRadius: BorderRadius.circular(10),
            iconSize: 28,
          ),
          const SizedBox(height: 8),
          Text(product.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${fmtMoney.format(product.price)} F', style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoyaltyCard extends StatelessWidget {
  final ClientUser client;
  final OnlineOrderSettings settings;
  const _LoyaltyCard({required this.client, required this.settings});

  @override
  Widget build(BuildContext context) {
    final pointValue = settings.loyaltyPointValue;
    final totalValue = client.loyaltyPoints * pointValue;
    final fmtMoney = NumberFormat('#,###', 'fr_FR');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF1A237E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              const Text('Programme Fidélité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Text('${client.loyaltyPoints} pts',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Équivalent : ${fmtMoney.format(totalValue)} F de réductions disponibles',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '1 point = $pointValue F • Gagnez 1 pt tous les ${settings.loyaltyPointsPerFCFA} F dépensés',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Bannière client ───────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final AppBanner banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext buildContext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3949AB).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image si disponible
            if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty)
              SizedBox(
                height: 140,
                child: Image.network(
                  banner.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: const Color(0xFF1A237E),
                    child: const Icon(Icons.campaign_outlined, color: Colors.white38, size: 48),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + Titre
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.campaign_outlined, size: 11, color: Colors.white70),
                        SizedBox(width: 4),
                        Text('Annonce',
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    banner.message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  // Bouton optionnel
                  if (banner.buttonLabel != null && banner.buttonLabel!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleAction(buildContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A237E),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          banner.buttonLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext ctx) {
    final action = banner.buttonAction ?? '';
    if (action == 'menu') {
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ClientMenuScreen(onGoHome: () => Navigator.pop(ctx)),
      ));
    } else if (action == 'orders') {
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ClientOrdersScreen(onGoHome: () => Navigator.pop(ctx)),
      ));
    }
    // Pour url:... on pourrait ajouter url_launcher ici
  }
}
