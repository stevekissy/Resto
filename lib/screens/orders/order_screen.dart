import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/product_image_widget.dart';
import '../../models/models.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Nouvelle Commande', icon: Icon(Icons.add_circle_outline, size: 18)),
                Tab(text: 'Suivi Commandes', icon: Icon(Icons.list_alt, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                NewOrderTab(),
                OrdersListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================== NEW ORDER TAB ===================
class NewOrderTab extends StatefulWidget {
  const NewOrderTab({super.key});

  @override
  State<NewOrderTab> createState() => _NewOrderTabState();
}

class _NewOrderTabState extends State<NewOrderTab> {
  final _tableController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  final List<OrderItem> _cartItems = [];
  bool _isUrgent = false;
  bool _isTakeaway = false;
  String _selectedCategory = 'Tous';
  String _searchQuery = '';
  AppUser? _selectedServer;

  @override
  void dispose() {
    _tableController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _getServers(AppProvider provider) {
    return provider.users
        .where((u) => u.role == UserRole.server && u.isActive)
        .toList();
  }

  double get _cartTotal => _cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  int get _cartCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(Product product, {int qty = 1}) {
    setState(() {
      final existing = _cartItems.firstWhere(
        (i) => i.productId == product.id && !i.isCambuse,
        orElse: () => OrderItem(productId: '', productName: '', quantity: 0, unitPrice: 0),
      );
      if (existing.productId.isNotEmpty) {
        existing.quantity += qty;
      } else {
        _cartItems.add(OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: qty,
          unitPrice: product.price,
          category: product.category,
          itemType: 'menu',     // plat cuisine
        ));
      }
    });
  }

  /// Ajouter une boisson Cambuse au panier
  void _addCambuseToCart(CambuseItem item, {int qty = 1}) {
    setState(() {
      final existing = _cartItems.firstWhere(
        (i) => i.isCambuse && i.cambuseItemId == item.id,
        orElse: () => OrderItem(productId: '', productName: '', quantity: 0, unitPrice: 0),
      );
      if (existing.productId.isNotEmpty || existing.cambuseItemId != null) {
        existing.quantity += qty;
      } else {
        _cartItems.add(OrderItem(
          productId:     'cambuse_${item.id}', // ID unique pour éviter collision
          productName:   item.name,
          quantity:      qty,
          unitPrice:     item.sellingPrice,
          isCambuse:     true,
          cambuseItemId: item.id,
          category:      item.category,
          itemType:      'cambuse',   // boisson — ne passe PAS en cuisine
        ));
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cartItems.removeWhere((i) => i.productId == productId);
    });
  }

  void _updateQty(String productId, int delta) {
    setState(() {
      final item = _cartItems.firstWhere((i) => i.productId == productId);
      item.quantity += delta;
      if (item.quantity <= 0) _cartItems.removeWhere((i) => i.productId == productId);
    });
  }

  void _setQtyDirect(String productId, int newQty) {
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.productId == productId);
      if (idx == -1) return;
      if (newQty <= 0) {
        _cartItems.removeAt(idx);
      } else {
        _cartItems[idx].quantity = newQty;
      }
    });
  }

  Future<void> _submitOrder() async {
    if (!_isTakeaway && _tableController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un numéro de table'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un article'), backgroundColor: AppTheme.error),
      );
      return;
    }

    final provider = context.read<AppProvider>();

    final insufficient = await provider.checkStockForItems(_cartItems);
    if (!mounted) return;

    if (insufficient.isNotEmpty) {
      final confirmed = await _showStockWarningDialog(insufficient);
      if (!mounted) return;
      if (!confirmed) return;
    }

    final order = await provider.createOrder(
      tableNumber: _isTakeaway ? '' : _tableController.text,
      items: List.from(_cartItems),
      specialInstructions: _notesController.text.isEmpty ? null : _notesController.text,
      isUrgent: _isUrgent,
      serverId: _selectedServer?.id,
      serverName: _selectedServer?.name,
      serverEmail: _selectedServer?.email,
      orderType: _isTakeaway ? 'takeaway' : 'dine_in',
    );

    if (!mounted) return;
    // Fermer le bottom sheet panier s'il est ouvert
    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name != '/cart');
    setState(() {
      _cartItems.clear();
      _tableController.clear();
      _notesController.clear();
      _isUrgent = false;
      _isTakeaway = false;
      _selectedServer = null;
    });

    // Message adapté : boissons seules → directement en caisse, plats → envoi cuisine
    final hasKitchen = order.items.any((i) => i.isKitchenItem);
    final hasCambuse = order.items.any((i) => i.isCambuse);
    final String snackMsg;
    if (!hasKitchen && hasCambuse) {
      snackMsg = 'Commande #${order.orderNumber} — Boissons en caisse directement !';
    } else if (hasKitchen && hasCambuse) {
      snackMsg = 'Commande #${order.orderNumber} — Plats en cuisine, boissons en caisse !';
    } else {
      snackMsg = 'Commande #${order.orderNumber} envoyée en cuisine !';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackMsg),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Dialogue stock insuffisant.
  Future<bool> _showStockWarningDialog(List<String> items) async {
    final provider = context.read<AppProvider>();
    final role = provider.currentUser?.role;
    final canOverride =
        role == UserRole.admin || role == UserRole.manager;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warning, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Stock insuffisant',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Les produits suivants ont un stock insuffisant :',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...items.map(
                  (name) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_circle_outline,
                            color: AppTheme.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canOverride) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.warning.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'En tant qu\'admin/manager, vous pouvez forcer la commande.',
                      style: TextStyle(
                          color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Contactez un admin ou un manager pour valider.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              if (canOverride)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.warning_amber_rounded,
                      size: 16),
                  label: const Text('Forcer la commande'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.black),
                ),
            ],
          ),
        ) ??
        false;
  }

  /// Tri alphabétique+numérique (natural sort)
  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+|\D+)');
    final partsA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
    final partsB = regExp.allMatches(b).map((m) => m.group(0)!).toList();
    for (int i = 0; i < min(partsA.length, partsB.length); i++) {
      final numA = int.tryParse(partsA[i]);
      final numB = int.tryParse(partsB[i]);
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else {
        final cmp = partsA[i].toLowerCase().compareTo(partsB[i].toLowerCase());
        if (cmp != 0) return cmp;
      }
    }
    return partsA.length.compareTo(partsB.length);
  }

  /// Ouvre le panier en bottom sheet plein écran
  void _openCart() {
    final provider = context.read<AppProvider>();
    final servers = _getServers(provider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _CartBottomSheet(
          cartItems: _cartItems,
          cartTotal: _cartTotal,
          isTakeaway: _isTakeaway,
          isUrgent: _isUrgent,
          tableController: _tableController,
          notesController: _notesController,
          selectedServer: _selectedServer,
          servers: servers,
          onTakeawayChanged: (v) {
            setState(() { _isTakeaway = v; if (v) _tableController.clear(); });
            setSheetState(() {});
          },
          onUrgentChanged: (v) {
            setState(() => _isUrgent = v);
            setSheetState(() {});
          },
          onServerChanged: (v) {
            setState(() => _selectedServer = v);
            setSheetState(() {});
          },
          onRemove: (id) {
            _removeFromCart(id);
            setSheetState(() {});
            if (_cartItems.isEmpty) Navigator.pop(ctx);
          },
          onDecrease: (id) {
            _updateQty(id, -1);
            setSheetState(() {});
            if (_cartItems.isEmpty) Navigator.pop(ctx);
          },
          onIncrease: (id) {
            _updateQty(id, 1);
            setSheetState(() {});
          },
          onSetQty: (id, v) {
            _setQtyDirect(id, v);
            setSheetState(() {});
            if (_cartItems.isEmpty) Navigator.pop(ctx);
          },
          onSubmit: () { Navigator.pop(ctx); _submitOrder(); },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // ── Catégories plats (issues des produits disponibles) ──────────
    final rawPlatCats = provider.availableProducts.map((p) => p.category).toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    // ── Catégories Cambuse : union de (catégories paramétrées + catégories utilisées) ──
    // Prendre les catégories paramétrées en priorité, compléter avec celles des items
    final paramCambuseCatNames = provider.cambuseCategories.map((c) => c.name).toSet();
    final usedCambuseCatNames  = provider.cambuseItems.map((i) => i.category).toSet();
    final allCambuseCatNames   = {...paramCambuseCatNames, ...usedCambuseCatNames}.toList()..sort();

    // Détermine si la catégorie sélectionnée est une catégorie Cambuse
    final isCambuseCatSelected = allCambuseCatNames.contains(_selectedCategory);

    // Filtrage plats : masqués si catégorie Cambuse sélectionnée
    final q = _searchQuery.toLowerCase();
    final filteredProducts = isCambuseCatSelected
        ? <Product>[]    // catégorie cambuse → aucun plat affiché
        : provider.availableProducts.where((p) {
            final catMatch = _selectedCategory == 'Tous' || p.category == _selectedCategory;
            if (!catMatch) return false;
            if (q.isEmpty) return true;
            return p.name.toLowerCase().contains(q) ||
                   p.category.toLowerCase().contains(q) ||
                   p.price.toStringAsFixed(0).contains(q);
          }).toList()
            ..sort((a, b) => _naturalCompare(a.name, b.name));

    // Boissons Cambuse disponibles (qty > 0), filtrées par recherche + catégorie
    final cambuseItems = provider.cambuseItems.where((item) {
      if (item.isOutOfStock) return false;
      // Filtre catégorie : si une catégorie Cambuse est sélectionnée, n'afficher que celle-ci
      if (isCambuseCatSelected && item.category != _selectedCategory) return false;
      // Si une catégorie PLAT est sélectionnée (pas Cambuse, pas Tous) → masquer les boissons
      if (!isCambuseCatSelected && _selectedCategory != 'Tous') return false;
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
             item.category.toLowerCase().contains(q) ||
             item.sellingPrice.toStringAsFixed(0).contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Catégories cambuse présentes dans la liste filtrée (pour le regroupement)
    final cambuseCats = cambuseItems.map((i) => i.category).toSet().toList()..sort();

    return Stack(
      children: [
        // ── CORPS PRINCIPAL ─────────────────────────────────────────
        Column(
          children: [
            // ── ZONE 1 : Recherche ──────────────────────────────────
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, catégorie, prix...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // ── ZONE 2 : Catégories scrollables (Plats + Boissons) ─
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // ── Puce "Tous" ───────────────────────────────────
                    _CategoryChip(
                      label: 'Tous',
                      selected: _selectedCategory == 'Tous',
                      isCambuse: false,
                      onTap: () => setState(() => _selectedCategory = 'Tous'),
                    ),
                    // ── Catégories Plats ──────────────────────────────
                    ...rawPlatCats.map((cat) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CategoryChip(
                        label: cat,
                        selected: _selectedCategory == cat,
                        isCambuse: false,
                        onTap: () => setState(() => _selectedCategory = cat),
                      ),
                    )),
                    // ── Séparateur vertical entre Plats et Boissons ───
                    if (allCambuseCatNames.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: Container(
                            width: 1,
                            height: 22,
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    // ── Catégories Cambuse / Boissons ─────────────────
                    ...allCambuseCatNames.where((cat) =>
                      // N'afficher que les catégories qui ont au moins 1 item actif
                      provider.cambuseItems.any((i) => i.category == cat && !i.isOutOfStock)
                    ).map((cat) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CategoryChip(
                        label: cat,
                        selected: _selectedCategory == cat,
                        isCambuse: true,
                        onTap: () => setState(() => _selectedCategory = cat),
                      ),
                    )),
                  ],
                ),
              ),
            ),

            // Séparateur
            const Divider(height: 1, color: Color(0xFF2A2A5A)),

            // ── ZONE 3 : Liste des plats + boissons ─────────────────
            Expanded(
              child: (filteredProducts.isEmpty && cambuseItems.isEmpty)
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'Aucun article trouvé',
                      subtitle: 'Modifiez votre recherche ou la catégorie',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                      children: [
                        // ── Plats du menu ─────────────────────────────
                        if (filteredProducts.isNotEmpty) ...[
                          ...filteredProducts.map((p) => _ProductCard(
                            key: ValueKey('plat_${p.id}'),
                            product: p,
                            cartItems: _cartItems,
                            stockItems: provider.stockItems,
                            onAdd: (qty) => _addToCart(p, qty: qty),
                          )),
                        ],
                        // ── Section Boissons Cambuse ──────────────────
                        if (cambuseItems.isNotEmpty) ...[
                          // En-tête "Boissons" uniquement si des plats sont aussi affichés
                          if (filteredProducts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.liquor, color: Color(0xFF42A5F5), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    isCambuseCatSelected ? _selectedCategory : 'Boissons',
                                    style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Divider(color: const Color(0xFF42A5F5).withValues(alpha: 0.3), height: 1)),
                                ],
                              ),
                            ),
                          // Si catégorie Cambuse précise sélectionnée → pas de sous-titres
                          if (isCambuseCatSelected)
                            ...cambuseItems.map((item) => _CambuseCard(
                              key: ValueKey('cambuse_${item.id}'),
                              item: item,
                              cartItems: _cartItems,
                              onAdd: (qty) => _addCambuseToCart(item, qty: qty),
                            ))
                          else
                            // Tous ou catégorie plat → regroupement par sous-catégorie Cambuse
                            ...cambuseCats.expand((cat) {
                              final catItems = cambuseItems.where((i) => i.category == cat).toList();
                              return [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6, top: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_drink, color: Color(0xFF42A5F5), size: 11),
                                      const SizedBox(width: 5),
                                      Text(
                                        cat.toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF42A5F5),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...catItems.map((item) => _CambuseCard(
                                  key: ValueKey('cambuse_${item.id}'),
                                  item: item,
                                  cartItems: _cartItems,
                                  onAdd: (qty) => _addCambuseToCart(item, qty: qty),
                                )),
                              ];
                            }),
                        ],
                      ],
                    ),
            ),
          ],
        ),

        // ── ZONE 4 : FAB Panier flottant (compact, coin bas-droit) ─────
        Positioned(
          bottom: 12,
          right: 16,
          child: SafeArea(
            top: false,
            child: _CartFab(
              count: _cartCount,
              total: _cartTotal,
              onTap: _cartCount > 0 ? _openCart : null,
            ),
          ),
        ),
      ],
    );
  }
}

