import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/print_service.dart';

// Import conditionnel : dart:js uniquement sur web
// ignore: uri_does_not_exist
import '../../services/print_web_stub.dart'
    if (dart.library.js) '../../services/print_web_impl.dart' as print_web;

// ══════════════════════════════════════════════════════════════════════════════
//  PAGE PUBLIQUE — Vérification & visualisation d'une facture
//  Route : /facture/:invoiceId
//  Accessible sans authentification — lit Firestore en lecture seule.
//  Fonctionne avec cashout_invoices (provisoires) ET settlement_invoices (définitives).
// ══════════════════════════════════════════════════════════════════════════════

class InvoiceVerifyScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceVerifyScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceVerifyScreen> createState() => _InvoiceVerifyScreenState();
}

class _InvoiceVerifyScreenState extends State<InvoiceVerifyScreen> {
  final _fmt = NumberFormat('#,###', 'fr_FR');

  bool   _loading  = true;
  String? _error;

  // Données de la facture (normalisées depuis cashout ou settlement)
  String? _kind;          // 'cashout' | 'settlement'
  String? _invoiceNumber;
  String? _status;        // 'Provisoire' | 'Définitive / Réglée'
  double? _amount;
  String? _paymentMethod;
  String? _tableNumber;
  String? _cashierName;
  String? _serverName;
  DateTime? _invoiceDate;
  List<Map<String, dynamic>> _items = [];

  // Numéro de référence croisée
  String? _refCashout;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  // ── Lecture Firestore : cherche dans settlement_invoices puis cashout_invoices ──
  Future<void> _loadInvoice() async {
    setState(() { _loading = true; _error = null; });

    try {
      final db = FirebaseFirestore.instance;

      // 1. Chercher d'abord dans settlement_invoices (définitives)
      final settDoc = await db
          .collection('settlement_invoices')
          .doc(widget.invoiceId)
          .get();

      if (settDoc.exists) {
        _parseSettlement(settDoc.data()!);
        setState(() => _loading = false);
        return;
      }

      // 2. Chercher dans cashout_invoices (provisoires)
      final cashDoc = await db
          .collection('cashout_invoices')
          .doc(widget.invoiceId)
          .get();

      if (cashDoc.exists) {
        _parseCashout(cashDoc.data()!);
        setState(() => _loading = false);
        return;
      }

      // 3. Introuvable dans les deux collections
      setState(() {
        _loading = false;
        _error = 'Facture introuvable.\nVérifiez le numéro : ${widget.invoiceId}';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Impossible de charger la facture.\nErreur : $e';
      });
    }
  }

  void _parseSettlement(Map<String, dynamic> d) {
    _kind          = 'settlement';
    _invoiceNumber = (d['settlementInvoiceNumber'] as String?) ?? widget.invoiceId;
    _status        = 'Définitive · Réglée ✓';
    _amount        = (d['amountDue'] as num?)?.toDouble();
    _paymentMethod = d['paymentMethod'] as String?;
    _tableNumber   = d['tableNumber'] as String?;
    _cashierName   = d['cashierName'] as String?;
    _serverName    = d['serverName'] as String?;
    _refCashout    = d['cashoutInvoiceNumber'] as String?;
    _items         = List<Map<String, dynamic>>.from(d['items'] as List? ?? []);

    final ts = d['settledAt'];
    if (ts is int) {
      _invoiceDate = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is Timestamp) {
      _invoiceDate = ts.toDate();
    }
  }

  void _parseCashout(Map<String, dynamic> d) {
    _kind          = 'cashout';
    _invoiceNumber = (d['id'] as String?) ?? widget.invoiceId;
    _status        = 'Provisoire · En attente de règlement';
    _amount        = (d['amountDue'] as num?)?.toDouble();
    _paymentMethod = null;
    _tableNumber   = d['tableNumber'] as String?;
    _cashierName   = d['cashierName'] as String?;
    _serverName    = d['serverName'] as String?;
    _items         = List<Map<String, dynamic>>.from(d['items'] as List? ?? []);

    final ts = d['cashoutAtMs'];
    if (ts is int) {
      _invoiceDate = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      final ts2 = d['createdAt'];
      if (ts2 is Timestamp) _invoiceDate = ts2.toDate();
    }
  }

  // ── Impression PDF (même technique que les reçus) ─────────────────────────
  void _printPdf() {
    if (_invoiceNumber == null || _amount == null) return;
    final dateStr = _invoiceDate != null ? DateFormat('dd/MM/yyyy').format(_invoiceDate!) : '—';
    final html = _buildPrintableHtml(dateStr: dateStr);
    print_web.webOpenPrintWindow(html);
  }

