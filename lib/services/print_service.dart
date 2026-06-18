import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

// Import conditionnel : dart:js uniquement sur web
// ignore: uri_does_not_exist
import 'print_web_stub.dart'
    if (dart.library.js) 'print_web_impl.dart' as print_web;

/// ══════════════════════════════════════════════════════════════════════
///  PrintService — Service d'impression de reçus thermiques 80mm
///  - Web   : génère un HTML 80mm + window.print() dans nouvelle fenêtre
///  - Mobile: lance le dialogue d'impression système via window.print fallback
/// ══════════════════════════════════════════════════════════════════════
class PrintService {
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  final _fmt = NumberFormat('#,###', 'fr_FR');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  // ─────────────────────────────────────────────────────────────────────
  //  FACTURE D'ENCAISSEMENT PROVISOIRE (Étape 1)
  //  N'inclut PAS les informations de paiement.
  //  Titre : "FACTURE D'ENCAISSEMENT" (provisoire)
  // ─────────────────────────────────────────────────────────────────────
  void printCashoutInvoice({
    required Order order,
    required String cashoutInvoiceNumber,
    String? cashierName,
  }) {
    final html = _buildCashoutHtml(
      order: order,
      cashoutInvoiceNumber: cashoutInvoiceNumber,
      cashierName: cashierName,
    );
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: facture encaissement #$cashoutInvoiceNumber');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  FACTURE DE RÈGLEMENT DÉFINITIVE (Étape 2)
  //  Inclut : mode paiement, montant payé, monnaie rendue, caissier.
  //  Titre : "FACTURE DE RÈGLEMENT" (définitif)
  // ─────────────────────────────────────────────────────────────────────
  void printSettlementInvoice({
    required Order order,
    required String settlementInvoiceNumber,
    required String paymentMethod,
    required double amountPaid,
    required double changeAmount,
    String? cashierName,
  }) {
    final html = _buildSettlementHtml(
      order: order,
      settlementInvoiceNumber: settlementInvoiceNumber,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      cashierName: cashierName,
    );
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: règlement #$settlementInvoiceNumber');
    }
  }

