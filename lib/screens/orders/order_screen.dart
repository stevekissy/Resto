import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
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
  final List<OrderItem> _cartItems = [];
  bool _isUrgent = false;
  String _selectedCategory = 'Tous';
  String _searchQuery = '';

  final List<String> _quickComments = [
    'Sans piment', 'Très chaud', 'Portion supplémentaire', 'Livraison',
    'Sauce à part', 'Peu de sel', 'Extra épicé', 'Sans oignon',
  ];

  @override
  void dispose() {
    _tableController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _cartTotal => _cartItems.fold(0, (sum, item) => sum + item.totalPrice);

  void _addToCart(Product product) {
    setState(() {
      final existing = _cartItems.firstWhere(
        (i) => i.productId == product.id,
        orElse: () => OrderItem(productId: '', productName: '', quantity: 0, unitPrice: 0),
      );
      if (existing.productId.isNotEmpty) {
        existing.quantity++;
      } else {
        _cartItems.add(OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.price,
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

  Future<void> _submitOrder() async {
    if (_tableController.text.isEmpty) {
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
    final order = await provider.createOrder(
      tableNumber: _tableController.text,
      items: List.from(_cartItems),
      specialInstructions: _notesController.text.isEmpty ? null : _notesController.text,
      isUrgent: _isUrgent,
    );

    if (!mounted) return;
    setState(() {
      _cartItems.clear();
      _tableController.clear();
      _notesController.clear();
      _isUrgent = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Commande #${order.orderNumber} envoyée en cuisine !'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = ['Tous', ...{...provider.availableProducts.map((p) => p.category)}];
    final filteredProducts = provider.availableProducts.where((p) {
      final catMatch = _selectedCategory == 'Tous' || p.category == _selectedCategory;
      final searchMatch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return catMatch && searchMatch;
    }).toList();

    return Row(
      children: [
        // Products panel
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un plat...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cat = categories[i];
                          final selected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? AppTheme.primary : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                                border: selected ? null : Border.all(color: const Color(0xFF2A2A5A)),
                              ),
                              child: Text(cat, style: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.2,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, i) => _ProductCard(
                    product: filteredProducts[i],
                    cartItems: _cartItems,
                    onAdd: () => _addToCart(filteredProducts[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Cart panel
        Container(
          width: 260,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(left: BorderSide(color: const Color(0xFF2A2A5A), width: 1)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2A2A5A)))),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Commande', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        if (_isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Text('URGENT', style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tableController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'N° de table',
                        prefixIcon: Icon(Icons.table_restaurant, color: AppTheme.primary, size: 18),
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Switch(
                          value: _isUrgent,
                          onChanged: (v) => setState(() => _isUrgent = v),
                          activeColor: AppTheme.error,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Text('Commande urgente', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              // Cart items
              Expanded(
                child: _cartItems.isEmpty
                  ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Panier vide', subtitle: 'Ajoutez des plats depuis le menu')
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _cartItems.length,
                      itemBuilder: (context, i) => _CartItem(
                        item: _cartItems[i],
                        onRemove: () => _removeFromCart(_cartItems[i].productId),
                        onDecrease: () => _updateQty(_cartItems[i].productId, -1),
                        onIncrease: () => _updateQty(_cartItems[i].productId, 1),
                        onComment: () => _addComment(_cartItems[i]),
                      ),
                    ),
              ),
              // Quick comments
              if (_cartItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF2A2A5A)))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Commentaires rapides', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: _quickComments.map((c) => GestureDetector(
                          onTap: () {
                            _notesController.text = _notesController.text.isEmpty ? c : '${_notesController.text}, $c';
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(c, style: const TextStyle(color: AppTheme.primary, fontSize: 10)),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Instructions spéciales...',
                          contentPadding: EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Total & Submit
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: const Color(0xFF2A2A5A))),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        Text('${_cartTotal.toStringAsFixed(0)} F CFA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Envoyer en Cuisine',
                      icon: Icons.send,
                      isFullWidth: true,
                      onPressed: _cartItems.isEmpty ? null : _submitOrder,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addComment(OrderItem item) {
    final ctrl = TextEditingController(text: item.specialComment);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Commentaire - ${item.productName}'),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Ex: Sans piment, très chaud...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              setState(() => item.specialComment = ctrl.text.isEmpty ? null : ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final List<OrderItem> cartItems;
  final VoidCallback onAdd;

  const _ProductCard({required this.product, required this.cartItems, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cartItem = cartItems.firstWhere(
      (i) => i.productId == product.id,
      orElse: () => OrderItem(productId: '', productName: '', quantity: 0, unitPrice: 0),
    );
    final inCart = cartItem.productId.isNotEmpty;

    return GestureDetector(
      onTap: onAdd,
      child: Container(
        decoration: BoxDecoration(
          color: inCart ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCart ? AppTheme.primary : const Color(0xFF2A2A5A),
            width: inCart ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(_getCategoryIcon(product.category), color: AppTheme.primary, size: 18),
                ),
                if (inCart) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text('×${cartItem.quantity}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${product.price.toStringAsFixed(0)} F', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 11),
                        const SizedBox(width: 2),
                        Text('${product.prepTime.toInt()}min', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Boissons': return Icons.local_drink;
      case 'Accompagnements': return Icons.rice_bowl;
      default: return Icons.restaurant;
    }
  }
}

class _CartItem extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onRemove;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onComment;

  const _CartItem({required this.item, required this.onRemove, required this.onDecrease, required this.onIncrease, required this.onComment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close, color: AppTheme.error, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
          if (item.specialComment != null) ...[
            const SizedBox(height: 2),
            Text(item.specialComment!, style: const TextStyle(color: AppTheme.warning, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onDecrease,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.remove, size: 14, color: AppTheme.error),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: onIncrease,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.add, size: 14, color: AppTheme.success),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onComment,
                    child: const Icon(Icons.comment_outlined, size: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Text('${item.totalPrice.toStringAsFixed(0)} F', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ],
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
      border: Border.all(color: order.statusColor.withValues(alpha: 0.3), width: 1),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: order.statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text('#${order.orderNumber}', style: TextStyle(color: order.statusColor, fontWeight: FontWeight.w800, fontSize: 14)),
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
                        Text('Table ${order.tableNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
    if (order.status == OrderStatus.pending) {
      return [
        ElevatedButton.icon(
          onPressed: () => provider.updateOrderStatus(order.id, OrderStatus.preparing),
          icon: const Icon(Icons.restaurant, size: 14),
          label: const Text('Commencer', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.preparing, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ];
    } else if (order.status == OrderStatus.preparing) {
      return [
        ElevatedButton.icon(
          onPressed: () => provider.updateOrderStatus(order.id, OrderStatus.ready),
          icon: const Icon(Icons.check_circle, size: 14),
          label: const Text('Prêt', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ready, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ];
    } else if (order.status == OrderStatus.ready) {
      return [
        ElevatedButton.icon(
          onPressed: () => provider.updateOrderStatus(order.id, OrderStatus.served),
          icon: const Icon(Icons.done_all, size: 14),
          label: const Text('Servi', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ];
    }
    return [];
  }
}
