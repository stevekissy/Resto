import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_provider.dart';
import '../../../sandbox/client_provider_proxy.dart';
import '../../../models/models.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/product_image_widget.dart';
import '../checkout/checkout_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MENU CLIENT — Catégories + Grille produits + Panier flottant
// ═══════════════════════════════════════════════════════════════════════════

class ClientMenuScreen extends StatefulWidget {
  final VoidCallback? onGoHome;
  const ClientMenuScreen({super.key, this.onGoHome});

  @override
  State<ClientMenuScreen> createState() => _ClientMenuScreenState();
}

class _ClientMenuScreenState extends State<ClientMenuScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'Tous';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ClientProviderProxy.watch(context);
    final allProducts = provider.products;
    final categories = ['Tous', ...provider.categories];
    final cartCount = provider.cartCount;
    final cartTotal = provider.cartTotal;
    final fmt = NumberFormat('#,###', 'fr_FR');

    // Filtrer produits
    List<Product> filtered = allProducts;
    if (_selectedCategory != 'Tous') {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          tooltip: 'Retour à l\'accueil',
          onPressed: widget.onGoHome,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            tooltip: 'Accueil',
            onPressed: widget.onGoHome,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Barre de recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A5A)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un plat…',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              // Onglets catégories
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: allProducts.isEmpty
          ? const _EmptyMenu()
          : filtered.isEmpty
              ? _NoResults(query: _searchQuery)
              : GridView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, cartCount > 0 ? 88 : 30),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _ProductCard(product: filtered[i]),
                ),
      // Bouton panier flottant — compact, safe-area, ombre discrète
      floatingActionButton: cartCount > 0
          ? SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () => _openCheckout(context),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 46,                        // réduit de ~30 %
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF0D47A1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                      const BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 5,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Badge compteur
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Label
                        const Expanded(
                          child: Text(
                            'Voir le panier',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Montant
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${fmt.format(cartTotal)} F',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _openCheckout(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CheckoutScreen(onGoHome: widget.onGoHome),
    ));
  }
}

// ── Carte produit ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final provider = ClientProviderProxy.watch(context);
    final fmt = NumberFormat('#,###', 'fr_FR');
    final cartItem = provider.cart.where((i) => i.productId == product.id).isNotEmpty
        ? provider.cart.firstWhere((i) => i.productId == product.id)
        : null;
    final qty = cartItem?.quantity ?? 0;
    final isFav = provider.isFavorite(product.id);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0 ? AppTheme.primary.withValues(alpha: 0.5) : const Color(0xFF2A2A5A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / icône
          Stack(
            children: [
              ProductImage(
                imageUrl: product.imageUrl,
                height: 100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                iconSize: 36,
              ),
              // Badge favori
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => provider.toggleFavorite(product.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.background.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : AppTheme.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
              ),
              // Badge catégorie
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(product.category,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ),
              ),
            ],
          ),
          // Infos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${fmt.format(product.price)} F',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                      // Contrôle quantité
                      if (qty == 0)
                        GestureDetector(
                          onTap: () {
                            provider.addToCart(product);
                            _showAddedSnack(context, product.name);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        )
                      else
                        Row(
                          children: [
                            _QtyBtn(
                              icon: Icons.remove,
                              onTap: () => provider.updateCartQuantity(product.id, qty - 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('$qty',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                            _QtyBtn(
                              icon: Icons.add,
                              onTap: () => provider.updateCartQuantity(product.id, qty + 1),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddedSnack(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name ajouté au panier', style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 14),
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, color: AppTheme.textSecondary, size: 64),
          SizedBox(height: 16),
          Text('Menu en chargement…', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          SizedBox(height: 8),
          Text('Les plats apparaîtront ici', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: AppTheme.textSecondary, size: 56),
          const SizedBox(height: 16),
          Text('Aucun résultat pour "$query"',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Essayez un autre mot-clé ou une autre catégorie',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