  /// Retourne le HTML de la facture définitive SANS ouvrir la fenêtre d'impression.
  /// Utilisé par le bouton "Imprimer la facture définitive" affiché après règlement.
  String buildSettlementHtmlForDisplay({
    required Order order,
    required String settlementInvoiceNumber,
    required String paymentMethod,
    required double amountPaid,
    required double changeAmount,
    String? cashierName,
  }) {
    return _buildSettlementHtml(
      order: order,
      settlementInvoiceNumber: settlementInvoiceNumber,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      cashierName: cashierName,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  3. REÇU D'ENCAISSEMENT (méthode héritée — conservée)
  // ─────────────────────────────────────────────────────────────────────
  void printEncaissement({
    required Order order,
    required double amountPaid,
    required String receiptNumber,
    String? cashierName,
  }) {
    final html = _buildEncaissementHtml(
      order: order,
      amountPaid: amountPaid,
      receiptNumber: receiptNumber,
      cashierName: cashierName,
    );

    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      // Sur mobile, on génère le même HTML et on utilise url_launcher
      // ou simplement on affiche le reçu dans une WebView
      // Pour l'instant : appel window.print() via JS si disponible
      if (kDebugMode) debugPrint('[PrintService] Mobile: impression encaissement #$receiptNumber');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  2. REÇU DE RÈGLEMENT CAISSE
  // ─────────────────────────────────────────────────────────────────────
  void printReglement({
    required Order order,
    required double amountPaid,
    required String settlementNumber,
    String? cashierName,
  }) {
    final html = _buildReglementHtml(
      order: order,
      amountPaid: amountPaid,
      settlementNumber: settlementNumber,
      cashierName: cashierName,
    );

    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: impression règlement #$settlementNumber');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  BUILD HTML — Facture d'Encaissement PROVISOIRE (80mm)
  //  Étape 1 : affiche commande + total, PAS de détails paiement
  // ─────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────
  //  BUILD HTML — Facture d'Encaissement PROVISOIRE (80mm)
  //  Étape 1 : commande + total, PAS de détails paiement
  // ─────────────────────────────────────────────────────────────────────
  String _buildCashoutHtml({
    required Order order,
    required String cashoutInvoiceNumber,
    String? cashierName,
  }) {
    final dateStr = _dateFmt.format(DateTime.now());
    final itemsHtml = order.items.map((item) => '''
      <tr>
        <td class="item-name">${_escape(item.productName)}</td>
        <td class="item-qty">×${item.quantity}</td>
        <td class="item-price">${_fmt.format(item.unitPrice)} F</td>
        <td class="item-total">${_fmt.format(item.totalPrice)} F</td>
      </tr>
    ''').join('');

    final discountRow = order.discount > 0
        ? '<tr class="discount-row"><td colspan="3">Remise</td><td>-${_fmt.format(order.discount)} F</td></tr>'
        : '';

    final serverRow = order.serverName != null
        ? '<tr><td class="info-label">Serveur</td><td class="info-value">${_escape(order.serverName!)}</td></tr>'
        : '';
    final cashierRow = cashierName != null
        ? '<tr><td class="info-label">Caissier</td><td class="info-value">${_escape(cashierName)}</td></tr>'
        : '';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Facture Encaissement #${order.orderNumber}</title>
  <style>
    ${_thermalCss()}
    .receipt-type { color: #1565C0; border: 2px solid #1565C0; padding: 3px 8px; border-radius: 4px; letter-spacing: 1px; }
    .provisional-banner { background: #E3F2FD; border: 1px dashed #1565C0; padding: 4px 8px; text-align: center; font-size: 9px; color: #1565C0; margin: 6px 0; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="receipt">
    <div class="header">
      <img src="${_logoBase64()}" alt="Logo" class="logo-img" />
      <div class="restaurant-name">RESTAURANT SANKADIOKRO</div>
      <div class="restaurant-sub">Yopougon Millionnaire</div>
      <div class="restaurant-sub">Abidjan - Côte d\'Ivoire</div>
      <div class="restaurant-sub">Tél : 0757564300 / 0594114223</div>
      <div class="divider-double"></div>
      <div class="receipt-title receipt-type">FACTURE D\'ENCAISSEMENT</div>
    </div>
    <div class="provisional-banner">PROVISOIRE — En attente de règlement</div>
    <table class="info-table">
      <tr><td class="info-label">N° Facture</td><td class="info-value">$cashoutInvoiceNumber</td></tr>
      <tr><td class="info-label">N° Commande</td><td class="info-value">#${order.orderNumber}</td></tr>
      <tr><td class="info-label">Table</td><td class="info-value">${_escape(order.tableNumber)}</td></tr>
      <tr><td class="info-label">Date</td><td class="info-value">$dateStr</td></tr>
      $serverRow
      $cashierRow
    </table>
    <div class="divider"></div>
    <table class="items-table">
      <thead><tr><th class="item-name">Article</th><th class="item-qty">Qté</th><th class="item-price">P.U</th><th class="item-total">Total</th></tr></thead>
      <tbody>$itemsHtml</tbody>
    </table>
    <div class="divider"></div>
    <table class="totals-table">
      <tr><td colspan="3">Sous-total</td><td>${_fmt.format(order.subtotal)} F CFA</td></tr>
      $discountRow
      <tr class="total-row"><td colspan="3"><strong>TOTAL À PAYER</strong></td><td><strong>${_fmt.format(order.totalAmount)} F CFA</strong></td></tr>
    </table>
    <div class="divider-double"></div>
    <div class="footer">
      <p style="font-size:10px; color:#1565C0;">Le règlement sera effectué à la caisse.</p>
      <p class="merci">Merci pour votre visite !</p>
      <p class="footer-small">— SANKADIOKRO — Facture provisoire —</p>
    </div>
  </div>
</body>
</html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  BUILD HTML — Facture Définitive (80mm)
  //  Étape 2 : logo, serveur, caissier, articles (P.U + total), paiement, PAYÉE
  // ─────────────────────────────────────────────────────────────────────
  String _buildSettlementHtml({
    required Order order,
    required String settlementInvoiceNumber,
    required String paymentMethod,
    required double amountPaid,
    required double changeAmount,
    String? cashierName,
  }) {
    final dateStr = _dateFmt.format(order.settledAt ?? DateTime.now());
    final itemsHtml = order.items.map((item) =>
      '<tr>'
      '<td class="item-name">${_escape(item.productName)}</td>'
      '<td class="item-qty" style="text-align:center">${item.quantity}</td>'
      '<td class="item-price" style="text-align:right">${_fmt.format(item.unitPrice)} F</td>'
      '<td class="item-total">${_fmt.format(item.totalPrice)} F</td>'
      '</tr>'
    ).join('');

    final cashierRow = cashierName != null
        ? '<tr><td class="info-label">Caissier</td><td class="info-value">${_escape(cashierName)}</td></tr>'
        : '';
    final serverRow = order.serverName != null
        ? '<tr><td class="info-label">Serveur</td><td class="info-value">${_escape(order.serverName!)}</td></tr>'
        : '';
    final cashoutRef = order.cashoutInvoiceNumber != null
        ? '<tr><td class="info-label">Réf. encaiss.</td><td class="info-value">${_escape(order.cashoutInvoiceNumber!)}</td></tr>'
        : '';
    final cashierSign = cashierName != null
        ? '<p style="font-size:9px; text-align:center; margin:2px 0;">${_escape(cashierName)}</p>'
        : '';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Facture Définitive #\${order.orderNumber}</title>
  <style>
    \${_thermalCss()}
    .receipt-type { color: #2E7D32; border: 2px solid #2E7D32; padding: 3px 8px; border-radius: 4px; letter-spacing: 1px; }
    .status-paid { display: inline-block; background: #1B5E20; color: #fff; font-weight: bold; font-size: 14px; padding: 5px 20px; border-radius: 4px; letter-spacing: 3px; margin: 8px 0; }
    .big-amount { font-size: 17px; font-weight: bold; text-align: center; border: 2px solid #1B5E20; color: #1B5E20; padding: 6px; border-radius: 4px; margin: 6px 0; letter-spacing: 1px; }
    .signature-box { border: 1px dashed #999; height: 40px; margin: 6px 0; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: #999; font-size: 9px; }
    .items-table thead tr th { font-size: 9px; font-weight: bold; padding: 2px 0; border-bottom: 1px solid #ccc; }
  </style>
</head>
<body>
  <div class="receipt">
    <div class="header">
      <img src="\${_logoBase64()}" alt="Logo" class="logo-img" />
      <div class="restaurant-name">RESTAURANT SANKADIOKRO</div>
      <div class="restaurant-sub">Yopougon Millionnaire</div>
      <div class="restaurant-sub">Abidjan - Côte d\'Ivoire</div>
      <div class="restaurant-sub">Tél : 0757564300 / 0594114223</div>
      <div class="divider-double"></div>
      <div class="receipt-title receipt-type">FACTURE DÉFINITIVE</div>
    </div>
    <div style="text-align:center; margin: 6px 0;"><span class="status-paid">&#10003; PAYÉE</span></div>
    <table class="info-table">
      <tr><td class="info-label">N° Facture</td><td class="info-value">\$settlementInvoiceNumber</td></tr>
      <tr><td class="info-label">N° Commande</td><td class="info-value">#\${order.orderNumber}</td></tr>
      \$cashoutRef
      <tr><td class="info-label">Table</td><td class="info-value">\${_escape(order.tableNumber)}</td></tr>
      <tr><td class="info-label">Date / Heure</td><td class="info-value">\$dateStr</td></tr>
      \$serverRow
      \$cashierRow
      <tr><td class="info-label">Mode paiement</td><td class="info-value">\${_escape(paymentMethod)}</td></tr>
    </table>
    <div class="divider"></div>
    <div class="section-title">ARTICLES COMMANDÉS</div>
    <table class="items-table">
      <thead><tr><th class="item-name">Article</th><th class="item-qty">Qté</th><th class="item-price" style="text-align:right">P.U</th><th class="item-total">Total</th></tr></thead>
      <tbody>\$itemsHtml</tbody>
    </table>
    <div class="divider"></div>
    <div class="section-title">DÉTAIL DU RÈGLEMENT</div>
    <table class="totals-table">
      <tr><td colspan="3">Sous-total</td><td>\${_fmt.format(order.subtotal)} F CFA</td></tr>
      \${order.discount > 0 ? '<tr class="discount-row"><td colspan="3">Remise</td><td>-\${_fmt.format(order.discount)} F CFA</td></tr>' : ''}
      <tr class="total-row"><td colspan="3"><strong>MONTANT DÛ</strong></td><td><strong>\${_fmt.format(order.totalAmount)} F CFA</strong></td></tr>
      <tr><td colspan="3">Montant versé</td><td>\${_fmt.format(amountPaid)} F CFA</td></tr>
      <tr><td colspan="3">Monnaie rendue</td><td>\${_fmt.format(changeAmount)} F CFA</td></tr>
    </table>
    <div class="big-amount">TOTAL RÉGLÉ : \${_fmt.format(order.totalAmount)} F CFA</div>
    <div class="divider"></div>
    <div class="section-title">VISA CAISSIER(ÈRE)</div>
    <div class="signature-box">Signature &amp; cachet caisse</div>
    \$cashierSign
    <div class="divider-double"></div>
    <div class="footer">
      <p class="merci">Merci pour votre confiance !</p>
      <p>SANKADIOKRO — Restaurant Africain</p>
      <p class="footer-small">— Facture définitive — Document de règlement —</p>
    </div>
  </div>
</body>
</html>''';
  }
  String _buildEncaissementHtml({
    required Order order,
    required double amountPaid,
    required String receiptNumber,
    String? cashierName,
  }) {
    final dateStr = _dateFmt.format(DateTime.now());
    final change = (amountPaid - order.totalAmount).clamp(0.0, double.infinity);
    final hasDiscount = order.discount > 0;
    final hasAmountPaid = amountPaid > 0;

    final itemsHtml = order.items.map((item) => '''
      <tr>
        <td class="item-name">${_escape(item.productName)}</td>
        <td class="item-qty">×${item.quantity}</td>
        <td class="item-price">${_fmt.format(item.unitPrice)} F</td>
        <td class="item-total">${_fmt.format(item.totalPrice)} F</td>
      </tr>
    ''').join('');

    final discountRow = hasDiscount
        ? '<tr class="discount-row"><td colspan="3">Remise</td><td>-${_fmt.format(order.discount)} F</td></tr>'
        : '';

    final amountPaidRow = hasAmountPaid
        ? '''
      <tr><td colspan="3">Montant reçu</td><td>${_fmt.format(amountPaid)} F CFA</td></tr>
      <tr><td colspan="3">Monnaie rendue</td><td>${_fmt.format(change)} F CFA</td></tr>
    '''
        : '';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reçu d'Encaissement #${order.orderNumber}</title>
  <style>
    ${_thermalCss()}

    /* Spécifique encaissement */
    .receipt-type {
      color: #1565C0;
      border: 2px solid #1565C0;
      padding: 3px 8px;
      border-radius: 4px;
      letter-spacing: 1px;
    }
  </style>
</head>
<body>
  <div class="receipt">
    <!-- ── EN-TÊTE OFFICIEL ── -->
    <div class="header">
      <img src="${_logoBase64()}" alt="Logo Sankadiokro" class="logo-img" />
      <div class="restaurant-name">RESTAURANT SANKADIOKRO</div>
      <div class="restaurant-sub">Yopougon Millionnaire</div>
      <div class="restaurant-sub">Abidjan - Côte d'Ivoire</div>
      <div class="restaurant-sub">Tél : 0757564300 / 0594114223</div>
      <div class="divider-double"></div>
      <div class="receipt-title receipt-type">REÇU D'ENCAISSEMENT</div>
    </div>

    <!-- ── INFOS REÇU ── -->
    <table class="info-table">
      <tr><td class="info-label">N° Reçu</td><td class="info-value">$receiptNumber</td></tr>
      <tr><td class="info-label">N° Commande</td><td class="info-value">#${order.orderNumber}</td></tr>
      <tr><td class="info-label">Table</td><td class="info-value">${_escape(order.tableNumber)}</td></tr>
      <tr><td class="info-label">Date</td><td class="info-value">$dateStr</td></tr>
      ${order.serverName != null ? '<tr><td class="info-label">Serveur</td><td class="info-value">${_escape(order.serverName!)}</td></tr>' : ''}
      ${cashierName != null ? '<tr><td class="info-label">Caissier</td><td class="info-value">${_escape(cashierName)}</td></tr>' : ''}
      <tr><td class="info-label">Paiement</td><td class="info-value">${_escape(order.paymentMethod ?? 'Espèces')}</td></tr>
    </table>

    <div class="divider"></div>

    <!-- ── ARTICLES ── -->
    <table class="items-table">
      <thead>
        <tr>
          <th class="item-name">Article</th>
          <th class="item-qty">Qté</th>
          <th class="item-price">P.U</th>
          <th class="item-total">Total</th>
        </tr>
      </thead>
      <tbody>
        $itemsHtml
      </tbody>
    </table>

    <div class="divider"></div>

    <!-- ── TOTAUX ── -->
    <table class="totals-table">
      <tr><td colspan="3">Sous-total</td><td>${_fmt.format(order.subtotal)} F CFA</td></tr>
      $discountRow
      <tr class="total-row"><td colspan="3"><strong>TOTAL ENCAISSÉ</strong></td><td><strong>${_fmt.format(order.totalAmount)} F CFA</strong></td></tr>
      $amountPaidRow
    </table>

    <div class="divider-double"></div>

    <!-- ── PIED ── -->
    <div class="footer">
      <p class="merci">Merci pour votre visite !</p>
      <p>À bientôt chez SANKADIOKRO</p>
      <p class="footer-small">— Ce reçu fait foi de paiement —</p>
    </div>
  </div>

  <script>
    window.onload = function() {
      // L'impression est déclenchée par le code Dart via setTimeout
    };
  </script>
</body>
</html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  BUILD HTML — Reçu de Règlement Caisse (ticket thermique 80mm)
  // ─────────────────────────────────────────────────────────────────────
  String _buildReglementHtml({
    required Order order,
    required double amountPaid,
    required String settlementNumber,
    String? cashierName,
  }) {
    final dateStr = _dateFmt.format(DateTime.now());
    final change = (amountPaid - order.totalAmount).clamp(0.0, double.infinity);
    final hasAmountPaid = amountPaid > 0;

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reçu de Règlement #${order.orderNumber}</title>
  <style>
    ${_thermalCss()}

    /* Spécifique règlement */
    .receipt-type {
      color: #E65100;
      border: 2px solid #E65100;
      padding: 3px 8px;
      border-radius: 4px;
      letter-spacing: 1px;
    }
    .status-paid {
      display: inline-block;
      background: #1B5E20;
      color: #fff;
      font-weight: bold;
      font-size: 13px;
      padding: 4px 16px;
      border-radius: 4px;
      letter-spacing: 2px;
      margin: 6px 0;
    }
    .signature-box {
      border: 1px dashed #999;
      height: 40px;
      margin: 6px 0;
      border-radius: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #999;
      font-size: 9px;
    }
    .big-amount {
      font-size: 18px;
      font-weight: bold;
      text-align: center;
      border: 2px solid #333;
      padding: 6px;
      border-radius: 4px;
      margin: 6px 0;
      letter-spacing: 1px;
    }
  </style>
</head>
<body>
  <div class="receipt">
    <!-- ── EN-TÊTE OFFICIEL ── -->
    <div class="header">
      <img src="${_logoBase64()}" alt="Logo Sankadiokro" class="logo-img" />
      <div class="restaurant-name">RESTAURANT SANKADIOKRO</div>
      <div class="restaurant-sub">Yopougon Millionnaire</div>
      <div class="restaurant-sub">Abidjan - Côte d'Ivoire</div>
      <div class="restaurant-sub">Tél : 0757564300 / 0594114223</div>
      <div class="divider-double"></div>
      <div class="receipt-title receipt-type">REÇU DE RÈGLEMENT CAISSE</div>
    </div>

    <!-- ── INFOS RÈGLEMENT ── -->
    <table class="info-table">
      <tr><td class="info-label">N° Règlement</td><td class="info-value">$settlementNumber</td></tr>
      <tr><td class="info-label">N° Commande</td><td class="info-value">#${order.orderNumber}</td></tr>
      <tr><td class="info-label">Table</td><td class="info-value">${_escape(order.tableNumber)}</td></tr>
      <tr><td class="info-label">Date</td><td class="info-value">$dateStr</td></tr>
      ${cashierName != null ? '<tr><td class="info-label">Caissier</td><td class="info-value">${_escape(cashierName)}</td></tr>' : ''}
      <tr><td class="info-label">Mode paiement</td><td class="info-value">${_escape(order.paymentMethod ?? 'Espèces')}</td></tr>
    </table>

    <div class="divider"></div>

    <!-- ── DÉTAIL PAIEMENT ── -->
    <div class="section-title">DÉTAIL DU RÈGLEMENT</div>
    <table class="totals-table">
      <tr><td colspan="3">Montant à payer</td><td>${_fmt.format(order.totalAmount)} F CFA</td></tr>
      ${hasAmountPaid ? '<tr><td colspan="3">Montant reçu</td><td>${_fmt.format(amountPaid)} F CFA</td></tr>' : ''}
      ${hasAmountPaid ? '<tr><td colspan="3">Monnaie rendue</td><td>${_fmt.format(change)} F CFA</td></tr>' : ''}
    </table>

    <div class="divider"></div>

    <!-- ── MONTANT TOTAL ENCAISSÉ ── -->
    <div class="big-amount">TOTAL RÉGLÉ : ${_fmt.format(order.totalAmount)} F CFA</div>

    <!-- ── STATUT ── -->
    <div style="text-align:center; margin: 8px 0;">
      <span class="status-paid">✓ RÉGLÉ</span>
    </div>

    <div class="divider"></div>

    <!-- ── ARTICLES RÉSUMÉ ── -->
    <div class="section-title">ARTICLES COMMANDÉS</div>
    <table class="items-table">
      <tbody>
        ${order.items.map((item) => '<tr><td class="item-name">${_escape(item.productName)}</td><td class="item-qty" style="text-align:center">×${item.quantity}</td><td class="item-total">${_fmt.format(item.totalPrice)} F</td></tr>').join('')}
      </tbody>
    </table>

    <div class="divider"></div>

    <!-- ── SIGNATURE CAISSE ── -->
    <div class="section-title">VISA CAISSIER(ÈRE)</div>
    <div class="signature-box">Signature &amp; cachet caisse</div>
    ${cashierName != null ? '<p style="font-size:9px; text-align:center; margin:2px 0;">$cashierName</p>' : ''}

    <div class="divider-double"></div>

    <!-- ── PIED ── -->
    <div class="footer">
      <p class="merci">Merci pour votre confiance !</p>
      <p>SANKADIOKRO — Restaurant Africain</p>
      <p class="footer-small">— Document de règlement caisse —</p>
    </div>
  </div>
</body>
</html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  CSS COMMUN — Ticket thermique 80mm
  // ─────────────────────────────────────────────────────────────────────
  String _thermalCss() => '''
    @page {
      size: 80mm auto;
      margin: 0;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: 'Courier New', Courier, monospace;
      font-size: 11px;
      color: #000;
      background: #fff;
      width: 80mm;
      max-width: 80mm;
    }

    .receipt {
      width: 76mm;
      margin: 0 auto;
      padding: 4mm 0;
    }

    /* ── En-tête ── */
    .header {
      text-align: center;
      margin-bottom: 6px;
    }

    .logo-img {
      width: 60px;
      height: 60px;
      object-fit: contain;
      display: block;
      margin: 0 auto 4px auto;
    }

    .restaurant-name {
      font-size: 14px;
      font-weight: bold;
      letter-spacing: 1px;
      margin-bottom: 2px;
    }

    .restaurant-sub {
      font-size: 10px;
      color: #333;
    }

    .receipt-title {
      font-size: 12px;
      font-weight: bold;
      margin-top: 6px;
      display: inline-block;
    }

    /* ── Séparateurs ── */
    .divider {
      border-top: 1px dashed #666;
      margin: 6px 0;
    }

    .divider-double {
      border-top: 2px solid #000;
      margin: 6px 0;
    }

    /* ── Tableau infos ── */
    .info-table {
      width: 100%;
      border-collapse: collapse;
    }

    .info-table tr td {
      padding: 1.5px 0;
      font-size: 10.5px;
      vertical-align: top;
    }

    .info-label {
      color: #555;
      width: 40%;
    }

    .info-value {
      font-weight: bold;
      text-align: right;
    }

    /* ── Tableau articles ── */
    .items-table {
      width: 100%;
      border-collapse: collapse;
    }

    .items-table thead tr th {
      font-size: 10px;
      font-weight: bold;
      padding: 2px 0;
      border-bottom: 1px solid #ccc;
      text-align: left;
    }

    .items-table tbody tr td {
      padding: 2px 0;
      font-size: 10.5px;
      vertical-align: top;
    }

    .item-name {
      width: 38%;
    }

    .item-qty {
      width: 10%;
      text-align: center;
    }

    .item-price {
      width: 22%;
      text-align: right;
    }

    .item-total {
      width: 30%;
      text-align: right;
      font-weight: bold;
    }

    /* ── Tableau totaux ── */
    .totals-table {
      width: 100%;
      border-collapse: collapse;
    }

    .totals-table tr td {
      padding: 2px 0;
      font-size: 10.5px;
    }

    .totals-table tr td:last-child {
      text-align: right;
      font-weight: bold;
    }

    .total-row td {
      font-size: 13px;
      padding: 3px 0;
    }

    .discount-row td {
      color: #B71C1C;
    }

    /* ── Section titre ── */
    .section-title {
      font-size: 9px;
      font-weight: bold;
      color: #555;
      letter-spacing: 1px;
      margin: 4px 0 2px 0;
      text-transform: uppercase;
    }

    /* ── Pied ── */
    .footer {
      text-align: center;
      margin-top: 8px;
    }

    .merci {
      font-size: 12px;
      font-weight: bold;
      margin-bottom: 3px;
    }

    .footer-small {
      font-size: 9px;
      color: #777;
      margin-top: 3px;
    }

    /* ── Masquer tout sauf le reçu en impression ── */
    @media screen {
      body {
        background: #f5f5f5;
        display: flex;
        justify-content: center;
        padding: 20px;
      }
      .receipt {
        background: #fff;
        box-shadow: 0 2px 12px rgba(0,0,0,0.15);
        padding: 16px;
      }
    }

    @media print {
      body {
        background: #fff;
        width: 80mm;
      }
      .receipt {
        box-shadow: none;
      }
    }
  ''';

  // ─────────────────────────────────────────────────────────────────────
  //  Utilitaires
  // ─────────────────────────────────────────────────────────────────────

  /// Génère un numéro de reçu unique basé sur la date + orderNumber
  static String generateReceiptNumber(int orderNumber) {
    final now = DateTime.now();
    final prefix = DateFormat('yyyyMMdd').format(now);
    return 'REC-$prefix-${orderNumber.toString().padLeft(4, '0')}';
  }

  /// Génère un numéro de règlement unique
  static String generateSettlementNumber(int orderNumber) {
    final now = DateTime.now();
    final prefix = DateFormat('yyyyMMdd').format(now);
    return 'REG-$prefix-${orderNumber.toString().padLeft(4, '0')}';
  }

  /// Ouvre du HTML dans un nouvel onglet (Web uniquement)
  /// Utilisé pour la Recette de Vente et autres rapports personnalisés
  static void openHtmlInNewTab(String html) {
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    }
  }

  /// Échappe les caractères HTML dangereux
  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Retourne l'URL du logo pour inclusion dans les tickets HTML
  /// Sur Web Flutter, les assets sont accessibles via chemin relatif depuis la racine
  String _logoBase64() {
    // Sur Flutter Web, les assets sont publiés à la racine de /assets/
    // L'URL relative fonctionne dans la fenêtre d'impression (même origine)
    return 'assets/images/logo_sankadiokro.png';
  }
}
