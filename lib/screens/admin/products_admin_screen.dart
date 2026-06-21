import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class ProductsAdminScreen extends StatefulWidget {
  const ProductsAdminScreen({super.key});

  @override
  State<ProductsAdminScreen> createState() => _ProductsAdminScreenState();
}

class _ProductsAdminScreenState extends State<ProductsAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'Tous';
  String _search = '';

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
      appBar: AppBar(
        title: const Text('Gestion Produits & Menu'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Produits', icon: Icon(Icons.restaurant_menu, size: 16)),
            Tab(text: 'Catégories', icon: Icon(Icons.category, size: 16)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(context),
          const _CategoriesTab(),
        ],
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = ['Tous', ...provider.customCategories];
    var filtered = provider.products.where((p) {
      final catOk = _selectedCategory == 'Tous' || p.category == _selectedCategory;
      final searchOk = _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase());
      return catOk && searchOk;
    }).toList();

    final isWide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      floatingActionButton: isWide
          ? FloatingActionButton.extended(
              onPressed: () => _showProductDialog(context, provider, null),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau Produit'),
            )
          : FloatingActionButton(
              onPressed: () => _showProductDialog(context, provider, null),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un produit...',
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
                            border: Border.all(color: selected ? AppTheme.primary : const Color(0xFF2A2A5A)),
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
            child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'Aucun produit',
                  action: ElevatedButton.icon(
                    onPressed: () => _showProductDialog(context, provider, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un produit'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _ProductAdminCard(
                    product: filtered[i],
                    provider: provider,
                    onEdit: () => _showProductDialog(context, provider, filtered[i]),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, AppProvider provider, Product? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toStringAsFixed(0) ?? '');
    final prepTimeCtrl = TextEditingController(text: existing?.prepTime.toStringAsFixed(0) ?? '10');
    final stockCtrl = TextEditingController(text: existing?.stockQuantity.toString() ?? '0');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final cats = provider.customCategories;
    String category = existing?.category ?? (cats.isNotEmpty ? cats.first : 'Plats');
    // Assurer que la catégorie est dans la liste
    if (!cats.contains(category)) category = cats.isNotEmpty ? cats.first : 'Plats';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? 'Modifier ${existing.name}' : 'Ajouter un produit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom du produit *')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Prix (F CFA) *')),
                const SizedBox(height: 8),
                TextField(controller: prepTimeCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Temps de préparation (minutes)')),
                const SizedBox(height: 8),
                TextField(controller: stockCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Quantité en stock')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description (optionnel)'), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text);
                if (name.isNotEmpty && price != null) {
                  final product = Product(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name,
                    category: category,
                    price: price,
                    prepTime: double.tryParse(prepTimeCtrl.text) ?? 10,
                    stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    isAvailable: (int.tryParse(stockCtrl.text) ?? 0) > 0,
                  );
                  if (isEdit) {
                    await provider.updateProduct(product);
                  } else {
                    await provider.addProduct(product);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: Text(isEdit ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== ONGLET CATÉGORIES ===================
class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = provider.customCategories;

    final isWide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      floatingActionButton: isWide
          ? FloatingActionButton.extended(
              onPressed: () => _showAddCategoryDialog(context, provider),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle Catégorie'),
            )
          : FloatingActionButton(
              onPressed: () => _showAddCategoryDialog(context, provider),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${categories.length} catégorie(s) • Utilisées pour organiser votre menu',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: categories.isEmpty
              ? const EmptyState(icon: Icons.category, title: 'Aucune catégorie', subtitle: 'Créez vos catégories de menu')
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final productCount = provider.products.where((p) => p.category == cat).length;
                    return _CategoryCard(
                      category: cat,
                      productCount: productCount,
                      onRename: () => _showRenameCategoryDialog(context, provider, cat),
                      onDelete: productCount > 0
                        ? () => _showCannotDeleteDialog(context, cat, productCount)
                        : () => _confirmDeleteCategory(context, provider, cat),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, AppProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Nouvelle Catégorie'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nom de la catégorie *',
                hintText: 'Ex: Plats africains, Desserts...',
                prefixIcon: Icon(Icons.category_outlined, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                if (provider.customCategories.contains(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$name" existe déjà'), backgroundColor: AppTheme.warning),
                  );
                  return;
                }
                provider.addCategory(name);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Catégorie "$name" créée'), backgroundColor: AppTheme.success),
                );
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showRenameCategoryDialog(BuildContext context, AppProvider provider, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Renommer la catégorie'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nouveau nom',
                prefixIcon: Icon(Icons.category_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Les produits de cette catégorie seront mis à jour automatiquement.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                if (provider.customCategories.contains(newName)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$newName" existe déjà'), backgroundColor: AppTheme.warning),
                  );
                  return;
                }
                provider.renameCategory(oldName, newName);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$oldName" → "$newName"'), backgroundColor: AppTheme.success),
                );
              }
            },
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
  }

  void _showCannotDeleteDialog(BuildContext context, String category, int count) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
            SizedBox(width: 8),
            Text('Suppression impossible'),
          ],
        ),
        content: Text(
          'La catégorie "$category" contient $count produit(s). '
          'Veuillez d\'abord déplacer ou supprimer ces produits.',
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Compris')),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, AppProvider provider, String category) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
            SizedBox(width: 8),
            Text('Supprimer la catégorie'),
          ],
        ),
        content: Text('Êtes-vous sûr de supprimer la catégorie "$category" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              provider.deleteCategory(category);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Catégorie "$category" supprimée'), backgroundColor: AppTheme.error),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// =================== CARTE CATÉGORIE ===================
