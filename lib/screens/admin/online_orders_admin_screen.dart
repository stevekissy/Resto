import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/client_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/client_models.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PANNEAU ADMIN — Commandes en ligne (refonte complète)
// Accès : admin et manager uniquement
// Workflow : Reçue → Confirmée → En cuisine → En préparation → Prête →
//            Yango appelé → En livraison → Livrée → Payée/clôturée
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initProvider();
  }

  Future<void> _initProvider() async {
    final prov = context.read<ClientProvider>();
    if (!_settingsLoaded) {
      await prov.initSettingsOnly();
      if (mounted) setState(() => _settingsLoaded = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientProvider>();
    final settings = provider.settings;
    final pendingCount = provider.orders
        .where((o) => o.status == ClientOrderStatus.pending)
        .length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            const Text('Commandes en Ligne',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$pendingCount', style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ],
        ),
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        actions: [
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
      body: Column(
        children: [
          // ── Badge fix discret (temporaire) ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0xFF0D1B2A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.verified, size: 11, color: Color(0xFF4CAF50)),
                SizedBox(width: 4),
                Text(
                  'LIVE ORDER FIX : 3cd7cc7',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OrdersTab(provider: provider),
                _ConfigTab(settings: settings),
                _PromotionsTab(provider: provider),
                _ClientsTab(provider: provider),
              ],
            ),
          ),
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
          content: Text(enabled ? 'Commandes en ligne activées ✓' : 'Commandes en ligne désactivées'),
          backgroundColor: enabled ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET COMMANDES — avec recherche + filtres + cartes complètes
// ══════════════════════════════════════════════════════════════════════════════

class _OrdersTab extends StatefulWidget {
  final ClientProvider provider;
  const _OrdersTab({required this.provider});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  ClientOrderStatus? _filterStatus; // null = tous

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ClientOrder> get _filteredOrders {
    var orders = List<ClientOrder>.from(widget.provider.orders);
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Filtre par statut
    if (_filterStatus != null) {
      orders = orders.where((o) => o.status == _filterStatus).toList();
    }

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      orders = orders.where((o) {
        return (o.clientName.toLowerCase().contains(q)) ||
               (o.clientPhone.contains(q)) ||
               ((o.orderNumber ?? o.id).toLowerCase().contains(q)) ||
               (o.id.toLowerCase().contains(q));
      }).toList();
    }

    return orders;
  }

  // Compteurs par statut
  int _countByStatus(ClientOrderStatus s) =>
      widget.provider.orders.where((o) => o.status == s).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final total = widget.provider.orders.length;

    return Column(
      children: [
        // ── Stats rapides ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppTheme.surface,
          child: Row(
            children: [
              _QuickStat(label: 'Total', value: '$total', color: AppTheme.primary),
              const SizedBox(width: 8),
              _QuickStat(label: 'Reçues', value: '${_countByStatus(ClientOrderStatus.pending)}', color: AppTheme.warning),
              const SizedBox(width: 8),
              _QuickStat(label: 'Cuisine', value: '${_countByStatus(ClientOrderStatus.preparing)}', color: AppTheme.preparing),
              const SizedBox(width: 8),
              _QuickStat(label: 'Prêtes', value: '${_countByStatus(ClientOrderStatus.ready)}', color: AppTheme.success),
              const SizedBox(width: 8),
              _QuickStat(label: 'Livraison', value: '${_countByStatus(ClientOrderStatus.delivering)}', color: const Color(0xFFF57C00)),
            ],
          ),
        ),

        // ── Barre de recherche ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, téléphone ou numéro…',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppTheme.primary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A5A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.6)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),

        // ── Chips de filtres ───────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            children: [
              _FilterChip(
                label: 'Toutes',
                count: total,
                selected: _filterStatus == null,
                color: AppTheme.primary,
                onTap: () => setState(() => _filterStatus = null),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Reçues',
                count: _countByStatus(ClientOrderStatus.pending),
                selected: _filterStatus == ClientOrderStatus.pending,
                color: AppTheme.warning,
                onTap: () => setState(() => _filterStatus = ClientOrderStatus.pending),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Confirmées',
                count: _countByStatus(ClientOrderStatus.confirmed),
                selected: _filterStatus == ClientOrderStatus.confirmed,
                color: AppTheme.success,
                onTap: () => setState(() => _filterStatus = ClientOrderStatus.confirmed),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Cuisine',
                count: _countByStatus(ClientOrderStatus.preparing),
                selected: _filterStatus == ClientOrderStatus.preparing,
                color: const Color(0xFFFF6B00),
                onTap: () => setState(() => _filterStatus = ClientOrderStatus.preparing),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Prêtes',
                count: _countByStatus(ClientOrderStatus.ready),
                selected: _filterStatus == ClientOrderStatus.ready,
                color: const Color(0xFF4CAF50),
                onTap: () => setState(() => _filterStatus = ClientOrderStatus.ready),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Livraison',
                count: _countByStatus(ClientOrderStatus.delivering),
                selected: _filterStatus == ClientOrderStatus.delivering,
                color: const Color(0xFFF57C00),
                onTap: () => setState(() => _filterStatus = ClientOrderStatus.delivering),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Livrées',
                count: _countByStatus(ClientOrderStatus.delivered),
                selected: _filterStatus == ClientOrderStatus.delivered,
                color: AppTheme.success,
                onTap: () => setState(() => _filterStatus = ClientOrderStatus.delivered),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Annulées',
                count: _countByStatus(ClientOrderStatus.cancelled),
                selected: _filterStatus == ClientOrderStatus.cancelled,
                color: AppTheme.error,
                onTap: () => setState(() => _filterStatus = ClientOrderStatus.cancelled),
              ),
            ],
          ),
        ),

        // ── Liste des commandes ────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, color: AppTheme.textSecondary, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _filterStatus != null
                            ? 'Aucune commande trouvée'
                            : 'Aucune commande en ligne',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 30),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _AdminOrderCard(order: filtered[i]),
                ),
        ),
      ],
    );
  }
}