  // ── HTML imprimable (80mm thermique) ─────────────────────────────────────
  String _buildPrintableHtml({required String dateStr}) {
    final isSettled  = _kind == 'settlement';
    final titleLabel = isSettled ? 'FACTURE RÉGLÉE' : "REÇU D'ENCAISSEMENT";
    final titleClass = isSettled ? 'title-reglee'  : 'title-provisoire';
    final statusBadge = isSettled
        ? '<div class="badge-center"><span class="badge-paid">PAYÉE</span></div>'
        : '<div class="badge-center"><span class="badge-pending">EN ATTENTE</span></div>';

    final itemsRows = _items.map((item) {
      final name  = _escHtml((item['productName'] as String?) ?? '—');
      final qty   = item['quantity'] ?? 1;
      final pu    = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final total = (item['totalPrice'] as num?)?.toDouble() ?? (pu * (qty as int));
      return '<tr>'
        '<td class="item-name">$name</td>'
        '<td class="item-qty">$qty</td>'
        '<td class="item-price">${_fmt.format(pu)} F</td>'
        '<td class="item-total">${_fmt.format(total)} F</td>'
        '</tr>';
    }).join('');

    final cashierRow = _cashierName != null
        ? '<tr><td class="info-label">Caissier :</td><td class="info-value">${_escHtml(_cashierName!)}</td></tr>' : '';
    final serverRow = _serverName != null
        ? '<tr><td class="info-label">Serveur :</td><td class="info-value">${_escHtml(_serverName!)}</td></tr>' : '';
    final payRow = _paymentMethod != null
        ? '<div class="payment-row"><span class="payment-label">Mode :</span>'
          '<span class="payment-value">${_escHtml(_paymentMethod!)}</span></div>' : '';
    final refRow = _refCashout != null
        ? '<tr><td class="info-label">R&eacute;f. encaiss. :</td>'
          '<td class="info-value">${_escHtml(_refCashout!)}</td></tr>' : '';

    final verifyUrl = 'https://www.restaurantsankadiokro.com/facture/${widget.invoiceId}';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>$titleLabel #${_invoiceNumber ?? widget.invoiceId}</title>
<style>${PrintService.sharedThermalCss()}</style>
</head>
<body>
<div class="receipt">
<div class="header">
  <div class="restaurant-name">Restaurant Sankadiokro</div>
  <div class="restaurant-tagline">Cuisine Africaine &amp; Ivoirienne</div>
</div>
<hr class="sep-solid" />
<div class="receipt-title-block">
  <span class="receipt-title $titleClass">$titleLabel</span>
</div>
<hr class="sep-dashed" />
<div class="section-title">Informations document</div>
<table class="info-table">
<tr><td class="info-label">N° :</td><td class="info-value">${_invoiceNumber ?? widget.invoiceId}</td></tr>
<tr><td class="info-label">Date :</td><td class="info-value">$dateStr</td></tr>
$cashierRow
$serverRow
<tr><td class="info-label">Table :</td><td class="info-value">${_escHtml(_tableNumber ?? '—')}</td></tr>
$refRow
</table>
<hr class="sep-dashed" />
<div class="section-title">D&eacute;tails commande</div>
<table class="items-table">
<thead><tr>
  <th class="item-name">Article</th>
  <th class="item-qty">Qté</th>
  <th class="item-price">P.U</th>
  <th class="item-total">Total</th>
</tr></thead>
<tbody>$itemsRows</tbody>
</table>
<hr class="sep-dashed" />
<table class="totals-table">
<tr class="total-row"><td colspan="3">Total TTC :</td><td>${_fmt.format(_amount ?? 0)} F CFA</td></tr>
</table>
${isSettled ? '<div class="section-title">Paiement</div><div class="payment-block">$payRow</div>' : ''}
$statusBadge
<div class="qr-block" style="margin-top:8px;">
  <div style="font-size:8px;color:#555;text-align:center;">
    V&eacute;rification en ligne :<br/>
    <span style="font-size:7px;word-break:break-all;">$verifyUrl</span>
  </div>
</div>
<hr class="sep-solid" />
<div class="footer-block">
  <div class="footer-name">Restaurant Sankadiokro</div>
  <div class="footer-address">&#128205; Yopougon Millionnaire</div>
  <div class="footer-address">&#9993; restaurantsankadiokro@gmail.com</div>
  <div class="footer-address">&#128222; 07 07 04 29 47</div>
  <div class="footer-stars">&#9733;&#9733;&#9733;&#9733;&#9733;</div>
  <div class="footer-merci-final">~ MERCI DE VOTRE CONFIANCE ~</div>
</div>
<div class="print-btn">
  <button onclick="window.print()"
    style="padding:8px 24px;background:#111;color:#fff;border:none;
           border-radius:6px;cursor:pointer;font-size:12px;font-weight:bold;">
    &#128424; Imprimer / Enregistrer PDF
  </button>
</div>
</div>
</body>
</html>''';
  }

  String _escHtml(String t) => t
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  // ── UI principale ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0A00),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vérification facture',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(widget.invoiceId,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          if (!_loading && _error == null)
            TextButton.icon(
              onPressed: _printPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFB5451B)),
              label: const Text('PDF', style: TextStyle(color: Color(0xFFB5451B), fontWeight: FontWeight.w700, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadInvoice)
              : _InvoiceDetail(
                  invoiceNumber : _invoiceNumber ?? widget.invoiceId,
                  status        : _status ?? '—',
                  kind          : _kind ?? 'cashout',
                  amount        : _amount ?? 0,
                  invoiceDate   : _invoiceDate,
                  paymentMethod : _paymentMethod,
                  tableNumber   : _tableNumber,
                  cashierName   : _cashierName,
                  serverName    : _serverName,
                  refCashout    : _refCashout,
                  items         : _items,
                  onPrint       : _printPdf,
                ),
    );
  }
}

// ── Vue chargement ────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFB5451B)),
          SizedBox(height: 18),
          Text('Chargement de la facture…',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Vue erreur ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2D1200),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFB5451B).withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFFB5451B), size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Facture introuvable',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5451B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vue détail facture ────────────────────────────────────────────────────────
class _InvoiceDetail extends StatelessWidget {
  final String   invoiceNumber;
  final String   status;
  final String   kind;           // 'cashout' | 'settlement'
  final double   amount;
  final DateTime? invoiceDate;
  final String?  paymentMethod;
  final String?  tableNumber;
  final String?  cashierName;
  final String?  serverName;
  final String?  refCashout;
  final List<Map<String, dynamic>> items;
  final VoidCallback onPrint;

  const _InvoiceDetail({
    required this.invoiceNumber,
    required this.status,
    required this.kind,
    required this.amount,
    this.invoiceDate,
    this.paymentMethod,
    this.tableNumber,
    this.cashierName,
    this.serverName,
    this.refCashout,
    required this.items,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat('#,###', 'fr_FR');
    final dateFmt = DateFormat('dd/MM/yyyy à HH:mm');
    final isSettled = kind == 'settlement';

    final statusColor = isSettled ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final statusBg    = isSettled ? const Color(0xFF1B3A1D) : const Color(0xFF3A1A00);
    final statusIcon  = isSettled ? Icons.check_circle       : Icons.pending_outlined;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Badge statut ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Carte principale ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D1200),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFB5451B).withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.receipt_long, color: Color(0xFFB5451B), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoiceNumber,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      const Text('Restaurant Sankadiokro',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  )),
                ]),
                const Divider(color: Colors.white12, height: 24),

                // Infos document
                _InfoRow(label: 'Date', value: invoiceDate != null ? dateFmt.format(invoiceDate!) : '—'),
                if (tableNumber != null && tableNumber!.isNotEmpty)
                  _InfoRow(label: 'Table', value: tableNumber!),
                if (cashierName != null && cashierName!.isNotEmpty)
                  _InfoRow(label: 'Caissier', value: cashierName!),
                if (serverName != null && serverName!.isNotEmpty)
                  _InfoRow(label: 'Serveur', value: serverName!),
                if (paymentMethod != null && paymentMethod!.isNotEmpty)
                  _InfoRow(label: 'Mode de paiement', value: paymentMethod!),
                if (refCashout != null && refCashout!.isNotEmpty)
                  _InfoRow(label: 'Réf. encaissement', value: refCashout!),

                const Divider(color: Colors.white12, height: 24),

                // Montant total
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A0A00), Color(0xFF2D1200)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB5451B).withValues(alpha: 0.5)),
                  ),
                  child: Column(children: [
                    const Text('MONTANT TOTAL',
                        style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text('${fmt.format(amount)} F CFA',
                        style: const TextStyle(color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Articles ───────────────────────────────────────────────────────
          if (items.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DÉTAIL COMMANDE',
                      style: TextStyle(color: Colors.white54, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  ...items.map((item) {
                    final name  = (item['productName'] as String?) ?? '—';
                    final qty   = item['quantity'] ?? 1;
                    final total = (item['totalPrice'] as num?)?.toDouble()
                        ?? ((item['unitPrice'] as num?)?.toDouble() ?? 0) * (qty as num);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(name,
                              style: const TextStyle(color: Colors.white, fontSize: 12))),
                          Text('×$qty',
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(width: 12),
                          Text('${fmt.format(total)} F',
                              style: const TextStyle(color: Color(0xFFB5451B),
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('${fmt.format(amount)} F CFA',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Bouton Télécharger PDF ─────────────────────────────────────────
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.picture_as_pdf, size: 20),
              label: const Text('Télécharger / Imprimer le PDF',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5451B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Note de sécurité ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F0D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cette facture a été émise par Restaurant Sankadiokro. '
                    'Son authenticité est garantie par notre système.',
                    style: TextStyle(color: Colors.white54, fontSize: 10, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ── Ligne d'info ──────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
