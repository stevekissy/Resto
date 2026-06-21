import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ACCOUNTING SERVICE — Lecture directe Firestore pour la comptabilité
// Toutes les données viennent des collections réelles, sans démo
// ═══════════════════════════════════════════════════════════════════════════

class AccountingService {
  static final AccountingService _instance = AccountingService._();
  factory AccountingService() => _instance;
  AccountingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Filtre temporel ────────────────────────────────────────────────────
  static DateRange rangeForPeriod(AccountingPeriod period, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    switch (period) {
      case AccountingPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return DateRange(start, start.add(const Duration(days: 1)));
      case AccountingPeriod.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(DateTime(start.year, start.month, start.day), now);
      case AccountingPeriod.month:
        return DateRange(DateTime(now.year, now.month, 1), now);
      case AccountingPeriod.quarter:
        final q = ((now.month - 1) ~/ 3);
        return DateRange(DateTime(now.year, q * 3 + 1, 1), now);
      case AccountingPeriod.year:
        return DateRange(DateTime(now.year, 1, 1), now);
      case AccountingPeriod.custom:
        return DateRange(customStart ?? DateTime(now.year, now.month, 1), customEnd ?? now);
    }
  }

  // ── Calcul principal — charge tout en parallèle ───────────────────────
  Future<AccountingReport> buildReport(DateRange range) async {
    debugPrint('[AccountingService] buildReport ${range.start} → ${range.end}');

    final results = await Future.wait([
      _fetchSettlementInvoices(range),     // 0
      _fetchCashReports(range),            // 1
      _fetchDailyCharges(range),           // 2
      _fetchSupplierOrders(range),         // 3
      _fetchSupplierPayments(range),       // 4
      _fetchSalaries(range),               // 5
      _fetchSalaryPayments(range),         // 6
      _fetchReservationPayments(range),    // 7
      _fetchStockValue(),                  // 8
      _fetchStockMovementsLoss(range),     // 9
    ]);

    final invoices          = results[0] as List<Map<String, dynamic>>;
    final cashReports       = results[1] as List<Map<String, dynamic>>;
    final dailyCharges      = results[2] as List<Map<String, dynamic>>;
    final supplierOrders    = results[3] as List<SupplierOrder>;
    final supplierPayments  = results[4] as List<SupplierPayment>;
    final salaries          = results[5] as List<EmployeeSalary>;
    final salaryPayments    = results[6] as List<SalaryPayment>;
    final resvPayments      = results[7] as List<ReservationPayment>;
    final stockValue        = results[8] as double;
    final stockLoss         = results[9] as double;

    // ── PRODUITS ──────────────────────────────────────────────────────────
    // Chiffre d'affaires restaurant (settlement_invoices.amountDue)
    final caRestaurant = invoices.fold<double>(
        0, (s, d) => s + ((d['amountDue'] as num?)?.toDouble() ?? 0));

    // Recettes effectivement encaissées (cash_reports.amount)
    final recettesEncaissees = cashReports.fold<double>(
        0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));

    // Revenus réservations payés sur la période
    final caReservations = resvPayments.fold<double>(0, (s, p) => s + p.montant);

    final totalProduits = caRestaurant + caReservations;

    // ── CHARGES ───────────────────────────────────────────────────────────
    // Achats marchandises fournisseurs (commandes passées dans la période)
    final achatsFournisseurs = supplierOrders.fold<double>(0, (s, o) => s + o.totalAmount);

    // Paiements réels fournisseurs sur la période
    final paiementsFournisseurs = supplierPayments.fold<double>(0, (s, p) => s + p.amount);

    // Salaires nets à payer (fiches de la période)
    final salairesBruts = salaries.fold<double>(0, (s, e) => s + e.brut);
    final salairesPayes = salaryPayments.fold<double>(0, (s, p) => s + p.montant);
    final salairesDus   = salaries.fold<double>(0, (s, e) => s + e.netAPayer) - salairesPayes;

