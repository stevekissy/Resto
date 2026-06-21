import '../models/client_models.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SANDBOX DATA — Toutes les données de démonstration en mémoire
// Zéro Firebase, zéro impact sur la production
// ═══════════════════════════════════════════════════════════════════════════

class SandboxData {
  // ── Compte de démonstration ────────────────────────────────────────────
  static final ClientUser demoClient = ClientUser(
    id: 'sandbox_demo_001',
    name: 'Kouamé Démo',
    email: 'demo@sankadiokro.ci',
    phone: '+225 07 00 00 00',
    isActive: true,
    loyaltyPoints: 450,
    totalOrders: 12,
    totalSpent: 84500,
    favoriteProductIds: ['prod_001', 'prod_003', 'prod_006'],
    createdAt: DateTime.now().subtract(const Duration(days: 45)),
  );

  // ── Produits du menu (données réalistes) ───────────────────────────────
  static final List<Product> products = [
    Product(id: 'prod_001', name: 'Attiéké Poisson', category: 'Plats locaux',    price: 2500,  isAvailable: true,  prepTime: 15, description: 'Attiéké avec poisson braisé, tomate et oignons'),
    Product(id: 'prod_002', name: 'Riz au Sauce',    category: 'Plats locaux',    price: 2000,  isAvailable: true,  prepTime: 12, description: 'Riz blanc avec sauce tomate maison et poulet'),
    Product(id: 'prod_003', name: 'Aloco Poulet',    category: 'Plats locaux',    price: 3000,  isAvailable: true,  prepTime: 20, description: 'Bananes plantains frites avec poulet grillé'),
    Product(id: 'prod_004', name: 'Foutou Soupe',    category: 'Plats locaux',    price: 3500,  isAvailable: true,  prepTime: 25, description: 'Foutou banane avec soupe graine traditionnelle'),
    Product(id: 'prod_005', name: 'Garba',           category: 'Plats locaux',    price: 1500,  isAvailable: true,  prepTime: 8,  description: 'Attiéké avec thon frit, le classique populaire'),
    Product(id: 'prod_006', name: 'Brochettes Mix',  category: 'Grillades',       price: 4000,  isAvailable: true,  prepTime: 20, description: 'Brochettes bœuf et poulet marinés, sauce pimentée'),
    Product(id: 'prod_007', name: 'Grillades Bœuf',  category: 'Grillades',       price: 5500,  isAvailable: true,  prepTime: 30, description: 'Côte de bœuf grillée aux épices, accompagnement inclus'),
    Product(id: 'prod_008', name: 'Poulet DG',       category: 'Grillades',       price: 4500,  isAvailable: true,  prepTime: 25, description: 'Poulet sauté au beurre avec légumes sautés'),
    Product(id: 'prod_009', name: 'Jus Gingembre',   category: 'Boissons',        price: 800,   isAvailable: true,  prepTime: 3,  description: 'Jus de gingembre frais fait maison'),
    Product(id: 'prod_010', name: 'Bissap Glacé',    category: 'Boissons',        price: 700,   isAvailable: true,  prepTime: 3,  description: 'Infusion de fleurs d\'hibiscus refroidie'),
    Product(id: 'prod_011', name: 'Eau Minérale',    category: 'Boissons',        price: 500,   isAvailable: true,  prepTime: 1,  description: 'Eau minérale fraîche 1.5L'),
    Product(id: 'prod_012', name: 'Café Ivoirien',   category: 'Boissons',        price: 600,   isAvailable: true,  prepTime: 5,  description: 'Café arabica de Côte d\'Ivoire, servi chaud'),
    Product(id: 'prod_013', name: 'Tarte Ananas',    category: 'Desserts',        price: 1200,  isAvailable: true,  prepTime: 5,  description: 'Tarte maison à l\'ananas Victoria frais'),
    Product(id: 'prod_014', name: 'Beignets Sucre',  category: 'Desserts',        price: 800,   isAvailable: true,  prepTime: 10, description: 'Beignets chauds au sucre glace, 6 pièces'),
    Product(id: 'prod_015', name: 'Salade César',    category: 'Entrées',         price: 2200,  isAvailable: true,  prepTime: 8,  description: 'Salade romaine, croûtons, parmesan, sauce César'),
  ];

