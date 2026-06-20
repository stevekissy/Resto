// ============================================================================
//  ai_analytics_service.dart
//  Service d'analyse IA Restaurant — données 100 % Firestore, 0 données démo.
//  Lit : orders, settlement_invoices, cashout_invoices, cash_reports,
//        stock, stock_movements, menu, daily_charges, suppliers, supplier_orders
// ============================================================================
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Modèles de résultats
// ─────────────────────────────────────────────────────────────────────────────

enum AlertSeverity { critical, warning, info }

class AiAlert {
  final String title;
  final String detail;
  final AlertSeverity severity;
  const AiAlert({required this.title, required this.detail, required this.severity});
}

class AiRecommendation {
  final String title;
  final String detail;
  final String category; // 'stock','ventes','cuisine','caisse','service'
  const AiRecommendation({required this.title, required this.detail, required this.category});
}

class AiPrediction {
  final String title;
  final String value;
  final bool hasEnoughData;
  const AiPrediction({required this.title, required this.value, this.hasEnoughData = true});
}

class StockInsight {
  final String itemName;
  final double currentQty;
  final double minQty;
  final String unit;
  final StockInsightType type;
  final double? recommendedQty;
  const StockInsight({
    required this.itemName, required this.currentQty, required this.minQty,
    required this.unit, required this.type, this.recommendedQty,
  });
}

enum StockInsightType { critical, nearAlert, orderSoon }

class KitchenInsight {
  final double avgPrepMinutes;
  final int lateOrdersCount;
  final List<String> slowestDishes;
  final String performanceLabel;
  const KitchenInsight({
    required this.avgPrepMinutes, required this.lateOrdersCount,
    required this.slowestDishes, required this.performanceLabel,
  });
}

class DailyKpi {
  final double revenueToday;
  final double revenueWeek;
  final double revenueMonth;
  final int ordersToday;
  final int ordersServedToday;
  final int ordersCancelledToday;
  final double avgPrepMinutes;
  final double grossRevenue;     // settlement_invoices
  final double totalCharges;     // daily_charges
  final double netRevenue;
  final Map<String, int> topProducts;
  final Map<String, double> revenueByCategory;
  final Map<String, int> ordersByHour;
  final Map<String, double> revenueByPayment;
  final double revenueVsLastWeekPct; // +/- %
  const DailyKpi({
    required this.revenueToday, required this.revenueWeek, required this.revenueMonth,
    required this.ordersToday, required this.ordersServedToday, required this.ordersCancelledToday,
    required this.avgPrepMinutes, required this.grossRevenue, required this.totalCharges,
    required this.netRevenue, required this.topProducts, required this.revenueByCategory,
    required this.ordersByHour, required this.revenueByPayment, required this.revenueVsLastWeekPct,
  });
}

class AiAnalysisResult {
  final DailyKpi kpi;
  final List<AiAlert> alerts;
  final List<AiRecommendation> recommendations;
  final List<AiPrediction> predictions;
  final List<StockInsight> stockInsights;
  final KitchenInsight kitchenInsight;
  final String dailySummary;
  final DateTime computedAt;

