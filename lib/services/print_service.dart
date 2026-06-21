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
}