  // ── Adresses de livraison ──────────────────────────────────────────────
  static final List<DeliveryAddress> addresses = [
    DeliveryAddress(
      id: 'addr_001',
      label: 'Maison',
      address: 'Yopougon, Quartier Millionnaire, Rue 14',
      details: 'Maison bleue, portail vert',
      latitude: 5.3717,
      longitude: -4.0422,
      isDefault: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    DeliveryAddress(
      id: 'addr_002',
      label: 'Bureau',
      address: 'Plateau, Avenue Noguès, Immeuble SGBCI',
      details: '3ème étage, bureau 302',
      latitude: 5.3167,
      longitude: -4.0167,
      isDefault: false,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  // ── Promotions actives ─────────────────────────────────────────────────
  static final List<Promotion> promotions = [
    Promotion(
      id: 'promo_001',
      title: 'Happy Hour Midi',
      description: '-15% sur toutes les boissons de 12h à 14h',
      type: PromotionType.percentage,
      value: 15,
      minOrder: 2000,
      isActive: true,
      code: 'MIDI15',
      validUntil: DateTime.now().add(const Duration(days: 30)),
    ),
    Promotion(
      id: 'promo_002',
      title: 'Bienvenue !',
      description: '500 FCFA offerts sur votre première commande',
      type: PromotionType.fixedAmount,
      value: 500,
      minOrder: 3000,
      isActive: true,
      code: 'BIENVENUE',
      validUntil: DateTime.now().add(const Duration(days: 60)),
    ),
    Promotion(
      id: 'promo_003',
      title: 'Livraison Gratuite',
      description: 'Livraison offerte tous les vendredis',
      type: PromotionType.freeDelivery,
      value: 0,
      isActive: true,
      validUntil: DateTime.now().add(const Duration(days: 90)),
    ),
  ];

  // ── Historique de fidélité ──────────────────────────────────────────────
  static List<LoyaltyTransaction> loyaltyHistory = [
    LoyaltyTransaction(
      id: 'tx_001',
      clientId: 'sandbox_demo_001',
      type: LoyaltyType.earn,
      points: 85,
      description: 'Points gagnés sur commande #1038',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      orderId: 'order_sandbox_004',
    ),
    LoyaltyTransaction(
      id: 'tx_002',
      clientId: 'sandbox_demo_001',
      type: LoyaltyType.earn,
      points: 120,
      description: 'Points gagnés sur commande #1035',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      orderId: 'order_sandbox_003',
    ),
    LoyaltyTransaction(
      id: 'tx_003',
      clientId: 'sandbox_demo_001',
      type: LoyaltyType.redeem,
      points: -200,
      description: 'Réduction appliquée — commande #1030',
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      orderId: 'order_sandbox_002',
    ),
    LoyaltyTransaction(
      id: 'tx_004',
      clientId: 'sandbox_demo_001',
      type: LoyaltyType.bonus,
      points: 50,
      description: 'Bonus inscription',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    LoyaltyTransaction(
      id: 'tx_005',
      clientId: 'sandbox_demo_001',
      type: LoyaltyType.earn,
      points: 395,
      description: 'Points cumulés — commandes précédentes',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];

  // ── Commandes de démonstration ─────────────────────────────────────────
  static List<ClientOrder> _buildOrders() {
    return [
      // Commande livrée (historique)
      ClientOrder(
        id: 'order_sandbox_001',
        clientId: 'sandbox_demo_001',
        clientName: 'Kouamé Démo',
        clientPhone: '+225 07 00 00 00',
        items: [
          CartItem(productId: 'prod_001', productName: 'Attiéké Poisson', categoryName: 'Plats locaux', unitPrice: 2500, quantity: 2),
          CartItem(productId: 'prod_009', productName: 'Jus Gingembre', categoryName: 'Boissons', unitPrice: 800, quantity: 2),
        ],
        status: ClientOrderStatus.delivered,
        orderType: OrderType.delivery,
        deliveryAddress: addresses[0],
        paymentMethod: ClientPaymentMethod.orangeMoney,
        paymentStatus: ClientPaymentStatus.fullyPaid,
        totalAmount: 6600,
        deliveryFee: 1000,
        depositAmount: 2280,
        remainingAmount: 0,
        loyaltyPointsEarned: 76,
        orderNumber: '#1035',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      // Commande livrée (historique)
      ClientOrder(
        id: 'order_sandbox_002',
        clientId: 'sandbox_demo_001',
        clientName: 'Kouamé Démo',
        clientPhone: '+225 07 00 00 00',
        items: [
          CartItem(productId: 'prod_006', productName: 'Brochettes Mix', categoryName: 'Grillades', unitPrice: 4000, quantity: 1),
          CartItem(productId: 'prod_010', productName: 'Bissap Glacé', categoryName: 'Boissons', unitPrice: 700, quantity: 3),
        ],
        status: ClientOrderStatus.delivered,
        orderType: OrderType.takeaway,
        paymentMethod: ClientPaymentMethod.cashOnDelivery,
        paymentStatus: ClientPaymentStatus.fullyPaid,
        totalAmount: 6100,
        deliveryFee: 0,
        depositAmount: 0,
        remainingAmount: 0,
        loyaltyPointsEarned: 61,
        orderNumber: '#1038',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  static List<ClientOrder> get initialOrders => _buildOrders();

  // ── Paramètres en ligne ────────────────────────────────────────────────
  static final OnlineOrderSettings settings = OnlineOrderSettings(
    isOnlineOrderEnabled: true,
    depositPercentage: 30,
    deliveryFeeBase: 1000,
    minimumOrderAmount: 2000,
    estimatedDeliveryMinutes: 35,
    estimatedTakeawayMinutes: 15,
    loyaltyPointsPerFCFA: 100,
    loyaltyPointValue: 5,
    restaurantPhone: '+225 27 22 00 00',
    restaurantAddress: 'Yopougon Millionnaire, Abidjan',
    deliveryZones: ['Yopougon', 'Cocody', 'Plateau', 'Marcory', 'Treichville'],
  );

  // ── Scénarios de test disponibles ──────────────────────────────────────
  static const List<SandboxScenario> scenarios = [
    SandboxScenario(
      id: 'scenario_order_delivery',
      title: 'Commande Livraison complète',
      description: 'Parcours complet : sélectionner des plats → choisir livraison → payer acompte → suivre en temps réel',
      icon: '🛵',
      steps: [
        'Ouvrir le Menu',
        'Ajouter 2 plats au panier',
        'Choisir "Livraison" et sélectionner une adresse',
        'Payer l\'acompte de 30% via Orange Money',
        'Suivre la progression : Reçue → Validée → En préparation → Prête → En livraison → Livrée',
        'Vérifier les points de fidélité crédités',
      ],
      estimatedMinutes: 5,
      color: 0xFF2196F3,
    ),
    SandboxScenario(
      id: 'scenario_order_takeaway',
      title: 'Commande À Emporter',
      description: 'Commander à emporter sans frais de livraison avec paiement à la caisse',
      icon: '🛍️',
      steps: [
        'Ouvrir le Menu',
        'Ajouter des plats au panier',
        'Choisir "À emporter"',
        'Payer à la caisse (sans acompte)',
        'Suivre : Reçue → Prête (20 min)',
      ],
      estimatedMinutes: 3,
      color: 0xFF4CAF50,
    ),
    SandboxScenario(
      id: 'scenario_promo_code',
      title: 'Application Code Promo',
      description: 'Tester un code promo au checkout et voir la réduction appliquée',
      icon: '🎫',
      steps: [
        'Ajouter des articles (min 3 000 F)',
        'Au checkout, appliquer le code MIDI15',
        'Vérifier que -15% est appliqué sur le total',
        'Finaliser la commande avec réduction',
      ],
      estimatedMinutes: 2,
      color: 0xFFFF9800,
    ),
    SandboxScenario(
      id: 'scenario_loyalty',
      title: 'Fidélité & Réductions',
      description: 'Gagner des points sur une commande, puis utiliser les points sur la suivante',
      icon: '⭐',
      steps: [
        'Passer une commande (gagner des points)',
        'Consulter le solde de points dans Profil',
        'Utiliser les points comme réduction',
        'Vérifier le nouveau solde',
      ],
      estimatedMinutes: 4,
      color: 0xFFFFB300,
    ),
    SandboxScenario(
      id: 'scenario_tracking',
      title: 'Suivi de Livraison',
      description: 'Simuler la progression d\'une commande à travers les 6 étapes de statut',
      icon: '📍',
      steps: [
        'Créer une commande livraison',
        'Simuler : Reçue → Validée',
        'Simuler : Validée → En préparation',
        'Simuler : En préparation → Prête',
        'Simuler : Prête → En livraison (livreur assigné)',
        'Simuler : En livraison → Livrée',
      ],
      estimatedMinutes: 3,
      color: 0xFF9C27B0,
    ),
    SandboxScenario(
      id: 'scenario_cancel',
      title: 'Annulation de Commande',
      description: 'Tester l\'annulation d\'une commande en attente',
      icon: '❌',
      steps: [
        'Passer une commande (statut Reçue)',
        'Ouvrir les détails de la commande',
        'Appuyer sur "Annuler la commande"',
        'Confirmer l\'annulation',
        'Vérifier le statut "Annulée" dans l\'historique',
      ],
      estimatedMinutes: 2,
      color: 0xFFF44336,
    ),
  ];
}

// ── Modèle scénario ────────────────────────────────────────────────────────────

class SandboxScenario {
  final String id;
  final String title;
  final String description;
  final String icon;
  final List<String> steps;
  final int estimatedMinutes;
  final int color;

  const SandboxScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    required this.estimatedMinutes,
    required this.color,
  });
}
