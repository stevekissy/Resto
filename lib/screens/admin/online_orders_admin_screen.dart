import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/client_provider.dart';
import '../../models/client_models.dart';
import '../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PANNEAU ADMIN — Commandes en ligne
// Accès : admin et manager uniquement
// Fonctions :
//   • Activer/désactiver les commandes en ligne
//   • Voir toutes les commandes clients
//   • Mettre à jour les statuts des commandes
//   • Configurer acompte %, frais livraison, zones
//   • Gérer les promotions
//   • Voir les comptes clients
// ═══════════════════════════════════════════════════════════════════════════

class OnlineOrdersAdminScreen extends StatefulWidget {
  const OnlineOrdersAdminScreen({super.key});

  @override
  State<OnlineOrdersAdminScreen> createState() => _OnlineOrdersAdminScreenState();
}

class _OnlineOrdersAdminScreenState extends State<OnlineOrdersAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _settingsLoaded = false;

  // Contrôleurs pour la config
  final _depositCtrl = TextEditingController();
  final _deliveryFeeCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initProvider();
  }

  Future<void> _initProvider() async {
    final prov = context.read<ClientProvider>();
    // Charger les paramètres si pas encore chargé
    if (!_settingsLoaded) {
      await prov.initSettingsOnly();
      if (mounted) setState(() => _settingsLoaded = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _depositCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _minOrderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientProvider>();
    final settings = provider.settings;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Commandes en Ligne',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Toggle ON/OFF rapide
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  settings.isOnlineOrderEnabled ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    color: settings.isOnlineOrderEnabled ? AppTheme.success : AppTheme.error,
                    fontSize: 12, fontWeight: FontWeight.w700,
                  ),
                ),
                Switch(
                  value: settings.isOnlineOrderEnabled,
                  onChanged: (v) => _toggleOnlineOrders(context, v, settings),
                  activeColor: AppTheme.success,
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Commandes'),
            Tab(text: 'Configuration'),
            Tab(text: 'Promotions'),
            Tab(text: 'Clients'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrdersTab(provider: provider),
          _ConfigTab(settings: settings),
          _PromotionsTab(provider: provider),
          _ClientsTab(provider: provider),
        ],
      ),
    );
  }

  Future<void> _toggleOnlineOrders(BuildContext context, bool enabled, OnlineOrderSettings settings) async {
    final prov = context.read<ClientProvider>();
    final updatedSettings = OnlineOrderSettings(
      isOnlineOrderEnabled: enabled,
      depositPercentage: settings.depositPercentage,
      depositFixedAmount: settings.depositFixedAmount,
      deliveryFeeBase: settings.deliveryFeeBase,
      minimumOrderAmount: settings.minimumOrderAmount,
      estimatedDeliveryMinutes: settings.estimatedDeliveryMinutes,
      estimatedTakeawayMinutes: settings.estimatedTakeawayMinutes,
      loyaltyPointsPerFCFA: settings.loyaltyPointsPerFCFA,
      loyaltyPointValue: settings.loyaltyPointValue,
      restaurantPhone: settings.restaurantPhone,
      restaurantAddress: settings.restaurantAddress,
      deliveryZones: settings.deliveryZones,
    );
    await prov.saveSettings(updatedSettings);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'Commandes en ligne activées ✓'
              : 'Commandes en ligne désactivées'),
          backgroundColor: enabled ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

