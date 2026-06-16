import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'Stocks', icon: Icon(Icons.inventory, size: 16)),
                Tab(text: 'Produits Disponibles', icon: Icon(Icons.restaurant_menu, size: 16)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _StockTab(),
                _AvailableProductsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockTab extends StatefulWidget {
  const _StockTab();

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  String _selectedCategory = 'Tous';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = ['Tous', ...{...provider.stockItems.map((s) => s.category)}];
    var items = provider.stockItems;

    if (_selectedCategory != 'Tous') items = items.where((s) => s.category == _selectedCategory).toList();
    if (_filter == 'low') items = items.where((s) => s.isLow).toList();
    if (_filter == 'out') items = items.where((s) => s.isOut).toList();
    if (_filter == 'expired') items = items.where((s) => s.isExpired).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStockDialog(context, provider),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Filter buttons
                Row(
                  children: [
                    _FilterBtn(label: 'Tous', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all'), color: AppTheme.primary),
                    const SizedBox(width: 6),
                    _FilterBtn(label: '⚠ Faible (${provider.lowStockItems.length})', selected: _filter == 'low', onTap: () => setState(() => _filter = 'low'), color: AppTheme.warning),
                    const SizedBox(width: 6),
                    _FilterBtn(label: '🔴 Rupture (${provider.outOfStockItems.length})', selected: _filter == 'out', onTap: () => setState(() => _filter = 'out'), color: AppTheme.error),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final selected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? AppTheme.primary : const Color(0xFF2A2A5A)),
                          ),
                          child: Text(cat, style: TextStyle(color: selected ? AppTheme.primary : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
              ? const EmptyState(icon: Icons.inventory_2, title: 'Aucun article dans cette catégorie')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _StockItemCard(
                    item: items[i],
                    onEdit: () => _showEditDialog(context, items[i], provider),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, StockItem item, AppProvider provider) {
    final ctrl = TextEditingController(text: item.currentQuantity.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Mettre à jour: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Quantité actuelle: ${item.currentQuantity} ${item.unit}',
              style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nouvelle quantité (${item.unit})',
                prefixIcon: const Icon(Icons.edit, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(ctrl.text);
              if (qty != null && qty >= 0) {
                provider.updateStock(item.id, qty);
                Navigator.pop(context);
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'kg');
    final qtyCtrl = TextEditingController(text: '0');
    final minCtrl = TextEditingController(text: '5');
    final maxCtrl = TextEditingController(text: '100');
    final costCtrl = TextEditingController(text: '0');
    String category = 'Légumes';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Ajouter un article au stock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 8),
                TextField(controller: unitCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Unité (kg, L, pcs...)')),
                const SizedBox(height: 8),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Quantité actuelle')),
                const SizedBox(height: 8),
                TextField(controller: minCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Quantité minimale')),
                const SizedBox(height: 8),
                TextField(controller: costCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Coût unitaire (F CFA)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: ['Viandes & Poissons', 'Légumes', 'Féculents', 'Épices & Huiles', 'Boissons', 'Autres']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  provider.addStockItem(StockItem(
                    id: const Uuid().v4(),
                    name: nameCtrl.text,
                    unit: unitCtrl.text,
                    currentQuantity: double.tryParse(qtyCtrl.text) ?? 0,
                    minQuantity: double.tryParse(minCtrl.text) ?? 5,
                    maxQuantity: double.tryParse(maxCtrl.text) ?? 100,
                    unitCost: double.tryParse(costCtrl.text) ?? 0,
                    category: category,
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterBtn({required this.label, required this.selected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : const Color(0xFF2A2A5A)),
        ),
        child: Text(label, style: TextStyle(color: selected ? color : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StockItemCard extends StatelessWidget {
  final StockItem item;
  final VoidCallback onEdit;

  const _StockItemCard({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (item.isOut) {
      statusColor = AppTheme.error;
      statusLabel = 'RUPTURE';
      statusIcon = Icons.cancel;
    } else if (item.isExpired) {
      statusColor = const Color(0xFFFF6B00);
      statusLabel = 'EXPIRÉ';
      statusIcon = Icons.warning_amber;
    } else if (item.isLow) {
      statusColor = AppTheme.warning;
      statusLabel = 'FAIBLE';
      statusIcon = Icons.warning;
    } else {
      statusColor = AppTheme.success;
      statusLabel = 'OK';
      statusIcon = Icons.check_circle;
    }

    final pct = item.maxQuantity > 0 ? (item.currentQuantity / item.maxQuantity).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      onTap: onEdit,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: [
                        Text('${item.currentQuantity} ${item.unit}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(' / ${item.maxQuantity} ${item.unit}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    Text(item.category, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(label: statusLabel, color: statusColor, fontSize: 10),
                  const SizedBox(height: 4),
                  const Icon(Icons.edit, color: AppTheme.textSecondary, size: 14),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          if (item.expiryDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event, color: item.isExpired ? AppTheme.error : AppTheme.textSecondary, size: 12),
                const SizedBox(width: 4),
                Text('Expire: ${_formatDate(item.expiryDate!)}',
                  style: TextStyle(color: item.isExpired ? AppTheme.error : AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// =================== AVAILABLE PRODUCTS TAB ===================
class _AvailableProductsTab extends StatefulWidget {
  const _AvailableProductsTab();

  @override
  State<_AvailableProductsTab> createState() => _AvailableProductsTabState();
}

class _AvailableProductsTabState extends State<_AvailableProductsTab> {
  String _selectedCategory = 'Tous';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Show ALL products including unavailable ones (read-only display)
    final allProducts = provider.products;
    final categories = ['Tous', ...{...allProducts.map((p) => p.category)}];
    var filtered = _selectedCategory == 'Tous' ? allProducts : allProducts.where((p) => p.category == _selectedCategory).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), border: Border(bottom: BorderSide(color: const Color(0xFF2A2A5A)))),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              const Expanded(child: Text('Affichage en temps réel des produits et quantités disponibles (lecture seule)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final cat = categories[i];
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? AppTheme.primary : const Color(0xFF2A2A5A)),
                    ),
                    child: Text(cat, style: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _ProductAvailCard(product: filtered[i]),
          ),
        ),
      ],
    );
  }
}

class _ProductAvailCard extends StatelessWidget {
  final Product product;

  const _ProductAvailCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isAvail = product.isAvailable && product.stockQuantity > 0;
    final color = isAvail ? AppTheme.success : AppTheme.error;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(isAvail ? Icons.check_circle : Icons.cancel, color: color, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(isAvail ? 'DISPO' : 'INDISPO', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
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
                  Text('Stock: ${product.stockQuantity}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