// ── Widget stats rapides ──────────────────────────────────────────────────
class _QuickStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _QuickStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Chip filtre ──────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.count, required this.selected,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : const Color(0xFF2A2A5A), width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(
              color: selected ? color : AppTheme.textSecondary,
              fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            )),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.3) : AppTheme.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count', style: TextStyle(
                  color: selected ? color : AppTheme.textSecondary,
                  fontSize: 10, fontWeight: FontWeight.w700,
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARTE COMMANDE ADMIN — complète avec toutes les actions
// ══════════════════════════════════════════════════════════════════════════════

class _AdminOrderCard extends StatefulWidget {
  final ClientOrder order;
  const _AdminOrderCard({required this.order});

  @override
  State<_AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends State<_AdminOrderCard> {
  bool _expanded = false;
  bool _processing = false;

  final _fmt = NumberFormat('#,###', 'fr_FR');
  final _fmtDate = DateFormat('dd/MM HH:mm', 'fr_FR');

  // ── Workflow des statuts ─────────────────────────────────────────────
  List<ClientOrderStatus> _nextStatuses(ClientOrderStatus current) {
    switch (current) {
      case ClientOrderStatus.pending:
        return [ClientOrderStatus.confirmed, ClientOrderStatus.cancelled];
      case ClientOrderStatus.confirmed:
        return [ClientOrderStatus.preparing, ClientOrderStatus.cancelled];
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

  String _statusActionLabel(ClientOrderStatus s) {
    switch (s) {
      case ClientOrderStatus.confirmed:   return 'Confirmer';
      case ClientOrderStatus.preparing:   return 'Envoyer en cuisine';
      case ClientOrderStatus.ready:       return 'Marquer Prête';
      case ClientOrderStatus.delivering:  return 'En livraison';
      case ClientOrderStatus.delivered:   return 'Marquer Livrée';
      case ClientOrderStatus.cancelled:   return 'Annuler';
      default:                            return s.label;
    }
  }

  IconData _statusActionIcon(ClientOrderStatus s) {
    switch (s) {
      case ClientOrderStatus.confirmed:   return Icons.check_circle_outline;
      case ClientOrderStatus.preparing:   return Icons.restaurant;
      case ClientOrderStatus.ready:       return Icons.done_all;
      case ClientOrderStatus.delivering:  return Icons.delivery_dining;
      case ClientOrderStatus.delivered:   return Icons.where_to_vote;
      case ClientOrderStatus.cancelled:   return Icons.cancel_outlined;
      default:                            return Icons.arrow_forward;
    }
  }

  // ── Label mode de paiement ────────────────────────────────────────────
  String _paymentMethodLabel(ClientPaymentMethod method) {
    switch (method) {
      case ClientPaymentMethod.cashOnDelivery: return 'Espèces à la livraison';
      case ClientPaymentMethod.orangeMoney:    return 'Orange Money';
      case ClientPaymentMethod.mtnMoney:       return 'MTN Money';
      case ClientPaymentMethod.moovMoney:      return 'Moov Money';
      case ClientPaymentMethod.wave:           return 'Wave';
      case ClientPaymentMethod.card:           return 'Carte bancaire';
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────

  /// SOURCE UNIQUE : envoie la commande en cuisine via update direct du doc 'orders'.
  /// widget.order.id = id du doc orders (depuis streamAdminOnlineOrders, data['id'] = d.id)
  Future<void> _sendToKitchen() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      // SOURCE UNIQUE : widget.order.id = id du doc orders directement
      final orderId = widget.order.id;
      debugPrint('[_sendToKitchen] orderId=$orderId');
      await context.read<AppProvider>().sendOnlineOrderToKitchen(orderId);

      // Notification locale
      NotificationService().trigger(
        NotifEvent.nouvelleCommande,
        message: 'Commande #${widget.order.orderNumber} envoyée en cuisine',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.restaurant, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Commande envoyée en cuisine !'),
          ]),
          backgroundColor: const Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur envoi cuisine : $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _updateStatus(ClientOrderStatus newStatus) async {
    if (_processing) return;

    // ── Cas spécial : "Envoyer en cuisine" → méthode dédiée ──────────
    if (newStatus == ClientOrderStatus.preparing) {
      await _sendToKitchen();
      return;
    }
    
    // Confirmation pour annulation
    if (newStatus == ClientOrderStatus.cancelled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.warning_amber, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Annuler la commande ?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: Text(
            'La commande #${widget.order.orderNumber ?? widget.order.id.substring(0, 8)} de ${widget.order.clientName} sera annulée.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Annuler la commande'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _processing = true);
    try {
      await context.read<ClientProvider>().updateOrderStatus(widget.order.id, newStatus);
      
      // Notifier selon le statut
      final notifSvc = NotificationService();
      if (newStatus == ClientOrderStatus.confirmed) {
        notifSvc.trigger(NotifEvent.nouvelleCommande,
            message: 'Commande #${widget.order.orderNumber} confirmée');
      } else if (newStatus == ClientOrderStatus.ready) {
        notifSvc.trigger(NotifEvent.commandePrete,
            message: 'Commande #${widget.order.orderNumber} prête — appeler Yango');
      } else if (newStatus == ClientOrderStatus.delivered) {
        notifSvc.trigger(NotifEvent.paiementEnregistre,
            message: 'Commande #${widget.order.orderNumber} livrée — encaissement');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ Statut mis à jour : ${newStatus.label}'),
          backgroundColor: newStatus.color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _updateYangoStatus(YangoDeliveryStatus yangoStatus) async {
    await context.read<ClientProvider>().updateYangoStatus(widget.order.id, yangoStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Yango : ${yangoStatus.label}'),
        backgroundColor: yangoStatus.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _callClient() async {
    final phone = widget.order.clientPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(widget.order.clientPhone, 'Téléphone copié');
    }
  }

  void _copyToClipboard(String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📋 $msg'),
      backgroundColor: AppTheme.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openGps() async {
    final geo = widget.order.geoLocation;
    final addr = widget.order.deliveryAddress?.address ?? '';
    if (geo != null && geo.isNotEmpty && geo.contains(',')) {
      final parts = geo.split(',');
      final lat = parts[0].trim();
      final lng = parts[1].trim();
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (addr.isNotEmpty) {
      final encoded = Uri.encodeComponent(addr);
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _encaisserSolde() async {
    final order = widget.order;
    final remaining = order.remainingAmount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Commande déjà soldée'), backgroundColor: AppTheme.success));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.account_balance_wallet, color: AppTheme.success),
          SizedBox(width: 8),
          Text('Encaisser le solde', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client : ${order.clientName}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (order.depositPaid && order.depositAmount > 0) ...[
              _EncaissRow('Acompte payé', '${_fmt.format(order.depositAmount)} F', AppTheme.success),
              const SizedBox(height: 4),
            ],
            _EncaissRow(
              'Solde à encaisser',
              '${_fmt.format(remaining)} F',
              AppTheme.warning,
              bold: true,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Après encaissement : statut Payé / Clôturé\nPoints fidélité attribués automatiquement.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Encaisser'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _processing = true);
    try {
      // Marquer payée + livrée (déclenche attribution points fidélité)
      await context.read<ClientProvider>().updateOrderStatus(
          widget.order.id, ClientOrderStatus.delivered);
      
      // Notifier caisse
      NotificationService().trigger(NotifEvent.paiementEnregistre,
          message: 'Solde encaissé : commande #${order.orderNumber} — ${_fmt.format(remaining)} F');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ Solde encaissé — ${_fmt.format(remaining)} F'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order.status;
    final nextStatuses = _nextStatuses(status);
    final isDelivery = order.orderType == OrderType.delivery;
    final isClosed = status == ClientOrderStatus.delivered ||
                     status == ClientOrderStatus.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == ClientOrderStatus.pending
              ? AppTheme.warning.withValues(alpha: 0.7)
              : status.color.withValues(alpha: 0.35),
          width: status == ClientOrderStatus.pending ? 1.5 : 1,
        ),
        boxShadow: status == ClientOrderStatus.pending
            ? [BoxShadow(color: AppTheme.warning.withValues(alpha: 0.15), blurRadius: 12)]
            : null,
      ),
      child: Column(
        children: [
          // ── En-tête cliquable ────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icône statut
                      Container(
                        width: 38, height: 38,
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
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(order.orderNumber ?? order.id.substring(0, 8),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                // Badge EN LIGNE
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                                  ),
                                  child: const Text('📱 EN LIGNE',
                                      style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                                // Badge type (livraison / emporter)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDelivery
                                        ? const Color(0xFFF57C00).withValues(alpha: 0.15)
                                        : AppTheme.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    isDelivery ? '🚗 Livraison' : '🏃 Emporter',
                                    style: TextStyle(
                                      color: isDelivery ? const Color(0xFFF57C00) : AppTheme.success,
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                // Badge statut
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: status.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(status.label,
                                      style: TextStyle(color: status.color, fontSize: 9, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 11, color: AppTheme.textSecondary),
                                const SizedBox(width: 3),
                                Text(order.clientName,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                const Icon(Icons.phone_outlined, size: 11, color: AppTheme.textSecondary),
                                const SizedBox(width: 3),
                                Text(order.clientPhone,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_fmt.format(order.totalAmount)} F',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(_fmtDate.format(order.createdAt),
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                          Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                              color: AppTheme.textSecondary, size: 16),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Résumé articles
                  Text(
                    order.items.map((i) => '${i.quantity}× ${i.productName}').join(' • '),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    maxLines: _expanded ? null : 1,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // ── Détails expandés ─────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFF2A2A5A)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Articles détaillés ──────────────────────────────
                  const _SectionTitle(icon: Icons.restaurant_menu, label: 'Articles'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text('${item.quantity}',
                                      style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w900)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    if (item.comment != null && item.comment!.isNotEmpty)
                                      Text('💬 ${item.comment}',
                                          style: const TextStyle(color: Colors.amber, fontSize: 10)),
                                  ],
                                ),
                              ),
                              Text('${_fmt.format(item.totalPrice)} F',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        )),
                        const Divider(height: 10, color: Color(0xFF2A2A5A)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total commande', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            Text('${_fmt.format(order.totalAmount)} F',
                                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Financier : Acompte + Solde ─────────────────────
                  const _SectionTitle(icon: Icons.account_balance_wallet_outlined, label: 'Paiement'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _FinRow(
                          label: 'Acompte exigé',
                          value: order.depositRequired
                              ? '${_fmt.format(order.depositAmount)} F'
                              : 'Non requis',
                          color: order.depositRequired ? AppTheme.warning : AppTheme.textSecondary,
                        ),
                        if (order.depositRequired) ...[
                          const SizedBox(height: 4),
                          _FinRow(
                            label: 'Acompte reçu',
                            value: order.depositPaid
                                ? '${_fmt.format(order.depositAmount)} F ✓'
                                : 'En attente ⏳',
                            color: order.depositPaid ? AppTheme.success : AppTheme.error,
                          ),
                          const SizedBox(height: 4),
                          _FinRow(
                            label: 'Solde restant',
                            value: '${_fmt.format(order.remainingAmount)} F',
                            color: order.remainingAmount > 0 ? AppTheme.warning : AppTheme.success,
                            bold: true,
                          ),
                        ],
                        if (order.loyaltyPointsUsed > 0) ...[
                          const SizedBox(height: 4),
                          _FinRow(
                            label: 'Points utilisés',
                            value: '${order.loyaltyPointsUsed} pts → -${_fmt.format(order.loyaltyDiscountAmount)} F',
                            color: Colors.amber,
                          ),
                        ],
                        const SizedBox(height: 4),
                        _FinRow(
                          label: 'Mode de paiement',
                          value: _paymentMethodLabel(order.paymentMethod),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Livraison Yango ─────────────────────────────────
                  if (isDelivery) ...[
                    const _SectionTitle(icon: Icons.delivery_dining, label: 'Livraison Yango'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF57C00).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Adresse
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFFF57C00), size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  order.deliveryAddress?.address ?? 'Adresse non renseignée',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          if (order.geoLocation != null && order.geoLocation!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.gps_fixed, color: AppTheme.success, size: 12),
                                const SizedBox(width: 4),
                                Text('GPS : ${order.geoLocation}',
                                    style: const TextStyle(color: AppTheme.success, fontSize: 10)),
                              ],
                            ),
                          ],
                          if (order.deliveryNote != null && order.deliveryNote!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('📝 ${order.deliveryNote}',
                                style: const TextStyle(color: Colors.amber, fontSize: 11, fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 8),
                          // Info Yango frais
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF57C00).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Text('🚗', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Partenaire : Yango • Frais à payer directement au livreur',
                                    style: TextStyle(color: Color(0xFFF57C00), fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Statut Yango actuel
                          Row(
                            children: [
                              const Text('Statut Yango : ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: order.yangoStatus.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(order.yangoStatus.icon, color: order.yangoStatus.color, size: 12),
                                    const SizedBox(width: 4),
                                    Text(order.yangoStatus.label,
                                        style: TextStyle(color: order.yangoStatus.color, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Boutons mise à jour Yango
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: YangoDeliveryStatus.values.map((ys) {
                              final isActive = order.yangoStatus == ys;
                              return GestureDetector(
                                onTap: () => _updateYangoStatus(ys),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isActive ? ys.color.withValues(alpha: 0.22) : AppTheme.cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isActive ? ys.color : const Color(0xFF2A2A5A), width: isActive ? 1.5 : 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(ys.icon, color: isActive ? ys.color : AppTheme.textSecondary, size: 12),
                                      const SizedBox(width: 4),
                                      Text(ys.label, style: TextStyle(
                                        color: isActive ? ys.color : AppTheme.textSecondary,
                                        fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                      )),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Notes client ────────────────────────────────────
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    const _SectionTitle(icon: Icons.note_outlined, label: 'Instructions client'),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Text('💬 ${order.notes!}',
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Timestamps ──────────────────────────────────────
                  const _SectionTitle(icon: Icons.schedule, label: 'Historique'),
                  const SizedBox(height: 6),
                  _TimestampRow('Reçue', order.createdAt),
                  if (order.confirmedAt != null) _TimestampRow('Confirmée', order.confirmedAt!),
                  if (order.sentToKitchenAt != null) _TimestampRow('Envoyée en cuisine', order.sentToKitchenAt!),
                  if (order.readyAt != null) _TimestampRow('Prête', order.readyAt!),
                  if (order.deliveredAt != null) _TimestampRow('Livrée', order.deliveredAt!),
                  if (order.settledAt != null) _TimestampRow('Soldée', order.settledAt!),

                  // ── Actions utilitaires ─────────────────────────────
                  const SizedBox(height: 12),
                  const _SectionTitle(icon: Icons.touch_app, label: 'Actions'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Appeler client
                      _ActionBtn(
                        icon: Icons.call,
                        label: 'Appeler',
                        color: AppTheme.success,
                        onTap: _callClient,
                      ),
                      // Copier téléphone
                      _ActionBtn(
                        icon: Icons.copy,
                        label: 'Copier tél.',
                        color: AppTheme.primary,
                        onTap: () => _copyToClipboard(order.clientPhone, 'Téléphone copié : ${order.clientPhone}'),
                      ),
                      // Copier adresse
                      if (isDelivery && (order.deliveryAddress?.address ?? '').isNotEmpty)
                        _ActionBtn(
                          icon: Icons.content_copy,
                          label: 'Copier adresse',
                          color: AppTheme.primary,
                          onTap: () => _copyToClipboard(
                              order.deliveryAddress!.address, 'Adresse copiée'),
                        ),
                      // Ouvrir GPS
                      if (isDelivery)
                        _ActionBtn(
                          icon: Icons.map,
                          label: 'Ouvrir GPS',
                          color: const Color(0xFFF57C00),
                          onTap: _openGps,
                        ),
                      // Encaisser solde
                      if (!isClosed && order.remainingAmount > 0 &&
                          (order.status == ClientOrderStatus.delivering || order.status == ClientOrderStatus.delivered))
                        _ActionBtn(
                          icon: Icons.attach_money,
                          label: 'Encaisser solde',
                          color: Colors.amber,
                          onTap: _encaisserSolde,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A5A)),
          ],

          // ── Boutons workflow de statut ────────────────────────────────
          if (!isClosed && nextStatuses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _processing
                  ? const Center(child: SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: nextStatuses.map((s) {
                        final isCancel = s == ClientOrderStatus.cancelled;
                        return GestureDetector(
                          onTap: () => _updateStatus(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: isCancel ? 0.08 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: s.color.withValues(alpha: isCancel ? 0.3 : 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusActionIcon(s), color: s.color, size: 14),
                                const SizedBox(width: 5),
                                Text(_statusActionLabel(s),
                                    style: TextStyle(color: s.color, fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            )
          else if (isClosed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Icon(status == ClientOrderStatus.delivered ? Icons.check_circle : Icons.cancel,
                      color: status.color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    status == ClientOrderStatus.delivered ? '✓ Commande clôturée' : '✗ Commande annulée',
                    style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Widgets helpers de la carte ──────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 13),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ],
    );
  }
}

class _FinRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _FinRow({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
}

class _EncaissRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _EncaissRow(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
}

class _TimestampRow extends StatelessWidget {
  final String label;
  final DateTime dt;
  const _TimestampRow(this.label, this.dt);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 5, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('$label : ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          Text(fmt.format(dt), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 14),
          const SizedBox(width: 6),
          Text('$label : ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Expanded(
            child: Text(value, style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12, fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET CONFIGURATION — inchangé
// ══════════════════════════════════════════════════════════════════════════════

class _ConfigTab extends StatefulWidget {
  final OnlineOrderSettings settings;
  const _ConfigTab({required this.settings});

  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  late bool _depositRequired;
  late DepositType _depositType;
  late double _depositPct;
  late double _depositFixed;
  late double _minOrder;
  late int _estDelivery;
  late int _estTakeaway;
  late int _loyaltyPointValue;
  late int _loyaltyPointsPerFCFA;
  late int _minLoyaltyPoints;
  final _depositFixedCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _depositRequired      = widget.settings.depositRequired;
    _depositType          = widget.settings.depositType;
    _depositPct           = widget.settings.depositPercentage;
    _depositFixed         = widget.settings.depositFixedAmount ?? 5000;
    _minOrder             = widget.settings.minimumOrderAmount;
    _estDelivery          = widget.settings.estimatedDeliveryMinutes;
    _estTakeaway          = widget.settings.estimatedTakeawayMinutes;
    _loyaltyPointValue    = widget.settings.loyaltyPointValue;
    _loyaltyPointsPerFCFA = widget.settings.loyaltyPointsPerFCFA;
    _minLoyaltyPoints     = widget.settings.minLoyaltyPointsToUse;
    _depositFixedCtrl.text = _depositFixed.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _depositFixedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── Acompte ──────────────────────────────────────────────────
        _ConfigCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Acompte avant commande',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Acompte obligatoire', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Switch(
                    value: _depositRequired,
                    onChanged: (v) => setState(() => _depositRequired = v),
                    activeColor: AppTheme.warning,
                  ),
                ],
              ),
              if (_depositRequired) ...[
                const SizedBox(height: 12),
                const Text('Type d\'acompte :', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: DepositType.values.map((t) {
                    final isSelected = _depositType == t;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _depositType = t),
                        child: Container(
                          margin: EdgeInsets.only(right: t == DepositType.percentage ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.warning.withValues(alpha: 0.2) : AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.warning : const Color(0xFF2A2A5A),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                t == DepositType.percentage ? Icons.percent : Icons.attach_money,
                                color: isSelected ? AppTheme.warning : AppTheme.textSecondary, size: 18,
                              ),
                              const SizedBox(height: 4),
                              Text(t.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.warning : AppTheme.textSecondary,
                                    fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                if (_depositType == DepositType.percentage) ...[
                  Text('${_depositPct.toInt()}% du montant total',
                      style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 16)),
                  Slider(
                    value: _depositPct,
                    min: 5, max: 100, divisions: 19,
                    activeColor: AppTheme.warning,
                    onChanged: (v) => setState(() => _depositPct = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('5%', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      const Text('100% (prépaiement)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ] else ...[
                  TextField(
                    controller: _depositFixedCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _depositFixed = double.tryParse(v) ?? _depositFixed,
                    decoration: const InputDecoration(
                      labelText: 'Montant fixe (FCFA)',
                      prefixText: 'FCFA ',
                      prefixStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Livraison Yango ───────────────────────────────────────────
        _ConfigCard(
          icon: Icons.delivery_dining,
          title: 'Livraison — Partenaire Yango',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF57C00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🚗', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('Livraison gérée par Yango',
                        style: TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Les frais de livraison sont définis par Yango\n'
                  '• Le client paie directement le livreur\n'
                  '• Le restaurant encaisse uniquement la commande + acompte',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Programme fidélité ─────────────────────────────────────────
        _ConfigCard(
          icon: Icons.stars_rounded,
          title: 'Programme fidélité',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Valeur d\'1 point', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('$_loyaltyPointValue FCFA',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              Slider(
                value: _loyaltyPointValue.toDouble(),
                min: 1, max: 50, divisions: 49,
                activeColor: Colors.amber,
                onChanged: (v) => setState(() => _loyaltyPointValue = v.toInt()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Points gagnés / 100 FCFA', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('${(100 / _loyaltyPointsPerFCFA).toStringAsFixed(1)} pt',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              Slider(
                value: _loyaltyPointsPerFCFA.toDouble(),
                min: 10, max: 1000, divisions: 99,
                activeColor: Colors.amber,
                onChanged: (v) => setState(() => _loyaltyPointsPerFCFA = v.toInt()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Minimum points utilisables', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('$_minLoyaltyPoints pts',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              Slider(
                value: _minLoyaltyPoints.toDouble(),
                min: 1, max: 100, divisions: 99,
                activeColor: Colors.amber,
                onChanged: (v) => setState(() => _minLoyaltyPoints = v.toInt()),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '1 pt = $_loyaltyPointValue FCFA • ${(100 / _loyaltyPointsPerFCFA).toStringAsFixed(1)} pt / 100 FCFA',
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Commande minimum ──────────────────────────────────────────
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
                min: 0, max: 20000, divisions: 40,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _minOrder = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Temps estimés ─────────────────────────────────────────────
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
                min: 10, max: 120, divisions: 22,
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
                min: 5, max: 60, divisions: 11,
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
      depositRequired: _depositRequired,
      depositType: _depositType,
      depositPercentage: _depositPct,
      depositFixedAmount: _depositType == DepositType.fixedAmount ? _depositFixed : null,
      deliveryFeeBase: 0,
      minimumOrderAmount: _minOrder,
      estimatedDeliveryMinutes: _estDelivery,
      estimatedTakeawayMinutes: _estTakeaway,
      loyaltyPointsPerFCFA: _loyaltyPointsPerFCFA,
      loyaltyPointValue: _loyaltyPointValue,
      minLoyaltyPointsToUse: _minLoyaltyPoints,
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

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET PROMOTIONS — inchangé
// ══════════════════════════════════════════════════════════════════════════════

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
                Text(promo.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (promo.code != null) ...[
                  const SizedBox(height: 4),
                  Text('Code : ${promo.code}',
                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          Switch(value: promo.isActive, onChanged: (v) {}, activeColor: AppTheme.success),
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
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET CLIENTS — inchangé
// ══════════════════════════════════════════════════════════════════════════════

class _ClientsTab extends StatelessWidget {
  final ClientProvider provider;
  const _ClientsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
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
