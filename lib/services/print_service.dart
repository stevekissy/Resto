import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'accounting_service.dart';

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
  //  FRAGMENTS HTML PARTAGÉS — En-tête, pied de page, QR, bouton
  // ─────────────────────────────────────────────────────────────────────

  /// En-tête commun à tous les documents (logo, nom, adresse, titre)
  String _htmlHeader(String titleLabel, String titleClass) {
    final logo = _logoBase64();
    return '''
    <div class="header">
      <img src="$logo" alt="Logo" class="logo-img" onerror="this.style.display='none'" />
      <div class="restaurant-name">Restaurant Sankadiokro</div>
      <div class="restaurant-tagline">Cuisine Africaine &amp; Ivoirienne</div>
    </div>
    <hr class="sep-solid" />
    <div class="receipt-title-block">
      <span class="receipt-title $titleClass">$titleLabel</span>
    </div>
    <hr class="sep-dashed" />
    ''';
  }

  /// Pied de page commun à tous les documents
  String get _htmlFooter => '''
    <hr class="sep-solid" />
    <div class="footer-block">
      <div class="footer-merci">Merci d&apos;avoir choisi</div>
      <div class="footer-name">Restaurant Sankadiokro</div>
      <div class="footer-tagline">Votre satisfaction est notre priorit&eacute;.</div>
      <div class="footer-address">&#128205; Yopougon Millionnaire</div>
      <div class="footer-address">Derri&egrave;re le Groupe Scolaire Saint Louis</div>
      <div class="footer-address">Non loin de la Cit&eacute; BHCI</div>
      <div class="footer-address">&#9993; restaurantsankadiokro@gmail.com</div>
      <div class="footer-address">&#128222; 07 07 04 29 47</div>
      <div class="footer-stars">&#9733;&#9733;&#9733;&#9733;&#9733;</div>
      <div class="footer-merci-final">~ MERCI DE VOTRE CONFIANCE ~</div>
      <div style="font-size:8px;color:#aaa;margin-top:4px;">Nous esp&eacute;rons vous revoir tr&egrave;s bient&ocirc;t.</div>
    </div>
  ''';

  /// Génère un bloc QR code visuel (canvas JS)
  String _qrScript(String qrData) {
    final safe = qrData.replaceAll('"', r'\"');
    return '''
    <div class="qr-block">
      <canvas id="qr-canvas" class="qr-canvas" width="90" height="90"></canvas>
      <div class="qr-label">Scannez pour v&eacute;rifier</div>
    </div>
    <script>
      (function() {
        var data = "$safe";
        var c = document.getElementById('qr-canvas');
        if (!c) return;
        var ctx = c.getContext('2d');
        var size = 90;
        ctx.fillStyle = '#fff'; ctx.fillRect(0,0,size,size);
        ctx.strokeStyle='#222'; ctx.lineWidth=2; ctx.strokeRect(2,2,size-4,size-4);
        function sq(x,y,s){ctx.fillStyle='#222';ctx.fillRect(x,y,s,s);ctx.fillStyle='#fff';ctx.fillRect(x+2,y+2,s-4,s-4);ctx.fillStyle='#222';ctx.fillRect(x+4,y+4,s-8,s-8);}
        sq(8,8,18); sq(size-26,8,18); sq(8,size-26,18);
        ctx.fillStyle='#333';
        var seed=0; for(var i=0;i<data.length;i++) seed+=data.charCodeAt(i);
        for(var r=0;r<7;r++) for(var col=0;col<7;col++) if((seed^(r*13+col*7))%3===0) ctx.fillRect(30+col*7,30+r*7,5,5);
        ctx.fillStyle='#888'; ctx.font='5px Arial'; ctx.textAlign='center';
        ctx.fillText('QR',size/2,size-8);
      })();
    </script>
    ''';
  }

  /// Bouton d'impression commun
  String get _printButton => '''
    <div class="print-btn">
      <button onclick="window.print()"
        style="padding:8px 24px;background:#111;color:#fff;border:none;border-radius:6px;
               cursor:pointer;font-size:12px;font-weight:bold;letter-spacing:0.5px;">
        &#128424; Imprimer / Enregistrer PDF
      </button>
    </div>
  ''';

  // ─────────────────────────────────────────────────────────────────────
  //  CSS COMMUN UNIFIÉ — Ticket thermique 80mm Sankadio v2
  //  Utilisé par les quatre documents imprimables.
  // ─────────────────────────────────────────────────────────────────────
  String _thermalCss() => r'''
    @page { size: 80mm auto; margin: 0; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: Arial, Helvetica, sans-serif;
      font-size: 11px; color: #111; background: #fff;
      width: 80mm; max-width: 80mm;
    }
    .receipt { width: 78mm; margin: 0 auto; padding: 3mm 1mm 5mm 1mm; }

    /* ══ EN-TÊTE ══ */
    .header { text-align: center; padding-bottom: 4px; }
    .logo-img { width: 58px; height: 58px; object-fit: contain; display: block; margin: 0 auto 4px auto; }
    .restaurant-name { font-size: 13.5px; font-weight: bold; letter-spacing: 0.8px; margin-bottom: 2px; text-transform: uppercase; }
    .restaurant-tagline { font-size: 9.5px; font-style: italic; color: #444; margin-bottom: 3px; }
    .restaurant-sub { font-size: 9px; color: #333; line-height: 1.4; }
    .restaurant-contact { font-size: 9px; color: #222; margin-top: 2px; }

    /* ══ TITRES DOCUMENTS ══ */
    .receipt-title-block { text-align: center; margin: 6px 0 5px 0; }
    .receipt-title { display: inline-block; font-size: 11.5px; font-weight: bold; letter-spacing: 1.2px; padding: 3px 12px; border-radius: 4px; text-transform: uppercase; }
    .title-encaissement { background: #E3F2FD; color: #0D47A1; border: 1.5px solid #0D47A1; }
    .title-reglee       { background: #E8F5E9; color: #1B5E20; border: 1.5px solid #1B5E20; }
    .title-provisoire   { background: #FFF3E0; color: #E65100; border: 1.5px solid #E65100; }

    /* ══ SÉPARATEURS ══ */
    .sep-solid  { border: none; border-top: 2px solid #111; margin: 5px 0; }
    .sep-dashed { border: none; border-top: 1px dashed #777; margin: 5px 0; }
    .sep-thin   { border: none; border-top: 1px solid #ccc; margin: 4px 0; }

    /* ══ INFOS DOCUMENT ══ */
    .info-table { width: 100%; border-collapse: collapse; margin: 3px 0; }
    .info-table tr td { padding: 1.8px 0; font-size: 10px; vertical-align: top; }
    .info-label { color: #555; width: 42%; }
    .info-value { font-weight: bold; text-align: right; color: #111; }

    /* ══ TABLEAU ARTICLES ══ */
    .items-table { width: 100%; border-collapse: collapse; margin: 3px 0; }
    .items-table thead tr { background: #222; color: #fff; }
    .items-table thead th { font-size: 9.5px; font-weight: bold; padding: 3px 2px; text-align: left; }
    .items-table tbody tr:nth-child(even) { background: #F9F9F9; }
    .items-table tbody tr td { padding: 2.5px 2px; font-size: 10px; vertical-align: top; border-bottom: 1px solid #EBEBEB; }
    .item-name  { width: 40%; }
    .item-qty   { width: 10%; text-align: center; }
    .item-price { width: 22%; text-align: right; }
    .item-total { width: 28%; text-align: right; font-weight: bold; }

    /* ══ SECTION TITRE ══ */
    .section-title { font-size: 8.5px; font-weight: bold; color: #555; letter-spacing: 1.2px; text-transform: uppercase; margin: 5px 0 2px 0; padding-bottom: 1px; border-bottom: 1px solid #ddd; }

    /* ══ TOTAUX ══ */
    .totals-table { width: 100%; border-collapse: collapse; margin: 3px 0; }
    .totals-table tr td { padding: 2px 2px; font-size: 10.5px; vertical-align: middle; }
    .totals-table tr td:last-child { text-align: right; font-weight: bold; }
    .totals-table tr.discount-row td { color: #B71C1C; font-style: italic; }
    .totals-table tr.subtotal-row td { color: #333; }
    .totals-table tr.total-row td { font-size: 12px; font-weight: bold; background: #111; color: #fff; padding: 4px 4px; }

    /* ══ PAIEMENT ══ */
    .payment-block { background: #F8F8F8; border: 1px solid #ddd; border-radius: 4px; padding: 5px 7px; margin: 5px 0; }
    .payment-row { display: flex; justify-content: space-between; font-size: 10px; padding: 1.5px 0; }
    .payment-label { color: #555; }
    .payment-value { font-weight: bold; }
    .payment-value.change { color: #1B5E20; }

    /* ══ TOTAL ENCADRÉ ══ */
    .big-total-box { text-align: center; border: 2px solid #111; border-radius: 4px; padding: 6px 4px; margin: 5px 0; }
    .big-total-label { font-size: 9px; color: #555; letter-spacing: 1px; text-transform: uppercase; }
    .big-total-amount { font-size: 16px; font-weight: bold; letter-spacing: 0.5px; margin-top: 1px; }

    /* ══ BADGES ══ */
    .badge-paid    { display: inline-block; background: #1B5E20; color: #fff; font-weight: bold; font-size: 11px; padding: 3px 14px; border-radius: 12px; letter-spacing: 2px; }
    .badge-pending { display: inline-block; background: #E65100; color: #fff; font-weight: bold; font-size: 10px; padding: 2px 10px; border-radius: 12px; letter-spacing: 1px; }
    .badge-center  { text-align: center; margin: 5px 0; }

    /* ══ QR CODE ══ */
    .qr-block  { text-align: center; margin: 6px 0 4px 0; }
    .qr-canvas { display: block; margin: 0 auto; }
    .qr-label  { font-size: 8px; color: #888; margin-top: 2px; letter-spacing: 0.5px; }

    /* ══ PIED DE PAGE ══ */
    .footer-block { text-align: center; margin-top: 8px; padding-top: 5px; }
    .footer-merci { font-size: 10.5px; font-weight: bold; margin-bottom: 2px; }
    .footer-name  { font-size: 11px; font-weight: bold; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 3px; }
    .footer-tagline { font-size: 9px; font-style: italic; color: #555; margin-bottom: 4px; }
    .footer-address { font-size: 8.5px; color: #333; line-height: 1.5; }
    .footer-stars   { font-size: 12px; color: #F9A825; letter-spacing: 3px; margin: 4px 0; }
    .footer-merci-final { font-size: 9px; font-weight: bold; color: #333; letter-spacing: 1px; border-top: 1px dashed #aaa; padding-top: 3px; margin-top: 3px; }
    .print-btn { text-align: center; margin-top: 14px; }

    /* ══ MEDIA ══ */
    @media screen {
      body { background: #ECEFF1; display: flex; justify-content: center; padding: 20px; }
      .receipt { background: #fff; box-shadow: 0 4px 20px rgba(0,0,0,0.15); padding: 16px; }
    }
    @media print {
      body { background: #fff; width: 80mm; }
      .receipt { box-shadow: none; }
      .print-btn { display: none; }
    }
  ''';

  // ─────────────────────────────────────────────────────────────────────
  //  REÇU D'ENCAISSEMENT — design Sankadio v2 (80mm)
  // ─────────────────────────────────────────────────────────────────────
  String _buildEncaissementHtml({
    required Order order,
    required double amountPaid,
    required String receiptNumber,
    String? cashierName,
  }) {
    final now = DateTime.now();
    final dateFmt2 = DateFormat('dd/MM/yyyy');
    final timeFmt  = DateFormat('HH:mm');
    final dateStr  = dateFmt2.format(now);
    final timeStr  = timeFmt.format(now);
    final change   = (amountPaid - order.totalAmount).clamp(0.0, double.infinity);

    final itemsRows = order.items.map((item) =>
      '<tr>'
      '<td class="item-name">${_escape(item.productName)}</td>'
      '<td class="item-qty">${item.quantity}</td>'
      '<td class="item-price">${_fmt.format(item.unitPrice)} F</td>'
      '<td class="item-total">${_fmt.format(item.totalPrice)} F</td>'
      '</tr>'
    ).join('');

    final discountRow = order.discount > 0
        ? '<tr class="discount-row"><td colspan="3">Remise accord&eacute;e</td><td>-${_fmt.format(order.discount)}</td></tr>'
        : '';

    final changeVisible = amountPaid > 0;
    final resteRow = (order.totalAmount > amountPaid && amountPaid > 0)
        ? '<div class="payment-row"><span class="payment-label">Reste d&ucirc; :</span><span class="payment-value" style="color:#B71C1C;">${_fmt.format(order.totalAmount - amountPaid)} F CFA</span></div>'
        : '';
    final qrData = 'N:$receiptNumber|D:$dateStr|M:${_fmt.format(order.totalAmount)}|R:Sankadiokro';
    final qrBlock = _qrScript(qrData);
    final header  = _htmlHeader("REÇU D'ENCAISSEMENT", "title-encaissement");
    final footer  = _htmlFooter;
    final prtBtn  = _printButton;
    final css     = _thermalCss();
    final orderType = order.isTakeaway ? 'À emporter' : 'Sur place';
    final cashierRow = cashierName != null ? '<tr><td class="info-label">Caissier :</td><td class="info-value">${_escape(cashierName)}</td></tr>' : '';
    final serverRow  = order.serverName != null ? '<tr><td class="info-label">Serveur :</td><td class="info-value">${_escape(order.serverName!)}</td></tr>' : '';
    final amtRow = amountPaid > 0 ? '<div class="payment-row"><span class="payment-label">Montant reçu :</span><span class="payment-value">${_fmt.format(amountPaid)} F CFA</span></div>' : '';
    final chgRow = changeVisible ? '<div class="payment-row"><span class="payment-label">Monnaie rendue :</span><span class="payment-value change">${_fmt.format(change)} F CFA</span></div>' : '';
    final payMode = _escape(order.paymentMethod ?? 'Espèces');
    final tableNum = _escape(order.tableNumber);
    final subTot = _fmt.format(order.subtotal);
    final tot    = _fmt.format(order.totalAmount);

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Reçu Encaissement #$receiptNumber</title>
<style>$css</style>
</head>
<body>
<div class="receipt">
$header
<div class="section-title">Informations document</div>
<table class="info-table">
<tr><td class="info-label">N° :</td><td class="info-value">$receiptNumber</td></tr>
<tr><td class="info-label">Date :</td><td class="info-value">$dateStr</td></tr>
<tr><td class="info-label">Heure :</td><td class="info-value">$timeStr</td></tr>
$cashierRow
$serverRow
<tr><td class="info-label">Table :</td><td class="info-value">$tableNum</td></tr>
<tr><td class="info-label">Type :</td><td class="info-value">$orderType</td></tr>
</table>
<hr class="sep-dashed" />
<div class="section-title">D&eacute;tails commande</div>
<table class="items-table">
<thead><tr><th class="item-name">Article</th><th class="item-qty">Qté</th><th class="item-price">P.U</th><th class="item-total">Total</th></tr></thead>
<tbody>$itemsRows</tbody>
</table>
<hr class="sep-dashed" />
<table class="totals-table">
<tr class="subtotal-row"><td colspan="3">Sous-total :</td><td>$subTot F CFA</td></tr>
$discountRow
<tr class="total-row"><td colspan="3">Total TTC :</td><td>$tot F CFA</td></tr>
</table>
<hr class="sep-dashed" />
<div class="section-title">Paiement</div>
<div class="payment-block">
<div class="payment-row"><span class="payment-label">Mode :</span><span class="payment-value">$payMode</span></div>
$amtRow
$chgRow
$resteRow
</div>
<div class="big-total-box">
<div class="big-total-label">Total encaissé</div>
<div class="big-total-amount">$tot F CFA</div>
</div>
$qrBlock
$footer
$prtBtn
</div>
</body>
</html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  FACTURE RÉGLÉE — design Sankadio v2 (80mm)
  // ─────────────────────────────────────────────────────────────────────
  String _buildReglementHtml({
    required Order order,
    required double amountPaid,
    required String settlementNumber,
    String? cashierName,
  }) {
    final now = DateTime.now();
    final dateFmt2 = DateFormat('dd/MM/yyyy');
    final timeFmt  = DateFormat('HH:mm');
    final dateStr  = dateFmt2.format(now);
    final timeStr  = timeFmt.format(now);
    final change   = (amountPaid - order.totalAmount).clamp(0.0, double.infinity);

    final itemsRows = order.items.map((item) =>
      '<tr>'
      '<td class="item-name">${_escape(item.productName)}</td>'
      '<td class="item-qty">${item.quantity}</td>'
      '<td class="item-price">${_fmt.format(item.unitPrice)} F</td>'
      '<td class="item-total">${_fmt.format(item.totalPrice)} F</td>'
      '</tr>'
    ).join('');

    final discountRow = order.discount > 0
        ? '<tr class="discount-row"><td colspan="3">Remise accord&eacute;e</td><td>-${_fmt.format(order.discount)}</td></tr>'
        : '';

    final resteRow = (order.totalAmount > amountPaid && amountPaid > 0)
        ? '<div class="payment-row"><span class="payment-label">Reste d&ucirc; :</span><span class="payment-value" style="color:#B71C1C;">${_fmt.format(order.totalAmount - amountPaid)} F CFA</span></div>'
        : '';
    final qrData = 'N:$settlementNumber|D:$dateStr|M:${_fmt.format(order.totalAmount)}|R:Sankadiokro';
    final qrBlock = _qrScript(qrData);
    final header  = _htmlHeader("FACTURE RÉGLÉE", "title-reglee");
    final footer  = _htmlFooter;
    final prtBtn  = _printButton;
    final css     = _thermalCss();
    final orderType  = order.isTakeaway ? 'À emporter' : 'Sur place';
    final cashierRow = cashierName != null ? '<tr><td class="info-label">Caissier :</td><td class="info-value">${_escape(cashierName)}</td></tr>' : '';
    final serverRow  = order.serverName != null ? '<tr><td class="info-label">Serveur :</td><td class="info-value">${_escape(order.serverName!)}</td></tr>' : '';
    final amtRow  = amountPaid > 0 ? '<div class="payment-row"><span class="payment-label">Montant reçu :</span><span class="payment-value">${_fmt.format(amountPaid)} F CFA</span></div>' : '';
    final payMode = _escape(order.paymentMethod ?? 'Espèces');
    final tableNum = _escape(order.tableNumber);
    final subTot  = _fmt.format(order.subtotal);
    final tot     = _fmt.format(order.totalAmount);
    final chg     = _fmt.format(change);

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Facture Réglée #$settlementNumber</title>
<style>$css</style>
</head>
<body>
<div class="receipt">
$header
<div class="badge-center"><span class="badge-paid">&#10003;&nbsp;RÉGLÉE</span></div>
<hr class="sep-dashed" />
<div class="section-title">Informations document</div>
<table class="info-table">
<tr><td class="info-label">N° :</td><td class="info-value">$settlementNumber</td></tr>
<tr><td class="info-label">Date :</td><td class="info-value">$dateStr</td></tr>
<tr><td class="info-label">Heure :</td><td class="info-value">$timeStr</td></tr>
$cashierRow
$serverRow
<tr><td class="info-label">Table :</td><td class="info-value">$tableNum</td></tr>
<tr><td class="info-label">Type :</td><td class="info-value">$orderType</td></tr>
</table>
<hr class="sep-dashed" />
<div class="section-title">D&eacute;tails commande</div>
<table class="items-table">
<thead><tr><th class="item-name">Article</th><th class="item-qty">Qté</th><th class="item-price">P.U</th><th class="item-total">Total</th></tr></thead>
<tbody>$itemsRows</tbody>
</table>
<hr class="sep-dashed" />
<table class="totals-table">
<tr class="subtotal-row"><td colspan="3">Sous-total :</td><td>$subTot F CFA</td></tr>
$discountRow
<tr class="total-row"><td colspan="3">Total TTC :</td><td>$tot F CFA</td></tr>
</table>
<hr class="sep-dashed" />
<div class="section-title">Paiement</div>
<div class="payment-block">
<div class="payment-row"><span class="payment-label">Mode :</span><span class="payment-value">$payMode</span></div>
$amtRow
<div class="payment-row"><span class="payment-label">Monnaie rendue :</span><span class="payment-value change">$chg F CFA</span></div>
$resteRow
</div>
<div class="big-total-box">
<div class="big-total-label">Montant réglé</div>
<div class="big-total-amount">$tot F CFA</div>
</div>
$qrBlock
$footer
$prtBtn
</div>
</body>
</html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  REÇU D'ENCAISSEMENT PROVISOIRE — design Sankadio v2 (80mm)
  //  Étape 1 : commande + total. Pas de détails paiement.
  // ─────────────────────────────────────────────────────────────────────
  String _buildCashoutHtml({
    required Order order,
    required String cashoutInvoiceNumber,
    String? cashierName,
  }) {
    final now      = DateTime.now();
    final dateFmt2 = DateFormat('dd/MM/yyyy');
    final timeFmt  = DateFormat('HH:mm');
    final dateStr  = dateFmt2.format(now);
    final timeStr  = timeFmt.format(now);

    final itemsRows = order.items.map((item) =>
      '<tr>'
      '<td class="item-name">${_escape(item.productName)}</td>'
      '<td class="item-qty">${item.quantity}</td>'
      '<td class="item-price">${_fmt.format(item.unitPrice)} F</td>'
      '<td class="item-total">${_fmt.format(item.totalPrice)} F</td>'
      '</tr>'
    ).join('');

    final discountRow = order.discount > 0
        ? '<tr class="discount-row"><td colspan="3">Remise</td><td>-${_fmt.format(order.discount)}</td></tr>'
        : '';

    final qrData = 'N:$cashoutInvoiceNumber|D:$dateStr|M:${_fmt.format(order.totalAmount)}|R:Sankadiokro';
    final qrBlock = _qrScript(qrData);
    final header  = _htmlHeader("REÇU D'ENCAISSEMENT", "title-provisoire");
    final footer  = _htmlFooter;
    final prtBtn  = _printButton;
    final css     = _thermalCss();
    final orderType  = order.isTakeaway ? 'À emporter' : 'Sur place';
    final cashierRow = cashierName != null ? '<tr><td class="info-label">Caissier :</td><td class="info-value">${_escape(cashierName)}</td></tr>' : '';
    final serverRow  = order.serverName != null ? '<tr><td class="info-label">Serveur :</td><td class="info-value">${_escape(order.serverName!)}</td></tr>' : '';
    final tableNum = _escape(order.tableNumber);
    final subTot   = _fmt.format(order.subtotal);
    final tot      = _fmt.format(order.totalAmount);

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Reçu Encaissement Provisoire #$cashoutInvoiceNumber</title>
<style>$css</style>
</head>
<body>
<div class="receipt">
$header
<div class="badge-center"><span class="badge-pending">&#9888; En attente de r&egrave;glement</span></div>
<hr class="sep-dashed" />
<div class="section-title">Informations document</div>
<table class="info-table">
<tr><td class="info-label">N° :</td><td class="info-value">$cashoutInvoiceNumber</td></tr>
<tr><td class="info-label">Date :</td><td class="info-value">$dateStr</td></tr>
<tr><td class="info-label">Heure :</td><td class="info-value">$timeStr</td></tr>
$cashierRow
$serverRow
<tr><td class="info-label">Table :</td><td class="info-value">$tableNum</td></tr>
<tr><td class="info-label">Type :</td><td class="info-value">$orderType</td></tr>
</table>
<hr class="sep-dashed" />
<div class="section-title">D&eacute;tails commande</div>
<table class="items-table">
<thead><tr><th class="item-name">Article</th><th class="item-qty">Qté</th><th class="item-price">P.U</th><th class="item-total">Total</th></tr></thead>
<tbody>$itemsRows</tbody>
</table>
<hr class="sep-dashed" />
<table class="totals-table">
<tr class="subtotal-row"><td colspan="3">Sous-total :</td><td>$subTot F CFA</td></tr>
$discountRow
<tr class="total-row"><td colspan="3">Net à payer :</td><td>$tot F CFA</td></tr>
</table>
$qrBlock
$footer
$prtBtn
</div>
</body>
</html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  FACTURE RÉGLÉE DÉFINITIVE — design Sankadio v2 (80mm)
  //  Étape 2 : paiement complet avec mode, montant, monnaie.
  // ─────────────────────────────────────────────────────────────────────
  String _buildSettlementHtml({
    required Order order,
    required String settlementInvoiceNumber,
    required String paymentMethod,
    required double amountPaid,
    required double changeAmount,
    String? cashierName,
  }) {
    final settledDate = order.settledAt ?? DateTime.now();
    final dateFmt2 = DateFormat('dd/MM/yyyy');
    final timeFmt  = DateFormat('HH:mm');
    final dateStr  = dateFmt2.format(settledDate);
    final timeStr  = timeFmt.format(settledDate);

    final itemsRows = order.items.map((item) =>
      '<tr>'
      '<td class="item-name">${_escape(item.productName)}</td>'
      '<td class="item-qty">${item.quantity}</td>'
      '<td class="item-price">${_fmt.format(item.unitPrice)} F</td>'
      '<td class="item-total">${_fmt.format(item.totalPrice)} F</td>'
      '</tr>'
    ).join('');

    final discountRow = order.discount > 0
        ? '<tr class="discount-row"><td colspan="3">Remise</td><td>-${_fmt.format(order.discount)}</td></tr>'
        : '';

    final cashoutRef = order.cashoutInvoiceNumber != null
        ? '<tr><td class="info-label">R&eacute;f. encaiss. :</td><td class="info-value">${_escape(order.cashoutInvoiceNumber!)}</td></tr>'
        : '';

    final qrData = 'N:$settlementInvoiceNumber|D:$dateStr|M:${_fmt.format(order.totalAmount)}|R:Sankadiokro';
    final qrBlock = _qrScript(qrData);
    final header  = _htmlHeader("FACTURE RÉGLÉE", "title-reglee");
    final footer  = _htmlFooter;
    final prtBtn  = _printButton;
    final css     = _thermalCss();
    final orderType  = order.isTakeaway ? 'À emporter' : 'Sur place';
    final cashierRow = cashierName != null ? '<tr><td class="info-label">Caissier :</td><td class="info-value">${_escape(cashierName)}</td></tr>' : '';
    final serverRow  = order.serverName != null ? '<tr><td class="info-label">Serveur :</td><td class="info-value">${_escape(order.serverName!)}</td></tr>' : '';
    final tableNum = _escape(order.tableNumber);
    final subTot   = _fmt.format(order.subtotal);
    final tot      = _fmt.format(order.totalAmount);
    final amtFmt   = _fmt.format(amountPaid);
    final chgFmt   = _fmt.format(changeAmount);
    final payMode  = _escape(paymentMethod);

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Facture Réglée #$settlementInvoiceNumber</title>
<style>$css</style>
</head>
<body>
<div class="receipt">
$header
<div class="badge-center"><span class="badge-paid">&#10003;&nbsp;PAYÉE</span></div>
<hr class="sep-dashed" />
<div class="section-title">Informations document</div>
<table class="info-table">
<tr><td class="info-label">N° :</td><td class="info-value">$settlementInvoiceNumber</td></tr>
$cashoutRef
<tr><td class="info-label">Date :</td><td class="info-value">$dateStr</td></tr>
<tr><td class="info-label">Heure :</td><td class="info-value">$timeStr</td></tr>
$cashierRow
$serverRow
<tr><td class="info-label">Table :</td><td class="info-value">$tableNum</td></tr>
<tr><td class="info-label">Type :</td><td class="info-value">$orderType</td></tr>
</table>
<hr class="sep-dashed" />
<div class="section-title">D&eacute;tails commande</div>
<table class="items-table">
<thead><tr><th class="item-name">Article</th><th class="item-qty">Qté</th><th class="item-price">P.U</th><th class="item-total">Total</th></tr></thead>
<tbody>$itemsRows</tbody>
</table>
<hr class="sep-dashed" />
<table class="totals-table">
<tr class="subtotal-row"><td colspan="3">Sous-total :</td><td>$subTot F CFA</td></tr>
$discountRow
<tr class="total-row"><td colspan="3">Total TTC :</td><td>$tot F CFA</td></tr>
</table>
<hr class="sep-dashed" />
<div class="section-title">Paiement</div>
<div class="payment-block">
<div class="payment-row"><span class="payment-label">Mode :</span><span class="payment-value">$payMode</span></div>
<div class="payment-row"><span class="payment-label">Montant reçu :</span><span class="payment-value">$amtFmt F CFA</span></div>
<div class="payment-row"><span class="payment-label">Monnaie rendue :</span><span class="payment-value change">$chgFmt F CFA</span></div>
</div>
<div class="big-total-box">
<div class="big-total-label">Total réglé</div>
<div class="big-total-amount">$tot F CFA</div>
</div>
$qrBlock
$footer
$prtBtn
</div>
</body>
</html>''';
  }

    /// Génère un numéro de facture d'encaissement au format Sankadio : HHMMSS-OOOO
  /// Exemple : 194156-4546  (heure 19:41:56 + orderNumber 4546)
  static String generateReceiptNumber(int orderNumber) {
    final now = DateTime.now();
    final timePart = DateFormat('HHmmss').format(now);
    final orderPart = orderNumber.toString().padLeft(4, '0');
    return '$timePart-$orderPart';
  }

  /// Génère un numéro de facture provisoire au format FAC-YYYYMMDD-OOOO
  /// Exemple : FAC-20250712-0042
  /// Utilisé comme identifiant garanti non-vide pour les factures provisoires.
  static String generateFacNumber(int orderNumber) {
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);
    return 'FAC-$datePart-${orderNumber.toString().padLeft(4, '0')}';
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

  // ─────────────────────────────────────────────────────────────────────
  //  CONTRAT EMPLOYÉ — impression PDF A4
  //  Appelé depuis contract_screen.dart via PrintService().printContract(contract: c)
  // ─────────────────────────────────────────────────────────────────────
  void printContract({required EmployeeContract contract}) {
    final html = _buildContractHtml(contract: contract);
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: contrat employé ${contract.employeeId}');
    }
  }

  /// Construit le HTML A4 pour un contrat employé.
  String _buildContractHtml({required EmployeeContract contract}) {
    final logo = _logoBase64();
    final dateFmtShort = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();

    final startStr  = dateFmtShort.format(contract.startDate);
    final endStr    = contract.endDate != null ? dateFmtShort.format(contract.endDate!) : '—';
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final typeLabel   = contract.type.label;
    final statusLabel = contract.computedStatus.label;
    final salary = contract.salary > 0
        ? '${_fmt.format(contract.salary)} FCFA'
        : '—';
    final poste   = _escape(contract.poste.isNotEmpty ? contract.poste : '—');
    final site    = _escape(contract.site.isNotEmpty  ? contract.site  : '—');
    final comment = _escape(contract.comment.isNotEmpty ? contract.comment : '—');

    // Status colour for the badge
    final statusHex = _contractStatusHex(contract.computedStatus);

    // Days left row (only when there's an endDate)
    String daysLeftRow = '';
    if (contract.endDate != null) {
      final d = contract.daysLeft!;
      final daysStr = d < 0 ? 'Expiré (${d.abs()} jours)' : 'Dans $d jour(s)';
      daysLeftRow = '''
        <tr>
          <td class="ct-label">Jours restants</td>
          <td class="ct-value">$daysStr</td>
        </tr>''';
    }

    // Comment/decision block (shown when comment is set)
    String decisionBlock = '';
    if (contract.comment.isNotEmpty) {
      decisionBlock = '''
      <div class="section-block">
        <div class="section-heading">Commentaire / Décision</div>
        <p class="decision-text">${_escape(contract.comment)}</p>
      </div>''';
    }

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8"/>
<title>Contrat Employé — ${_escape(contract.poste)}</title>
<style>
  @page { size: A4; margin: 18mm 15mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    font-size: 11px; color: #111; background: #fff;
  }
  .page { width: 100%; }

  /* ── EN-TÊTE ── */
  .doc-header { display: flex; align-items: center; border-bottom: 2px solid #111; padding-bottom: 10px; margin-bottom: 14px; }
  .logo-wrap  { flex-shrink: 0; margin-right: 14px; }
  .logo-img   { width: 64px; height: 64px; object-fit: contain; }
  .hdr-text   { flex: 1; }
  .hdr-name   { font-size: 16px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; }
  .hdr-tag    { font-size: 10px; font-style: italic; color: #555; margin-top: 2px; }
  .doc-title-wrap { text-align: right; }
  .doc-title  { font-size: 13px; font-weight: bold; text-transform: uppercase;
                letter-spacing: 1.2px; color: #0D47A1; border: 1.5px solid #0D47A1;
                padding: 4px 14px; border-radius: 4px; display: inline-block; }
  .doc-subtitle { font-size: 9px; color: #777; margin-top: 4px; }

  /* ── BADGE STATUT ── */
  .status-badge { display: inline-block; padding: 3px 12px; border-radius: 12px;
                  font-weight: bold; font-size: 10.5px; letter-spacing: 0.8px;
                  background: $statusHex; color: #fff; }

  /* ── SECTIONS ── */
  .section-block { margin-bottom: 14px; }
  .section-heading {
    font-size: 9px; font-weight: bold; text-transform: uppercase;
    letter-spacing: 1.4px; color: #555;
    border-bottom: 1px solid #ddd; padding-bottom: 3px; margin-bottom: 6px;
  }

  /* ── TABLE CONTRAT ── */
  .ct-table { width: 100%; border-collapse: collapse; }
  .ct-table tr td { padding: 4px 4px; font-size: 11px; vertical-align: top; border-bottom: 1px solid #f0f0f0; }
  .ct-label { color: #555; width: 38%; }
  .ct-value { font-weight: bold; color: #111; }

  /* ── DÉCISION ── */
  .decision-text {
    font-style: italic; color: #333; background: #F9F9F9;
    border-left: 3px solid #0D47A1; padding: 6px 10px;
    border-radius: 0 4px 4px 0; font-size: 11px; margin-top: 4px;
  }

  /* ── SIGNATURES ── */
  .signatures-row { display: flex; gap: 24px; margin-top: 40px; }
  .sig-block { flex: 1; text-align: center; }
  .sig-title { font-size: 10px; font-weight: bold; color: #333; text-transform: uppercase;
               letter-spacing: 0.8px; margin-bottom: 48px; }
  .sig-line  { border-top: 1px solid #111; padding-top: 4px; font-size: 9.5px; color: #555; }

  /* ── PIED DE PAGE ── */
  .doc-footer { border-top: 1px dashed #aaa; margin-top: 30px; padding-top: 6px;
                text-align: center; font-size: 8.5px; color: #777; }

  /* ── BOUTON ── */
  .print-btn { text-align: center; margin-top: 18px; }

  /* ── ÉCRAN ── */
  @media screen {
    body { background: #ECEFF1; display: flex; justify-content: center; padding: 24px; }
    .page { background: #fff; max-width: 210mm; box-shadow: 0 4px 24px rgba(0,0,0,0.15); padding: 20px 24px; }
  }
  @media print {
    body { background: #fff; }
    .print-btn { display: none; }
  }
</style>
</head>
<body>
<div class="page">

  <!-- EN-TÊTE -->
  <div class="doc-header">
    <div class="logo-wrap">
      <img src="$logo" alt="Logo" class="logo-img" onerror="this.style.display='none'" />
    </div>
    <div class="hdr-text">
      <div class="hdr-name">Restaurant Sankadiokro</div>
      <div class="hdr-tag">Cuisine Africaine &amp; Ivoirienne</div>
    </div>
    <div class="doc-title-wrap">
      <div class="doc-title">Contrat de Travail</div>
      <div class="doc-subtitle">Imprimé le $printedAt</div>
    </div>
  </div>

  <!-- INFORMATIONS DU CONTRAT -->
  <div class="section-block">
    <div class="section-heading">Informations du Contrat</div>
    <table class="ct-table">
      <tr>
        <td class="ct-label">Type de contrat</td>
        <td class="ct-value">$typeLabel</td>
      </tr>
      <tr>
        <td class="ct-label">Poste</td>
        <td class="ct-value">$poste</td>
      </tr>
      <tr>
        <td class="ct-label">Site d'affectation</td>
        <td class="ct-value">$site</td>
      </tr>
      <tr>
        <td class="ct-label">Date de début</td>
        <td class="ct-value">$startStr</td>
      </tr>
      <tr>
        <td class="ct-label">Date de fin</td>
        <td class="ct-value">$endStr</td>
      </tr>
      $daysLeftRow
      <tr>
        <td class="ct-label">Salaire mensuel</td>
        <td class="ct-value">$salary</td>
      </tr>
      <tr>
        <td class="ct-label">Statut</td>
        <td class="ct-value"><span class="status-badge">$statusLabel</span></td>
      </tr>
      <tr>
        <td class="ct-label">Commentaire</td>
        <td class="ct-value">$comment</td>
      </tr>
    </table>
  </div>

  $decisionBlock

  <!-- CLAUSES -->
  <div class="section-block">
    <div class="section-heading">Clauses &amp; Conditions</div>
    <p style="font-size:10.5px;color:#333;line-height:1.7;">
      Le présent contrat est établi conformément aux dispositions du Code du Travail de la République de
      Côte d'Ivoire. L'employé s'engage à respecter le règlement intérieur de l'établissement,
      à observer les horaires fixés et à accomplir les tâches relevant de son poste.
      En cas de manquement grave, le contrat pourra être résilié selon les modalités légales en vigueur.
    </p>
  </div>

  <!-- SIGNATURES -->
  <div class="signatures-row">
    <div class="sig-block">
      <div class="sig-title">Signature de l'Employé</div>
      <div class="sig-line">Nom &amp; Signature</div>
    </div>
    <div class="sig-block">
      <div class="sig-title">Signature de la Direction</div>
      <div class="sig-line">Directeur / Gérant</div>
    </div>
    <div class="sig-block">
      <div class="sig-title">Cachet de l'Établissement</div>
      <div class="sig-line">Tampon officiel</div>
    </div>
  </div>

  <!-- PIED DE PAGE -->
  <div class="doc-footer">
    Restaurant Sankadiokro &nbsp;|&nbsp; Yopougon Millionnaire, Abidjan &nbsp;|&nbsp;
    &#9993; restaurantsankadiokro@gmail.com &nbsp;|&nbsp; &#128222; 07 07 04 29 47
  </div>

  <!-- BOUTON IMPRESSION -->
  <div class="print-btn">
    <button onclick="window.print()"
      style="padding:8px 24px;background:#0D47A1;color:#fff;border:none;border-radius:6px;
             cursor:pointer;font-size:12px;font-weight:bold;letter-spacing:0.5px;">
      &#128424; Imprimer / Enregistrer PDF
    </button>
  </div>

</div>
</body>
</html>''';
  }

  /// Retourne la couleur hex correspondant à un statut de contrat (pour le badge HTML)
  String _contractStatusHex(ContractStatus s) {
    switch (s) {
      case ContractStatus.actif:         return '#2E7D32';
      case ContractStatus.bientotExpire: return '#E65100';
      case ContractStatus.expire:        return '#B71C1C';
      case ContractStatus.renouvele:     return '#1565C0';
      case ContractStatus.nonRenouvele:  return '#4E342E';
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  FICHE DE PAIE — PDF A4 identique au modèle Restaurant Sankadiokro
  //  Appelé depuis salary_screen.dart via PrintService().printPayslip(salary: s)
  // ─────────────────────────────────────────────────────────────────────
  void printPayslip({required EmployeeSalary salary}) {
    final html = _buildPayslipHtml(salary: salary);
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: fiche de paie ${salary.employeeName} ${salary.periode}');
    }
  }

  /// Construit le HTML A4 de la fiche de paie.
  String _buildPayslipHtml({required EmployeeSalary salary}) {
    final logo     = _logoBase64();
    final fmt      = NumberFormat('#,###', 'fr_FR');
    final dateFmt  = DateFormat('dd/MM/yyyy');
    final now      = DateTime.now();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(now);

    final name    = _escape(salary.employeeName);
    final poste   = _escape(salary.poste.isNotEmpty  ? salary.poste   : '—');
    final matricule = _escape(salary.matricule.isNotEmpty ? salary.matricule : '—');
    final periode = _escape(salary.periode);

    // ── Lignes gains ─────────────────────────────────────────────────────
    String gainsRows = '';
    void addGainRow(String label, double base, double taux, double montant) {
      if (montant <= 0) return;
      gainsRows += '''
        <tr>
          <td class="col-desig">${_escape(label)}</td>
          <td class="col-base">${fmt.format(base)}</td>
          <td class="col-taux">${taux > 0 ? '${taux.toStringAsFixed(1)}%' : '—'}</td>
          <td class="col-mont">${fmt.format(montant)}</td>
        </tr>''';
    }
    addGainRow('Salaire de base',        salary.salaryBase, 100.0, salary.salaryBase);
    addGainRow('Heures supplémentaires', salary.heuresSup,  0,     salary.heuresSup);
    addGainRow('Primes',                 salary.primes,     0,     salary.primes);
    addGainRow('Indemnités',             salary.indemnites, 0,     salary.indemnites);

    // ── Lignes retenues ─────────────────────────────────────────────────
    String retenuesRows = '';
    void addRetenueRow(String label, double taux, double montant) {
      if (montant <= 0) return;
      retenuesRows += '''
        <tr>
          <td class="col-desig">${_escape(label)}</td>
          <td class="col-base">—</td>
          <td class="col-taux">${taux > 0 ? '${taux.toStringAsFixed(2)}%' : '—'}</td>
          <td class="col-mont ret-neg">${fmt.format(montant)}</td>
        </tr>''';
    }
    addRetenueRow('CNPS (Cotisation sociale)',    3.2,  salary.cnps);
    addRetenueRow('ITS (Impôt sur traitement)',   0,    salary.its);
    addRetenueRow('Autres retenues',              0,    salary.autresRetenues);
    addRetenueRow('Avances sur salaire',          0,    salary.avances);

    // ── Statut paiement ──────────────────────────────────────────────────
    final stHex  = _payStatusHex(salary.paymentStatus);
    final stLabel = salary.paymentStatus.label.toUpperCase();
    final datePaie = salary.datePaiement != null
        ? dateFmt.format(salary.datePaiement!)
        : '—';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8"/>
<title>Fiche de Paie — $name — $periode</title>
<style>
  @page { size: A4; margin: 14mm 12mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 11px; color: #111; background: #fff; }
  .page { width: 100%; }

  /* ── EN-TÊTE ── */
  .header-wrap {
    display: flex; align-items: flex-start;
    border-bottom: 3px double #111; padding-bottom: 10px; margin-bottom: 12px;
  }
  .logo-wrap { flex-shrink: 0; margin-right: 12px; }
  .logo-img  { width: 62px; height: 62px; object-fit: contain; }
  .company   { flex: 1; }
  .co-name   { font-size: 17px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; color: #0D47A1; }
  .co-sub    { font-size: 9.5px; color: #555; font-style: italic; margin-top: 2px; }
  .co-addr   { font-size: 9px; color: #333; margin-top: 4px; line-height: 1.6; }
  .doc-title-wrap { text-align: right; }
  .doc-title {
    font-size: 14px; font-weight: bold; text-transform: uppercase;
    letter-spacing: 1.5px; color: #0D47A1;
    border: 2px solid #0D47A1; padding: 5px 16px; border-radius: 4px;
    display: inline-block;
  }
  .doc-periode { font-size: 10px; color: #555; margin-top: 5px; font-weight: bold; }
  .doc-printed { font-size: 8.5px; color: #999; margin-top: 3px; }

  /* ── INFOS EMPLOYÉ ── */
  .emp-box {
    background: #F4F6FB; border: 1px solid #dde2f0;
    border-radius: 6px; padding: 9px 14px; margin-bottom: 12px;
    display: flex; gap: 24px; flex-wrap: wrap;
  }
  .emp-col { flex: 1; min-width: 140px; }
  .emp-label { font-size: 8.5px; color: #666; text-transform: uppercase; letter-spacing: 0.8px; }
  .emp-value { font-size: 11.5px; font-weight: bold; color: #111; margin-top: 1px; }

  /* ── TABLEAU SALAIRE ── */
  .sal-table { width: 100%; border-collapse: collapse; margin-bottom: 4px; }
  .sal-table thead tr { background: #0D47A1; color: #fff; }
  .sal-table thead th { padding: 6px 8px; font-size: 10px; font-weight: bold; text-align: left; text-transform: uppercase; letter-spacing: 0.5px; }
  .sal-table tbody tr:nth-child(even) { background: #F8F9FF; }
  .sal-table tbody td { padding: 5px 8px; font-size: 10.5px; border-bottom: 1px solid #e8ecf5; }
  .col-desig { width: 44%; }
  .col-base  { width: 18%; text-align: right; }
  .col-taux  { width: 14%; text-align: center; }
  .col-mont  { width: 24%; text-align: right; font-weight: bold; }
  .ret-neg   { color: #B71C1C; }
  .section-hdr td {
    background: #E8EAF6; font-size: 9px; font-weight: bold;
    letter-spacing: 1.1px; color: #3949AB;
    text-transform: uppercase; padding: 4px 8px;
  }
  .total-row td { background: #fff3e0; font-weight: bold; font-size: 11px; padding: 5px 8px; }
  .total-row .col-mont { color: #E65100; }

  /* ── NET À PAYER ── */
  .net-box {
    display: flex; justify-content: space-between; align-items: center;
    background: #0D47A1; color: #fff;
    padding: 10px 16px; border-radius: 6px; margin: 10px 0;
  }
  .net-label { font-size: 13px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; }
  .net-amount { font-size: 20px; font-weight: bold; letter-spacing: 0.5px; }

  /* ── PAIEMENT ── */
  .pay-row {
    display: flex; gap: 16px; margin-bottom: 12px; flex-wrap: wrap;
  }
  .pay-chip {
    flex: 1; min-width: 100px;
    background: #F4F6FB; border: 1px solid #dde2f0;
    border-radius: 6px; padding: 7px 12px; text-align: center;
  }
  .pay-chip-label { font-size: 8.5px; color: #666; text-transform: uppercase; letter-spacing: 0.7px; }
  .pay-chip-value { font-size: 12px; font-weight: bold; color: #111; margin-top: 2px; }
  .status-badge {
    display: inline-block; padding: 3px 14px; border-radius: 12px;
    font-size: 10px; font-weight: bold; letter-spacing: 1px; color: #fff;
    background: $stHex;
  }

  /* ── SIGNATURES ── */
  .sig-section { margin-top: 24px; border-top: 1px dashed #bbb; padding-top: 14px; }
  .sig-row { display: flex; gap: 24px; }
  .sig-block { flex: 1; text-align: center; }
  .sig-title { font-size: 9.5px; font-weight: bold; text-transform: uppercase; letter-spacing: 0.8px; color: #333; margin-bottom: 48px; }
  .sig-line  { border-top: 1px solid #111; padding-top: 4px; font-size: 9px; color: #555; }

  /* ── PIED DE PAGE ── */
  .footer { text-align: center; margin-top: 18px; font-size: 8px; color: #999; border-top: 1px solid #eee; padding-top: 6px; }

  /* ── BOUTON ── */
  .print-btn { text-align: center; margin-top: 16px; }

  @media screen {
    body { background: #ECEFF1; display: flex; justify-content: center; padding: 24px; }
    .page { background: #fff; max-width: 210mm; box-shadow: 0 4px 24px rgba(0,0,0,0.15); padding: 20px 24px; }
  }
  @media print {
    body { background: #fff; }
    .print-btn { display: none; }
  }
</style>
</head>
<body>
<div class="page">

  <!-- EN-TÊTE -->
  <div class="header-wrap">
    <div class="logo-wrap">
      <img src="$logo" alt="Logo" class="logo-img" onerror="this.style.display='none'" />
    </div>
    <div class="company">
      <div class="co-name">Restaurant Sankadiokro</div>
      <div class="co-sub">Cuisine Africaine &amp; Ivoirienne</div>
      <div class="co-addr">
        &#128205; Yopougon Millionnaire, Abidjan<br/>
        &#9993; restaurantsankadiokro@gmail.com &nbsp;|&nbsp; &#128222; 07 07 04 29 47
      </div>
    </div>
    <div class="doc-title-wrap">
      <div class="doc-title">Fiche de Paie</div>
      <div class="doc-periode">Période : $periode</div>
      <div class="doc-printed">Imprimé le $printedAt</div>
    </div>
  </div>

  <!-- INFOS EMPLOYÉ -->
  <div class="emp-box">
    <div class="emp-col">
      <div class="emp-label">Nom &amp; Prénoms</div>
      <div class="emp-value">$name</div>
    </div>
    <div class="emp-col">
      <div class="emp-label">Poste</div>
      <div class="emp-value">$poste</div>
    </div>
    <div class="emp-col">
      <div class="emp-label">Matricule</div>
      <div class="emp-value">$matricule</div>
    </div>
    <div class="emp-col">
      <div class="emp-label">Période</div>
      <div class="emp-value">$periode</div>
    </div>
  </div>

  <!-- TABLEAU DÉSIGNATION / BASE / TAUX / MONTANT -->
  <table class="sal-table">
    <thead>
      <tr>
        <th class="col-desig">Désignation</th>
        <th class="col-base">Base (F CFA)</th>
        <th class="col-taux">Taux</th>
        <th class="col-mont">Montant (F CFA)</th>
      </tr>
    </thead>
    <tbody>
      <tr class="section-hdr"><td colspan="4">GAINS</td></tr>
      $gainsRows
      <tr class="total-row">
        <td colspan="3">SALAIRE BRUT</td>
        <td class="col-mont">${fmt.format(salary.brut)}</td>
      </tr>
      <tr class="section-hdr"><td colspan="4">RETENUES</td></tr>
      $retenuesRows
      <tr class="total-row">
        <td colspan="3">TOTAL RETENUES</td>
        <td class="col-mont">${fmt.format(salary.totalRetenues)}</td>
      </tr>
    </tbody>
  </table>

  <!-- NET À PAYER -->
  <div class="net-box">
    <span class="net-label">Net à payer</span>
    <span class="net-amount">${fmt.format(salary.netAPayer)} F CFA</span>
  </div>

  <!-- PAIEMENT -->
  <div class="pay-row">
    <div class="pay-chip">
      <div class="pay-chip-label">Statut</div>
      <div class="pay-chip-value"><span class="status-badge">$stLabel</span></div>
    </div>
    <div class="pay-chip">
      <div class="pay-chip-label">Montant payé</div>
      <div class="pay-chip-value">${fmt.format(salary.montantPaye)} F</div>
    </div>
    <div class="pay-chip">
      <div class="pay-chip-label">Reste à payer</div>
      <div class="pay-chip-value">${fmt.format(salary.resteAPayer)} F</div>
    </div>
    <div class="pay-chip">
      <div class="pay-chip-label">Date paiement</div>
      <div class="pay-chip-value">$datePaie</div>
    </div>
    <div class="pay-chip">
      <div class="pay-chip-label">Mode paiement</div>
      <div class="pay-chip-value">${salary.modePaiement.label}</div>
    </div>
  </div>

  <!-- SIGNATURES -->
  <div class="sig-section">
    <div class="sig-row">
      <div class="sig-block">
        <div class="sig-title">Signature du Salarié</div>
        <div class="sig-line">Lu et approuvé</div>
      </div>
      <div class="sig-block">
        <div class="sig-title">Date &amp; Cachet Direction</div>
        <div class="sig-line">Le Directeur / Gérant</div>
      </div>
    </div>
  </div>

  <!-- PIED DE PAGE -->
  <div class="footer">
    Restaurant Sankadiokro &nbsp;|&nbsp; Yopougon Millionnaire, Abidjan &nbsp;|&nbsp;
    Ce document est confidentiel — usage interne uniquement
  </div>

  <!-- BOUTON -->
  <div class="print-btn">
    <button onclick="window.print()"
      style="padding:8px 24px;background:#0D47A1;color:#fff;border:none;border-radius:6px;
             cursor:pointer;font-size:12px;font-weight:bold;letter-spacing:0.5px;">
      &#128424; Imprimer / Enregistrer PDF
    </button>
  </div>

</div>
</body>
</html>''';
  }

  /// Couleur hex pour le badge de statut de paiement
  String _payStatusHex(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.nonPaye: return '#B71C1C';
      case PaymentStatus.partiel: return '#E65100';
      case PaymentStatus.paye:    return '#2E7D32';
    }
  }

  /// Retourne l'URL du logo pour inclusion dans les tickets HTML
  /// Sur Web Flutter, les assets sont accessibles via chemin relatif depuis la racine
  String _logoBase64() {
    // Sur Flutter Web, les assets sont publiés à la racine de /assets/
    // L'URL relative fonctionne dans la fenêtre d'impression (même origine)
    return 'assets/images/logo_sankadiokro.png';
  }

  // ── DEVIS RÉSERVATION ─────────────────────────────────────────────────────
  void printReservationQuote({required Reservation reservation}) {
    final html = _buildReservationQuoteHtml(reservation: reservation);
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    }
  }

  String _buildReservationQuoteHtml({required Reservation reservation}) {
    final r       = reservation;
    final fmt     = NumberFormat('#,###', 'fr_FR');
    final fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');
    final fmtFull = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');
    final now     = DateTime.now();
    final ref     = 'DEV-${now.year}${now.month.toString().padLeft(2, '0')}-${now.millisecond}';

    String statusColor;
    switch (r.paymentStatus) {
      case ReservationPaymentStatus.paye:    statusColor = '#2E7D32'; break;
      case ReservationPaymentStatus.partiel: statusColor = '#E65100'; break;
      default:                               statusColor = '#B71C1C';
    }

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8"/>
<title>Devis Réservation – ${r.nomClient}</title>
<style>
  @page { size: A4; margin: 18mm 16mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #fff; color: #1a1a2e; font-size: 11px; }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #1565C0; padding-bottom: 14px; margin-bottom: 18px; }
  .logo-block { display: flex; align-items: center; gap: 12px; }
  .logo { width: 60px; height: 60px; object-fit: contain; }
  .company h1 { font-size: 18px; font-weight: 900; color: #1565C0; letter-spacing: 2px; }
  .company p  { font-size: 10px; color: #555; }
  .doc-info   { text-align: right; }
  .doc-info h2 { font-size: 16px; font-weight: 900; color: #1565C0; text-transform: uppercase; }
  .doc-info .ref { font-size: 11px; color: #555; margin-top: 4px; }
  .section { margin-bottom: 16px; }
  .section-title { font-size: 12px; font-weight: 800; color: #1565C0; border-left: 4px solid #1565C0; padding-left: 8px; margin-bottom: 8px; text-transform: uppercase; }
  .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 4px 20px; }
  .info-row  { display: flex; gap: 6px; }
  .info-row .lbl { color: #666; min-width: 110px; }
  .info-row .val { font-weight: 600; color: #1a1a2e; }
  table.montants { width: 100%; border-collapse: collapse; margin-top: 6px; }
  table.montants th { background: #1565C0; color: #fff; padding: 8px 10px; text-align: left; font-size: 11px; }
  table.montants td { padding: 8px 10px; border-bottom: 1px solid #e0e0e0; }
  table.montants tr:nth-child(even) td { background: #f5f5f5; }
  .net-box { background: #1565C0; color: white; padding: 14px 20px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; margin: 14px 0; }
  .net-box .lbl { font-size: 14px; font-weight: 700; }
  .net-box .val { font-size: 20px; font-weight: 900; }
  .badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 10px; font-weight: 700; color: white; }
  .event-box { background: #E3F2FD; border: 1px solid #1565C0; border-radius: 8px; padding: 12px 16px; margin-bottom: 14px; }
  .event-box .emoji { font-size: 28px; }
  .event-type { font-size: 14px; font-weight: 900; color: #1565C0; }
  .footer { margin-top: 24px; border-top: 1px solid #e0e0e0; padding-top: 12px; font-size: 9px; color: #888; text-align: center; }
  .signatures { display: flex; gap: 20px; margin-top: 30px; }
  .sig-block { flex: 1; border: 1px dashed #aaa; padding: 16px; border-radius: 6px; min-height: 70px; text-align: center; color: #666; font-size: 10px; }
  @media print { body { print-color-adjust: exact; -webkit-print-color-adjust: exact; } }
</style>
</head>
<body>

<div class="header">
  <div class="logo-block">
    <img src="${_logoBase64()}" class="logo" alt="Logo"/>
    <div class="company">
      <h1>RESTAURANT SANKADIOKRO</h1>
      <p>Restaurant Africain • Cuisine traditionnelle</p>
      <p>Abidjan, Côte d\'Ivoire</p>
    </div>
  </div>
  <div class="doc-info">
    <h2>Devis Réservation</h2>
    <div class="ref">Réf : $ref</div>
    <div class="ref">Date : ${fmtDate.format(now)}</div>
    <span class="badge" style="background:${statusColor}">${r.paymentStatus.label}</span>
  </div>
</div>

<div class="event-box">
  <div style="display:flex;align-items:center;gap:12px">
    <span class="emoji">${r.typeEvenement.emoji}</span>
    <div>
      <div class="event-type">${r.typeEvenement.label}</div>
      <div style="font-size:11px;color:#555">Le ${fmtFull.format(r.dateEvenement)}</div>
      ${r.heureDebut.isNotEmpty ? '<div style="font-size:11px;color:#555">Horaires : ${r.heureDebut}${r.heureFin.isNotEmpty ? " – ${r.heureFin}" : ""}</div>' : ''}
    </div>
  </div>
</div>

<div class="section">
  <div class="section-title">Informations client</div>
  <div class="info-grid">
    <div class="info-row"><span class="lbl">Nom complet :</span><span class="val">${r.nomClient}</span></div>
    <div class="info-row"><span class="lbl">Téléphone :</span><span class="val">${r.telephone}</span></div>
    ${r.telephoneSecondaire.isNotEmpty ? '<div class="info-row"><span class="lbl">Tél. secondaire :</span><span class="val">${r.telephoneSecondaire}</span></div>' : ''}
    ${r.email.isNotEmpty ? '<div class="info-row"><span class="lbl">Email :</span><span class="val">${r.email}</span></div>' : ''}
    ${r.adresse.isNotEmpty ? '<div class="info-row"><span class="lbl">Adresse :</span><span class="val">${r.adresse}</span></div>' : ''}
  </div>
</div>

<div class="section">
  <div class="section-title">Détails de l\'événement</div>
  <div class="info-grid">
    <div class="info-row"><span class="lbl">Type :</span><span class="val">${r.typeEvenement.label}</span></div>
    <div class="info-row"><span class="lbl">Date événement :</span><span class="val">${fmtFull.format(r.dateEvenement)}</span></div>
    <div class="info-row"><span class="lbl">Nb. personnes :</span><span class="val">${r.nombrePersonnes} personnes</span></div>
    ${r.salle.isNotEmpty ? '<div class="info-row"><span class="lbl">Salle :</span><span class="val">${r.salle}</span></div>' : ''}
    ${r.responsableCommercial.isNotEmpty ? '<div class="info-row"><span class="lbl">Responsable :</span><span class="val">${r.responsableCommercial}</span></div>' : ''}
  </div>
  ${r.description.isNotEmpty ? '<div style="margin-top:8px"><span style="color:#666">Description : </span>${r.description}</div>' : ''}
</div>

<div class="section">
  <div class="section-title">Détail des montants</div>
  <table class="montants">
    <tr><th>Désignation</th><th style="text-align:right">Montant (F CFA)</th></tr>
    <tr><td>Montant total devis</td><td style="text-align:right;font-weight:600">${fmt.format(r.montantTotal)}</td></tr>
    ${r.remise > 0 ? '<tr><td>Remise accordée</td><td style="text-align:right;color:#c00">- ${fmt.format(r.remise)}</td></tr>' : ''}
    <tr style="background:#E3F2FD"><td style="font-weight:800">Montant net</td><td style="text-align:right;font-weight:800">${fmt.format(r.montantNet)}</td></tr>
    <tr><td>Acompte versé</td><td style="text-align:right;color:green">- ${fmt.format(r.acompteVerse)}</td></tr>
    <tr><td>Montant déjà payé</td><td style="text-align:right;color:green">- ${fmt.format(r.montantPaye)}</td></tr>
  </table>
</div>

<div class="net-box">
  <span class="lbl">SOLDE RESTANT À PAYER</span>
  <span class="val">${fmt.format(r.soldeRestant.clamp(0, double.infinity))} F CFA</span>
</div>

<div class="section">
  <div class="section-title">Signatures</div>
  <div class="signatures">
    <div class="sig-block">
      <div>Le Client</div>
      <div style="margin-top:30px;border-top:1px solid #ccc;padding-top:6px">${r.nomClient}</div>
    </div>
    <div class="sig-block">
      <div>La Direction</div>
      <div style="margin-top:30px;border-top:1px solid #ccc;padding-top:6px">Restaurant SANKADIOKRO</div>
    </div>
  </div>
</div>

<div class="footer">
  Ce document est un devis valable 30 jours à compter de sa date d\'émission.<br>
  Restaurant SANKADIOKRO — Abidjan, Côte d\'Ivoire — Généré le ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(now)}
</div>

</body></html>''';
  }

  // ── CONTRAT RÉSERVATION ───────────────────────────────────────────────────
  void printReservationContract({required Reservation reservation}) {
    final html = _buildReservationContractHtml(reservation: reservation);
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    }
  }

  String _buildReservationContractHtml({required Reservation reservation}) {
    final r       = reservation;
    final fmt     = NumberFormat('#,###', 'fr_FR');
    final fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');
    final fmtFull = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');
    final now     = DateTime.now();
    final ref     = 'CONT-${now.year}${now.month.toString().padLeft(2, '0')}-${r.nomClient.length}${now.millisecond}';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8"/>
<title>Contrat de Réservation – ${r.nomClient}</title>
<style>
  @page { size: A4; margin: 18mm 16mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #fff; color: #1a1a2e; font-size: 11px; line-height: 1.5; }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #1565C0; padding-bottom: 14px; margin-bottom: 18px; }
  .logo-block { display: flex; align-items: center; gap: 12px; }
  .logo { width: 60px; height: 60px; object-fit: contain; }
  .company h1 { font-size: 18px; font-weight: 900; color: #1565C0; letter-spacing: 2px; }
  .company p  { font-size: 10px; color: #555; }
  .doc-info   { text-align: right; }
  .doc-info h2 { font-size: 16px; font-weight: 900; color: #1565C0; text-transform: uppercase; }
  .doc-info .ref { font-size: 11px; color: #555; margin-top: 4px; }
  .parties { display: flex; gap: 16px; margin-bottom: 16px; }
  .partie { flex: 1; background: #f5f9ff; border: 1px solid #1565C0; border-radius: 6px; padding: 12px; }
  .partie h3 { font-size: 12px; font-weight: 800; color: #1565C0; margin-bottom: 6px; text-transform: uppercase; }
  .article { margin-bottom: 14px; }
  .article h4 { font-size: 12px; font-weight: 800; color: #1565C0; border-left: 4px solid #1565C0; padding-left: 8px; margin-bottom: 6px; }
  .article p  { text-align: justify; color: #333; }
  .fin-table { width: 100%; border-collapse: collapse; margin: 8px 0; }
  .fin-table th { background: #1565C0; color: #fff; padding: 7px 10px; text-align: left; font-size: 11px; }
  .fin-table td { padding: 7px 10px; border-bottom: 1px solid #e0e0e0; }
  .net-box { background: #1565C0; color: white; padding: 12px 18px; border-radius: 8px; display: flex; justify-content: space-between; margin: 12px 0; }
  .net-box .lbl { font-size: 13px; font-weight: 700; }
  .net-box .val { font-size: 18px; font-weight: 900; }
  .signatures { display: flex; gap: 20px; margin-top: 30px; }
  .sig-block { flex: 1; border: 1px dashed #aaa; padding: 16px; border-radius: 6px; min-height: 80px; text-align: center; color: #666; font-size: 10px; }
  .footer { margin-top: 20px; border-top: 1px solid #e0e0e0; padding-top: 10px; font-size: 9px; color: #888; text-align: center; }
  @media print { body { print-color-adjust: exact; -webkit-print-color-adjust: exact; } }
</style>
</head>
<body>

<div class="header">
  <div class="logo-block">
    <img src="${_logoBase64()}" class="logo" alt="Logo"/>
    <div class="company">
      <h1>RESTAURANT SANKADIOKRO</h1>
      <p>Restaurant Africain • Cuisine traditionnelle</p>
      <p>Abidjan, Côte d\'Ivoire</p>
    </div>
  </div>
  <div class="doc-info">
    <h2>Contrat de Réservation</h2>
    <div class="ref">Réf : $ref</div>
    <div class="ref">Date : ${fmtDate.format(now)}</div>
  </div>
</div>

<div class="parties">
  <div class="partie">
    <h3>Le Prestataire</h3>
    <p><strong>Restaurant SANKADIOKRO</strong><br>Abidjan, Côte d\'Ivoire<br>Restauration – Événementiel</p>
  </div>
  <div class="partie">
    <h3>Le Client</h3>
    <p><strong>${r.nomClient}</strong><br>Tél. : ${r.telephone}${r.email.isNotEmpty ? '<br>' + r.email : ''}${r.adresse.isNotEmpty ? '<br>' + r.adresse : ''}</p>
  </div>
</div>

<div class="article">
  <h4>Article 1 – Objet du contrat</h4>
  <p>Le Restaurant SANKADIOKRO s\'engage à mettre à la disposition du Client ses locaux et ses services pour l\'organisation de : <strong>${r.typeEvenement.emoji} ${r.typeEvenement.label}</strong>${r.description.isNotEmpty ? ', ' + r.description : ''}.</p>
</div>

<div class="article">
  <h4>Article 2 – Date et détails de l\'événement</h4>
  <p>
    <strong>Date :</strong> ${fmtFull.format(r.dateEvenement)}<br>
    ${r.heureDebut.isNotEmpty ? '<strong>Horaires :</strong> ${r.heureDebut}${r.heureFin.isNotEmpty ? " – ${r.heureFin}" : ""}<br>' : ''}
    <strong>Nombre de personnes :</strong> ${r.nombrePersonnes} personnes<br>
    ${r.salle.isNotEmpty ? '<strong>Salle/espace :</strong> ${r.salle}<br>' : ''}
    ${r.responsableCommercial.isNotEmpty ? '<strong>Responsable commercial :</strong> ${r.responsableCommercial}' : ''}
  </p>
</div>

<div class="article">
  <h4>Article 3 – Conditions financières</h4>
  <table class="fin-table">
    <tr><th>Désignation</th><th style="text-align:right">Montant (F CFA)</th></tr>
    <tr><td>Montant total convenu</td><td style="text-align:right;font-weight:700">${fmt.format(r.montantTotal)}</td></tr>
    ${r.remise > 0 ? '<tr><td>Remise accordée</td><td style="text-align:right;color:green">- ${fmt.format(r.remise)}</td></tr>' : ''}
    <tr><td><strong>Montant net</strong></td><td style="text-align:right;font-weight:800">${fmt.format(r.montantNet)}</td></tr>
    <tr><td>Acompte à verser à la signature</td><td style="text-align:right;color:#c00">${fmt.format(r.acompteVerse)}</td></tr>
  </table>
  <div class="net-box">
    <span class="lbl">SOLDE À RÉGLER LE JOUR DE L\'ÉVÉNEMENT</span>
    <span class="val">${fmt.format((r.montantNet - r.acompteVerse).clamp(0, double.infinity))} F CFA</span>
  </div>
</div>

<div class="article">
  <h4>Article 4 – Conditions d\'annulation</h4>
  <p>Toute annulation devra être notifiée par écrit au Restaurant SANKADIOKRO :<br>
  — Annulation plus de 30 jours avant l\'événement : remboursement intégral de l\'acompte.<br>
  — Annulation entre 15 et 30 jours : retenue de 50% de l\'acompte.<br>
  — Annulation moins de 15 jours avant l\'événement : l\'acompte reste acquis au Prestataire.</p>
</div>

<div class="article">
  <h4>Article 5 – Obligations du Prestataire</h4>
  <p>Le Restaurant SANKADIOKRO s\'engage à fournir les prestations convenues dans les conditions définies au présent contrat, à maintenir la confidentialité des informations transmises par le Client, et à respecter les délais et conditions fixés.</p>
</div>

<div class="article">
  <h4>Article 6 – Obligations du Client</h4>
  <p>Le Client s\'engage à verser l\'acompte prévu à la signature du présent contrat, à informer le Prestataire de tout changement dans le nombre de convives au moins 72h avant l\'événement, et à régler le solde restant avant ou le jour de l\'événement.</p>
</div>

<div class="article">
  <h4>Article 7 – Signatures</h4>
  <p>Les parties reconnaissent avoir lu et accepté les termes du présent contrat.</p>
  <div class="signatures">
    <div class="sig-block">
      <div><strong>Le Client</strong></div>
      <div style="margin-top:8px;font-size:9px;color:#aaa">Lu et approuvé — Bon pour accord</div>
      <div style="margin-top:24px;border-top:1px solid #ccc;padding-top:6px">${r.nomClient}</div>
    </div>
    <div class="sig-block">
      <div><strong>Direction SANKADIOKRO</strong></div>
      <div style="margin-top:8px;font-size:9px;color:#aaa">Cachet et signature</div>
      <div style="margin-top:24px;border-top:1px solid #ccc;padding-top:6px">Restaurant SANKADIOKRO</div>
    </div>
    <div class="sig-block">
      <div><strong>Responsable commercial</strong></div>
      <div style="margin-top:8px;font-size:9px;color:#aaa">Visa</div>
      <div style="margin-top:24px;border-top:1px solid #ccc;padding-top:6px">${r.responsableCommercial.isNotEmpty ? r.responsableCommercial : "_______________"}</div>
    </div>
  </div>
</div>

<div class="footer">
  Contrat établi en deux exemplaires originaux de valeur égale.<br>
  Restaurant SANKADIOKRO — Abidjan, Côte d\'Ivoire — ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(now)}
</div>

</body></html>''';
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  COMPTABILITÉ — 3 rapports PDF A4
  // ═══════════════════════════════════════════════════════════════════════

  // ─────────────────────────────────────────────────────────────────────
  //  BILAN COMPTABLE A4
  // ─────────────────────────────────────────────────────────────────────
  void printBilan({required AccountingReport report}) {
    final html = _buildBilanHtml(report: report);
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: bilan comptable');
    }
  }

  String _buildBilanHtml({required AccountingReport report}) {
    final now = DateTime.now();
    final dateFmt = DateFormat('dd MMMM yyyy', 'fr_FR');
    final periodLabel = _periodLabel(report.range);
    final sante = report.santeFinanciere;
    final santeColor = sante == 'Excellente'
        ? '#27ae60'
        : sante == 'Bonne'
            ? '#2ecc71'
            : sante == 'Moyenne'
                ? '#f39c12'
                : '#e74c3c';

    String fmtMoney(double v) =>
        '${NumberFormat('#,###', 'fr_FR').format(v.abs())} F CFA';
    String fmtPct(double v) => '${v.toStringAsFixed(1)} %';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Bilan Comptable — SANKADIOKRO</title>
<style>
  @page { size: A4; margin: 18mm 15mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 11px; color: #222; background: #fff; }
  .header { display: flex; align-items: center; justify-content: space-between; border-bottom: 3px solid #c0392b; padding-bottom: 10px; margin-bottom: 14px; }
  .logo-block { display: flex; align-items: center; gap: 12px; }
  .logo-circle { width: 50px; height: 50px; background: linear-gradient(135deg,#c0392b,#e74c3c); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-weight: 900; font-size: 16px; flex-shrink: 0; }
  .company h1 { font-size: 16px; font-weight: 900; color: #c0392b; letter-spacing: 1px; }
  .company p  { font-size: 9px; color: #777; }
  .doc-info { text-align: right; }
  .doc-info h2 { font-size: 14px; font-weight: 700; color: #2c3e50; }
  .doc-info p  { font-size: 10px; color: #555; margin-top: 3px; }
  .sante-badge { display: inline-block; padding: 4px 14px; border-radius: 20px; font-size: 11px; font-weight: 700; color: #fff; background: ${santeColor}; margin-top: 6px; }

  h3 { font-size: 12px; font-weight: 700; color: #c0392b; text-transform: uppercase; letter-spacing: .5px; border-left: 4px solid #c0392b; padding-left: 8px; margin: 14px 0 8px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 12px; }
  th { background: #2c3e50; color: #fff; padding: 6px 8px; font-size: 10px; text-align: left; }
  td { padding: 5px 8px; border-bottom: 1px solid #eee; font-size: 10px; }
  tr:nth-child(even) td { background: #f9f9f9; }
  .total-row td { background: #2c3e50; color: #fff; font-weight: 700; padding: 6px 8px; }
  .section-total-row td { background: #ecf0f1; font-weight: 700; color: #2c3e50; }
  .amount { text-align: right; font-weight: 600; }
  .positive { color: #27ae60; }
  .negative { color: #e74c3c; }

  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 12px; }
  .bilan-card { border: 1px solid #dee2e6; border-radius: 6px; overflow: hidden; }
  .bilan-card-header { padding: 7px 10px; font-size: 11px; font-weight: 700; color: #fff; }
  .actif-header  { background: #27ae60; }
  .passif-header { background: #e74c3c; }
  .bilan-row { display: flex; justify-content: space-between; padding: 5px 10px; border-bottom: 1px solid #f0f0f0; font-size: 10px; }
  .bilan-total { display: flex; justify-content: space-between; padding: 6px 10px; font-weight: 700; font-size: 11px; }
  .actif-total  { background: #eafaf1; color: #27ae60; }
  .passif-total { background: #fdf0ed; color: #e74c3c; }

  .result-box { border: 2px solid ${santeColor}; border-radius: 8px; padding: 10px 14px; text-align: center; margin: 8px 0; }
  .result-box .label { font-size: 10px; color: #777; }
  .result-box .value { font-size: 20px; font-weight: 900; color: ${santeColor}; margin: 4px 0; }

  .signature-section { margin-top: 20px; display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
  .sig-block { border-top: 1px solid #bbb; padding-top: 8px; text-align: center; }
  .sig-block p { font-size: 9px; color: #555; }

  .footer { margin-top: 16px; padding-top: 8px; border-top: 1px solid #ddd; text-align: center; font-size: 9px; color: #aaa; }
</style>
</head>
<body>

<!-- EN-TÊTE -->
<div class="header">
  <div class="logo-block">
    <div class="logo-circle">S</div>
    <div class="company">
      <h1>RESTAURANT SANKADIOKRO</h1>
      <p>Abidjan, Côte d\'Ivoire</p>
      <p>Restauration · Événementiel · Traiteur</p>
    </div>
  </div>
  <div class="doc-info">
    <h2>BILAN COMPTABLE</h2>
    <p>Période : $periodLabel</p>
    <p>Édité le ${dateFmt.format(now)}</p>
    <span class="sante-badge">$sante</span>
  </div>
</div>

<!-- RÉSUMÉ EXÉCUTIF -->
<h3>Résumé financier</h3>
<table>
  <tr><th style="width:55%">Indicateur</th><th style="width:22%">Valeur</th><th>Variation</th></tr>
  <tr><td>Chiffre d\'affaires total</td><td class="amount">${fmtMoney(report.totalProduits)}</td><td></td></tr>
  <tr><td>Recettes encaissées</td><td class="amount">${fmtMoney(report.recettesEncaissees)}</td><td></td></tr>
  <tr><td>Charges totales</td><td class="amount negative">${fmtMoney(report.totalCharges)}</td><td></td></tr>
  <tr><td>Marge brute</td><td class="amount">${fmtPct(report.margeBrute)}</td><td></td></tr>
  <tr><td>Marge nette</td><td class="amount">${fmtPct(report.margeNette)}</td><td></td></tr>
  <tr class="total-row"><td>Résultat net</td><td class="amount">${fmtMoney(report.resultatNet)}</td><td>${report.isRentable ? "✅ Bénéfice" : "❌ Perte"}</td></tr>
</table>

<!-- BILAN ACTIF / PASSIF -->
<h3>Bilan simplifié</h3>
<div class="grid-2">
  <div class="bilan-card">
    <div class="bilan-card-header actif-header">ACTIF</div>
    <div class="bilan-row"><span>Caisse disponible</span><span><strong>${fmtMoney(report.caisse)}</strong></span></div>
    <div class="bilan-row"><span>Créances clients</span><span><strong>${fmtMoney(report.creancesClients)}</strong></span></div>
    <div class="bilan-row"><span>Stock valorisé</span><span><strong>${fmtMoney(report.stockValue)}</strong></span></div>
    <div class="bilan-total actif-total"><span>TOTAL ACTIF</span><span>${fmtMoney(report.totalActif)}</span></div>
  </div>
  <div class="bilan-card">
    <div class="bilan-card-header passif-header">PASSIF</div>
    <div class="bilan-row"><span>Dettes fournisseurs</span><span><strong>${fmtMoney(report.dettesFournisseurs)}</strong></span></div>
    <div class="bilan-row"><span>Salaires dus</span><span><strong>${fmtMoney(report.salairesDus)}</strong></span></div>
    <div class="bilan-total passif-total"><span>TOTAL PASSIF</span><span>${fmtMoney(report.totalPassif)}</span></div>
  </div>
</div>

<div class="result-box">
  <div class="label">Équilibre financier (Actif − Passif)</div>
  <div class="value">${fmtMoney(report.equilibre)}</div>
  <div class="label">${report.equilibre >= 0 ? "✅ Actif supérieur au passif — situation saine" : "⚠️ Passif supérieur à l\'actif — vigilance requise"}</div>
</div>

<!-- ALERTES -->
${report.alerts.isNotEmpty ? '''
<h3>Alertes comptables</h3>
<table>
  <tr><th>Niveau</th><th>Message</th></tr>
  ${report.alerts.map((a) => '<tr><td>${a.icon} ${a.type == AlertType.danger ? "Critique" : a.type == AlertType.warning ? "Attention" : "Info"}</td><td>${a.message}</td></tr>').join()}
</table>''' : ''}

<!-- SIGNATURES -->
<div class="signature-section">
  <div class="sig-block">
    <p>Établi par le service comptable</p>
    <br><br><br>
    <p>Signature &amp; cachet</p>
  </div>
  <div class="sig-block">
    <p>Approuvé par la Direction</p>
    <br><br><br>
    <p>Signature Direction générale</p>
  </div>
</div>

<div class="footer">
  Bilan comptable confidentiel — Restaurant SANKADIOKRO — Généré automatiquement le ${dateFmt.format(now)}
</div>

</body></html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  COMPTE DE RÉSULTAT A4
  // ─────────────────────────────────────────────────────────────────────
  void printCompteResultat({required AccountingReport report}) {
    final html = _buildCompteResultatHtml(report: report);
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: compte de résultat');
    }
  }

  String _buildCompteResultatHtml({required AccountingReport report}) {
    final now = DateTime.now();
    final dateFmt = DateFormat('dd MMMM yyyy', 'fr_FR');
    final periodLabel = _periodLabel(report.range);
    final isProfit = report.isRentable;
    final resultColor = isProfit ? '#27ae60' : '#e74c3c';

    String fmtMoney(double v) =>
        '${NumberFormat('#,###', 'fr_FR').format(v.abs())} F CFA';
    String fmtPct(double base, double part) =>
        base > 0 ? '${(part / base * 100).toStringAsFixed(1)} %' : '—';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Compte de Résultat — SANKADIOKRO</title>
<style>
  @page { size: A4; margin: 18mm 15mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 11px; color: #222; background: #fff; }
  .header { display: flex; align-items: center; justify-content: space-between; border-bottom: 3px solid #2980b9; padding-bottom: 10px; margin-bottom: 14px; }
  .logo-circle { width: 50px; height: 50px; background: linear-gradient(135deg,#c0392b,#e74c3c); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-weight: 900; font-size: 16px; flex-shrink: 0; }
  .logo-block { display: flex; align-items: center; gap: 12px; }
  .company h1 { font-size: 16px; font-weight: 900; color: #c0392b; letter-spacing: 1px; }
  .company p  { font-size: 9px; color: #777; }
  .doc-info { text-align: right; }
  .doc-info h2 { font-size: 14px; font-weight: 700; color: #2980b9; }
  .doc-info p  { font-size: 10px; color: #555; margin-top: 3px; }

  h3 { font-size: 12px; font-weight: 700; color: #2980b9; text-transform: uppercase; letter-spacing: .5px; border-left: 4px solid #2980b9; padding-left: 8px; margin: 14px 0 8px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 12px; }
  th { padding: 6px 8px; font-size: 10px; text-align: left; color: #fff; }
  .produits-header th { background: #27ae60; }
  .charges-header  th { background: #e74c3c; }
  .result-header   th { background: ${resultColor}; }
  td { padding: 5px 8px; border-bottom: 1px solid #eee; font-size: 10px; }
  tr:nth-child(even) td { background: #f9f9f9; }
  .sub-total td { background: #ecf0f1; font-weight: 700; font-size: 10px; }
  .amount { text-align: right; }
  .pct    { text-align: right; color: #888; font-size: 9px; }

  .result-final { margin: 12px 0; border: 3px solid ${resultColor}; border-radius: 8px; padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; }
  .result-final .label { font-size: 13px; font-weight: 700; color: #333; }
  .result-final .value { font-size: 22px; font-weight: 900; color: ${resultColor}; }
  .result-final .verdict { font-size: 11px; color: ${resultColor}; font-weight: 600; }

  .note { font-size: 9px; color: #888; margin: 4px 0 10px; }

  .signature-section { margin-top: 20px; display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
  .sig-block { border-top: 1px solid #bbb; padding-top: 8px; text-align: center; }
  .sig-block p { font-size: 9px; color: #555; }
  .footer { margin-top: 16px; padding-top: 8px; border-top: 1px solid #ddd; text-align: center; font-size: 9px; color: #aaa; }
</style>
</head>
<body>

<!-- EN-TÊTE -->
<div class="header">
  <div class="logo-block">
    <div class="logo-circle">S</div>
    <div class="company">
      <h1>RESTAURANT SANKADIOKRO</h1>
      <p>Abidjan, Côte d\'Ivoire</p>
      <p>Restauration · Événementiel · Traiteur</p>
    </div>
  </div>
  <div class="doc-info">
    <h2>COMPTE DE RÉSULTAT</h2>
    <p>Période : $periodLabel</p>
    <p>Édité le ${dateFmt.format(now)}</p>
  </div>
</div>

<!-- PRODUITS -->
<h3>Produits (Revenus)</h3>
<table>
  <thead class="produits-header"><tr><th style="width:55%">Libellé</th><th style="width:25%">Montant</th><th>% du CA</th></tr></thead>
  <tbody>
    <tr><td>Ventes restaurant (factures)</td><td class="amount">${fmtMoney(report.caRestaurant)}</td><td class="pct">${fmtPct(report.totalProduits, report.caRestaurant)}</td></tr>
    <tr><td>Revenus réservations / événements</td><td class="amount">${fmtMoney(report.caReservations)}</td><td class="pct">${fmtPct(report.totalProduits, report.caReservations)}</td></tr>
    <tr class="sub-total"><td>TOTAL PRODUITS</td><td class="amount">${fmtMoney(report.totalProduits)}</td><td class="pct">100 %</td></tr>
  </tbody>
</table>
<p class="note">• Recettes effectivement encaissées : ${fmtMoney(report.recettesEncaissees)} (${fmtPct(report.totalProduits, report.recettesEncaissees)})</p>

<!-- CHARGES -->
<h3>Charges (Dépenses)</h3>
<table>
  <thead class="charges-header"><tr><th style="width:55%">Libellé</th><th style="width:25%">Montant</th><th>% du CA</th></tr></thead>
  <tbody>
    <tr><td>Achats marchandises fournisseurs</td><td class="amount">${fmtMoney(report.achatsFournisseurs)}</td><td class="pct">${fmtPct(report.totalProduits, report.achatsFournisseurs)}</td></tr>
    <tr><td>Salaires bruts du personnel</td><td class="amount">${fmtMoney(report.salairesBruts)}</td><td class="pct">${fmtPct(report.totalProduits, report.salairesBruts)}</td></tr>
    <tr><td>Charges du jour (dépenses diverses)</td><td class="amount">${fmtMoney(report.chargesJour)}</td><td class="pct">${fmtPct(report.totalProduits, report.chargesJour)}</td></tr>
    <tr><td>Pertes et déchets stock</td><td class="amount">${fmtMoney(report.pertesStock)}</td><td class="pct">${fmtPct(report.totalProduits, report.pertesStock)}</td></tr>
    <tr class="sub-total"><td>TOTAL CHARGES</td><td class="amount">${fmtMoney(report.totalCharges)}</td><td class="pct">${fmtPct(report.totalProduits, report.totalCharges)}</td></tr>
  </tbody>
</table>

<!-- RÉSULTAT NET -->
<div class="result-final">
  <div>
    <div class="label">RÉSULTAT NET = Produits − Charges</div>
    <div class="verdict">${isProfit ? "✅ Le restaurant est rentable sur cette période" : "❌ Le restaurant est en perte sur cette période"}</div>
  </div>
  <div class="value">${isProfit ? "+" : "−"}${fmtMoney(report.resultatNet)}</div>
</div>

<!-- DÉTAIL FOURNISSEURS si disponible -->
${report.supplierOrdersDetail.isNotEmpty ? '''
<h3>Détail commandes fournisseurs (${report.nbCommandesFournisseurs})</h3>
<table>
  <tr><th>Fournisseur</th><th>Montant total</th><th>Payé</th><th>Reste dû</th></tr>
  ${report.supplierOrdersDetail.take(8).map((o) => '<tr><td>${o.supplierName}</td><td class="amount">${fmtMoney(o.totalAmount)}</td><td class="amount">${fmtMoney(o.paidAmount)}</td><td class="amount">${fmtMoney(o.remainingAmount)}</td></tr>').join()}
  ${report.supplierOrdersDetail.length > 8 ? '<tr><td colspan="4" style="text-align:center;color:#888;font-size:9px">… et ${report.supplierOrdersDetail.length - 8} autres commandes</td></tr>' : ''}
</table>''' : ''}

<!-- SIGNATURES -->
<div class="signature-section">
  <div class="sig-block">
    <p>Établi par le service comptable</p>
    <br><br><br>
    <p>Signature &amp; cachet</p>
  </div>
  <div class="sig-block">
    <p>Approuvé par la Direction</p>
    <br><br><br>
    <p>Signature Direction générale</p>
  </div>
</div>

<div class="footer">
  Compte de résultat confidentiel — Restaurant SANKADIOKRO — Généré automatiquement le ${dateFmt.format(now)}
</div>

</body></html>''';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  RAPPORT DE RENTABILITÉ A4
  // ─────────────────────────────────────────────────────────────────────
  void printRentabilite({required AccountingReport report}) {
    final html = _buildRentabiliteHtml(report: report);
    if (kIsWeb) {
      print_web.webOpenPrintWindow(html);
    } else {
      if (kDebugMode) debugPrint('[PrintService] Mobile: rapport rentabilité');
    }
  }

  String _buildRentabiliteHtml({required AccountingReport report}) {
    final now = DateTime.now();
    final dateFmt = DateFormat('dd MMMM yyyy', 'fr_FR');
    final periodLabel = _periodLabel(report.range);
    final isProfit = report.isRentable;
    final sante = report.santeFinanciere;
    final mainColor = sante == 'Excellente' || sante == 'Bonne' ? '#8e44ad' : '#e74c3c';

    String fmtMoney(double v) =>
        '${NumberFormat('#,###', 'fr_FR').format(v.abs())} F CFA';
    String pctBar(double pct, {String color = '#8e44ad'}) {
      final p = pct.clamp(0, 100).toStringAsFixed(0);
      return '''<div style="background:#eee;border-radius:4px;height:10px;width:100%;margin-top:3px">
        <div style="background:$color;height:10px;border-radius:4px;width:$p%"></div>
      </div><div style="font-size:9px;color:$color;margin-top:2px">$p %</div>''';
    }

    final chargesItems = [
      {'label': 'Achats fournisseurs', 'val': report.achatsFournisseurs, 'color': '#e74c3c'},
      {'label': 'Salaires bruts',      'val': report.salairesBruts,      'color': '#e67e22'},
      {'label': 'Charges du jour',     'val': report.chargesJour,        'color': '#f39c12'},
      {'label': 'Pertes stock',        'val': report.pertesStock,        'color': '#95a5a6'},
    ];

    String chargesTableRows() {
      return chargesItems.map((item) {
        final pct = report.totalCharges > 0
            ? (item['val']! as double) / report.totalCharges * 100
            : 0.0;
        final p = pct.toStringAsFixed(1);
        return '''<tr>
          <td>${item['label']}</td>
          <td class="amount">${fmtMoney(item['val']! as double)}</td>
          <td style="width:35%">
            <div style="background:#eee;border-radius:3px;height:8px">
              <div style="background:${item['color']};height:8px;border-radius:3px;width:${pct.clamp(0,100).toStringAsFixed(0)}%"></div>
            </div>
            <span style="font-size:9px;color:${item['color']}">$p %</span>
          </td>
        </tr>''';
      }).join();
    }

    // Recommandations IA
    final recs = <String>[];
    if (report.achatsFournisseurs > report.totalProduits * 0.45) {
      recs.add('🔍 Renégocier les tarifs fournisseurs — les achats représentent ${(report.achatsFournisseurs/report.totalProduits*100).toStringAsFixed(0)}% du CA (optimal : < 45%).');
    }
    if (report.salairesBruts > report.totalProduits * 0.35) {
      recs.add('👥 Optimiser la masse salariale — les salaires représentent ${(report.salairesBruts/report.totalProduits*100).toStringAsFixed(0)}% du CA (optimal : < 35%).');
    }
    if (report.creancesClients > report.recettesEncaissees * 0.2) {
      recs.add('💰 Accélérer le recouvrement client — créances élevées : ${fmtMoney(report.creancesClients)}.');
    }
    if (report.stockValue < 30000) {
      recs.add('📦 Reconstituer le stock — valeur actuelle très faible : ${fmtMoney(report.stockValue)}.');
    }
    if (report.caReservations > 0 && report.caReservations < report.totalProduits * 0.1) {
      recs.add('🎉 Développer les réservations événementielles — potentiel sous-exploité (${(report.caReservations/report.totalProduits*100).toStringAsFixed(0)}% du CA).');
    }
    if (report.salairesDus > 0) {
      recs.add('⚠️ Régulariser les salaires impayés : ${fmtMoney(report.salairesDus)} restants.');
    }
    if (recs.isEmpty) {
      recs.add('✅ Bonne gestion globale — maintenir les pratiques actuelles et surveiller les tendances.');
      recs.add('📈 Continuer à développer les ventes réservations pour diversifier les revenus.');
    }

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Rapport de Rentabilité — SANKADIOKRO</title>
<style>
  @page { size: A4; margin: 18mm 15mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 11px; color: #222; background: #fff; }
  .header { display: flex; align-items: center; justify-content: space-between; border-bottom: 3px solid $mainColor; padding-bottom: 10px; margin-bottom: 14px; }
  .logo-circle { width: 50px; height: 50px; background: linear-gradient(135deg,#c0392b,#e74c3c); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-weight: 900; font-size: 16px; flex-shrink: 0; }
  .logo-block { display: flex; align-items: center; gap: 12px; }
  .company h1 { font-size: 16px; font-weight: 900; color: #c0392b; letter-spacing: 1px; }
  .company p  { font-size: 9px; color: #777; }
  .doc-info { text-align: right; }
  .doc-info h2 { font-size: 14px; font-weight: 700; color: $mainColor; }
  .doc-info p  { font-size: 10px; color: #555; margin-top: 3px; }

  h3 { font-size: 12px; font-weight: 700; color: $mainColor; text-transform: uppercase; letter-spacing: .5px; border-left: 4px solid $mainColor; padding-left: 8px; margin: 14px 0 8px; }

  .kpi-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 12px; }
  .kpi-card { border: 1px solid #ddd; border-radius: 6px; padding: 8px 10px; text-align: center; }
  .kpi-card .kpi-label { font-size: 9px; color: #888; text-transform: uppercase; letter-spacing: .3px; }
  .kpi-card .kpi-value { font-size: 14px; font-weight: 900; color: $mainColor; margin: 4px 0 2px; }
  .kpi-card .kpi-sub   { font-size: 9px; color: #aaa; }

  .verdict-box { background: linear-gradient(135deg, $mainColor, ${isProfit ? '#9b59b6' : '#c0392b'}); border-radius: 8px; padding: 12px 16px; color: #fff; margin: 8px 0; }
  .verdict-box h4 { font-size: 13px; font-weight: 700; margin-bottom: 6px; }
  .verdict-box p  { font-size: 10px; line-height: 1.5; }

  table { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
  th { background: $mainColor; color: #fff; padding: 6px 8px; font-size: 10px; text-align: left; }
  td { padding: 5px 8px; border-bottom: 1px solid #eee; font-size: 10px; }
  tr:nth-child(even) td { background: #f9f9f9; }
  .amount { text-align: right; font-weight: 600; }

  .recs-list { list-style: none; }
  .recs-list li { padding: 6px 8px; border-left: 3px solid $mainColor; margin-bottom: 5px; background: #fdf6ff; font-size: 10px; line-height: 1.4; }

  .conclusion-box { border: 2px solid ${isProfit ? '#27ae60' : '#e74c3c'}; border-radius: 8px; padding: 10px 14px; margin: 10px 0; }
  .conclusion-box h4 { font-size: 11px; font-weight: 700; color: ${isProfit ? '#27ae60' : '#e74c3c'}; margin-bottom: 5px; }
  .conclusion-box p  { font-size: 10px; line-height: 1.5; }

  .signature-section { margin-top: 20px; display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
  .sig-block { border-top: 1px solid #bbb; padding-top: 8px; text-align: center; }
  .sig-block p { font-size: 9px; color: #555; }
  .footer { margin-top: 16px; padding-top: 8px; border-top: 1px solid #ddd; text-align: center; font-size: 9px; color: #aaa; }
</style>
</head>
<body>

<!-- EN-TÊTE -->
<div class="header">
  <div class="logo-block">
    <div class="logo-circle">S</div>
    <div class="company">
      <h1>RESTAURANT SANKADIOKRO</h1>
      <p>Abidjan, Côte d\'Ivoire</p>
      <p>Restauration · Événementiel · Traiteur</p>
    </div>
  </div>
  <div class="doc-info">
    <h2>RAPPORT DE RENTABILITÉ</h2>
    <p>Période : $periodLabel</p>
    <p>Édité le ${dateFmt.format(now)}</p>
  </div>
</div>

<!-- VERDICT -->
<div class="verdict-box">
  <h4>${isProfit ? "✅ Le restaurant est RENTABLE sur cette période" : "❌ Le restaurant est en PERTE sur cette période"}</h4>
  <p>Résultat net : <strong>${isProfit ? "+" : "−"}${fmtMoney(report.resultatNet)}</strong> — 
  Marge brute : <strong>${report.margeBrute.toStringAsFixed(1)} %</strong> — 
  Marge nette : <strong>${report.margeNette.toStringAsFixed(1)} %</strong> — 
  Santé financière : <strong>$sante</strong></p>
</div>

<!-- KPI -->
<h3>Indicateurs clés de performance</h3>
<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-label">Chiffre d\'affaires</div>
    <div class="kpi-value">${fmtMoney(report.totalProduits)}</div>
    <div class="kpi-sub">${report.nbFactures} factures</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Charges totales</div>
    <div class="kpi-value">${fmtMoney(report.totalCharges)}</div>
    <div class="kpi-sub">${report.margeNette >= 0 ? "Marge nette " + report.margeNette.toStringAsFixed(1) + "%" : "Déficit"}</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Résultat net</div>
    <div class="kpi-value" style="color:${isProfit ? '#27ae60' : '#e74c3c'}">${isProfit ? "+" : "−"}${fmtMoney(report.resultatNet)}</div>
    <div class="kpi-sub">${isProfit ? "Bénéfice" : "Perte"}</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Marge brute</div>
    <div class="kpi-value">${report.margeBrute.toStringAsFixed(1)} %</div>
    <div class="kpi-sub">Avant salaires & charges</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Caisse disponible</div>
    <div class="kpi-value">${fmtMoney(report.caisse)}</div>
    <div class="kpi-sub">Liquidités</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Stock valorisé</div>
    <div class="kpi-value">${fmtMoney(report.stockValue)}</div>
    <div class="kpi-sub">Actif circulant</div>
  </div>
</div>

<!-- RÉPARTITION DES CHARGES -->
<h3>Répartition des charges</h3>
<table>
  <tr><th style="width:40%">Poste de charge</th><th style="width:25%">Montant</th><th>Part relative</th></tr>
  $chargesTableRows
</table>

<!-- COMPARATIF PRODUITS -->
<h3>Comparatif produits vs charges</h3>
<table>
  <tr><th>Flux</th><th>Montant</th><th>% CA</th></tr>
  <tr><td>✅ Ventes restaurant</td><td class="amount">${fmtMoney(report.caRestaurant)}</td><td>${report.totalProduits > 0 ? (report.caRestaurant/report.totalProduits*100).toStringAsFixed(1) : 0} %</td></tr>
  <tr><td>✅ Réservations / événements</td><td class="amount">${fmtMoney(report.caReservations)}</td><td>${report.totalProduits > 0 ? (report.caReservations/report.totalProduits*100).toStringAsFixed(1) : 0} %</td></tr>
  <tr><td>🔴 Achats fournisseurs</td><td class="amount">${fmtMoney(report.achatsFournisseurs)}</td><td>${report.totalProduits > 0 ? (report.achatsFournisseurs/report.totalProduits*100).toStringAsFixed(1) : 0} %</td></tr>
  <tr><td>🔴 Salaires</td><td class="amount">${fmtMoney(report.salairesBruts)}</td><td>${report.totalProduits > 0 ? (report.salairesBruts/report.totalProduits*100).toStringAsFixed(1) : 0} %</td></tr>
  <tr><td>🔴 Charges diverses</td><td class="amount">${fmtMoney(report.chargesJour)}</td><td>${report.totalProduits > 0 ? (report.chargesJour/report.totalProduits*100).toStringAsFixed(1) : 0} %</td></tr>
</table>

<!-- RECOMMANDATIONS IA -->
<h3>Recommandations de l\'assistant comptable</h3>
<ul class="recs-list">
  ${recs.map((r) => '<li>$r</li>').join()}
</ul>

<!-- CONCLUSION -->
<div class="conclusion-box">
  <h4>${isProfit ? "CONCLUSION — Activité rentable" : "CONCLUSION — Activité déficitaire"}</h4>
  <p>
    ${isProfit 
      ? "Sur la période $periodLabel, le Restaurant SANKADIOKRO dégage un résultat net positif de ${fmtMoney(report.resultatNet)} pour un chiffre d\'affaires de ${fmtMoney(report.totalProduits)}. La marge nette de ${report.margeNette.toStringAsFixed(1)}% indique une santé financière $sante. Il est recommandé de maintenir cette dynamique en surveillant l\'évolution des charges fournisseurs."
      : "Sur la période $periodLabel, le Restaurant SANKADIOKRO enregistre une perte nette de ${fmtMoney(report.resultatNet)} pour un chiffre d\'affaires de ${fmtMoney(report.totalProduits)}. Une analyse approfondie des postes de charges est nécessaire pour rétablir la rentabilité. Les recommandations ci-dessus doivent être appliquées en priorité."
    }
  </p>
</div>

<!-- SIGNATURES -->
<div class="signature-section">
  <div class="sig-block">
    <p>Établi par le service comptable</p>
    <br><br><br>
    <p>Signature &amp; cachet</p>
  </div>
  <div class="sig-block">
    <p>Approuvé par la Direction</p>
    <br><br><br>
    <p>Signature Direction générale</p>
  </div>
</div>

<div class="footer">
  Rapport de rentabilité confidentiel — Restaurant SANKADIOKRO — Généré automatiquement le ${dateFmt.format(now)}
</div>

</body></html>''';
  }

  // ── Utilitaire : libellé de période ────────────────────────────────────
  String _periodLabel(DateRange range) {
    final fmt = DateFormat('dd/MM/yyyy', 'fr_FR');
    return '${fmt.format(range.start)} → ${fmt.format(range.end)}';
  }
}
