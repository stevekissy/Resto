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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, provider, null),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau Produit'),
      ),
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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, provider),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Catégorie'),
      ),
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
class _ProductAdminCard extends StatelessWidget {
  final Product product;
  final AppProvider provider;
  final VoidCallback onEdit;

  const _ProductAdminCard({required this.product, required this.provider, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isAvail = product.isAvailable && product.stockQuantity > 0;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: isAvail ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isAvail ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
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
                Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(product.category, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Row(
                  children: [
                    Text('${product.price.toStringAsFixed(0)} F CFA', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text('Stock: ${product.stockQuantity}', style: TextStyle(
                      color: product.stockQuantity == 0 ? AppTheme.error : product.stockQuantity < 5 ? AppTheme.warning : AppTheme.success,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(width: 12),
                    Text('${product.prepTime.toInt()} min', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: AppTheme.primary, size: 18),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                onPressed: () => provider.toggleProductAvailability(product.id), // async fire-and-forget
                icon: Icon(
                  product.isAvailable ? Icons.visibility_off : Icons.visibility,
                  color: product.isAvailable ? AppTheme.warning : AppTheme.success,
                  size: 18,
                ),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, provider),
                icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text('Êtes-vous sûr de supprimer "${product.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteProduct(product.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