// =================== PUCE CATÉGORIE ===================
/// Puce de filtre catégorie — style différencié entre plats (violet) et boissons (bleu)
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCambuse; // true → couleur bleue (boissons)
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.isCambuse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isCambuse ? const Color(0xFF42A5F5) : AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor
                : isCambuse
                    ? const Color(0xFF42A5F5).withValues(alpha: 0.35)
                    : const Color(0xFF2A2A5A),
          ),
          boxShadow: selected
              ? [BoxShadow(color: activeColor.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCambuse) ...[
              Icon(Icons.local_drink, size: 11, color: selected ? Colors.white : const Color(0xFF42A5F5)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : isCambuse
                        ? const Color(0xFF42A5F5)
                        : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== FAB PANIER ===================
class _CartFab extends StatelessWidget {
  final int count;
  final double total;
  final VoidCallback? onTap;

  const _CartFab({required this.count, required this.total, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasItems = count > 0;
    if (!hasItems) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône + badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
                  Positioned(
                    top: -5, right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Text('$count', style: TextStyle(color: AppTheme.primary, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                'Panier',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${total.toStringAsFixed(0)} F',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== CARTE PRODUIT (REFONTE COMPLÈTE) ===================
class _ProductCard extends StatefulWidget {
  final Product product;
  final List<OrderItem> cartItems;
  final List<StockItem> stockItems;   // pour afficher le vrai stock physique
  final void Function(int qty) onAdd;

  const _ProductCard({
    super.key,
    required this.product,
    required this.cartItems,
    required this.stockItems,
    required this.onAdd,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  int _qty = 1;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _decrement() {
    if (_qty > 1) setState(() => _qty--);
  }

  void _increment() {
    setState(() => _qty++);
  }

  void _addToCart() {
    widget.onAdd(_qty);
    _animCtrl.forward(from: 0);
    setState(() => _qty = 1);
  }

  @override
  Widget build(BuildContext context) {
    final cartItem = widget.cartItems.firstWhere(
      (i) => i.productId == widget.product.id,
      orElse: () => OrderItem(productId: '', productName: '', quantity: 0, unitPrice: 0),
    );
    final inCart = cartItem.productId.isNotEmpty;
    final cartQty = inCart ? cartItem.quantity : 0;
    // Stock effectif — bloque le bouton + et Ajouter si épuisé
    final effectiveStock = widget.product.computedStock(widget.stockItems);
    final isOutOfStock = effectiveStock <= 0;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: inCart
              ? AppTheme.primary.withValues(alpha: 0.07)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart
                ? AppTheme.primary.withValues(alpha: 0.45)
                : const Color(0xFF2A2A5A),
            width: inCart ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LIGNE 1 : Infos produit ─────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Miniature image — placeholder toujours visible
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty)
                        ? ProductImageSmall(imageUrl: widget.product.imageUrl, size: 52, radius: 8)
                        : Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A3E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.restaurant_menu, color: Color(0xFF3A3A6A), size: 22),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom — jamais coupé
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                        // Description (si disponible)
                        if (widget.product.description != null &&
                            widget.product.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.product.description!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        // Prix + badge Stock + badge panier
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${widget.product.price.toStringAsFixed(0)} F',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            // Badge Stock — utilise stockQuantity synchronisé en RAM
                            // (mis à jour automatiquement depuis stockLinks via le stream stock)
                            Builder(builder: (_) {
                              final realStock = widget.product.computedStock(widget.stockItems);
                              final isOut  = realStock <= 0;
                              final isLow  = !isOut && realStock <= widget.product.minStockAlert;
                              final color  = isOut
                                  ? AppTheme.error
                                  : isLow ? AppTheme.warning : AppTheme.success;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOut ? 'Épuisé' : 'Stock: $realStock',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }),
                            if (inCart)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '×$cartQty au panier',
                                  style: const TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── LIGNE 2 : Contrôles quantité + bouton Ajouter (même ligne) ───
              Row(
                children: [
                  // Bouton −
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: _decrement,
                    enabled: _qty > 1,
                    color: const Color(0xFF8888AA),
                  ),
                  // Quantité éditable
                  _EditableQty(
                    quantity: _qty,
                    maxStock: effectiveStock > 0 ? effectiveStock : null,
                    width: 38,
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                  // Bouton +
                  _QtyButton(
                    icon: Icons.add,
                    onTap: _increment,
                    enabled: !isOutOfStock,
                    color: AppTheme.success,
                  ),
                  // Espace flexible entre quantité et bouton Ajouter
                  const Spacer(),
                  // Bouton Ajouter — compact, aligné à droite
                  // Grisé et désactivé si stock épuisé
                  GestureDetector(
                    onTap: isOutOfStock ? null : _addToCart,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? AppTheme.textSecondary.withValues(alpha: 0.25)
                            : AppTheme.primary,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: isOutOfStock ? [] : [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOutOfStock ? Icons.block : Icons.add_shopping_cart,
                            size: 15,
                            color: isOutOfStock
                                ? AppTheme.textSecondary
                                : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOutOfStock ? 'Épuisé' : 'Ajouter',
                            style: TextStyle(
                              color: isOutOfStock
                                  ? AppTheme.textSecondary
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== CARTE BOISSON CAMBUSE ===================
/// Carte boisson compacte — même style que _ProductCard mais pour Cambuse.
/// - Icône 🍺 à la place de l'image produit
/// - Pas d'envoi en cuisine, pas de liaison stock
class _CambuseCard extends StatefulWidget {
  final CambuseItem item;
  final List<OrderItem> cartItems;
  final void Function(int qty) onAdd;

  const _CambuseCard({
    super.key,
    required this.item,
    required this.cartItems,
    required this.onAdd,
  });

  @override
  State<_CambuseCard> createState() => _CambuseCardState();
}

class _CambuseCardState extends State<_CambuseCard>
    with SingleTickerProviderStateMixin {
  int _qty = 1;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _addToCart() {
    widget.onAdd(_qty);
    _animCtrl.forward(from: 0);
    setState(() => _qty = 1);
  }

  @override
  Widget build(BuildContext context) {
    final cartItem = widget.cartItems.firstWhere(
      (i) => i.isCambuse && i.cambuseItemId == widget.item.id,
      orElse: () => OrderItem(productId: '', productName: '', quantity: 0, unitPrice: 0, isCambuse: true),
    );
    final inCart  = cartItem.cambuseItemId != null;
    final cartQty = inCart ? cartItem.quantity : 0;
    final isLow   = widget.item.isLowStock;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: inCart
              ? const Color(0xFF42A5F5).withValues(alpha: 0.07)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart
                ? const Color(0xFF42A5F5).withValues(alpha: 0.45)
                : const Color(0xFF2A2A5A),
            width: inCart ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône boisson
                  Container(
                    width: 40, height: 40,
                    margin: const EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.liquor, color: Color(0xFF42A5F5), size: 20),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${widget.item.sellingPrice.toStringAsFixed(0)} F',
                              style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            // Stock badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLow
                                    ? AppTheme.warning.withValues(alpha: 0.12)
                                    : AppTheme.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Stock: ${widget.item.quantity}',
                                style: TextStyle(
                                  color: isLow ? AppTheme.warning : AppTheme.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (inCart) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '×$cartQty au panier',
                                  style: const TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 10),
              // Contrôles quantité
              Row(
                children: [
                  _QtyButton(icon: Icons.remove, onTap: () { if (_qty > 1) setState(() => _qty--); }, enabled: _qty > 1, color: const Color(0xFF8888AA)),
                  _EditableQty(
                    quantity: _qty,
                    width: 44,
                    textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                  _QtyButton(icon: Icons.add, onTap: () => setState(() => _qty++), enabled: true, color: AppTheme.success),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _addToCart,
                    icon: const Icon(Icons.add_shopping_cart, size: 14),
                    label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bouton quantité réutilisable ─────────────────────────────────────────
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF161E36),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.5)
                : const Color(0xFF252D4A),
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? color : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

// ── Widget quantité éditable ──────────────────────────────────────────────
// Affiche la quantité en Text. Au tap → bascule sur un TextField numérique.
// Valide sur Entrée ou perte de focus. Gère le stock max et la valeur min (1).
class _EditableQty extends StatefulWidget {
  final int quantity;
  final int? maxStock;      // null = pas de limite
  final TextStyle textStyle;
  final double width;
  final void Function(int newQty) onChanged;

  const _EditableQty({
    required this.quantity,
    required this.onChanged,
    required this.textStyle,
    this.maxStock,
    this.width = 38,
  });

  @override
  State<_EditableQty> createState() => _EditableQtyState();
}

class _EditableQtyState extends State<_EditableQty> {
  bool _editing = false;
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.quantity}');
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(_EditableQty old) {
    super.didUpdateWidget(old);
    // Sync si la quantité change depuis l'extérieur (ex: bouton +/-)
    if (!_editing && old.quantity != widget.quantity) {
      _ctrl.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _ctrl.text = '${widget.quantity}';
    });
    // Sélectionner tout le texte pour faciliter la saisie
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  void _commit() {
    final raw = int.tryParse(_ctrl.text.trim());
    int newVal;
    if (raw == null || raw <= 0) {
      newVal = 1; // vide ou 0 → 1 par défaut
    } else if (widget.maxStock != null && raw > widget.maxStock!) {
      // Stock dépassé → snackbar + garder l'ancienne valeur
      newVal = widget.quantity;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quantité supérieure au stock disponible'),
              backgroundColor: AppTheme.error,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } else {
      newVal = raw;
    }
    setState(() {
      _editing = false;
      _ctrl.text = '$newVal';
    });
    if (newVal != widget.quantity) widget.onChanged(newVal);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: widget.width,
        height: 28,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: widget.textStyle,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFF1E2640),
          ),
          onSubmitted: (_) => _commit(),
        ),
      );
    }
    // Mode affichage — tap pour éditer
    return GestureDetector(
      onTap: _startEdit,
      child: Container(
        width: widget.width,
        alignment: Alignment.center,
        child: Text('${widget.quantity}', style: widget.textStyle),
      ),
    );
  }
}

// =================== PANIER BOTTOM SHEET PLEIN ÉCRAN ===================
class _CartBottomSheet extends StatefulWidget {
  final List<OrderItem> cartItems;
  final double cartTotal;
  final bool isTakeaway;
  final bool isUrgent;
  final TextEditingController tableController;
  final TextEditingController notesController;
  final AppUser? selectedServer;
  final List<AppUser> servers;
  final ValueChanged<bool> onTakeawayChanged;
  final ValueChanged<bool> onUrgentChanged;
  final ValueChanged<AppUser?> onServerChanged;
  final void Function(String id) onRemove;
  final void Function(String id) onDecrease;
  final void Function(String id) onIncrease;
  final void Function(String id, int newQty) onSetQty;
  final VoidCallback onSubmit;

  const _CartBottomSheet({
    required this.cartItems,
    required this.cartTotal,
    required this.isTakeaway,
    required this.isUrgent,
    required this.tableController,
    required this.notesController,
    required this.selectedServer,
    required this.servers,
    required this.onTakeawayChanged,
    required this.onUrgentChanged,
    required this.onServerChanged,
    required this.onRemove,
    required this.onDecrease,
    required this.onIncrease,
    required this.onSetQty,
    required this.onSubmit,
  });

  @override
  State<_CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends State<_CartBottomSheet> {
  bool _infoExpanded = false;
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _notesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _notesFocus.addListener(() {
      if (_notesFocus.hasFocus) {
        // Auto-expand le panneau et scroll vers le bas
        setState(() => _infoExpanded = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  int get _totalQty => widget.cartItems.fold(0, (s, i) => s + i.quantity);

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1629),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Poignée ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A4A7A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── En-tête ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Panier (${ _totalQty} article${ _totalQty > 1 ? 's' : ''})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                if (widget.isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('URGENT', style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                if (widget.isTakeaway) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('À EMPORTER', style: TextStyle(color: Color(0xFFE65100), fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF2A2A5A)),

          // ── Zone scrollable : articles + panneau infos ───────────
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // Articles
                  widget.cartItems.isEmpty
                      ? const SizedBox(
                          height: 120,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 52, color: Color(0xFF3A4A7A)),
                                SizedBox(height: 12),
                                Text('Panier vide', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          itemCount: widget.cartItems.length,
                          itemBuilder: (context, i) {
                            final item = widget.cartItems[i];
                            return _CartSheetItem(
                              item: item,
                              onRemove: () => widget.onRemove(item.productId),
                              onDecrease: () => widget.onDecrease(item.productId),
                              onIncrease: () => widget.onIncrease(item.productId),
                              onDirectQty: (v) => widget.onSetQty(item.productId, v),
                            );
                          },
                        ),

                  // ── Panneau "Informations commande" ────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A5A)),
                    ),
                    child: Column(
                      children: [
                        // Bouton toggle
                        GestureDetector(
                  onTap: () => setState(() => _infoExpanded = !_infoExpanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined,
                            color: _infoExpanded ? AppTheme.primary : AppTheme.textSecondary, size: 17),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Informations commande',
                            style: TextStyle(
                              color: _infoExpanded ? AppTheme.primary : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Badges résumé quand replié
                        if (!_infoExpanded) ...[
                          if (widget.isTakeaway)
                            _InfoBadge(label: 'À emporter', color: const Color(0xFFE65100)),
                          if (widget.isUrgent)
                            _InfoBadge(label: 'URGENT', color: AppTheme.error),
                          if (!widget.isTakeaway && widget.tableController.text.isNotEmpty)
                            _InfoBadge(label: 'Table ${widget.tableController.text}', color: AppTheme.primary),
                        ],
                        const SizedBox(width: 4),
                        Icon(
                          _infoExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppTheme.textSecondary, size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                // Contenu dépliable
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: _infoExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Column(
                            children: [
                              const Divider(height: 1, color: Color(0xFF2A2A5A)),
                              const SizedBox(height: 10),
                              // Toggle à emporter
                              _ToggleRow(
                                icon: Icons.takeout_dining,
                                label: 'Commande à emporter',
                                value: widget.isTakeaway,
                                activeColor: const Color(0xFFE65100),
                                onChanged: (v) { widget.onTakeawayChanged(v); setState(() {}); },
                              ),
                              const SizedBox(height: 8),
                              // Toggle urgent
                              _ToggleRow(
                                icon: Icons.flash_on,
                                label: 'Commande urgente',
                                value: widget.isUrgent,
                                activeColor: AppTheme.error,
                                onChanged: (v) { widget.onUrgentChanged(v); setState(() {}); },
                              ),
                              const SizedBox(height: 10),
                              // Champ table
                              if (!widget.isTakeaway) ...[
                                TextField(
                                  controller: widget.tableController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    hintText: 'N° de table *',
                                    prefixIcon: Icon(Icons.table_restaurant, color: AppTheme.primary, size: 18),
                                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              // Dropdown serveur
                              DropdownButtonFormField<AppUser?>(
                                value: widget.selectedServer,
                                dropdownColor: AppTheme.surface,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  hintText: 'Responsable de table',
                                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary, size: 18),
                                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                items: [
                                  const DropdownMenuItem<AppUser?>(
                                    value: null,
                                    child: Text('— Aucun serveur —', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  ),
                                  ...widget.servers.map((s) => DropdownMenuItem<AppUser?>(
                                    value: s,
                                    child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                                  )),
                                ],
                                onChanged: (v) { widget.onServerChanged(v); setState(() {}); },
                              ),
                              const SizedBox(height: 8),
                              // Notes — FocusNode pour scroll auto sur mobile
                              TextField(
                                controller: widget.notesController,
                                focusNode: _notesFocus,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                maxLines: 2,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  hintText: 'Instructions spéciales...',
                                  contentPadding: EdgeInsets.all(10),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                    ),       // AnimatedSize
                      ],     // Column.children (info panel)
                    ),       // Column (info panel)
                  ),         // Container (info panel)
                  const SizedBox(height: 4),  // breathing room at bottom
                ],           // SingleChildScrollView Column children
              ),             // Column
            ),               // SingleChildScrollView
          ),                 // Expanded

          // ── Total + Bouton envoyer (monte avec le clavier) ────────
          Padding(
            padding: EdgeInsets.only(bottom: keyboardH),
            child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1629),
              border: Border(top: BorderSide(color: Color(0xFF2A2A5A))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Résumé total
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total général', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          '${widget.cartTotal.toStringAsFixed(0)} F CFA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Bouton envoyer
                  Builder(builder: (ctx) {
                    // Adapter le bouton selon le contenu du panier
                    final hasKitchen = widget.cartItems.any((i) => i.isKitchenItem);
                    final hasCambuse = widget.cartItems.any((i) => i.isCambuse);
                    final btnLabel = !hasKitchen && hasCambuse
                        ? 'Valider la commande boissons'
                        : hasKitchen && hasCambuse
                            ? 'Envoyer cuisine + caisse'
                            : 'Envoyer en Cuisine';
                    final btnIcon = !hasKitchen && hasCambuse
                        ? Icons.local_bar
                        : Icons.send;
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: widget.cartItems.isEmpty ? null : widget.onSubmit,
                        icon: Icon(btnIcon, size: 18),
                        label: Text(btnLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF2A2A5A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          elevation: 4,
                        ),
                      ),
                    );
                  }),
                ],       // SafeArea Column children
              ),         // SafeArea Column
            ),           // SafeArea
          ),             // Container (total+button)
          ),             // Padding(bottom: keyboardH)
        ],               // outer Column children
      ),                 // outer Column
    );
  }
}

// ── Item dans le panier bottom sheet ─────────────────────────────────────
class _CartSheetItem extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onRemove;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final void Function(int newQty)? onDirectQty;

  const _CartSheetItem({
    required this.item,
    required this.onRemove,
    required this.onDecrease,
    required this.onIncrease,
    this.onDirectQty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Row(
        children: [
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  softWrap: true,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} F',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Contrôles
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: onDecrease, enabled: item.quantity > 1, color: AppTheme.error),
              _EditableQty(
                quantity: item.quantity,
                width: 34,
                textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                onChanged: onDirectQty ?? (_) {},
              ),
              _QtyButton(icon: Icons.add, onTap: onIncrease, enabled: true, color: AppTheme.primary),
            ],
          ),
          const SizedBox(width: 12),
          // Total ligne
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.totalPrice.toStringAsFixed(0)} F',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              GestureDetector(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =================== PANNEAU INFORMATIONS COMMANDE ===================
// (accessible depuis le panier — non utilisé directement dans le build principal,
//  mais utilisable comme widget autonome si besoin)
class _OrderInfoPanel extends StatefulWidget {
  final TextEditingController tableController;
  final TextEditingController notesController;
  final bool isTakeaway;
  final bool isUrgent;
  final AppUser? selectedServer;
  final List<AppUser> servers;
  final ValueChanged<bool> onTakeawayChanged;
  final ValueChanged<bool> onUrgentChanged;
  final ValueChanged<AppUser?> onServerChanged;

  const _OrderInfoPanel({
    required this.tableController,
    required this.notesController,
    required this.isTakeaway,
    required this.isUrgent,
    required this.selectedServer,
    required this.servers,
    required this.onTakeawayChanged,
    required this.onUrgentChanged,
    required this.onServerChanged,
  });

  @override
  State<_OrderInfoPanel> createState() => _OrderInfoPanelState();
}

class _OrderInfoPanelState extends State<_OrderInfoPanel> {
  bool _expanded = false;
  final FocusNode _notesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _notesFocus.addListener(() {
      if (_notesFocus.hasFocus && !_expanded) {
        setState(() => _expanded = true);
      }
    });
  }

  @override
  void dispose() {
    _notesFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        children: [
          // Bouton toggle
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,
                      color: _expanded ? AppTheme.primary : AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Informations commande',
                      style: TextStyle(
                        color: _expanded ? AppTheme.primary : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Badges résumé quand replié
                  if (!_expanded) ...[
                    if (widget.isTakeaway)
                      _InfoBadge(label: 'À emporter', color: const Color(0xFFE65100)),
                    if (widget.isUrgent)
                      _InfoBadge(label: 'URGENT', color: AppTheme.error),
                    if (!widget.isTakeaway && widget.tableController.text.isNotEmpty)
                      _InfoBadge(label: 'Table ${widget.tableController.text}', color: AppTheme.primary),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary, size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Contenu dépliable
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        const Divider(height: 1, color: Color(0xFF2A2A5A)),
                        const SizedBox(height: 12),
                        // Toggle à emporter
                        _ToggleRow(
                          icon: Icons.takeout_dining,
                          label: 'Commande à emporter',
                          value: widget.isTakeaway,
                          activeColor: const Color(0xFFE65100),
                          onChanged: widget.onTakeawayChanged,
                        ),
                        const SizedBox(height: 8),
                        // Toggle urgent
                        _ToggleRow(
                          icon: Icons.flash_on,
                          label: 'Commande urgente',
                          value: widget.isUrgent,
                          activeColor: AppTheme.error,
                          onChanged: widget.onUrgentChanged,
                        ),
                        const SizedBox(height: 10),
                        // Champ table
                        if (!widget.isTakeaway) ...[
                          TextField(
                            controller: widget.tableController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'N° de table *',
                              prefixIcon: Icon(Icons.table_restaurant, color: AppTheme.primary, size: 18),
                              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Dropdown serveur
                        DropdownButtonFormField<AppUser?>(
                          value: widget.selectedServer,
                          dropdownColor: AppTheme.surface,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Responsable de table',
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary, size: 18),
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          items: [
                            const DropdownMenuItem<AppUser?>(
                              value: null,
                              child: Text('— Aucun serveur —', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ),
                            ...widget.servers.map((s) => DropdownMenuItem<AppUser?>(
                              value: s,
                              child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: widget.onServerChanged,
                        ),
                        const SizedBox(height: 8),
                        // Notes
                        TextField(
                          controller: widget.notesController,
                          focusNode: _notesFocus,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          maxLines: 2,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'Instructions spéciales...',
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? activeColor.withValues(alpha: 0.12) : const Color(0xFF161E36),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? activeColor.withValues(alpha: 0.5) : const Color(0xFF2A2A5A),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: value ? activeColor : AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value ? activeColor : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: value ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: activeColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// =================== ORDERS LIST TAB ===================
class OrdersListTab extends StatefulWidget {
  const OrdersListTab({super.key});

  @override
  State<OrdersListTab> createState() => _OrdersListTabState();
}

class _OrdersListTabState extends State<OrdersListTab> {
  OrderStatus? _filterStatus;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    var orders = provider.orders;
    if (_filterStatus != null) orders = orders.where((o) => o.status == _filterStatus).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Toutes', selected: _filterStatus == null, onTap: () => setState(() => _filterStatus = null)),
                const SizedBox(width: 8),
                ...OrderStatus.values.where((s) => s != OrderStatus.cancelled).map((s) {
                  final labels = ['En attente', 'En préparation', 'Prêtes', 'Servies', ''];
                  final colors = [AppTheme.pending, AppTheme.preparing, AppTheme.ready, const Color(0xFF2196F3), AppTheme.error];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: labels[s.index],
                      color: colors[s.index],
                      selected: _filterStatus == s,
                      onTap: () => setState(() => _filterStatus = s),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Expanded(
          child: orders.isEmpty
            ? const EmptyState(icon: Icons.receipt_long, title: 'Aucune commande trouvée')
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, i) => _OrderListCard(order: orders[i], provider: provider),
              ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : const Color(0xFF2A2A5A)),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _OrderListCard extends StatelessWidget {
  final Order order;
  final AppProvider provider;

  const _OrderListCard({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(
        color: order.isOnlineOrder
            ? const Color(0xFF7C4DFF).withValues(alpha: 0.5)
            : order.statusColor.withValues(alpha: 0.3),
        width: order.isOnlineOrder ? 1.5 : 1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: order.statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Icon(
                      order.isOnlineOrder ? Icons.storefront_outlined : Icons.receipt_long,
                      color: order.isOnlineOrder ? const Color(0xFF7C4DFF) : order.statusColor,
                      size: 18,
                    ),
                    const SizedBox(height: 2),
                    Text('#${order.orderNumber}', style: TextStyle(color: order.statusColor, fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (order.isOnlineOrder) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('EN LIGNE', style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(child: Text(order.tableLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
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
                    Text('${order.items.fold(0, (s, i) => s + i.quantity)} articles • ${order.totalAmount.toStringAsFixed(0)} F CFA',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Text('Il y a ${order.elapsedMinutes} min', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              StatusBadge(label: order.statusLabel, color: order.statusColor),
            ],
          ),
          // Items preview
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.quantity}× ${item.productName}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                    Text('${item.totalPrice.toStringAsFixed(0)} F', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                  ],
                ),
              )).toList(),
            ),
          ),
          // Infos serveur si présent
          if (order.serverName != null) ...[                                           
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 13),
                const SizedBox(width: 4),
                Text('Serveur : ${order.serverName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
          // Status actions
          if (order.status != OrderStatus.served && order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActions(context, order, provider),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, Order order, AppProvider provider) {
    final role = provider.currentUser?.role;

    // Cuisine / admin / manager : peuvent passer preparing → ready
    final canChangeKitchenStatus = role == UserRole.kitchen ||
                                   role == UserRole.admin   ||
                                   role == UserRole.manager;

    // Serveur / cuisine / admin / manager : peuvent passer ready → served
    final canServeOrder = role == UserRole.server  ||
                          role == UserRole.kitchen ||
                          role == UserRole.admin   ||
                          role == UserRole.manager;

    Widget? progressBtn;
    if (order.status == OrderStatus.pending && canChangeKitchenStatus) {
      progressBtn = ElevatedButton.icon(
        onPressed: () => provider.updateOrderStatus(order.id, OrderStatus.preparing),
        icon: const Icon(Icons.restaurant, size: 14),
        label: const Text('Commencer', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.preparing, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      );
    } else if (order.status == OrderStatus.preparing && canChangeKitchenStatus) {
      progressBtn = ElevatedButton.icon(
        onPressed: () => provider.updateOrderStatus(order.id, OrderStatus.ready),
        icon: const Icon(Icons.check_circle, size: 14),
        label: const Text('Prêt', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ready, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      );
    } else if (order.status == OrderStatus.ready && canServeOrder) {
      // Bouton "Servir" : accessible serveur + cuisine + admin + manager
      progressBtn = ElevatedButton.icon(
        onPressed: () => provider.updateOrderStatus(order.id, OrderStatus.served),
        icon: const Icon(Icons.done_all, size: 14),
        label: const Text('Servir', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      );
    }

    // ── Verrouillage dès "En préparation" ─────────────────────────────
    // Une commande en préparation (ou au-delà) est entièrement verrouillée :
    // - Bouton Modifier : masqué pour tous les rôles
    // - Bouton Annuler  : masqué pour tous les rôles
    // - Un badge "Verrouillé" s'affiche à la place
    final isLocked = order.status == OrderStatus.preparing ||
                     order.status == OrderStatus.ready     ||
                     order.status == OrderStatus.served;

    // Bouton Modifier : visible uniquement si commande en attente (pending) et non payée
    final canEdit = !order.isPaid &&
        !isLocked &&
        order.status != OrderStatus.cancelled;

    // Bouton Annuler : visible uniquement si commande en attente (pending) et non payée
    final canCancel = !order.isPaid &&
        !isLocked &&
        order.status != OrderStatus.cancelled;

    // Badge verrouillé affiché quand la commande est en cours/prête/servie
    final lockBadge = isLocked
        ? Tooltip(
            message: 'Commande déjà en préparation, modification impossible.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.preparing.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.preparing.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, color: AppTheme.preparing, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Verrouillé',
                    style: TextStyle(
                      color: AppTheme.preparing,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;

    final editBtn = canEdit
        ? OutlinedButton.icon(
            onPressed: () => _showEditDialog(context, order, provider),
            icon: const Icon(Icons.edit_outlined, size: 13),
            label: const Text('Modifier', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          )
        : null;

    final cancelBtn = canCancel
        ? OutlinedButton.icon(
            onPressed: () => _showCancelDialog(context, order, provider),
            icon: const Icon(Icons.cancel_outlined, size: 13),
            label: const Text('Annuler', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          )
        : null;

    return [
      if (lockBadge != null) lockBadge,
      if (cancelBtn != null) ...[const SizedBox(width: 6), cancelBtn],
      if (editBtn != null) ...[const SizedBox(width: 6), editBtn],
      if (progressBtn != null) ...[const SizedBox(width: 6), progressBtn],
    ];
  }

  void _showCancelDialog(BuildContext context, Order order, AppProvider provider) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cancel, color: AppTheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Annuler #${order.orderNumber}',
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order.tableLabel} — ${order.totalAmount.toStringAsFixed(0)} F CFA',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            const Text('Raison de l\'annulation *',
                style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ex: Erreur de saisie, client parti...',
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);
              try {
                await provider.cancelOrder(orderId: order.id, cancelReason: reason);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Commande #${order.orderNumber} annulée'),
                    backgroundColor: AppTheme.error,
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur : $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            icon: const Icon(Icons.cancel, size: 14),
            label: const Text('Confirmer l\'annulation'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Order order, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _EditOrderDialog(order: order, provider: provider),
    );
  }
}

// ── Dialog Modifier Commande ─────────────────────────────────────────────────
class _EditOrderDialog extends StatefulWidget {
  final Order order;
  final AppProvider provider;
  const _EditOrderDialog({required this.order, required this.provider});

  @override
  State<_EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<_EditOrderDialog> {
  late TextEditingController _tableCtrl;
  late List<OrderItem> _items;
  AppUser? _selectedServer;

  /// Vrai si la commande est déjà en préparation (ou plus avancée) → ajout bloqué
  bool get _isLocked =>
      widget.order.status == OrderStatus.preparing ||
      widget.order.status == OrderStatus.ready ||
      widget.order.status == OrderStatus.served ||
      widget.order.kitchenStatus == 'preparing';

  @override
  void initState() {
    super.initState();
    _tableCtrl = TextEditingController(text: widget.order.tableNumber);
    _items = widget.order.items.map((i) => OrderItem(
      productId: i.productId,
      productName: i.productName,
      quantity: i.quantity,
      unitPrice: i.unitPrice,
      specialComment: i.specialComment,
      isCambuse: i.isCambuse,
      cambuseItemId: i.cambuseItemId,
    )).toList();
    // Pré-sélectionner le serveur actuel si présent
    if (widget.order.serverId != null) {
      try {
        _selectedServer = widget.provider.users.firstWhere(
          (u) => u.id == widget.order.serverId,
        );
      } catch (_) {
        _selectedServer = null;
      }
    }
  }

  @override
  void dispose() {
    _tableCtrl.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0, (s, i) => s + i.totalPrice);

  List<AppUser> get _servers => widget.provider.users
      .where((u) => u.role == UserRole.server && u.isActive)
      .toList();

  // ── Ajout d'articles ──────────────────────────────────────────────────────

  /// Ajoute ou incrémente un plat (Product) dans _items
  void _addProduct(Product product, int qty) {
    setState(() {
      final idx = _items.indexWhere(
        (i) => !i.isCambuse && i.productId == product.id,
      );
      if (idx >= 0) {
        _items[idx].quantity = (_items[idx].quantity + qty).clamp(1, 99);
      } else {
        _items.add(OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: qty,
          unitPrice: product.price,
          isCambuse: false,
        ));
      }
    });
  }

  /// Ajoute ou incrémente un article cambuse (CambuseItem) dans _items
  void _addCambuseItem(CambuseItem item, int qty) {
    setState(() {
      final idx = _items.indexWhere(
        (i) => i.isCambuse && i.cambuseItemId == item.id,
      );
      if (idx >= 0) {
        _items[idx].quantity = (_items[idx].quantity + qty).clamp(1, 99);
      } else {
        _items.add(OrderItem(
          productId: item.productId ?? item.id,
          productName: item.name,
          quantity: qty,
          unitPrice: item.sellingPrice,
          isCambuse: true,
          cambuseItemId: item.id,
        ));
      }
    });
  }

  /// Ouvre la bottom-sheet de sélection d'articles
  void _showAddArticleDialog() {
    // Blocage côté logique (sécurité supplémentaire)
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Commande déjà en préparation, ajout impossible.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddArticleSheet(
        provider: widget.provider,
        onAddProduct: (p, qty) {
          _addProduct(p, qty);
        },
        onAddCambuseItem: (c, qty) {
          _addCambuseItem(c, qty);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.edit, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text('Modifier #${widget.order.orderNumber}',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table
              TextField(
                controller: _tableCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'N° de table',
                  prefixIcon: Icon(Icons.table_restaurant, color: AppTheme.primary, size: 18),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
              ),
              const SizedBox(height: 10),
              // Responsable
              DropdownButtonFormField<AppUser?>(
                value: _selectedServer,
                dropdownColor: AppTheme.surface,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Responsable de table',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary, size: 18),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                items: [
                  const DropdownMenuItem<AppUser?>(
                    value: null,
                    child: Text('— Aucun serveur —', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  ..._servers.map((s) => DropdownMenuItem<AppUser?>(
                    value: s,
                    child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedServer = v),
              ),
              const SizedBox(height: 12),
              // Articles
              const Text('Articles', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              ..._items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A5A)),
                ),
                child: Row(
                  children: [
                    // Icône cambuse vs plat
                    if (item.isCambuse)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.local_bar, size: 14, color: Color(0xFF42A5F5)),
                      ),
                    Expanded(
                      child: Text(item.productName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    IconButton(
                      onPressed: () => setState(() { item.quantity = (item.quantity - 1).clamp(1, 99); }),
                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppTheme.error),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _EditableQty(
                        quantity: item.quantity,
                        width: 32,
                        textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        onChanged: (v) => setState(() { item.quantity = v; }),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() { item.quantity++; }),
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.success),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => setState(() => _items.removeWhere((i) => i.productId == item.productId && i.isCambuse == item.isCambuse)),
                      icon: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 8),
              // ── Bouton "+ Ajouter article" (masqué si commande en préparation) ──
              if (!_isLocked)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddArticleDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                    label: const Text(
                      '+ Ajouter article',
                      style: TextStyle(color: AppTheme.primary, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (!_isLocked) const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Total : ${_total.toStringAsFixed(0)} F CFA',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _items.isEmpty ? null : () async {
            if (_tableCtrl.text.trim().isEmpty) return;
            Navigator.pop(context);
            try {
              await widget.provider.updateOrderItems(
                orderId: widget.order.id,
                items: _items,
                tableNumber: _tableCtrl.text.trim(),
                serverId: _selectedServer?.id,
                serverName: _selectedServer?.name,
                serverEmail: _selectedServer?.email,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Commande #${widget.order.orderNumber} mise à jour'),
                  backgroundColor: AppTheme.success,
                ));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Erreur : $e'), backgroundColor: Colors.red,
                ));
              }
            }
          },
          icon: const Icon(Icons.save, size: 14),
          label: const Text('Enregistrer'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

// ── Bottom-sheet sélection d'articles ────────────────────────────────────────
class _AddArticleSheet extends StatefulWidget {
  final AppProvider provider;
  final void Function(Product, int) onAddProduct;
  final void Function(CambuseItem, int) onAddCambuseItem;

  const _AddArticleSheet({
    required this.provider,
    required this.onAddProduct,
    required this.onAddCambuseItem,
  });

  @override
  State<_AddArticleSheet> createState() => _AddArticleSheetState();
}

class _AddArticleSheetState extends State<_AddArticleSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  // Quantités temporaires par article (id → qty)
  final Map<String, int> _productQty = {};
  final Map<String, int> _cambuseQty = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts => widget.provider.availableProducts
      .where((p) => _search.isEmpty || p.name.toLowerCase().contains(_search))
      .toList();

  List<CambuseItem> get _filteredCambuse => widget.provider.cambuseItems
      .where((c) => !c.isOutOfStock)
      .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
      .toList();

  // Retourne la quantité sélectionnée (min 0)
  int _pQty(String id) => _productQty[id] ?? 0;
  int _cQty(String id) => _cambuseQty[id] ?? 0;

  // Compte total des articles sélectionnés
  int get _totalSelected =>
      _productQty.values.fold(0, (s, v) => s + v) +
      _cambuseQty.values.fold(0, (s, v) => s + v);

  void _confirm() {
    // Ajouter tous les produits avec qty > 0
    for (final entry in _productQty.entries) {
      if (entry.value > 0) {
        final product = widget.provider.availableProducts
            .firstWhere((p) => p.id == entry.key);
        widget.onAddProduct(product, entry.value);
      }
    }
    for (final entry in _cambuseQty.entries) {
      if (entry.value > 0) {
        final item = widget.provider.cambuseItems
            .firstWhere((c) => c.id == entry.key);
        widget.onAddCambuseItem(item, entry.value);
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Poignée
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Titre
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.add_shopping_cart, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ajouter des articles',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tabs Plats / Boissons
          TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.restaurant_menu, size: 14),
                  const SizedBox(width: 4),
                  Text('Plats (${_filteredProducts.length})'),
                ]),
              ),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_bar, size: 14),
                  const SizedBox(width: 4),
                  Text('Boissons (${_filteredCambuse.length})'),
                ]),
              ),
            ],
          ),
          // Liste
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── Onglet Plats ──
                _filteredProducts.isEmpty
                    ? const Center(child: Text('Aucun plat disponible', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (_, i) {
                          final p = _filteredProducts[i];
                          final qty = _pQty(p.id);
                          return _ArticleRow(
                            name: p.name,
                            category: p.category,
                            price: p.price,
                            quantity: qty,
                            accentColor: AppTheme.primary,
                            onDecrement: qty > 0
                                ? () => setState(() => _productQty[p.id] = qty - 1)
                                : null,
                            onIncrement: () => setState(() => _productQty[p.id] = qty + 1),
                            onDirectQty: (v) => setState(() => _productQty[p.id] = v),
                          );
                        },
                      ),
                // ── Onglet Boissons ──
                _filteredCambuse.isEmpty
                    ? const Center(child: Text('Aucune boisson disponible', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: _filteredCambuse.length,
                        itemBuilder: (_, i) {
                          final c = _filteredCambuse[i];
                          final qty = _cQty(c.id);
                          return _ArticleRow(
                            name: c.name,
                            category: c.category,
                            price: c.sellingPrice,
                            quantity: qty,
                            accentColor: const Color(0xFF42A5F5),
                            onDecrement: qty > 0
                                ? () => setState(() => _cambuseQty[c.id] = qty - 1)
                                : null,
                            onIncrement: () => setState(() => _cambuseQty[c.id] = qty + 1),
                            onDirectQty: (v) => setState(() => _cambuseQty[c.id] = v),
                          );
                        },
                      ),
              ],
            ),
          ),
          // Bouton Confirmer
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _totalSelected > 0 ? _confirm : null,
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  _totalSelected > 0
                      ? 'Ajouter $_totalSelected article${_totalSelected > 1 ? 's' : ''}'
                      : 'Sélectionnez des articles',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.surfaceLight,
                  disabledForegroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne article dans la bottom-sheet ───────────────────────────────────────
class _ArticleRow extends StatelessWidget {
  final String name;
  final String category;
  final double price;
  final int quantity;
  final Color accentColor;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final void Function(int newQty)? onDirectQty;

  const _ArticleRow({
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    required this.accentColor,
    required this.onDecrement,
    required this.onIncrement,
    this.onDirectQty,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = quantity > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.10)
            : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? accentColor.withValues(alpha: 0.5) : const Color(0xFF2A2A5A),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                Text('${category.isNotEmpty ? "$category · " : ""}${price.toStringAsFixed(0)} F',
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8), fontSize: 11)),
              ],
            ),
          ),
          // Contrôle quantité
          IconButton(
            onPressed: onDecrement,
            icon: Icon(Icons.remove_circle_outline, size: 20,
                color: onDecrement != null ? AppTheme.error : AppTheme.textSecondary.withValues(alpha: 0.3)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _EditableQty(
              quantity: quantity,
              width: 28,
              textStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ),
              onChanged: onDirectQty ?? (_) {},
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: Icon(Icons.add_circle_outline, size: 20, color: accentColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
