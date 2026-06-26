import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CambuseScreen — Gestion des boissons
//  Tab 0 : Stock boissons   (liste + badges alerte)
//  Tab 1 : Approvisionner   (ajout stock)
//  Tab 2 : Historique       (mouvements)
// ════════════════════════════════════════════════════════════════════════════

class CambuseScreen extends StatefulWidget {
  const CambuseScreen({super.key});

  @override
  State<CambuseScreen> createState() => _CambuseScreenState();
}

class _CambuseScreenState extends State<CambuseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final items    = provider.cambuseItems;
    final lowCount = items.where((i) => i.isLowStock || i.isOutOfStock).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.liquor, color: Color(0xFF42A5F5), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'CAMBUSE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    if (lowCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: AppTheme.error, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '$lowCount alerte${lowCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppTheme.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Bouton ajouter boisson
                    ElevatedButton.icon(
                      onPressed: () => _showAddOrEditDialog(context, provider),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF42A5F5),
                  labelColor: const Color(0xFF42A5F5),
                  unselectedLabelColor: AppTheme.textSecondary,
                  tabs: [
                    Tab(
                      icon: Badge(
                        label: Text('${items.length}'),
                        isLabelVisible: items.isNotEmpty,
                        backgroundColor: AppTheme.primary,
                        child: const Icon(Icons.inventory_2, size: 16),
                      ),
                      text: 'Stock',
                    ),
                    const Tab(
                      icon: Icon(Icons.add_box, size: 16),
                      text: 'Approvisionner',
                    ),
                    const Tab(
                      icon: Icon(Icons.history, size: 16),
                      text: 'Historique',
                    ),
                    Tab(
                      icon: Badge(
                        label: Text('${provider.cambuseCategories.length}'),
                        isLabelVisible: provider.cambuseCategories.isNotEmpty,
                        backgroundColor: AppTheme.primary,
                        child: const Icon(Icons.category, size: 16),
                      ),
                      text: 'Catégories',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Tabs ────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StockTab(provider: provider, onEdit: (item) => _showAddOrEditDialog(context, provider, item: item)),
                _ApproTab(provider: provider),
                _HistoriqueTab(provider: provider),
                _CategoriesTab(provider: provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogue Ajouter / Modifier une boisson ─────────────────────────────
  void _showAddOrEditDialog(BuildContext context, AppProvider provider, {CambuseItem? item}) {
    showDialog(
      context: context,
      builder: (ctx) => _CambuseItemDialog(
        existing: item,
        availableCategories: provider.cambuseCustomCategories,
        onSave: (name, category, qty, threshold, price, productId) async {
          final id = item?.id ?? _uuid();
          final newItem = CambuseItem(
            id:             id,
            name:           name,
            category:       category,
            quantity:       qty,
            alertThreshold: threshold,
            sellingPrice:   price,
            productId:      productId.isEmpty ? null : productId,
            createdAt:      item?.createdAt ?? DateTime.now(),
          );
          await provider.saveCambuseItem(newItem, isNew: item == null);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        products: provider.products,
      ),
    );
  }

  String _uuid() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 1 — Stock boissons
// ════════════════════════════════════════════════════════════════════════════
class _StockTab extends StatefulWidget {
  final AppProvider provider;
  final void Function(CambuseItem) onEdit;
  const _StockTab({required this.provider, required this.onEdit});

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  String _filterCategory = 'Tous';
  final _fmt = NumberFormat('#,###', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final items = widget.provider.cambuseItems;
    final rawCats = items.map((i) => i.category).toSet().toList()..sort();
    final categories = ['Tous', ...rawCats];
    final filtered = _filterCategory == 'Tous'
        ? items
        : items.where((i) => i.category == _filterCategory).toList();

    return Column(
      children: [
        // Filtre catégorie
        if (categories.length > 2)
          Container(
            height: 36,
            color: AppTheme.surface,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final cat = categories[i];
                final selected = cat == _filterCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _filterCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF42A5F5).withValues(alpha: 0.2)
                            : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF42A5F5)
                              : AppTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected ? const Color(0xFF42A5F5) : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        // Liste boissons
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.liquor,
                  title: 'Aucune boisson',
                  subtitle: 'Appuyez sur "Ajouter" pour créer une boisson',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _CambuseItemCard(
                    item: filtered[i],
                    fmt: _fmt,
                    onEdit: () => widget.onEdit(filtered[i]),
                    onAppro: () => _showApproDialog(context, filtered[i]),
                    onDelete: () => _confirmDelete(context, filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  void _showApproDialog(BuildContext context, CambuseItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _ApproDialog(
        item: item,
        onConfirm: (qty) async {
          await widget.provider.approCambuse(item: item, quantite: qty);
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('✅ +$qty ${item.name} ajouté(s)'),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 2),
            ));
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, CambuseItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete, color: AppTheme.error),
          SizedBox(width: 8),
          Text('Supprimer ?', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Text(
          'Supprimer "${item.name}" de la cambuse ?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await widget.provider.deleteCambuseItem(item.id);
    }
  }
}

// ── Carte boisson ────────────────────────────────────────────────────────
class _CambuseItemCard extends StatelessWidget {
  final CambuseItem item;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onAppro;
  final VoidCallback onDelete;

  const _CambuseItemCard({
    required this.item,
    required this.fmt,
    required this.onEdit,
    required this.onAppro,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOut  = item.isOutOfStock;
    final isLow  = item.isLowStock;
    final Color statusColor = isOut
        ? AppTheme.error
        : isLow
            ? AppTheme.warning
            : AppTheme.success;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Icône + indicateur stock
          Stack(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.liquor, color: Color(0xFF42A5F5), size: 24),
              ),
              if (isOut || isLow)
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOut)
                      _AlertBadge('RUPTURE', AppTheme.error)
                    else if (isLow)
                      _AlertBadge('STOCK FAIBLE', AppTheme.warning),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      item.category,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${fmt.format(item.sellingPrice)} F CFA',
                      style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Jauge quantité
                    _QuantityBadge(
                      quantity: item.quantity,
                      threshold: item.alertThreshold,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'seuil : ${item.alertThreshold}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Column(
            children: [
              _IconActionBtn(icon: Icons.add_circle, color: AppTheme.success, onTap: onAppro, tooltip: 'Approvisionner'),
              const SizedBox(height: 4),
              _IconActionBtn(icon: Icons.edit, color: AppTheme.primary, onTap: onEdit, tooltip: 'Modifier'),
              const SizedBox(height: 4),
              _IconActionBtn(icon: Icons.delete_outline, color: AppTheme.error, onTap: onDelete, tooltip: 'Supprimer'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _AlertBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  final int quantity;
  final int threshold;
  final Color color;
  const _QuantityBadge({required this.quantity, required this.threshold, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$quantity unité${quantity > 1 ? 's' : ''}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _IconActionBtn({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 2 — Approvisionner
// ════════════════════════════════════════════════════════════════════════════
class _ApproTab extends StatefulWidget {
  final AppProvider provider;
  const _ApproTab({required this.provider});

  @override
  State<_ApproTab> createState() => _ApproTabState();
}

class _ApproTabState extends State<_ApproTab> {
  CambuseItem? _selectedItem;
  final _qtyCtrl = TextEditingController(text: '1');
  bool _saving = false;
  final _fmt = NumberFormat('#,###', 'fr_FR');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final item = _selectedItem;
    if (item == null) return;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Quantité invalide'), backgroundColor: AppTheme.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.provider.approCambuse(item: item, quantite: qty);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ +$qty ${item.name} — nouveau stock : ${item.quantity + qty}'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 3),
        ));
        _qtyCtrl.text = '1';
        setState(() => _selectedItem = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.provider.cambuseItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approvisionner une boisson',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          // Sélection boisson
          const Text('Boisson', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CambuseItem>(
                value: _selectedItem,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Sélectionner une boisson', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                isExpanded: true,
                dropdownColor: AppTheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: items.map((item) => DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      const Icon(Icons.liquor, color: Color(0xFF42A5F5), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      _QuantityBadge(
                        quantity: item.quantity,
                        threshold: item.alertThreshold,
                        color: item.isOutOfStock
                            ? AppTheme.error
                            : item.isLowStock ? AppTheme.warning : AppTheme.success,
                      ),
                    ],
                  ),
                )).toList(),
                onChanged: (v) => setState(() => _selectedItem = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Quantité à ajouter
          const Text('Quantité à ajouter', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              // Bouton -
              _QtyBtn(
                icon: Icons.remove,
                onTap: () {
                  final v = int.tryParse(_qtyCtrl.text) ?? 1;
                  if (v > 1) _qtyCtrl.text = '${v - 1}';
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton +
              _QtyBtn(
                icon: Icons.add,
                onTap: () {
                  final v = int.tryParse(_qtyCtrl.text) ?? 1;
                  _qtyCtrl.text = '${v + 1}';
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Présets rapides
          Row(
            children: [5, 10, 24, 48].map((qty) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: OutlinedButton(
                onPressed: () => _qtyCtrl.text = '$qty',
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('+$qty', style: const TextStyle(fontSize: 12)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          // Aperçu
          if (_selectedItem != null)
            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF42A5F5), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedItem!.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Stock actuel : ${_selectedItem!.quantity} → '
                          'Nouveau : ${_selectedItem!.quantity + (int.tryParse(_qtyCtrl.text) ?? 0)}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Bouton confirmer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving || _selectedItem == null ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_circle),
              label: const Text('Confirmer l\'approvisionnement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 3 — Historique des mouvements
// ════════════════════════════════════════════════════════════════════════════
class _HistoriqueTab extends StatelessWidget {
  final AppProvider provider;
  const _HistoriqueTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final movements = provider.cambuseMovements;

    if (movements.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Aucun mouvement',
        subtitle: 'L\'historique apparaîtra ici',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: movements.length,
      itemBuilder: (_, i) => _MovementCard(movement: movements[i]),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final CambuseMovement movement;
  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isEntry  = movement.type == CambuseMovementType.entree ||
                     movement.type == CambuseMovementType.inventaire;
    final color    = isEntry ? AppTheme.success : AppTheme.error;
    final sign     = isEntry ? '+' : '-';
    final dateFmt  = DateFormat('dd/MM HH:mm', 'fr_FR');

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Icône type
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEntry ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movement.cambuseItemName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$sign${movement.quantity}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      movement.type.label,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    if (movement.orderNumber != null) ...[
                      const Text(' · ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text(
                        movement.orderNumber!,
                        style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 11),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${movement.quantityBefore} → ${movement.quantityAfter}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      movement.createdBy,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                    const Spacer(),
                    Text(
                      dateFmt.format(movement.createdAt),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DIALOGUE — Ajouter / Modifier une boisson
// ════════════════════════════════════════════════════════════════════════════
class _CambuseItemDialog extends StatefulWidget {
  final CambuseItem? existing;
  final Future<void> Function(String name, String category, int qty, int threshold, double price, String productId) onSave;
  final List<Product> products;
  final List<String> availableCategories;

  const _CambuseItemDialog({
    required this.existing,
    required this.onSave,
    required this.products,
    required this.availableCategories,
  });

  @override
  State<_CambuseItemDialog> createState() => _CambuseItemDialogState();
}

class _CambuseItemDialogState extends State<_CambuseItemDialog> {
  final _nameCtrl      = TextEditingController();
  final _qtyCtrl       = TextEditingController(text: '0');
  final _threshCtrl    = TextEditingController(text: '10');
  final _priceCtrl     = TextEditingController(text: '0');
  String _linkedProductId = '';
  String? _selectedCategory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text   = e.name;
      _qtyCtrl.text    = '${e.quantity}';
      _threshCtrl.text = '${e.alertThreshold}';
      _priceCtrl.text  = '${e.sellingPrice.toInt()}';
      _linkedProductId = e.productId ?? '';
      // Retrouver la catégorie existante dans la liste
      _selectedCategory = widget.availableCategories.contains(e.category) ? e.category : null;
    }
    // Si une seule catégorie, pré-sélectionner
    if (_selectedCategory == null && widget.availableCategories.length == 1) {
      _selectedCategory = widget.availableCategories.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _threshCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.liquor, color: Color(0xFF42A5F5)),
          const SizedBox(width: 8),
          Text(
            isEdit ? 'Modifier la boisson' : 'Nouvelle boisson',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FormField(label: 'Nom de la boisson *', controller: _nameCtrl, hint: 'ex: Coca-Cola 33cl'),
              const SizedBox(height: 12),
              // Dropdown catégorie (basé sur les catégories Cambuse créées)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catégorie *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  widget.availableCategories.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: AppTheme.warning, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Créez d\'abord une catégorie dans l\'onglet Catégories',
                                style: TextStyle(color: AppTheme.warning, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            hint: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Sélectionner une catégorie', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ),
                            isExpanded: true,
                            dropdownColor: AppTheme.surface,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            items: widget.availableCategories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            )).toList(),
                            onChanged: (v) => setState(() => _selectedCategory = v),
                          ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _FormField(label: 'Quantité initiale', controller: _qtyCtrl, hint: '0', isNumber: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _FormField(label: 'Seuil d\'alerte', controller: _threshCtrl, hint: '10', isNumber: true)),
                ],
              ),
              const SizedBox(height: 12),
              _FormField(label: 'Prix de vente (F CFA)', controller: _priceCtrl, hint: '0', isNumber: true),
              const SizedBox(height: 12),
              // Liaison produit (optionnel)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lier au produit menu (optionnel)',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _linkedProductId.isEmpty ? null : _linkedProductId,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Aucun lien', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ),
                        isExpanded: true,
                        dropdownColor: AppTheme.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Aucun lien', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ),
                          ...widget.products.map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              p.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                        onChanged: (v) => setState(() => _linkedProductId = v ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Si lié : quand ce produit est vendu, -1 en cambuse automatiquement',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  ),
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
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save, size: 16),
          label: Text(isEdit ? 'Modifier' : 'Créer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name     = _nameCtrl.text.trim();
    final category = _selectedCategory ?? '';
    if (name.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nom et catégorie obligatoires'), backgroundColor: AppTheme.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        name,
        category,
        int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        int.tryParse(_threshCtrl.text.trim()) ?? 10,
        double.tryParse(_priceCtrl.text.trim()) ?? 0,
        _linkedProductId,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Approvisionner depuis la carte boisson ───────────────────────────────
class _ApproDialog extends StatefulWidget {
  final CambuseItem item;
  final Future<void> Function(int qty) onConfirm;
  const _ApproDialog({required this.item, required this.onConfirm});

  @override
  State<_ApproDialog> createState() => _ApproDialogState();
}

class _ApproDialogState extends State<_ApproDialog> {
  final _ctrl = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.add_circle, color: AppTheme.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Approvisionner ${widget.item.name}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Stock actuel : ${widget.item.quantity} unité(s)',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Quantité à ajouter *',
            controller: _ctrl,
            hint: '1',
            isNumber: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : () async {
            final qty = int.tryParse(_ctrl.text.trim()) ?? 0;
            if (qty <= 0) return;
            setState(() => _saving = true);
            await widget.onConfirm(qty);
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Confirmer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB 4 — Catégories Cambuse
// ════════════════════════════════════════════════════════════════════════════
class _CategoriesTab extends StatelessWidget {
  final AppProvider provider;
  const _CategoriesTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final categories = provider.cambuseCategories;
    final items      = provider.cambuseItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, provider),
        backgroundColor: const Color(0xFF42A5F5),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Nouvelle catégorie', style: TextStyle(fontSize: 13)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          // Info banner
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF42A5F5), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${categories.length} catégorie(s) · Utilisées pour organiser vos boissons',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Liste
          Expanded(
            child: categories.isEmpty
              ? const EmptyState(
                  icon: Icons.category,
                  title: 'Aucune catégorie',
                  subtitle: 'Exemples : Bières, Vins, Eau, Jus, Sucreries…',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: categories.length,
                  itemBuilder: (ctx, i) {
                    final cat       = categories[i];
                    final useCount  = items.where((item) => item.category == cat.name).length;
                    return _CategoryCard(
                      category:  cat,
                      useCount:  useCount,
                      onRename:  () => _showRenameDialog(ctx, provider, cat),
                      onDelete:  () => _confirmDelete(ctx, provider, cat, useCount),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  // ── Ajouter ─────────────────────────────────────────────────────────────
  void _showAddDialog(BuildContext context, AppProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: Color(0xFF42A5F5)),
            SizedBox(width: 8),
            Text('Nouvelle catégorie', style: TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: _FormField(
          label: 'Nom de la catégorie *',
          controller: ctrl,
          hint: 'ex: Bières, Vins, Eau, Jus…',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await provider.addCambuseCategory(name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5), foregroundColor: Colors.white),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  // ── Renommer ─────────────────────────────────────────────────────────────
  void _showRenameDialog(BuildContext context, AppProvider provider, CambuseCategory cat) {
    final ctrl = TextEditingController(text: cat.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF42A5F5)),
            SizedBox(width: 8),
            Text('Modifier catégorie', style: TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: _FormField(
          label: 'Nouveau nom *',
          controller: ctrl,
          hint: cat.name,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await provider.renameCambuseCategory(cat.id, name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5), foregroundColor: Colors.white),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
  }

  // ── Supprimer ─────────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, AppProvider provider, CambuseCategory cat, int useCount) {
    if (useCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: AppTheme.warning),
              SizedBox(width: 8),
              Text('Impossible', style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
          content: Text(
            '$useCount boisson(s) utilisent la catégorie "${cat.name}".\nModifiez-les d\'abord.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Supprimer ?', style: TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: Text(
          'Supprimer la catégorie "${cat.name}" ?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteCambuseCategory(cat.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ── Carte catégorie cambuse ────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final CambuseCategory category;
  final int useCount;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.useCount,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Icône
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.local_bar, color: Color(0xFF42A5F5), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Nom + compteur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  useCount == 0 ? 'Aucune boisson' : '$useCount boisson(s)',
                  style: TextStyle(
                    color: useCount > 0 ? AppTheme.textSecondary : AppTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            onPressed: onRename,
            icon: const Icon(Icons.edit, color: Color(0xFF42A5F5), size: 18),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: 'Renommer',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: useCount > 0 ? AppTheme.textSecondary : AppTheme.error, size: 18),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }
}

// ── Widget formulaire champ texte ──────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isNumber;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 12),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
        ),
      ],
    );
  }
}