    // Charges du jour
    final chargesJour = dailyCharges.fold<double>(
        0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));

    final totalCharges = achatsFournisseurs + salairesBruts + chargesJour + stockLoss;

    // ── RÉSULTAT ──────────────────────────────────────────────────────────
    final margeB = totalProduits > 0
        ? ((totalProduits - achatsFournisseurs) / totalProduits * 100)
        : 0.0;
    final margeN = totalProduits > 0
        ? ((totalProduits - totalCharges) / totalProduits * 100)
        : 0.0;
    final resultatNet = totalProduits - totalCharges;

    // ── BILAN ACTIF ───────────────────────────────────────────────────────
    // Caisse disponible = recettes - paiements fournisseurs - salaires payés - charges
    final caisse = recettesEncaissees + caReservations - paiementsFournisseurs - salairesPayes - chargesJour;

    // Créances clients = CA facturé - encaissé
    final creancesClients = ((caRestaurant - recettesEncaissees).clamp(0, double.infinity) as num).toDouble();

    // ── BILAN PASSIF ──────────────────────────────────────────────────────
    final dettesFournisseurs = supplierOrders.fold<double>(0, (s, o) => s + o.remainingAmount);

    // ── ALERTES ───────────────────────────────────────────────────────────
    final alerts = <AccountingAlert>[];

    if (resultatNet < 0) {
      alerts.add(AccountingAlert(
        type: AlertType.danger,
        message: 'Résultat net négatif : ${_f(resultatNet)} F CFA. Le restaurant est en perte sur cette période.',
        icon: '🔴',
      ));
    }
    if (dettesFournisseurs > caisse && caisse > 0) {
      alerts.add(AccountingAlert(
        type: AlertType.warning,
        message: 'Dettes fournisseurs (${_f(dettesFournisseurs)} F) supérieures à la caisse disponible.',
        icon: '⚠️',
      ));
    }
    if (dettesFournisseurs > totalProduits * 0.3) {
      alerts.add(AccountingAlert(
        type: AlertType.warning,
        message: 'Dettes fournisseurs élevées : ${_f(dettesFournisseurs)} F (${(dettesFournisseurs/totalProduits*100).toStringAsFixed(1)}% du CA).',
        icon: '⚠️',
      ));
    }
    if (salairesDus > 0) {
      alerts.add(AccountingAlert(
        type: AlertType.warning,
        message: 'Salaires impayés : ${_f(salairesDus)} F CFA restants à verser.',
        icon: '👥',
      ));
    }
    if (stockValue < 50000) {
      alerts.add(AccountingAlert(
        type: AlertType.info,
        message: 'Stock valorisé faible : ${_f(stockValue)} F CFA. Risque de rupture.',
        icon: '📦',
      ));
    }
    if (achatsFournisseurs > totalProduits * 0.5 && totalProduits > 0) {
      alerts.add(AccountingAlert(
        type: AlertType.warning,
        message: 'Achats fournisseurs représentent ${(achatsFournisseurs/totalProduits*100).toStringAsFixed(1)}% du CA (seuil 50%).',
        icon: '🛒',
      ));
    }
    if (chargesJour > totalProduits * 0.2 && totalProduits > 0) {
      alerts.add(AccountingAlert(
        type: AlertType.info,
        message: 'Dépenses diverses élevées : ${_f(chargesJour)} F (${(chargesJour/totalProduits*100).toStringAsFixed(1)}% du CA).',
        icon: '💸',
      ));
    }

    return AccountingReport(
      range:                range,
      // Produits
      caRestaurant:         caRestaurant,
      caReservations:       caReservations,
      totalProduits:        totalProduits,
      recettesEncaissees:   recettesEncaissees,
      // Charges
      achatsFournisseurs:   achatsFournisseurs,
      paiementsFournisseurs: paiementsFournisseurs,
      salairesBruts:        salairesBruts,
      salairesPayes:        salairesPayes,
      chargesJour:          chargesJour,
      pertesStock:          stockLoss,
      totalCharges:         totalCharges,
      // Résultat
      resultatNet:          resultatNet,
      margeBrute:           margeB.toDouble(),
      margeNette:           margeN.toDouble(),
      // Bilan actif
      caisse:               (caisse.clamp(0, double.infinity) as num).toDouble(),
      creancesClients:      creancesClients,
      stockValue:           stockValue,
      // Bilan passif
      dettesFournisseurs:   dettesFournisseurs,
      salairesDus:          (salairesDus.clamp(0, double.infinity) as num).toDouble(),
      // Détails
      nbFactures:           invoices.length,
      nbCommandesFournisseurs: supplierOrders.length,
      nbSalaries:           salaries.length,
      nbChargesJour:        dailyCharges.length,
      // Alertes
      alerts:               alerts,
      // Données brutes pour drill-down
      dailyChargesDetail:   dailyCharges,
      supplierOrdersDetail: supplierOrders,
    );
  }

  // ── Fetchers Firestore ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchSettlementInvoices(DateRange r) async {
    try {
      final snap = await _db.collection('settlement_invoices')
          .where('settledAtMs', isGreaterThanOrEqualTo: r.start.millisecondsSinceEpoch)
          .where('settledAtMs', isLessThanOrEqualTo: r.end.millisecondsSinceEpoch)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('[accounting] settlement_invoices: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCashReports(DateRange r) async {
    try {
      final snap = await _db.collection('cash_reports')
          .where('settledAtMs', isGreaterThanOrEqualTo: r.start.millisecondsSinceEpoch)
          .where('settledAtMs', isLessThanOrEqualTo: r.end.millisecondsSinceEpoch)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('[accounting] cash_reports: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDailyCharges(DateRange r) async {
    try {
      final snap = await _db.collection('daily_charges').get();
      return snap.docs.map((d) => d.data()).where((d) {
        final raw = d['createdAt'];
        DateTime? dt;
        if (raw is Timestamp) dt = raw.toDate();
        else if (raw is String) dt = DateTime.tryParse(raw);
        else if (raw is int) dt = DateTime.fromMillisecondsSinceEpoch(raw);
        if (dt == null) return true; // inclure si date inconnue
        return !dt.isBefore(r.start) && dt.isBefore(r.end);
      }).toList();
    } catch (e) {
      debugPrint('[accounting] daily_charges: $e');
      return [];
    }
  }

  Future<List<SupplierOrder>> _fetchSupplierOrders(DateRange r) async {
    try {
      final snap = await _db.collection('supplier_orders').get();
      return snap.docs.map((d) => SupplierOrder.fromMap(d.data())).where((o) {
        final dt = o.createdAt ?? o.orderDate;
        return !dt.isBefore(r.start) && dt.isBefore(r.end);
      }).toList();
    } catch (e) {
      debugPrint('[accounting] supplier_orders: $e');
      return [];
    }
  }

  Future<List<SupplierPayment>> _fetchSupplierPayments(DateRange r) async {
    try {
      final snap = await _db.collection('supplier_payments').get();
      return snap.docs.map((d) => SupplierPayment.fromMap(d.data())).where((p) {
        return !p.paymentDate.isBefore(r.start) && p.paymentDate.isBefore(r.end);
      }).toList();
    } catch (e) {
      debugPrint('[accounting] supplier_payments: $e');
      return [];
    }
  }

  Future<List<EmployeeSalary>> _fetchSalaries(DateRange r) async {
    try {
      final snap = await _db.collection('employee_salaries').get();
      return snap.docs.map((d) => EmployeeSalary.fromMap(d.data(), d.id)).where((s) {
        final d = DateTime(s.annee, s.mois, 1);
        return !d.isBefore(r.start) && d.isBefore(r.end.add(const Duration(days: 31)));
      }).toList();
    } catch (e) {
      debugPrint('[accounting] employee_salaries: $e');
      return [];
    }
  }

  Future<List<SalaryPayment>> _fetchSalaryPayments(DateRange r) async {
    try {
      final snap = await _db.collection('salary_payments').get();
      return snap.docs.map((d) => SalaryPayment.fromMap(d.data(), d.id)).where((p) {
        return !p.date.isBefore(r.start) && p.date.isBefore(r.end);
      }).toList();
    } catch (e) {
      debugPrint('[accounting] salary_payments: $e');
      return [];
    }
  }

  Future<List<ReservationPayment>> _fetchReservationPayments(DateRange r) async {
    try {
      final snap = await _db.collection('reservation_payments').get();
      return snap.docs.map((d) => ReservationPayment.fromMap(d.data(), d.id)).where((p) {
        return !p.date.isBefore(r.start) && p.date.isBefore(r.end);
      }).toList();
    } catch (e) {
      debugPrint('[accounting] reservation_payments: $e');
      return [];
    }
  }

  Future<double> _fetchStockValue() async {
    try {
      final snap = await _db.collection('stock').get();
      return snap.docs.fold<double>(0, (s, d) {
        final qty  = (d.data()['currentQuantity'] as num?)?.toDouble() ?? 0;
        final cost = (d.data()['unitCost'] as num?)?.toDouble() ?? 0;
        return s + qty * cost;
      });
    } catch (e) {
      debugPrint('[accounting] stock value: $e');
      return 0;
    }
  }

  Future<double> _fetchStockMovementsLoss(DateRange r) async {
    try {
      final snap = await _db.collection('stock_movements')
          .where('type', whereIn: ['loss', 'waste', 'adjustment', 'perte', 'dechet'])
          .get();
      return snap.docs.fold<double>(0, (s, d) {
        final data = d.data();
        final raw = data['createdAt'];
        DateTime? dt;
        if (raw is Timestamp) dt = raw.toDate();
        else if (raw is String) dt = DateTime.tryParse(raw);
        if (dt == null || dt.isBefore(r.start) || dt.isAfter(r.end)) return s;
        final qty  = ((data['quantity'] as num?)?.toDouble() ?? 0).abs();
        final cost = (data['unitCost'] as num?)?.toDouble() ?? 0;
        return s + qty * cost;
      });
    } catch (e) {
      debugPrint('[accounting] stock_movements loss: $e');
      return 0;
    }
  }

  String _f(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Types de données comptables ────────────────────────────────────────────

enum AccountingPeriod { today, week, month, quarter, year, custom }

extension AccountingPeriodX on AccountingPeriod {
  String get label {
    switch (this) {
      case AccountingPeriod.today:   return "Aujourd'hui";
      case AccountingPeriod.week:    return 'Cette semaine';
      case AccountingPeriod.month:   return 'Ce mois';
      case AccountingPeriod.quarter: return 'Ce trimestre';
      case AccountingPeriod.year:    return 'Cette année';
      case AccountingPeriod.custom:  return 'Personnalisée';
    }
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);
}

enum AlertType { danger, warning, info }

class AccountingAlert {
  final AlertType type;
  final String message;
  final String icon;
  const AccountingAlert({required this.type, required this.message, required this.icon});
}

class AccountingReport {
  final DateRange range;
  // Produits
  final double caRestaurant;
  final double caReservations;
  final double totalProduits;
  final double recettesEncaissees;
  // Charges
  final double achatsFournisseurs;
  final double paiementsFournisseurs;
  final double salairesBruts;
  final double salairesPayes;
  final double chargesJour;
  final double pertesStock;
  final double totalCharges;
  // Résultat
  final double resultatNet;
  final double margeBrute;
  final double margeNette;
  // Bilan
  final double caisse;
  final double creancesClients;
  final double stockValue;
  final double dettesFournisseurs;
  final double salairesDus;
  // Stats
  final int nbFactures;
  final int nbCommandesFournisseurs;
  final int nbSalaries;
  final int nbChargesJour;
  // Alertes
  final List<AccountingAlert> alerts;
  // Bruts pour drill-down
  final List<Map<String, dynamic>> dailyChargesDetail;
  final List<SupplierOrder> supplierOrdersDetail;

  const AccountingReport({
    required this.range,
    required this.caRestaurant,
    required this.caReservations,
    required this.totalProduits,
    required this.recettesEncaissees,
    required this.achatsFournisseurs,
    required this.paiementsFournisseurs,
    required this.salairesBruts,
    required this.salairesPayes,
    required this.chargesJour,
    required this.pertesStock,
    required this.totalCharges,
    required this.resultatNet,
    required this.margeBrute,
    required this.margeNette,
    required this.caisse,
    required this.creancesClients,
    required this.stockValue,
    required this.dettesFournisseurs,
    required this.salairesDus,
    required this.nbFactures,
    required this.nbCommandesFournisseurs,
    required this.nbSalaries,
    required this.nbChargesJour,
    required this.alerts,
    required this.dailyChargesDetail,
    required this.supplierOrdersDetail,
  });

  bool get isRentable => resultatNet >= 0;
  double get totalActif  => caisse + creancesClients + stockValue;
  double get totalPassif => dettesFournisseurs + salairesDus;
  double get equilibre   => totalActif - totalPassif;

  String get santeFinanciere {
    if (resultatNet < 0) return 'Critique';
    if (margeBrute < 20) return 'Critique';
    if (margeNette < 5)  return 'Moyenne';
    if (margeNette < 15) return 'Bonne';
    return 'Excellente';
  }
}
