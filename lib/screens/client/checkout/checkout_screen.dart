import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_provider.dart';
import '../../../sandbox/client_provider_proxy.dart';
import '../../../models/client_models.dart';
import '../../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CHECKOUT — Panier + Type commande + Adresse + Paiement + Acompte + Fidélité
// ═══════════════════════════════════════════════════════════════════════════

class CheckoutScreen extends StatefulWidget {
  final VoidCallback? onGoHome;
  const CheckoutScreen({super.key, this.onGoHome});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Mode de paiement de l'acompte (mobile money uniquement)
  ClientPaymentMethod _depositMethod = ClientPaymentMethod.wave;
  DeliveryAddress? _selectedAddress;
  final _notesCtrl = TextEditingController();
  final _deliveryNoteCtrl = TextEditingController();
  bool _isPlacing = false;

  // Points fidélité
  int _loyaltyPointsToUse = 0;
  bool _useLoyaltyPoints = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _deliveryNoteCtrl.dispose();
    super.dispose();
  }

  // Modes de paiement autorisés pour l'acompte (Mobile Money uniquement)
  static const _depositMethods = [
    ClientPaymentMethod.wave,
    ClientPaymentMethod.orangeMoney,
    ClientPaymentMethod.mtnMoney,
    ClientPaymentMethod.moovMoney,
  ];

  @override
  Widget build(BuildContext context) {
    final provider = ClientProviderProxy.watch(context);
    final cart = provider.cart;
    final fmt = NumberFormat('#,###', 'fr_FR');
    final addr = _selectedAddress ?? provider.defaultAddress;
    final settings = provider.settings;

    // Calculs avec réduction fidélité
    final loyaltyDiscAmt = _useLoyaltyPoints
        ? provider.loyaltyDiscount(_loyaltyPointsToUse)
        : 0.0;
    final baseTotal = provider.cartTotal - provider.discountAmount;
    final totalAfterLoyalty = baseTotal - loyaltyDiscAmt;
    final depositAmt = settings.depositRequired
        ? settings.computeDeposit(totalAfterLoyalty)
        : 0.0;
    final remaining = totalAfterLoyalty - depositAmt;
    final clientPoints = provider.client?.loyaltyPoints ?? 0;

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
        actions: [
          if (widget.onGoHome != null)
            IconButton(
              icon: const Icon(Icons.home_outlined, color: Colors.white),
              tooltip: 'Accueil',
              onPressed: () {
                Navigator.pop(context);
                widget.onGoHome!();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
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

          // ── Section 2 : Type de commande ──────────────────────────────
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

          // ── Section 3 : Adresse + Message Yango (livraison) ───────────
          if (provider.orderType == OrderType.delivery) ...[
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.location_on_outlined, title: 'Adresse de livraison'),
            const SizedBox(height: 10),

            // Bandeau informatif Yango
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF57C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF57C00).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('🚗', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Livraison par Yango',
                                style: TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.w800, fontSize: 13)),
                            Text('Partenaire de livraison officiel',
                                style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ℹ️ Les frais de livraison sont définis par Yango et seront payés directement au livreur.',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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

            // Note pour le livreur Yango
            const SizedBox(height: 10),
            TextField(
              controller: _deliveryNoteCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Indication pour le livreur Yango (repère, étage…)',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                prefixIcon: const Icon(Icons.delivery_dining, color: Color(0xFFF57C00), size: 20),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A2A5A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A2A5A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF57C00), width: 1.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Section 4 : Points fidélité (si disponibles) ──────────────
          if (clientPoints >= settings.minLoyaltyPointsToUse) ...[
            _SectionHeader(icon: Icons.stars_rounded, title: 'Points fidélité'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Text('Utiliser mes points ($clientPoints pts disponibles)',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Switch(
                        value: _useLoyaltyPoints,
                        onChanged: (v) => setState(() {
                          _useLoyaltyPoints = v;
                          if (!v) _loyaltyPointsToUse = 0;
                        }),
                        activeColor: Colors.amber,
                      ),
                    ],
                  ),
                  if (_useLoyaltyPoints) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_loyaltyPointsToUse} points → -${fmt.format(provider.loyaltyDiscount(_loyaltyPointsToUse))} F',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          '1 pt = ${settings.loyaltyPointValue} F',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    Slider(
                      value: _loyaltyPointsToUse.toDouble(),
                      min: 0,
                      max: clientPoints.toDouble(),
                      divisions: clientPoints > 0 ? clientPoints : 1,
                      activeColor: Colors.amber,
                      label: '$_loyaltyPointsToUse pts',
                      onChanged: (v) => setState(() => _loyaltyPointsToUse = v.toInt()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('0 pts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        Text('$clientPoints pts max', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Section 5 : Mode de paiement ACOMPTE obligatoire ─────────
          _SectionHeader(icon: Icons.account_balance_wallet_outlined, title: 'Paiement de l\'acompte'),
          const SizedBox(height: 10),
          if (settings.depositRequired) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, color: AppTheme.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Acompte obligatoire : ${fmt.format(depositAmt)} F',
                          style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    settings.depositType == DepositType.percentage
                        ? 'Soit ${settings.depositPercentage.toInt()}% du montant total'
                        : 'Montant fixe défini par le restaurant',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ La commande ne peut pas être confirmée sans payer l\'acompte.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Choisissez votre mode de paiement Mobile Money :',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            ..._depositMethods.map((method) {
              final isSelected = _depositMethod == method;
              return GestureDetector(
                onTap: () => setState(() => _depositMethod = method),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? method.color.withValues(alpha: 0.12) : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? method.color : const Color(0xFF2A2A5A),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(method.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(method.label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 14,
                                )),
                            if (isSelected)
                              Text(
                                'Acompte : ${fmt.format(depositAmt)} F',
                                style: TextStyle(color: method.color, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: method.color, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            // Acompte non requis : choix libre
            ..._depositMethods.map((method) {
              final isSelected = _depositMethod == method;
              return GestureDetector(
                onTap: () => setState(() => _depositMethod = method),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? method.color.withValues(alpha: 0.12) : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? method.color : const Color(0xFF2A2A5A),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(method.icon, style: const TextStyle(fontSize: 22)),
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
          ],

          const SizedBox(height: 20),

          // ── Section 6 : Note pour le restaurant ──────────────────────
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
                  _TotalRow('Réduction promo', '-${fmt.format(provider.discountAmount)} F', color: AppTheme.success),
                if (_useLoyaltyPoints && loyaltyDiscAmt > 0)
                  _TotalRow('Réduction fidélité ($_loyaltyPointsToUse pts)', '-${fmt.format(loyaltyDiscAmt)} F', color: Colors.amber),
                // Livraison Yango — note spéciale
                if (provider.orderType == OrderType.delivery)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Livraison Yango',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF57C00).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Yango',
                                  style: TextStyle(color: Color(0xFFF57C00), fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const Text('Payé au livreur',
                            style: TextStyle(color: Color(0xFFF57C00), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const Divider(height: 16, color: Color(0xFF2A2A5A)),
                _TotalRow('Total restaurant', '${fmt.format(totalAfterLoyalty)} F', bold: true),
                if (settings.depositRequired) ...[
                  const SizedBox(height: 6),
                  _TotalRow('Acompte à payer maintenant', '${fmt.format(depositAmt)} F',
                      color: AppTheme.warning),
                  _TotalRow('Reste à payer au restaurant', '${fmt.format(remaining)} F',
                      color: AppTheme.textSecondary),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
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
      // ── Bouton commander ──────────────────────────────────────────────────
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
            // Résumé paiement
            if (settings.depositRequired) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Acompte à payer', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('${fmt.format(depositAmt)} F via ${_depositMethod.label}',
                      style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total restaurant', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text('${fmt.format(totalAfterLoyalty)} F',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPlacing ? null : () => _placeOrder(context, provider, addr,
                    depositAmt: depositAmt, loyaltyDiscAmt: loyaltyDiscAmt),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isPlacing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            settings.depositRequired
                                ? 'Confirmer & payer ${fmt.format(depositAmt)} F'
                                : 'Passer la commande',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(
    BuildContext context,
    ClientProviderProxy provider,
    DeliveryAddress? addr, {
    required double depositAmt,
    required double loyaltyDiscAmt,
  }) async {
    final settings = provider.settings;

    // Validation adresse livraison
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

    // Si acompte obligatoire, il n'y a pas de blocage supplémentaire
    // car l'acompte est toujours payé (mode sélectionné par défaut)

    setState(() => _isPlacing = true);
    try {
      final orderId = await provider.placeOrder(
        paymentMethod: _depositMethod,
        deliveryAddress: addr,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        payDepositNow: settings.depositRequired, // toujours vrai si acompte requis
        loyaltyPointsUsed: _useLoyaltyPoints ? _loyaltyPointsToUse : 0,
        deliveryNote: _deliveryNoteCtrl.text.trim().isEmpty ? null : _deliveryNoteCtrl.text.trim(),
      );

      if (orderId != null && mounted) {
        _showOrderSuccess(context, orderId, depositAmt);
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

  void _showOrderSuccess(BuildContext context, String orderId, double depositAmt) {
    final fmt = NumberFormat('#,###', 'fr_FR');
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
            if (depositAmt > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Acompte : ${fmt.format(depositAmt)} F',
                      style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'via ${_depositMethod.label}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                Navigator.pop(context);  // ferme dialog
                Navigator.pop(context);  // ferme checkout
                widget.onGoHome?.call();
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
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: bold ? Colors.white : AppTheme.textSecondary,
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                )),
          ),
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