  const AiAnalysisResult({
    required this.kpi, required this.alerts, required this.recommendations,
    required this.predictions, required this.stockInsights, required this.kitchenInsight,
    required this.dailySummary, required this.computedAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Service principal
// ─────────────────────────────────────────────────────────────────────────────

class AiAnalyticsService {
  static final AiAnalyticsService _instance = AiAnalyticsService._internal();
  factory AiAnalyticsService() => _instance;
  AiAnalyticsService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Helpers timestamp
  DateTime _dt(dynamic v, {DateTime? fallback}) {
    if (v == null) return fallback ?? DateTime(2000);
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return fallback ?? DateTime(2000);
  }
  bool _isToday(DateTime dt) {
    final n = DateTime.now();
    return dt.year == n.year && dt.month == n.month && dt.day == n.day;
  }
  bool _isThisWeek(DateTime dt) {
    final n = DateTime.now();
    final start = n.subtract(Duration(days: n.weekday - 1));
    final startDay = DateTime(start.year, start.month, start.day);
    return !dt.isBefore(startDay);
  }
  bool _isThisMonth(DateTime dt) {
    final n = DateTime.now();
    return dt.year == n.year && dt.month == n.month;
  }
  bool _isLastWeek(DateTime dt) {
    final n = DateTime.now();
    final thisWeekStart = n.subtract(Duration(days: n.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    return !dt.isBefore(DateTime(lastWeekStart.year, lastWeekStart.month, lastWeekStart.day)) &&
        dt.isBefore(DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day));
  }

  // ──────────────────────────────────────────────────────────────────
  //  Point d'entrée principal
  // ──────────────────────────────────────────────────────────────────
  Future<AiAnalysisResult> compute({
    required List<Order> liveOrders,
    required List<StockItem> stockItems,
    required List<Product> products,
    required List<Map<String, dynamic>> dailyCharges,
  }) async {
    try {
      // 1. Lectures Firestore parallèles
      final results = await Future.wait([
        _fetchSettlementInvoices(),
        _fetchCashoutInvoices(),
        _fetchStockMovements7Days(),
        _fetchSupplierOrders(),
      ]);

      final settlementInvoices = results[0] as List<Map<String, dynamic>>;
      final cashoutInvoices    = results[1] as List<Map<String, dynamic>>;
      final stockMoves         = results[2] as List<Map<String, dynamic>>;
      final supplierOrds       = results[3] as List<Map<String, dynamic>>;

      // 2. Calculs KPI
      final kpi = _computeKpi(
        liveOrders: liveOrders,
        settlementInvoices: settlementInvoices,
        dailyCharges: dailyCharges,
        products: products,
      );

      // 3. Analyses
      final stockInsights  = _analyzeStock(stockItems, stockMoves);
      final kitchenInsight = _analyzeKitchen(liveOrders);
      final alerts         = _buildAlerts(kpi, stockInsights, kitchenInsight, liveOrders);
      final recs           = _buildRecommendations(kpi, stockInsights, kitchenInsight, liveOrders, supplierOrds);
      final preds          = _buildPredictions(kpi, settlementInvoices, liveOrders, stockInsights);
      final summary        = _buildSummary(kpi, alerts, stockInsights);

      return AiAnalysisResult(
        kpi: kpi, alerts: alerts, recommendations: recs,
        predictions: preds, stockInsights: stockInsights,
        kitchenInsight: kitchenInsight,
        dailySummary: summary, computedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AiAnalytics] compute error: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────
  //  Lectures Firestore
  // ──────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchSettlementInvoices() async {
    final snap = await _db.collection('settlement_invoices').limit(500).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchCashoutInvoices() async {
    final snap = await _db.collection('cashout_invoices').limit(500).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchStockMovements7Days() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final snap = await _db.collection('stock_movements')
        .where('createdAt', isGreaterThan: since.millisecondsSinceEpoch)
        .limit(500)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchSupplierOrders() async {
    final snap = await _db.collection('supplier_orders').limit(200).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ──────────────────────────────────────────────────────────────────
  //  KPI
  // ──────────────────────────────────────────────────────────────────
  DailyKpi _computeKpi({
    required List<Order> liveOrders,
    required List<Map<String, dynamic>> settlementInvoices,
    required List<Map<String, dynamic>> dailyCharges,
    required List<Product> products,
  }) {
    // ── Revenu depuis settlement_invoices (source de vérité) ──
    double revToday = 0, revWeek = 0, revMonth = 0, revLastWeek = 0;
    final paymentMap = <String, double>{};

    for (final inv in settlementInvoices) {
      final tsRaw = inv['settledAtMs'] ?? inv['settledAt'];
      final dt = _dt(tsRaw);
      final amount = (inv['totalAmount'] as num?)?.toDouble()
          ?? (inv['amountDue']  as num?)?.toDouble() ?? 0;
      final method = (inv['paymentMethod'] as String?) ?? 'Espèces';

      if (_isToday(dt)) {
        revToday += amount;
        paymentMap[method] = (paymentMap[method] ?? 0) + amount;
      }
      if (_isThisWeek(dt))  revWeek  += amount;
      if (_isThisMonth(dt)) revMonth += amount;
      if (_isLastWeek(dt))  revLastWeek += amount;
    }

    // ── Commandes du jour (live) ──
    final todayOrders = liveOrders.where((o) => _isToday(o.createdAt)).toList();
    final servedToday = todayOrders.where((o) => o.status == OrderStatus.served).length;
    final cancelledToday = liveOrders
        .where((o) => o.status == OrderStatus.cancelled && _isToday(o.cancelledAt ?? o.createdAt)).length;

    // ── Préparation moyenne (toutes commandes avec startedAt + readyAt) ──
    final prepDone = liveOrders
        .where((o) => o.startedAt != null && o.readyAt != null)
        .toList();
    final avgPrep = prepDone.isEmpty
        ? 0.0
        : prepDone.fold(0.0, (s, o) => s + o.readyAt!.difference(o.startedAt!).inMinutes)
            / prepDone.length;

    // ── Charges du jour ──
    final charges = dailyCharges.fold<double>(
      0.0, (s, c) => s + ((c['amount'] as num?)?.toDouble() ?? 0));

    // ── Top produits (commandes servies, toutes périodes) ──
    final topProd = <String, int>{};
    for (final o in liveOrders.where((o) => o.status == OrderStatus.served)) {
      for (final item in o.items) {
        topProd[item.productName] = (topProd[item.productName] ?? 0) + item.quantity;
      }
    }
    final sortedTop = topProd.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // ── CA par catégorie (commandes servies/payées live) ──
    final catRev = <String, double>{};
    for (final o in liveOrders.where((o) => o.isPaid || o.status == OrderStatus.served)) {
      for (final item in o.items) {
        try {
          final p = products.firstWhere((prod) => prod.id == item.productId);
          catRev[p.category] = (catRev[p.category] ?? 0) + item.totalPrice;
        } catch (_) {
          catRev['Autres'] = (catRev['Autres'] ?? 0) + item.totalPrice;
        }
      }
    }

    // ── Commandes par heure (aujourd'hui) ──
    final byHour = <String, int>{};
    for (final o in todayOrders) {
      final h = '${o.createdAt.hour}h';
      byHour[h] = (byHour[h] ?? 0) + 1;
    }

    // ── Variation vs semaine dernière ──
    double vsLastWeekPct = 0;
    if (revLastWeek > 0) {
      vsLastWeekPct = ((revWeek - revLastWeek) / revLastWeek) * 100;
    }

    return DailyKpi(
      revenueToday: revToday,
      revenueWeek: revWeek,
      revenueMonth: revMonth,
      ordersToday: todayOrders.length,
      ordersServedToday: servedToday,
      ordersCancelledToday: cancelledToday,
      avgPrepMinutes: avgPrep,
      grossRevenue: revToday,
      totalCharges: charges,
      netRevenue: revToday - charges,
      topProducts: Map.fromEntries(sortedTop.take(8)),
      revenueByCategory: catRev,
      ordersByHour: byHour,
      revenueByPayment: paymentMap,
      revenueVsLastWeekPct: vsLastWeekPct,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  Analyse Stock
  // ──────────────────────────────────────────────────────────────────
  List<StockInsight> _analyzeStock(
    List<StockItem> items,
    List<Map<String, dynamic>> moves,
  ) {
    final insights = <StockInsight>[];

    // Calculer vitesse de consommation des 7 derniers jours
    final consumption = <String, double>{};
    for (final m in moves) {
      final type = m['type'] as String? ?? '';
      if (type == 'deduction' || type == 'deduct' || type == 'consumption') {
        final id  = m['stockItemId'] as String? ?? '';
        final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
        consumption[id] = (consumption[id] ?? 0) + qty;
      }
    }

    for (final item in items) {
      final dailyRate = (consumption[item.id] ?? 0) / 7.0; // unités/jour

      if (item.isOut) {
        insights.add(StockInsight(
          itemName: item.name, currentQty: item.currentQuantity,
          minQty: item.minQuantity, unit: item.unit,
          type: StockInsightType.critical,
          recommendedQty: dailyRate > 0 ? dailyRate * 14 : item.minQuantity * 3,
        ));
      } else if (item.isLow) {
        insights.add(StockInsight(
          itemName: item.name, currentQty: item.currentQuantity,
          minQty: item.minQuantity, unit: item.unit,
          type: StockInsightType.nearAlert,
          recommendedQty: dailyRate > 0 ? dailyRate * 14 : item.minQuantity * 2,
        ));
      } else if (dailyRate > 0) {
        final daysLeft = item.currentQuantity / dailyRate;
        if (daysLeft < 7) {
          insights.add(StockInsight(
            itemName: item.name, currentQty: item.currentQuantity,
            minQty: item.minQuantity, unit: item.unit,
            type: StockInsightType.orderSoon,
            recommendedQty: dailyRate * 14,
          ));
        }
      }
    }

    // Trier : critique en premier
    insights.sort((a, b) => a.type.index.compareTo(b.type.index));
    return insights;
  }

  // ──────────────────────────────────────────────────────────────────
  //  Analyse Cuisine
  // ──────────────────────────────────────────────────────────────────
  KitchenInsight _analyzeKitchen(List<Order> orders) {
    final done = orders.where((o) => o.startedAt != null && o.readyAt != null).toList();
    final avgMin = done.isEmpty
        ? 0.0
        : done.fold(0.0, (s, o) => s + o.readyAt!.difference(o.startedAt!).inMinutes) / done.length;

    // Commandes en retard = en préparation depuis > 25 min
    final lateCount = orders
        .where((o) =>
          o.status == OrderStatus.preparing &&
          DateTime.now().difference(o.startedAt ?? o.createdAt).inMinutes > 25)
        .length;

    // Plats lents (temps moyen > 20 min)
    final dishTimes = <String, List<int>>{};
    for (final o in done) {
      final mins = o.readyAt!.difference(o.startedAt!).inMinutes;
      for (final item in o.items) {
        dishTimes[item.productName] ??= [];
        dishTimes[item.productName]!.add(mins);
      }
    }
    final avgByDish = dishTimes.map((k, v) => MapEntry(
        k, v.fold(0, (s, x) => s + x) / v.length));
    final slow = avgByDish.entries
        .where((e) => e.value > 20)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final slowDishes = slow.take(3).map((e) => e.key).toList();

    String perfLabel;
    if (avgMin == 0)      perfLabel = 'Pas encore de données';
    else if (avgMin < 10) perfLabel = 'Excellente';
    else if (avgMin < 18) perfLabel = 'Bonne';
    else if (avgMin < 25) perfLabel = 'À améliorer';
    else                  perfLabel = 'Lente — intervention requise';

    return KitchenInsight(
      avgPrepMinutes: avgMin, lateOrdersCount: lateCount,
      slowestDishes: slowDishes, performanceLabel: perfLabel,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  Alertes
  // ──────────────────────────────────────────────────────────────────
  List<AiAlert> _buildAlerts(
    DailyKpi kpi,
    List<StockInsight> stock,
    KitchenInsight kitchen,
    List<Order> orders,
  ) {
    final alerts = <AiAlert>[];

    // Stock critique
    final critical = stock.where((s) => s.type == StockInsightType.critical).toList();
    if (critical.isNotEmpty) {
      alerts.add(AiAlert(
        title: 'Rupture de stock',
        detail: critical.map((s) => '${s.itemName} (${s.currentQty} ${s.unit})').join(', '),
        severity: AlertSeverity.critical,
      ));
    }

    // Stock bas
    final low = stock.where((s) => s.type == StockInsightType.nearAlert).toList();
    if (low.isNotEmpty) {
      alerts.add(AiAlert(
        title: 'Stock bas — à réapprovisionner',
        detail: low.map((s) => s.itemName).join(', '),
        severity: AlertSeverity.warning,
      ));
    }

    // Stock bientôt épuisé (< 7 jours)
    final soon = stock.where((s) => s.type == StockInsightType.orderSoon).toList();
    if (soon.isNotEmpty) {
      alerts.add(AiAlert(
        title: 'Commande fournisseur recommandée',
        detail: '${soon.map((s) => s.itemName).join(', ')} — moins de 7 jours de stock',
        severity: AlertSeverity.info,
      ));
    }

    // Commandes en retard
    if (kitchen.lateOrdersCount > 0) {
      alerts.add(AiAlert(
        title: 'Commandes en retard en cuisine',
        detail: '${kitchen.lateOrdersCount} commande(s) en préparation depuis plus de 25 min',
        severity: kitchen.lateOrdersCount >= 3 ? AlertSeverity.critical : AlertSeverity.warning,
      ));
    }

    // Annulations élevées
    if (kpi.ordersCancelledToday > 2) {
      alerts.add(AiAlert(
        title: 'Taux d\'annulation élevé',
        detail: '${kpi.ordersCancelledToday} annulations aujourd\'hui — vérifier les causes',
        severity: AlertSeverity.warning,
      ));
    }

    // Recette nette négative
    if (kpi.netRevenue < 0) {
      alerts.add(AiAlert(
        title: 'Recette nette négative',
        detail: 'Les charges (${kpi.totalCharges.toStringAsFixed(0)} F) dépassent le CA du jour',
        severity: AlertSeverity.critical,
      ));
    }

    // Baisse de ventes vs semaine dernière
    if (kpi.revenueVsLastWeekPct < -20) {
      alerts.add(AiAlert(
        title: 'Baisse des ventes hebdomadaires',
        detail: 'CA en baisse de ${kpi.revenueVsLastWeekPct.abs().toStringAsFixed(0)} % vs semaine dernière',
        severity: AlertSeverity.warning,
      ));
    }

    return alerts;
  }

  // ──────────────────────────────────────────────────────────────────
  //  Recommandations
  // ──────────────────────────────────────────────────────────────────
  List<AiRecommendation> _buildRecommendations(
    DailyKpi kpi,
    List<StockInsight> stock,
    KitchenInsight kitchen,
    List<Order> orders,
    List<Map<String, dynamic>> supplierOrds,
  ) {
    final recs = <AiRecommendation>[];

    // Top plats → à préparer à l'avance
    if (kpi.topProducts.isNotEmpty) {
      final top3 = kpi.topProducts.keys.take(3).join(', ');
      recs.add(AiRecommendation(
        title: 'Préparer à l\'avance',
        detail: 'Vos plats les plus commandés : $top3. Préparez les sauces et bases avant le service.',
        category: 'cuisine',
      ));
    }

    // Catégorie la plus rentable
    if (kpi.revenueByCategory.isNotEmpty) {
      final bestCat = kpi.revenueByCategory.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      recs.add(AiRecommendation(
        title: 'Catégorie la plus rentable',
        detail: '${bestCat.key} génère ${bestCat.value.toStringAsFixed(0)} F CFA. Renforcer l\'offre dans cette catégorie.',
        category: 'ventes',
      ));
    }

    // Heures de pointe réelles
    if (kpi.ordersByHour.isNotEmpty) {
      final sorted = kpi.ordersByHour.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final peakHours = sorted.take(2).map((e) => e.key).join(' et ');
      if (peakHours.isNotEmpty) {
        recs.add(AiRecommendation(
          title: 'Heures de forte affluence',
          detail: 'Pics de commandes constatés à $peakHours. Assurez un effectif complet à ces horaires.',
          category: 'service',
        ));
      }
    }

    // Stock à commander
    final needOrder = stock.where((s) =>
        s.type == StockInsightType.critical || s.type == StockInsightType.nearAlert).toList();
    if (needOrder.isNotEmpty) {
      final lines = needOrder.map((s) {
        final qty = s.recommendedQty;
        return qty != null
            ? '${s.itemName} (commander ~${qty.toStringAsFixed(0)} ${s.unit})'
            : s.itemName;
      }).join(', ');
      recs.add(AiRecommendation(
        title: 'Réapprovisionnement urgent',
        detail: 'Contacter vos fournisseurs pour : $lines.',
        category: 'stock',
      ));
    }

    // Performance cuisine
    if (kitchen.avgPrepMinutes > 20) {
      recs.add(AiRecommendation(
        title: 'Optimiser la vitesse de préparation',
        detail: 'Temps moyen : ${kitchen.avgPrepMinutes.toStringAsFixed(0)} min. '
            '${kitchen.slowestDishes.isNotEmpty ? "Plats lents : ${kitchen.slowestDishes.join(', ')}." : ""} '
            'Envisager une mise en place anticipée.',
        category: 'cuisine',
      ));
    }

    // Mode de paiement dominant
    if (kpi.revenueByPayment.isNotEmpty) {
      final dominant = kpi.revenueByPayment.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      recs.add(AiRecommendation(
        title: 'Mode de paiement dominant',
        detail: '${dominant.key} représente ${dominant.value.toStringAsFixed(0)} F CFA du CA du jour. '
            'Assurez la disponibilité de monnaie ou le terminal.',
        category: 'caisse',
      ));
    }

    // Fournisseurs impayés
    final unpaid = supplierOrds.where((o) {
      final status = o['paymentStatus'] as int? ?? 0;
      return status == 0; // unpaid
    }).toList();
    if (unpaid.isNotEmpty) {
      recs.add(AiRecommendation(
        title: 'Factures fournisseurs en attente',
        detail: '${unpaid.length} commande(s) fournisseur non réglée(s). Vérifier avant nouvelle commande.',
        category: 'stock',
      ));
    }

    return recs;
  }

  // ──────────────────────────────────────────────────────────────────
  //  Prédictions (basées sur historique réel)
  // ──────────────────────────────────────────────────────────────────
  List<AiPrediction> _buildPredictions(
    DailyKpi kpi,
    List<Map<String, dynamic>> settlementInvoices,
    List<Order> orders,
    List<StockInsight> stock,
  ) {
    final preds = <AiPrediction>[];
    const minData = 'Données insuffisantes pour prédiction fiable.';

    // ── Prédiction CA demain (moyenne 7 j) ──
    final last7 = <double>[];
    for (var i = 1; i <= 7; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final rev = settlementInvoices
          .where((inv) {
            final ts = inv['settledAtMs'] ?? inv['settledAt'];
            final dt = _dt(ts);
            return dt.year == d.year && dt.month == d.month && dt.day == d.day;
          })
          .fold<double>(0.0, (s, inv) =>
              s + ((inv['totalAmount'] as num?)?.toDouble()
                 ?? (inv['amountDue']  as num?)?.toDouble() ?? 0));
      if (rev > 0) last7.add(rev);
    }

    if (last7.length < 3) {
      preds.add(const AiPrediction(
        title: 'CA prévu demain', value: minData, hasEnoughData: false));
    } else {
      final avg7 = last7.fold(0.0, (s, v) => s + v) / last7.length;
      preds.add(AiPrediction(
        title: 'CA prévu demain',
        value: '~${avg7.toStringAsFixed(0)} F CFA (moy. 7 jours : ${last7.length} jours)',
      ));
    }

    // ── Heure de pointe prédite ──
    final hourCounts = <int, int>{};
    for (final o in orders) {
      if (_isThisWeek(o.createdAt) || _isLastWeek(o.createdAt)) {
        hourCounts[o.createdAt.hour] = (hourCounts[o.createdAt.hour] ?? 0) + 1;
      }
    }
    if (hourCounts.length < 3) {
      preds.add(const AiPrediction(
        title: 'Heure de forte affluence prévue', value: minData, hasEnoughData: false));
    } else {
      final sorted = hourCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final peakH = sorted.take(2).map((e) => '${e.key}h00').join(' et ');
      preds.add(AiPrediction(
        title: 'Heure de forte affluence prévue',
        value: peakH,
      ));
    }

    // ── Produits à risque rapide ──
    final criticalStock = stock.where((s) => s.type == StockInsightType.critical).toList();
    if (criticalStock.isNotEmpty) {
      preds.add(AiPrediction(
        title: 'Rupture imminente',
        value: criticalStock.map((s) => '${s.itemName} (${s.currentQty} ${s.unit} restants)').join(', '),
      ));
    }

    // ── Tendance ventes semaine ──
    if (kpi.revenueWeek == 0 && kpi.revenueToday == 0) {
      preds.add(const AiPrediction(
        title: 'Tendance ventes hebdomadaire', value: minData, hasEnoughData: false));
    } else {
      final trend = kpi.revenueVsLastWeekPct;
      final label = trend > 0
          ? '↑ +${trend.toStringAsFixed(0)} % vs semaine dernière'
          : trend < 0
              ? '↓ ${trend.toStringAsFixed(0)} % vs semaine dernière'
              : 'Stable vs semaine dernière';
      preds.add(AiPrediction(title: 'Tendance ventes hebdomadaire', value: label));
    }

    // ── Plats à fort risque de rupture ──
    final nearAlerts = stock.where((s) => s.type == StockInsightType.orderSoon).toList();
    if (nearAlerts.isNotEmpty) {
      preds.add(AiPrediction(
        title: 'Stock à commander cette semaine',
        value: nearAlerts.map((s) => s.itemName).join(', '),
      ));
    }

    return preds;
  }

  // ──────────────────────────────────────────────────────────────────
  //  Résumé intelligent du jour
  // ──────────────────────────────────────────────────────────────────
  String _buildSummary(
    DailyKpi kpi,
    List<AiAlert> alerts,
    List<StockInsight> stock,
  ) {
    final parts = <String>[];

    if (kpi.revenueToday > 0) {
      parts.add('CA du jour : ${kpi.revenueToday.toStringAsFixed(0)} F CFA '
          '(${kpi.ordersToday} commande${kpi.ordersToday > 1 ? 's' : ''}, '
          '${kpi.ordersServedToday} servie${kpi.ordersServedToday > 1 ? 's' : ''}).');
    } else {
      parts.add('Aucun règlement enregistré aujourd\'hui.');
    }

    if (kpi.netRevenue > 0) {
      parts.add('Recette nette : ${kpi.netRevenue.toStringAsFixed(0)} F CFA '
          'après ${kpi.totalCharges.toStringAsFixed(0)} F de charges.');
    }

    final critCount = alerts.where((a) => a.severity == AlertSeverity.critical).length;
    if (critCount > 0) {
      parts.add('$critCount alerte${critCount > 1 ? 's' : ''} critique${critCount > 1 ? 's' : ''} à traiter.');
    }

    final critStock = stock.where((s) => s.type == StockInsightType.critical).length;
    if (critStock > 0) {
      parts.add('$critStock article${critStock > 1 ? 's' : ''} en rupture de stock.');
    }

    if (kpi.topProducts.isNotEmpty) {
      parts.add('Meilleur plat : ${kpi.topProducts.keys.first}.');
    }

    return parts.join(' ');
  }
}