class _CategoryCard extends StatelessWidget {
  final String category;
  final int productCount;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.productCount,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasProducts = productCount > 0;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Icon(Icons.category, color: AppTheme.primary, size: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasProducts ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$productCount produit${productCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: hasProducts ? AppTheme.success : AppTheme.textSecondary,
                        fontSize: 11, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Actions
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                onPressed: onRename,
                tooltip: 'Renommer',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: hasProducts ? AppTheme.textSecondary : AppTheme.error,
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: hasProducts ? 'Catégorie non vide' : 'Supprimer',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// =================== CARTE PRODUIT ===================
class _ProductAdminCard extends StatefulWidget {
  final Product product;
  final AppProvider provider;
  final VoidCallback onEdit;

  const _ProductAdminCard(
      {required this.product,
      required this.provider,
      required this.onEdit});

  @override
  State<_ProductAdminCard> createState() => _ProductAdminCardState();
}

class _ProductAdminCardState extends State<_ProductAdminCard> {
  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final provider = widget.provider;
    final isAvail = product.isAvailable && product.stockQuantity > 0;
    final hasLinks = product.stockLinks.isNotEmpty;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(
          color: isAvail
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.error.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAvail
                      ? AppTheme.success.withValues(alpha: 0.15)
                      : AppTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAvail ? Icons.check_circle : Icons.cancel,
                  color: isAvail ? AppTheme.success : AppTheme.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    Text(product.category,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    Row(
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(0)} F CFA',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Stock: ${product.stockQuantity}',
                          style: TextStyle(
                            color: product.stockQuantity == 0
                                ? AppTheme.error
                                : product.stockQuantity < 5
                                    ? AppTheme.warning
                                    : AppTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${product.prepTime.toInt()} min',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11)),
                      ],
                    ),
                    if (hasLinks)
                      Row(
                        children: [
                          const Icon(Icons.link,
                              size: 11, color: AppTheme.primary),
                          const SizedBox(width: 3),
                          Text(
                            '${product.stockLinks.length} liaison(s) stock',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit,
                        color: AppTheme.primary, size: 18),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () =>
                        _showStockLinksDialog(context, product, provider),
                    icon: Icon(
                      Icons.link,
                      color: hasLinks
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      size: 18,
                    ),
                    tooltip: 'Liaisons stock',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () =>
                        provider.toggleProductAvailability(product.id),
                    icon: Icon(
                      product.isAvailable
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: product.isAvailable
                          ? AppTheme.warning
                          : AppTheme.success,
                      size: 18,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context, provider),
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.error, size: 18),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dialogue gestion liaisons stock ─────────────────────────────────
  void _showStockLinksDialog(
      BuildContext context, Product product, AppProvider provider) {
    List<StockLink> links = List.from(product.stockLinks);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.link, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Liaisons stock — ${product.name}',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Quand ce plat est vendu, ces produits seront déduits automatiquement du stock.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (links.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Aucune liaison définie',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    )
                  else
                    ...links.asMap().entries.map((entry) {
                      final i = entry.key;
                      final link = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    link.stockItemName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    '− ${link.quantityUsed} ${link.unit} par portion'
                                    '${link.mandatory ? ' • obligatoire' : ' • optionnel'}',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setS(() => links.removeAt(i)),
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.error, size: 18),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final newLink = await _showAddStockLinkDialog(
                            ctx, provider);
                        if (newLink != null) {
                          setS(() => links.add(newLink));
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter un produit stock',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                await provider.updateProductStockLinks(product.id, links);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogue d'ajout d'une liaison vers un produit stock.
  Future<StockLink?> _showAddStockLinkDialog(
      BuildContext context, AppProvider provider) async {
    if (provider.stockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun produit dans le stock'),
            backgroundColor: AppTheme.warning),
      );
      return null;
    }

    StockItem selectedItem = provider.stockItems.first;
    final qtyCtrl = TextEditingController(text: '1');
    String unit = selectedItem.unit;
    bool mandatory = true;

    return showDialog<StockLink>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Ajouter une liaison stock',
              style: TextStyle(fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedItem.id,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Produit stock'),
                  items: provider.stockItems
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() {
                    selectedItem = provider.stockItems
                        .firstWhere((s) => s.id == v!);
                    unit = selectedItem.unit;
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Quantité utilisée par portion',
                    suffixText: unit,
                    suffixStyle:
                        const TextStyle(color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(text: unit),
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Unité'),
                  onChanged: (v) => setS(() => unit = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Switch(
                      value: mandatory,
                      onChanged: (v) => setS(() => mandatory = v),
                      activeColor: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mandatory
                            ? 'Obligatoire (bloque si stock 0)'
                            : 'Optionnel (commande autorisée)',
                        style: TextStyle(
                            color: mandatory
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text) ?? 1;
                if (qty <= 0) return;
                Navigator.pop(
                  ctx,
                  StockLink(
                    stockItemId: selectedItem.id,
                    stockItemName: selectedItem.name,
                    quantityUsed: qty,
                    unit: unit.trim().isEmpty ? selectedItem.unit : unit.trim(),
                    mandatory: mandatory,
                  ),
                );
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text(
            'Êtes-vous sûr de supprimer "${widget.product.name}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteProduct(widget.product.id);
              if (context.mounted) Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
