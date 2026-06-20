import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _searchQuery = '';
  List<String> _firestoreCategories = [];
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final provider = context.read<AppProvider>();
    final cats = await provider.fetchStockCategories();
    if (mounted) {
      setState(() {
        _firestoreCategories = cats;
        _categoriesLoaded = true;
      });
    }
  }

  /// Retourne les catégories fusionnées : Firestore + items existants (dédupliqué)
  List<String> _buildCategories(List<StockItem> stockItems) {
    final fromItems = stockItems.map((s) => s.category).toSet();
    final merged = <String>{..._firestoreCategories, ...fromItems}
        .where((c) => c.isNotEmpty)
        .toList()
      ..sort();
    return ['Tous', ...merged];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = _buildCategories(provider.stockItems);

    var items = provider.stockItems;
    if (_selectedCategory != 'Tous') {
      items = items.where((s) => s.category == _selectedCategory).toList();
    }
    if (_filter == 'low')  items = items.where((s) => s.isLow).toList();
    if (_filter == 'out')  items = items.where((s) => s.isOut).toList();
    if (_filter == 'expired') items = items.where((s) => s.isExpired).toList();

    // Recherche multi-champ : nom, catégorie, fournisseur (stocké dans unitCost/note via convention)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.category.toLowerCase().contains(q)
      ).toList();
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // ── Ligne 1 : filtres statut + boutons ───────────────
                Row(
                  children: [
                    _FilterBtn(label: 'Tous',    selected: _filter == 'all',     onTap: () => setState(() => _filter = 'all'),     color: AppTheme.primary),
                    const SizedBox(width: 6),
                    _FilterBtn(label: '⚠ Faible (${provider.lowStockItems.length})',   selected: _filter == 'low',     onTap: () => setState(() => _filter = 'low'),     color: AppTheme.warning),
                    const SizedBox(width: 6),
                    _FilterBtn(label: '🔴 Rupture (${provider.outOfStockItems.length})', selected: _filter == 'out',  onTap: () => setState(() => _filter = 'out'),     color: AppTheme.error),
                    const Spacer(),
                    // Bouton Approvisionner
                    TextButton.icon(
                      onPressed: () => _showRestockDialog(context, provider),
                      icon: const Icon(Icons.add_shopping_cart, size: 15, color: Color(0xFF2E7D32)),
                      label: const Text('Approvisionner',
                          style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF2E7D32), width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Bouton Ajouter stock
                    TextButton.icon(
                      onPressed: () => _showAddStockDialog(context, provider, categories),
                      icon: const Icon(Icons.add_box_outlined, size: 15, color: AppTheme.primary),
                      label: const Text('Ajouter stock',
                          style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.primary, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Ligne 2 : barre de recherche ─────────────────────
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, catégorie…',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 16),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Ligne 3 : chips catégories + Gérer catégories ────
                Row(
                  children: [
                    Expanded(
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
                                  color: selected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: selected ? AppTheme.primary : const Color(0xFF2A2A5A)),
                                ),
                                child: Text(cat,
                                    style: TextStyle(
                                        color: selected ? AppTheme.primary : AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton Gérer catégories
                    GestureDetector(
                      onTap: () => _showManageCategoriesDialog(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2A2A5A)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune, color: AppTheme.textSecondary, size: 14),
                            SizedBox(width: 4),
                            Text('Catégories', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2,
                    title: _searchQuery.isNotEmpty
                        ? 'Aucun résultat pour "$_searchQuery"'
                        : provider.stockItems.isEmpty
                            ? 'Aucun article de stock enregistré'
                            : 'Aucun article dans cette catégorie',
                    subtitle: null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _StockItemCard(
                      item: items[i],
                      onEdit: () => _showEditDialog(context, items[i], provider, _buildCategories(provider.stockItems)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Dialog Modifier article ─────────────────────────────────────────────
  void _showEditDialog(BuildContext context, StockItem item, AppProvider provider, List<String> categories) {
    final nameCtrl = TextEditingController(text: item.name);
    final unitCtrl = TextEditingController(text: item.unit);
    final minCtrl  = TextEditingController(text: item.minQuantity.toString());
    String category = item.category;

    final availableCategories = categories.where((c) => c != 'Tous').toList();
    if (!availableCategories.contains(category)) {
      availableCategories.insert(0, category);
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Modifier: ${item.name}', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info quantité — lecture seule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A5A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, color: AppTheme.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Text('Stock actuel : ${item.currentQuantity} ${item.unit}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const Spacer(),
                      const Text('(non modifiable)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nom du produit',
                        prefixIcon: Icon(Icons.label_outline, color: AppTheme.primary))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: availableCategories.contains(category) ? category : availableCategories.first,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie',
                      prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primary)),
                  items: availableCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: unitCtrl, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Unité (kg, L, pcs…)',
                        prefixIcon: Icon(Icons.straighten, color: AppTheme.primary))),
                const SizedBox(height: 10),
                TextField(controller: minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Seuil d\'alerte',
                        prefixIcon: Icon(Icons.warning_amber_outlined, color: AppTheme.warning))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Enregistrer'),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Le nom est obligatoire'), backgroundColor: AppTheme.warning));
                  return;
                }
                final updated = StockItem(
                  id: item.id,
                  name: nameCtrl.text.trim(),
                  unit: unitCtrl.text.trim().isEmpty ? item.unit : unitCtrl.text.trim(),
                  currentQuantity: item.currentQuantity,
                  minQuantity: double.tryParse(minCtrl.text) ?? item.minQuantity,
                  maxQuantity: item.maxQuantity,
                  unitCost: item.unitCost,
                  category: category,
                  expiryDate: item.expiryDate,
                );
                await provider.updateStockItem(updated);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('✅ ${updated.name} mis à jour'), backgroundColor: AppTheme.success));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog Ajouter nouveau produit stock ────────────────────────────────
  void _showAddStockDialog(BuildContext context, AppProvider provider, List<String> categories) {
    final nameCtrl     = TextEditingController();
    final qtyCtrl      = TextEditingController(text: '0');
    final unitCtrl     = TextEditingController();
    final minCtrl      = TextEditingController(text: '0');
    final priceCtrl    = TextEditingController();
    final noteCtrl     = TextEditingController();
    String? selectedCategory = categories.where((c) => c != 'Tous').firstOrNull;
    String? selectedSupplierId;
    String? selectedSupplierName;

    final availableCats = categories.where((c) => c != 'Tous').toList();
    if (availableCats.isEmpty) availableCats.addAll(['Viandes & Poissons', 'Légumes', 'Boissons', 'Autres']);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_box_outlined, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text('Ajouter un produit stock'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nom du produit *',
                        prefixIcon: Icon(Icons.label_outline, color: AppTheme.primary))),
                const SizedBox(height: 10),
                // Catégorie
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie *',
                      prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primary)),
                  items: availableCats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setS(() => selectedCategory = v),
                ),
                const SizedBox(height: 10),
                // Quantité initiale
                TextField(controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Quantité initiale *',
                        prefixIcon: Icon(Icons.inventory_2, color: AppTheme.primary))),
                const SizedBox(height: 10),
                // Unité
                TextField(controller: unitCtrl, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Unité (kg, L, pcs, boîtes…) *',
                        prefixIcon: Icon(Icons.straighten, color: AppTheme.primary))),
                const SizedBox(height: 10),
                // Seuil d'alerte
                TextField(controller: minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Seuil d\'alerte (quantité minimale)',
                        prefixIcon: Icon(Icons.warning_amber_outlined, color: AppTheme.warning))),
                const SizedBox(height: 10),
                // Fournisseur (optionnel)
                if (provider.suppliers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedSupplierId,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: AppTheme.cardBg,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Fournisseur (optionnel)',
                        prefixIcon: Icon(Icons.local_shipping_outlined, color: AppTheme.textSecondary)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                      ...provider.suppliers.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setS(() {
                      selectedSupplierId = v;
                      selectedSupplierName = v == null
                          ? null
                          : provider.suppliers.firstWhere((s) => s.id == v).name;
                    }),
                  ),
                const SizedBox(height: 10),
                // Prix d'achat (optionnel)
                TextField(controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Prix d\'achat unitaire (F CFA, optionnel)',
                        prefixIcon: Icon(Icons.monetization_on_outlined, color: AppTheme.primary))),
                const SizedBox(height: 10),
                // Note
                TextField(controller: noteCtrl, style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note (optionnel)',
                        prefixIcon: Icon(Icons.notes, color: AppTheme.textSecondary))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Créer'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final unit = unitCtrl.text.trim();
                final qty  = double.tryParse(qtyCtrl.text) ?? 0;
                final cat  = selectedCategory ?? 'Autres';

                if (name.isEmpty || unit.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Nom et unité sont obligatoires'), backgroundColor: AppTheme.warning));
                  return;
                }

                final id = FirebaseFirestore.instance.collection('stock').doc().id;
                final minQty = double.tryParse(minCtrl.text) ?? 0;
                final unitCost = double.tryParse(priceCtrl.text) ?? 0;

                final newItem = StockItem(
                  id: id,
                  name: name,
                  unit: unit,
                  currentQuantity: qty,
                  minQuantity: minQty,
                  maxQuantity: qty > 0 ? qty * 2 : 100,
                  unitCost: unitCost,
                  category: cat,
                );

                try {
                  // Crée l'article dans Firestore (qty initiale incluse)
                  await provider.addStockItem(newItem);

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('✅ $name ajouté au stock'), backgroundColor: AppTheme.success));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Erreur: $e'), backgroundColor: AppTheme.error));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog Gérer catégories ──────────────────────────────────────────────
  void _showManageCategoriesDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _ManageCategoriesDialog(
        provider: provider,
        onCategoriesChanged: _loadCategories,
      ),
    );
  }

  // ── Dialog Approvisionner ────────────────────────────────────────────────
  void _showRestockDialog(BuildContext context, AppProvider provider) {
    if (provider.stockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun article de stock disponible'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    StockItem selectedItem = provider.stockItems.first;
    final qtyCtrl  = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final noteCtrl  = TextEditingController();
    String? selectedSupplierId;
    String? selectedSupplierName;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart, color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 8),
              Text('Approvisionner le stock'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Article
                DropdownButtonFormField<String>(
                  value: selectedItem.id,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Article *'),
                  items: provider.stockItems.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (${s.currentQuantity} ${s.unit})',
                        overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setS(() {
                    selectedItem = provider.stockItems.firstWhere((s) => s.id == v);
                  }),
                ),
                const SizedBox(height: 10),
                // Quantité
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Quantité à ajouter *',
                    suffixText: selectedItem.unit,
                    suffixStyle: const TextStyle(color: AppTheme.primary),
                    prefixIcon: const Icon(Icons.add_circle_outline, color: Color(0xFF2E7D32)),
                  ),
                ),
                const SizedBox(height: 10),
                // Prix d'achat
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Prix d\'achat (F CFA, optionnel)',
                    prefixIcon: Icon(Icons.monetization_on_outlined, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 10),
                // Fournisseur
                if (provider.suppliers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedSupplierId,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: AppTheme.cardBg,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Fournisseur (optionnel)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                      ...provider.suppliers.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => setS(() {
                      selectedSupplierId = v;
                      selectedSupplierName = v == null
                          ? null
                          : provider.suppliers.firstWhere((s) => s.id == v).name;
                    }),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Aucun fournisseur enregistré',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                const SizedBox(height: 10),
                // Note
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optionnel)',
                    prefixIcon: Icon(Icons.notes, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                // Résumé
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2E7D32), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stock actuel: ${selectedItem.currentQuantity} ${selectedItem.unit}\n'
                          'Après appro: ${selectedItem.currentQuantity + (double.tryParse(qtyCtrl.text) ?? 0)} ${selectedItem.unit}',
                          style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approvisionner'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text);
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Entrez une quantité valide (> 0)'),
                        backgroundColor: AppTheme.warning),
                  );
                  return;
                }
                try {
                  await provider.restockItem(
                    stockItemId: selectedItem.id,
                    qty: qty,
                    purchasePrice: double.tryParse(priceCtrl.text),
                    supplierId: selectedSupplierId,
                    supplierName: selectedSupplierName,
                    note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ +$qty ${selectedItem.unit} ajouté à ${selectedItem.name}',
                        ),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =================== MANAGE CATEGORIES DIALOG ===================
class _ManageCategoriesDialog extends StatefulWidget {
  final AppProvider provider;
  final VoidCallback onCategoriesChanged;

  const _ManageCategoriesDialog({required this.provider, required this.onCategoriesChanged});

  @override
  State<_ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<_ManageCategoriesDialog> {
  List<String> _categories = [];
  bool _loading = true;
  final _newCatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cats = await widget.provider.fetchStockCategories();
    if (mounted) setState(() { _categories = cats; _loading = false; });
  }

  /// Vérifie si un produit stock utilise cette catégorie
  bool _isCategoryInUse(String name) {
    return widget.provider.stockItems.any((s) => s.category == name);
  }

  Future<void> _add() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty) return;
    if (_categories.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('La catégorie "$name" existe déjà'), backgroundColor: AppTheme.warning));
      return;
    }
    await widget.provider.addStockCategory(name);
    _newCatCtrl.clear();
    widget.onCategoriesChanged();
    _load();
  }

  Future<void> _rename(String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer la catégorie'),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Nouveau nom'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Renommer')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty && ctrl.text.trim() != oldName) {
      await widget.provider.updateStockCategory(oldName, ctrl.text.trim());
      widget.onCategoriesChanged();
      _load();
    }
  }

  Future<void> _delete(String name) async {
    if (_isCategoryInUse(name)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible : des produits utilisent la catégorie "$name"'),
          backgroundColor: AppTheme.error));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text('Supprimer "$name" définitivement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.provider.deleteStockCategory(name);
      widget.onCategoriesChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('Gérer les catégories'),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Champ ajout nouvelle catégorie
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCatCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Nouvelle catégorie…',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _add,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: AppTheme.primary,
                  ),
                  child: const Text('Ajouter', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2A5A)),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_categories.isEmpty)
              const Text('Aucune catégorie. Ajoutez-en une ci-dessus.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF2A2A5A)),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final inUse = _isCategoryInUse(cat);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.label_outline, color: AppTheme.textSecondary, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(cat,
                                style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                          if (inUse)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.provider.stockItems.where((s) => s.category == cat).length} produits',
                                style: const TextStyle(color: AppTheme.primary, fontSize: 10),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Renommer
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: AppTheme.textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: 'Renommer',
                            onPressed: () => _rename(cat),
                          ),
                          // Supprimer
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 16,
                                color: inUse ? AppTheme.textSecondary.withValues(alpha: 0.4) : AppTheme.error),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: inUse ? 'Catégorie utilisée par des produits' : 'Supprimer',
                            onPressed: inUse ? null : () => _delete(cat),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ],
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