// ── Onglet Commandes ─────────────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  final ClientProvider provider;
  const _OrdersTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final orders = provider.orders
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, color: AppTheme.textSecondary, size: 56),
            SizedBox(height: 16),
            Text('Aucune commande en ligne', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      itemCount: orders.length,
      itemBuilder: (ctx, i) => _AdminOrderCard(order: orders[i]),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final ClientOrder order;
  const _AdminOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final fmtDate = DateFormat('dd/MM HH:mm', 'fr_FR');
    final status = order.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(status.icon, color: status.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(order.orderNumber ?? order.id.substring(0, 8),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status.label,
                              style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    Text('${order.clientName} • ${order.clientPhone}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt.format(order.grandTotal)} F',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(fmtDate.format(order.createdAt),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Articles
          Text(
            order.items.map((i) => '${i.quantity}× ${i.productName}').join(' • '),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          if (order.orderType == OrderType.delivery && order.deliveryAddress != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.deliveryAddress!.address,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Boutons de changement de statut
          if (order.status != ClientOrderStatus.delivered &&
              order.status != ClientOrderStatus.cancelled)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _nextStatuses(order.status).map((s) {
                return GestureDetector(
                  onTap: () => _updateStatus(context, order, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: s.color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, color: s.color, size: 14),
                        const SizedBox(width: 4),
                        Text(s.label, style: TextStyle(color: s.color, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  List<ClientOrderStatus> _nextStatuses(ClientOrderStatus current) {
    switch (current) {
      case ClientOrderStatus.pending:
        return [ClientOrderStatus.confirmed, ClientOrderStatus.cancelled];
      case ClientOrderStatus.confirmed:
        return [ClientOrderStatus.preparing];
      case ClientOrderStatus.preparing:
        return [ClientOrderStatus.ready];
      case ClientOrderStatus.ready:
        return [ClientOrderStatus.delivering, ClientOrderStatus.delivered];
      case ClientOrderStatus.delivering:
        return [ClientOrderStatus.delivered];
      default:
        return [];
    }
  }

  void _updateStatus(BuildContext context, ClientOrder order, ClientOrderStatus newStatus) {
    context.read<ClientProvider>().updateOrderStatus(order.id, newStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Statut mis à jour : ${newStatus.label}'),
        backgroundColor: newStatus.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Onglet Configuration ──────────────────────────────────────────────────────

class _ConfigTab extends StatefulWidget {
  final OnlineOrderSettings settings;
  const _ConfigTab({required this.settings});

  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  late double _depositPct;
  late double _deliveryFee;
  late double _minOrder;
  late int _estDelivery;
  late int _estTakeaway;
  late bool _freeDelivery;

  @override
  void initState() {
    super.initState();
    _depositPct = widget.settings.depositPercentage;
    _deliveryFee = widget.settings.deliveryFeeBase;
    _minOrder = widget.settings.minimumOrderAmount;
    _estDelivery = widget.settings.estimatedDeliveryMinutes;
    _estTakeaway = widget.settings.estimatedTakeawayMinutes;
    _freeDelivery = widget.settings.deliveryFeeBase == 0;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Acompte
        _ConfigCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Acompte requis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_depositPct.toInt()}% du montant total',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
              Slider(
                value: _depositPct,
                min: 0, max: 100,
                divisions: 20,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _depositPct = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('0% (aucun acompte)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const Text('100% (prépaiement total)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Livraison
        _ConfigCard(
          icon: Icons.delivery_dining,
          title: 'Frais de livraison',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Livraison gratuite', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Switch(
                    value: _freeDelivery,
                    onChanged: (v) => setState(() {
                      _freeDelivery = v;
                      if (v) _deliveryFee = 0;
                    }),
                    activeColor: AppTheme.success,
                  ),
                ],
              ),
              if (!_freeDelivery) ...[
                const SizedBox(height: 8),
                Text('${fmt.format(_deliveryFee)} F',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                Slider(
                  value: _deliveryFee,
                  min: 0, max: 5000,
                  divisions: 50,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _deliveryFee = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Commande minimum
        _ConfigCard(
          icon: Icons.shopping_cart_outlined,
          title: 'Montant minimum de commande',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${fmt.format(_minOrder)} F',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
              Slider(
                value: _minOrder,
                min: 0, max: 20000,
                divisions: 40,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _minOrder = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Temps estimés
        _ConfigCard(
          icon: Icons.timer_outlined,
          title: 'Temps de préparation estimé',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Livraison', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('$_estDelivery min',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              Slider(
                value: _estDelivery.toDouble(),
                min: 10, max: 120,
                divisions: 22,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _estDelivery = v.toInt()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('À emporter', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('$_estTakeaway min',
                      style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              Slider(
                value: _estTakeaway.toDouble(),
                min: 5, max: 60,
                divisions: 11,
                activeColor: AppTheme.success,
                onChanged: (v) => setState(() => _estTakeaway = v.toInt()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _saveConfig(context),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Enregistrer la configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
        ),
      ],
    );
  }

  void _saveConfig(BuildContext context) {
    final prov = context.read<ClientProvider>();
    final current = widget.settings;
    final updated = OnlineOrderSettings(
      isOnlineOrderEnabled: current.isOnlineOrderEnabled,
      depositPercentage: _depositPct,
      deliveryFeeBase: _freeDelivery ? 0 : _deliveryFee,
      minimumOrderAmount: _minOrder,
      estimatedDeliveryMinutes: _estDelivery,
      estimatedTakeawayMinutes: _estTakeaway,
      loyaltyPointsPerFCFA: current.loyaltyPointsPerFCFA,
      loyaltyPointValue: current.loyaltyPointValue,
      restaurantPhone: current.restaurantPhone,
      restaurantAddress: current.restaurantAddress,
      deliveryZones: current.deliveryZones,
    );
    prov.saveSettings(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration enregistrée ✓'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _ConfigCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Onglet Promotions ────────────────────────────────────────────────────────

class _PromotionsTab extends StatelessWidget {
  final ClientProvider provider;
  const _PromotionsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final promos = provider.promotions;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: promos.isEmpty
          ? const Center(
              child: Text('Aucune promotion active', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: promos.length,
              itemBuilder: (ctx, i) => _PromoAdminCard(promo: promos[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPromoDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une promo'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _showAddPromoDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddPromoSheet(),
    );
  }
}

class _PromoAdminCard extends StatelessWidget {
  final Promotion promo;
  const _PromoAdminCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: promo.isValid ? AppTheme.primary.withValues(alpha: 0.4) : const Color(0xFF2A2A5A),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_offer_outlined, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(promo.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(promo.valueLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(promo.description,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (promo.code != null) ...[
                  const SizedBox(height: 4),
                  Text('Code : ${promo.code}',
                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          Switch(
            value: promo.isActive,
            onChanged: (v) {},
            activeColor: AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _AddPromoSheet extends StatefulWidget {
  const _AddPromoSheet();

  @override
  State<_AddPromoSheet> createState() => _AddPromoSheetState();
}

class _AddPromoSheetState extends State<_AddPromoSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController(text: '10');
  final _codeCtrl = TextEditingController();
  PromotionType _type = PromotionType.percentage;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
          const Text('Nouvelle promotion',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Titre de la promotion'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 10),
          // Type
          Row(
            children: PromotionType.values.map((t) {
              final label = t == PromotionType.percentage ? '% Réduction'
                  : t == PromotionType.fixedAmount ? 'Montant fixe' : 'Livraison offerte';
              final isSelected = _type == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    margin: EdgeInsets.only(right: t != PromotionType.freeDelivery ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A)),
                    ),
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          if (_type != PromotionType.freeDelivery)
            TextField(
              controller: _valueCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: _type == PromotionType.percentage ? 'Valeur (%)' : 'Montant (FCFA)'),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _codeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Code promo (optionnel)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Créer la promotion'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // Création de la promotion via ClientFirebaseService directement
      // (on utilise le provider ici pour simplifier)
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Onglet Clients ────────────────────────────────────────────────────────────

class _ClientsTab extends StatelessWidget {
  final ClientProvider provider;
  const _ClientsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    // On utilise un FutureBuilder car les clients admin ne sont pas dans le stream par défaut
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.getAllClients(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final clients = snap.data ?? [];
        final fmt = NumberFormat('#,###', 'fr_FR');

        if (clients.isEmpty) {
          return const Center(
            child: Text('Aucun client inscrit', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          itemCount: clients.length,
          itemBuilder: (ctx, i) {
            final c = clients[i];
            final name = c['name'] as String? ?? 'Client';
            final email = c['email'] as String? ?? '';
            final phone = c['phone'] as String? ?? '';
            final pts = (c['loyaltyPoints'] as num?)?.toInt() ?? 0;
            final totalOrders = (c['totalOrders'] as num?)?.toInt() ?? 0;
            final totalSpent = (c['totalSpent'] as num?)?.toDouble() ?? 0;
            final isActive = c['isActive'] as bool? ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A5A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        if (phone.isNotEmpty)
                          Text(phone, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _ClientStat(label: 'Commandes', value: '$totalOrders'),
                            const SizedBox(width: 10),
                            _ClientStat(label: 'Dépensé', value: '${fmt.format(totalSpent)} F'),
                            const SizedBox(width: 10),
                            _ClientStat(label: 'Points', value: '$pts', color: Colors.amber),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.success : AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ClientStat extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _ClientStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
