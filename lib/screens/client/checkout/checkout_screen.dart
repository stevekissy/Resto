import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_provider.dart';
import '../../../sandbox/client_provider_proxy.dart';
import '../../../models/client_models.dart';
import '../../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CHECKOUT — Panier + Type commande + Adresse + Paiement + Acompte
// ═══════════════════════════════════════════════════════════════════════════

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  ClientPaymentMethod _paymentMethod = ClientPaymentMethod.cashOnDelivery;
  DeliveryAddress? _selectedAddress;
  bool _payDepositNow = false;
  final _notesCtrl = TextEditingController();
  bool _isPlacing = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ClientProviderProxy.watch(context);
    final cart = provider.cart;
    final fmt = NumberFormat('#,###', 'fr_FR');
    final addr = _selectedAddress ?? provider.defaultAddress;
    final settings = provider.settings;

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('Commande', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, color: AppTheme.textSecondary, size: 64),
              SizedBox(height: 16),
              Text('Votre panier est vide', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Valider la commande',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ── Section 1 : Articles ──────────────────────────────────────
          _SectionHeader(icon: Icons.shopping_bag_outlined, title: 'Votre commande (${provider.cartCount} articles)'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A5A)),
            ),
            child: Column(
              children: [
                ...cart.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            // Contrôle quantité
                            Row(
                              children: [
                                _SmallQtyBtn(
                                  icon: Icons.remove,
                                  onTap: () => provider.updateCartQuantity(item.productId, item.quantity - 1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('${item.quantity}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                ),
                                _SmallQtyBtn(
                                  icon: Icons.add,
                                  onTap: () => provider.updateCartQuantity(item.productId, item.quantity + 1),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (item.comment != null && item.comment!.isNotEmpty)
                                    Text(item.comment!,
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        maxLines: 1),
                                ],
                              ),
                            ),
                            Text('${fmt.format(item.totalPrice)} F',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (i < cart.length - 1)
                        const Divider(height: 1, color: Color(0xFF2A2A5A)),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Section 2 : Type livraison ────────────────────────────────
          _SectionHeader(icon: Icons.delivery_dining, title: 'Type de commande'),
          const SizedBox(height: 10),
          Row(
            children: OrderType.values.map((type) {
              final isSelected = provider.orderType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => provider.setOrderType(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: type == OrderType.delivery ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type.icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 22),
                        const SizedBox(width: 8),
                        Text(type.label,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 14,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // ── Section 3 : Adresse (livraison uniquement) ────────────────
          if (provider.orderType == OrderType.delivery) ...[
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.location_on_outlined, title: 'Adresse de livraison'),
            const SizedBox(height: 10),
            if (provider.addresses.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: AppTheme.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Ajoutez une adresse dans votre profil',
                          style: TextStyle(color: AppTheme.warning, fontSize: 13)),
                    ),
                  ],
                ),
              )
            else
              ...provider.addresses.map((a) {
                final isSelected = (addr?.id == a.id);
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAddress = a);
                    provider.setSelectedAddress(a);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : const Color(0xFF2A2A5A),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(a.icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.label,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.primary : Colors.white,
                                    fontWeight: FontWeight.w700, fontSize: 13,
                                  )),
                              Text(a.address,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }),
          ],

          const SizedBox(height: 20),

          // ── Section 4 : Mode de paiement ──────────────────────────────
          _SectionHeader(icon: Icons.payment_outlined, title: 'Mode de paiement'),
          const SizedBox(height: 10),
          ...ClientPaymentMethod.values.map((method) {
            final isSelected = _paymentMethod == method;
            return GestureDetector(
              onTap: () => setState(() => _paymentMethod = method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? method.color.withValues(alpha: 0.1) : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? method.color : const Color(0xFF2A2A5A),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(method.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(method.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          )),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: method.color, size: 20),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // ── Section 5 : Acompte (si requis) ──────────────────────────
          if (settings.depositPercentage > 0 &&
              _paymentMethod != ClientPaymentMethod.cashOnDelivery) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                      SizedBox(width: 8),
                      Text('Acompte requis',
                          style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Un acompte de ${settings.depositPercentage.toInt()}% (${fmt.format(provider.depositAmount)} F) '
                    'est requis pour valider votre commande.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payer l\'acompte maintenant : ${fmt.format(provider.depositAmount)} F',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: _payDepositNow,
                        onChanged: (v) => setState(() => _payDepositNow = v),
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Section 6 : Notes ─────────────────────────────────────────
          _SectionHeader(icon: Icons.note_outlined, title: 'Note pour le restaurant'),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Instructions spéciales, allergies, préférences…',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),

          const SizedBox(height: 20),

          // ── Récap des totaux ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A5A)),
            ),
            child: Column(
              children: [
                _TotalRow('Sous-total', '${fmt.format(provider.cartTotal)} F'),
                if (provider.discountAmount > 0)
                  _TotalRow('Réduction', '-${fmt.format(provider.discountAmount)} F', color: AppTheme.success),
                if (provider.orderType == OrderType.delivery)
                  _TotalRow('Livraison', provider.deliveryFee > 0 ? '${fmt.format(provider.deliveryFee)} F' : 'Gratuite',
                      color: provider.deliveryFee == 0 ? AppTheme.success : null),
                const Divider(height: 16, color: Color(0xFF2A2A5A)),
                _TotalRow('Total', '${fmt.format(provider.finalTotal)} F', bold: true),
                if (_payDepositNow && settings.depositPercentage > 0) ...[
                  const SizedBox(height: 6),
                  _TotalRow('À payer maintenant (acompte)', '${fmt.format(provider.depositAmount)} F',
                      color: AppTheme.warning),
                  _TotalRow('À payer à la livraison', '${fmt.format(provider.remainingAmount)} F',
                      color: AppTheme.textSecondary),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Vous gagnerez ${provider.loyaltyPointsToEarn} points de fidélité',
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      // Bouton commander
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total à payer', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text('${fmt.format(provider.finalTotal)} F',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPlacing ? null : () => _placeOrder(context, provider, addr),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isPlacing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Passer la commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, ClientProviderProxy provider, DeliveryAddress? addr) async {
    // Validation
    if (provider.orderType == OrderType.delivery && addr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une adresse de livraison'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPlacing = true);
    try {
      final orderId = await provider.placeOrder(
        paymentMethod: _paymentMethod,
        deliveryAddress: addr,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        payDepositNow: _payDepositNow,
      );

      if (orderId != null && mounted) {
        _showOrderSuccess(context, orderId);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la commande. Veuillez réessayer.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  void _showOrderSuccess(BuildContext context, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Commande passée !',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Votre commande a été envoyée au restaurant. Vous serez notifié dès qu\'elle sera prise en charge.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // ferme dialog
                Navigator.pop(context); // ferme checkout
                Navigator.pop(context); // ferme menu
              },
              child: const Text('Suivre ma commande'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _TotalRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: bold ? Colors.white : AppTheme.textSecondary,
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              )),
          Text(value,
              style: TextStyle(
                color: color ?? (bold ? AppTheme.primary : Colors.white),
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _SmallQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallQtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 16),
      ),
    );
  }
}
