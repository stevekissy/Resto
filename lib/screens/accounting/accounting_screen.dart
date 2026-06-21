// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/accounting_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/print_service.dart';

final _fmt     = NumberFormat('#,###', 'fr_FR');
final _fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');

// ════════════════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL COMPTABILITÉ
// ════════════════════════════════════════════════════════════════════════════
class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});
  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  AccountingPeriod _period = AccountingPeriod.month;
  DateTime? _customStart;
  DateTime? _customEnd;
  AccountingReport? _report;
  bool _loading = false;
  String? _error;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() => setState(() => _tabIndex = _tabCtrl.index));
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final range = AccountingService.rangeForPeriod(
          _period, customStart: _customStart, customEnd: _customEnd);
      final report = await AccountingService().buildReport(range);
      if (mounted) setState(() { _report = report; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Comptabilité & Bilan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          // Rafraîchir
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'Rafraîchir',
          ),
          // Impression
          if (_report != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.print_outlined, color: Colors.white),
              color: AppTheme.cardBg,
              onSelected: (v) {
                final r = _report!;
                if (v == 'bilan')     PrintService().printBilan(report: r);
                if (v == 'compte')    PrintService().printCompteResultat(report: r);
                if (v == 'rentabilite') PrintService().printRentabilite(report: r);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'bilan',
                    child: _PrintItem(icon: Icons.account_balance, label: 'Imprimer bilan comptable')),
                const PopupMenuItem(value: 'compte',
                    child: _PrintItem(icon: Icons.table_chart, label: 'Imprimer compte de résultat')),
                const PopupMenuItem(value: 'rentabilite',
                    child: _PrintItem(icon: Icons.trending_up, label: 'Rapport de rentabilité')),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 17), text: 'Dashboard'),
            Tab(icon: Icon(Icons.account_balance_outlined, size: 17), text: 'Bilan'),
            Tab(icon: Icon(Icons.table_chart_outlined, size: 17), text: 'Résultat'),
            Tab(icon: Icon(Icons.psychology_outlined, size: 17), text: 'Analyse IA'),
          ],
        ),
      ),
      body: Column(
        children: [
          _PeriodSelector(
            period: _period,
            customStart: _customStart,
            customEnd: _customEnd,
            onPeriodChange: (p) { setState(() => _period = p); _load(); },
            onCustomRange: (s, e) {
              setState(() { _period = AccountingPeriod.custom; _customStart = s; _customEnd = e; });
              _load();
            },
          ),
          if (_report != null && _report!.alerts.isNotEmpty)
            _AlertBanner(alerts: _report!.alerts),
          Expanded(
            child: _loading
                ? const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text('Calcul en cours…', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ]))
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _load)
                    : _report == null
                        ? const SizedBox()
                        : TabBarView(
                            controller: _tabCtrl,
                            children: [
                              _DashboardTab(report: _report!),
                              _BilanTab(report: _report!),
                              _CompteResultatTab(report: _report!),
                              _IaTab(report: _report!),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SÉLECTEUR DE PÉRIODE
// ════════════════════════════════════════════════════════════════════════════
class _PeriodSelector extends StatelessWidget {
  final AccountingPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<AccountingPeriod> onPeriodChange;
  final void Function(DateTime, DateTime) onCustomRange;
  const _PeriodSelector({
    required this.period, required this.customStart, required this.customEnd,
    required this.onPeriodChange, required this.onCustomRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: AccountingPeriod.values.map((p) {
                final sel = p == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () async {
                      if (p == AccountingPeriod.custom) {
                        await _pickCustomRange(context);
                      } else {
                        onPeriodChange(p);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppTheme.primary : const Color(0xFF2A2A5A)),
                      ),
                      child: Text(p.label,
                          style: TextStyle(
                              color: sel ? Colors.white : AppTheme.textSecondary,
                              fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (period == AccountingPeriod.custom && customStart != null && customEnd != null) ...[
            const SizedBox(height: 4),
            Text(
              'Du ${_fmtDate.format(customStart!)} au ${_fmtDate.format(customEnd!)}',
              style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final s = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      helpText: 'Date de début',
      builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
          child: child!),
    );
    if (s == null || !context.mounted) return;
    final e = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: s,
      lastDate: DateTime.now(),
      helpText: 'Date de fin',
      builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
          child: child!),
    );
    if (e == null) return;
    onCustomRange(s, e);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TABLEAU DE BORD
// ════════════════════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  final AccountingReport report;
  const _DashboardTab({required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final sante = r.santeFinanciere;
    final santeColor = sante == 'Excellente' ? AppTheme.success
        : sante == 'Bonne' ? const Color(0xFF4CAF50)
        : sante == 'Moyenne' ? AppTheme.warning
        : AppTheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Santé financière
          GlassCard(
            border: Border.all(color: santeColor.withValues(alpha: 0.5)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: santeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(r.isRentable ? Icons.trending_up : Icons.trending_down,
                    color: santeColor, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.isRentable ? 'Rentable ✓' : 'En perte ✗',
                      style: TextStyle(color: santeColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('Santé financière : $sante',
                      style: TextStyle(color: santeColor.withValues(alpha: 0.8), fontSize: 12)),
                  Text('Résultat net : ${_fmt.format(r.resultatNet)} F CFA',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 12),
          // KPI Produits
          _SecHeader('Chiffre d\'affaires & Produits', Icons.store_outlined),
          const SizedBox(height: 8),
          _TripleKpi(
            kpis: [
              _Kpi('CA Restaurant', r.caRestaurant, AppTheme.primary, Icons.restaurant),
              _Kpi('Réservations', r.caReservations, const Color(0xFF00BCD4), Icons.event),
              _Kpi('Total produits', r.totalProduits, AppTheme.success, Icons.account_balance_wallet),
            ],
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Row(children: [
              Expanded(child: _MiniKpi('Encaissé', r.recettesEncaissees, AppTheme.success)),
              _vDiv(),
              Expanded(child: _MiniKpi('Créances', r.creancesClients, AppTheme.warning)),
              _vDiv(),
              Expanded(child: _MiniKpi('Factures', r.nbFactures.toDouble(), AppTheme.primary, isCount: true)),
            ]),
          ),
          const SizedBox(height: 12),
          // KPI Charges
          _SecHeader('Charges totales', Icons.payments_outlined),
          const SizedBox(height: 8),
          _ChargesBar(report: r),
          const SizedBox(height: 8),
          _TripleKpi(
            kpis: [
              _Kpi('Fournisseurs', r.achatsFournisseurs, AppTheme.error, Icons.local_shipping),
              _Kpi('Salaires', r.salairesBruts, AppTheme.warning, Icons.people),
              _Kpi('Charges/jour', r.chargesJour, const Color(0xFFFF7043), Icons.receipt_long),
            ],
          ),
          const SizedBox(height: 12),
          // Résultat
          _SecHeader('Marges & Résultat', Icons.bar_chart_outlined),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _MargeCard('Marge brute', r.margeBrute, AppTheme.primary)),
            const SizedBox(width: 8),
            Expanded(child: _MargeCard('Marge nette', r.margeNette,
                r.margeNette >= 10 ? AppTheme.success : r.margeNette >= 0 ? AppTheme.warning : AppTheme.error)),
          ]),
          const SizedBox(height: 8),
          GlassCard(
            border: Border.all(
              color: r.isRentable ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.error.withValues(alpha: 0.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RÉSULTAT NET', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5)),
                Text(_fmt.format(r.resultatNet) + ' F CFA',
                    style: TextStyle(
                        color: r.isRentable ? AppTheme.success : AppTheme.error,
                        fontWeight: FontWeight.w900, fontSize: 22)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (r.isRentable ? AppTheme.success : AppTheme.error).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(r.isRentable ? 'BÉNÉFICE' : 'PERTE',
                    style: TextStyle(
                        color: r.isRentable ? AppTheme.success : AppTheme.error,
                        fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BILAN SIMPLIFIÉ
// ════════════════════════════════════════════════════════════════════════════
class _BilanTab extends StatelessWidget {
  final AccountingReport report;
  const _BilanTab({required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ACTIF
          _SecHeader('ACTIF', Icons.arrow_circle_up_outlined),
          const SizedBox(height: 8),
          GlassCard(
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            child: Column(children: [
              _BilanRow('💰 Caisse disponible',    r.caisse,         AppTheme.success),
              _BilanRow('📋 Créances clients',      r.creancesClients, AppTheme.warning),
              _BilanRow('📦 Stock valorisé',        r.stockValue,     AppTheme.primary),
              const Divider(color: Color(0xFF2A2A5A)),
              _BilanRow('TOTAL ACTIF', r.totalActif, AppTheme.success, isBold: true),
            ]),
          ),
          const SizedBox(height: 14),
          // PASSIF
          _SecHeader('PASSIF', Icons.arrow_circle_down_outlined),
          const SizedBox(height: 8),
          GlassCard(
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            child: Column(children: [
              _BilanRow('🚚 Dettes fournisseurs',  r.dettesFournisseurs, AppTheme.error),
              _BilanRow('👥 Salaires dus',          r.salairesDus,        AppTheme.warning),
              const Divider(color: Color(0xFF2A2A5A)),
              _BilanRow('TOTAL PASSIF', r.totalPassif, AppTheme.error, isBold: true),
            ]),
          ),
          const SizedBox(height: 14),
          // Équilibre
          _SecHeader('RÉSULTAT DU BILAN', Icons.balance_outlined),
          const SizedBox(height: 8),
          GlassCard(
            border: Border.all(
                color: r.equilibre >= 0 ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.error.withValues(alpha: 0.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Actif – Passif =', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('${_fmt.format(r.equilibre)} F CFA',
                      style: TextStyle(
                          color: r.equilibre >= 0 ? AppTheme.success : AppTheme.error,
                          fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _SanteChip(sante: r.santeFinanciere),
                  const SizedBox(width: 8),
                  Text(r.isRentable ? 'Position financière saine' : 'Attention : position fragile',
                      style: TextStyle(
                          color: r.isRentable ? AppTheme.success : AppTheme.error,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFF2A2A5A)),
                const SizedBox(height: 8),
                _bilanDetail(r),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _bilanDetail(AccountingReport r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Détail des éléments du bilan :', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      const SizedBox(height: 6),
      _DetailLine('Recettes encaissées', r.recettesEncaissees, AppTheme.success),
      _DetailLine('Paiements fournisseurs effectués', r.paiementsFournisseurs, AppTheme.error),
      _DetailLine('Salaires versés', r.salairesPayes, AppTheme.error),
      _DetailLine('Charges diverses décaissées', r.chargesJour, AppTheme.error),
      _DetailLine('Pertes stock estimées', r.pertesStock, AppTheme.error),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════════
// COMPTE DE RÉSULTAT
// ════════════════════════════════════════════════════════════════════════════
class _CompteResultatTab extends StatelessWidget {
  final AccountingReport report;
  const _CompteResultatTab({required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entête période
          GlassCard(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Compte de résultat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Text(
                '${_fmtDate.format(r.range.start)} → ${_fmtDate.format(r.range.end)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // PRODUITS
          _SecHeader('PRODUITS', Icons.add_circle_outline),
          const SizedBox(height: 8),
          GlassCard(
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            child: Column(children: [
              _CRRow('Ventes restaurant', 'Factures encaissées', r.caRestaurant, AppTheme.success, r.totalProduits),
              _CRRow('Réservations événements', 'Paiements réservations', r.caReservations, AppTheme.success, r.totalProduits),
              const Divider(color: Color(0xFF2A2A5A)),
              _CRTotalRow('TOTAL PRODUITS', r.totalProduits, AppTheme.success),
            ]),
          ),
          const SizedBox(height: 14),
          // CHARGES
          _SecHeader('CHARGES', Icons.remove_circle_outline),
          const SizedBox(height: 8),
          GlassCard(
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            child: Column(children: [
              _CRRow('Achats marchandises', '${r.nbCommandesFournisseurs} commandes fournisseurs',
                  r.achatsFournisseurs, AppTheme.error, r.totalCharges),
              _CRRow('Charges salariales', '${r.nbSalaries} fiches de paie',
                  r.salairesBruts, AppTheme.warning, r.totalCharges),
              _CRRow('Charges du jour', '${r.nbChargesJour} entrées',
                  r.chargesJour, const Color(0xFFFF7043), r.totalCharges),
              if (r.pertesStock > 0)
                _CRRow('Pertes & ajustements stock', 'Mouvements négatifs',
                    r.pertesStock, AppTheme.error, r.totalCharges),
              const Divider(color: Color(0xFF2A2A5A)),
              _CRTotalRow('TOTAL CHARGES', r.totalCharges, AppTheme.error),
            ]),
          ),
          const SizedBox(height: 14),
          // RÉSULTAT
          GlassCard(
            border: Border.all(
                color: r.isRentable ? AppTheme.success.withValues(alpha: 0.6) : AppTheme.error.withValues(alpha: 0.6),
                width: 2),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('RÉSULTAT NET DE LA PÉRIODE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  Text('Produits − Charges = résultat',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                ]),
                Text('${_fmt.format(r.resultatNet)} F',
                    style: TextStyle(
                        color: r.isRentable ? AppTheme.success : AppTheme.error,
                        fontWeight: FontWeight.w900, fontSize: 20)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _MargeCard('Marge brute', r.margeBrute, AppTheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: _MargeCard('Marge nette', r.margeNette,
                    r.margeNette >= 10 ? AppTheme.success : r.margeNette >= 0 ? AppTheme.warning : AppTheme.error)),
              ]),
            ]),
          ),
          // Détail charges fournisseurs
          if (r.supplierOrdersDetail.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SecHeader('Détail achats fournisseurs', Icons.local_shipping_outlined),
            const SizedBox(height: 8),
            ...r.supplierOrdersDetail.take(8).map((o) => Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.supplierName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(DateFormat('dd/MM/yy', 'fr_FR').format(o.createdAt ?? o.orderDate),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ])),
                Text('${_fmt.format(o.totalAmount)} F',
                    style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 11)),
              ]),
            )),
          ],
          // Détail charges jour
          if (r.dailyChargesDetail.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SecHeader('Détail charges diverses', Icons.receipt_long_outlined),
            const SizedBox(height: 8),
            ...r.dailyChargesDetail.take(8).map((d) {
              final label  = d['label']  as String? ?? '—';
              final amount = (d['amount'] as num?)?.toDouble() ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11))),
                  Text('${_fmt.format(amount)} F',
                      style: const TextStyle(color: Color(0xFFFF7043), fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              );
            }),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ASSISTANT IA / ANALYSE
// ════════════════════════════════════════════════════════════════════════════
class _IaTab extends StatelessWidget {
  final AccountingReport report;
  const _IaTab({required this.report});

  @override
  Widget build(BuildContext context) {
    final insights = _buildInsights(report);
    final recommendations = _buildRecommendations(report);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Synthèse IA
          GlassCard(
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assistant Comptable IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('Analyse automatique des données réelles Firestore',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  )),
                ]),
                const Divider(color: Color(0xFF2A2A5A), height: 18),
                ...insights.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.text, style: TextStyle(
                          color: i.color,
                          fontSize: 12, height: 1.5))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Répartition charges
          _SecHeader('Répartition des charges', Icons.pie_chart_outline),
          const SizedBox(height: 8),
          _ChargesPieCard(report: report),
          const SizedBox(height: 14),
          // Recommandations
          _SecHeader('Recommandations', Icons.lightbulb_outline),
          const SizedBox(height: 8),
          ...recommendations.map((rec) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rec.color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: rec.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec.title, style: TextStyle(color: rec.color, fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(rec.text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4)),
                  ],
                )),
              ],
            ),
          )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_Insight> _buildInsights(AccountingReport r) {
    final ins = <_Insight>[];
    // Rentabilité
    if (r.isRentable) {
      ins.add(_Insight('✅', 'Le restaurant est rentable sur cette période avec un bénéfice net de ${_fmt.format(r.resultatNet)} F CFA (marge ${r.margeNette.toStringAsFixed(1)}%).', AppTheme.success));
    } else {
      ins.add(_Insight('🔴', 'Le restaurant enregistre une perte de ${_fmt.format(r.resultatNet.abs())} F CFA sur cette période. Une révision des charges s\'impose.', AppTheme.error));
    }
    // Charges fournisseurs
    if (r.totalProduits > 0) {
      final pct = r.achatsFournisseurs / r.totalProduits * 100;
      ins.add(_Insight('🛒', 'Les charges fournisseurs représentent ${pct.toStringAsFixed(1)}% du chiffre d\'affaires (${_fmt.format(r.achatsFournisseurs)} F CFA sur ${r.nbCommandesFournisseurs} commandes).', AppTheme.textSecondary));
    }
    // Salaires
    if (r.totalProduits > 0 && r.salairesBruts > 0) {
      final pct = r.salairesBruts / r.totalProduits * 100;
      ins.add(_Insight('👥', 'La masse salariale représente ${pct.toStringAsFixed(1)}% du CA (${_fmt.format(r.salairesBruts)} F CFA pour ${r.nbSalaries} employés).', AppTheme.textSecondary));
    }
    // Stock
    ins.add(_Insight('📦', 'Stock valorisé actuel : ${_fmt.format(r.stockValue)} F CFA.${r.pertesStock > 0 ? " Pertes/ajustements stock de ${_fmt.format(r.pertesStock)} F détectés." : " Aucune perte stock détectée."}', AppTheme.primary));
    // Réservations
    if (r.caReservations > 0) {
      ins.add(_Insight('📅', 'Les réservations ont généré ${_fmt.format(r.caReservations)} F CFA de revenus supplémentaires (${r.totalProduits > 0 ? (r.caReservations / r.totalProduits * 100).toStringAsFixed(1) : "0"}% du CA total).', const Color(0xFF00BCD4)));
    }
    // Dettes
    if (r.dettesFournisseurs > 0) {
      ins.add(_Insight('⚠️', 'Dettes fournisseurs restantes : ${_fmt.format(r.dettesFournisseurs)} F CFA à régler.', AppTheme.warning));
    }
    // Salaires dus
    if (r.salairesDus > 0) {
      ins.add(_Insight('💸', 'Salaires encore dus : ${_fmt.format(r.salairesDus)} F CFA non versés aux employés.', AppTheme.warning));
    }
    return ins;
  }

  List<_Recommendation> _buildRecommendations(AccountingReport r) {
    final recs = <_Recommendation>[];
    if (!r.isRentable) {
      recs.add(_Recommendation('🎯', 'Réduire les charges', 'Le résultat net est négatif. Analysez chaque poste de charge pour identifier les réductions possibles, notamment les achats fournisseurs et les dépenses diverses.', AppTheme.error));
    }
    if (r.totalProduits > 0 && r.achatsFournisseurs / r.totalProduits > 0.4) {
      recs.add(_Recommendation('🤝', 'Négocier avec les fournisseurs', 'Les achats représentent plus de 40% du CA. Renégociez vos contrats fournisseurs ou cherchez des alternatives moins coûteuses.', AppTheme.warning));
    }
    if (r.caReservations < r.caRestaurant * 0.1 && r.caRestaurant > 0) {
      recs.add(_Recommendation('📅', 'Développer les réservations', 'Les revenus de réservations sont inférieurs à 10% du CA restaurant. Promouvoir les événements peut augmenter significativement les revenus.', AppTheme.primary));
    }
    if (r.stockValue < 100000) {
      recs.add(_Recommendation('📦', 'Renforcer le stock', 'Le stock valorisé est faible. Un stock insuffisant peut entraîner des ruptures et des pertes de ventes.', AppTheme.warning));
    }
    if (r.pertesStock > r.totalProduits * 0.02 && r.totalProduits > 0) {
      recs.add(_Recommendation('♻️', 'Réduire les pertes stock', 'Les pertes stock dépassent 2% du CA. Améliorez la gestion des dates de péremption et les procédures de stockage.', AppTheme.error));
    }
    if (r.margeBrute > 30 && r.margeNette < 10) {
      recs.add(_Recommendation('✂️', 'Maîtriser les charges fixes', 'Bonne marge brute mais faible marge nette : les charges fixes (salaires, loyer, charges) consomment trop de marge. Optimisez les plannings et les dépenses récurrentes.', AppTheme.warning));
    }
    if (recs.isEmpty) {
      recs.add(_Recommendation('⭐', 'Maintenir les bonnes pratiques', 'La situation financière est saine. Continuez à surveiller les charges et à diversifier les sources de revenus pour consolider la rentabilité.', AppTheme.success));
    }
    return recs;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BANDEAU ALERTES
// ════════════════════════════════════════════════════════════════════════════
class _AlertBanner extends StatefulWidget {
  final List<AccountingAlert> alerts;
  const _AlertBanner({required this.alerts});
  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}
class _AlertBannerState extends State<_AlertBanner> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final critical = widget.alerts.where((a) => a.type == AlertType.danger).length;
    final bannerColor = critical > 0 ? AppTheme.error : AppTheme.warning;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Icon(Icons.warning_amber, color: bannerColor, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    '${widget.alerts.length} alerte(s) comptable(s) — appuyez pour voir',
                    style: TextStyle(color: bannerColor, fontSize: 12, fontWeight: FontWeight.w700))),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: bannerColor, size: 18),
              ]),
            ),
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0xFF2A2A5A)),
              ...widget.alerts.map((a) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.message,
                        style: TextStyle(
                            color: a.type == AlertType.danger ? AppTheme.error
                                : a.type == AlertType.warning ? AppTheme.warning : AppTheme.primary,
                            fontSize: 11))),
                  ],
                ),
              )),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS HELPERS
// ════════════════════════════════════════════════════════════════════════════

class _PrintItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PrintItem({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.primary, size: 16),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
  ]);
}

class _SecHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SecHeader(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.primary, size: 16),
    const SizedBox(width: 6),
    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3)),
  ]);
}

class _Kpi {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _Kpi(this.label, this.value, this.color, this.icon);
}

class _TripleKpi extends StatelessWidget {
  final List<_Kpi> kpis;
  const _TripleKpi({required this.kpis});
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Row(
      children: kpis.asMap().entries.map((e) {
        final k = e.value;
        final isLast = e.key == kpis.length - 1;
        return Expanded(child: Row(children: [
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(k.icon, color: k.color, size: 16),
              const SizedBox(height: 4),
              Text(_fmt.format(k.value), style: TextStyle(color: k.color, fontWeight: FontWeight.w900, fontSize: 13)),
              Text(k.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
            ]),
          )),
          if (!isLast) Container(width: 1, height: 40, color: const Color(0xFF2A2A5A)),
        ]));
      }).toList(),
    ),
  );
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isCount;
  const _MiniKpi(this.label, this.value, this.color, {this.isCount = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: Column(children: [
      Text(isCount ? value.toInt().toString() : '${_fmt.format(value)} F',
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9), textAlign: TextAlign.center),
    ]),
  );
}

Widget _vDiv() => Container(width: 1, height: 35, color: const Color(0xFF2A2A5A));

class _MargeCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MargeCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        Text('${value.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value.abs() / 100).clamp(0, 1),
            backgroundColor: const Color(0xFF2A2A5A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    ),
  );
}

class _ChargesBar extends StatelessWidget {
  final AccountingReport report;
  const _ChargesBar({required this.report});
  @override
  Widget build(BuildContext context) {
    final total = report.totalCharges;
    if (total <= 0) return const SizedBox();
    final items = [
      _BarItem('Fournisseurs', report.achatsFournisseurs, AppTheme.error),
      _BarItem('Salaires', report.salairesBruts, AppTheme.warning),
      _BarItem('Charges/jour', report.chargesJour, const Color(0xFFFF7043)),
      if (report.pertesStock > 0)
        _BarItem('Pertes stock', report.pertesStock, const Color(0xFFAA00FF)),
    ];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total charges : ${_fmt.format(total)} F CFA',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          // Barre empilée
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(
                children: items.map((it) {
                  final pct = it.value / total;
                  return Flexible(
                    flex: (pct * 1000).round(),
                    child: Container(color: it.color, height: 14),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: items.map((it) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: it.color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${it.label} ${(it.value/total*100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  final Color color;
  const _BarItem(this.label, this.value, this.color);
}

class _ChargesPieCard extends StatelessWidget {
  final AccountingReport report;
  const _ChargesPieCard({required this.report});
  @override
  Widget build(BuildContext context) {
    final r = report;
    if (r.totalCharges <= 0) {
      return const GlassCard(child: Center(
        child: Text('Aucune charge enregistrée', style: TextStyle(color: AppTheme.textSecondary))));
    }
    final items = <_PieItem>[
      _PieItem('Fournisseurs', r.achatsFournisseurs, AppTheme.error),
      _PieItem('Salaires', r.salairesBruts, AppTheme.warning),
      _PieItem('Charges/jour', r.chargesJour, const Color(0xFFFF7043)),
      if (r.pertesStock > 0) _PieItem('Pertes stock', r.pertesStock, const Color(0xFFAA00FF)),
    ].where((i) => i.value > 0).toList();
    return GlassCard(
      child: Column(
        children: items.map((it) {
          final pct = r.totalCharges > 0 ? it.value / r.totalCharges * 100 : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: it.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(it.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                  Text('${_fmt.format(it.value)} F (${pct.toStringAsFixed(1)}%)',
                      style: TextStyle(color: it.color, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0, 1),
                    backgroundColor: const Color(0xFF2A2A5A),
                    valueColor: AlwaysStoppedAnimation<Color>(it.color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
class _PieItem { final String label; final double value; final Color color;
  const _PieItem(this.label, this.value, this.color); }

class _BilanRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isBold;
  const _BilanRow(this.label, this.value, this.color, {this.isBold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
          color: isBold ? Colors.white : AppTheme.textSecondary,
          fontSize: isBold ? 12 : 11,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.normal)),
      Text('${_fmt.format(value)} F CFA',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: isBold ? 14 : 12)),
    ]),
  );
}

class _DetailLine extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _DetailLine(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text('  • $label', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10))),
      Text('${_fmt.format(value)} F', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _SanteChip extends StatelessWidget {
  final String sante;
  const _SanteChip({required this.sante});
  @override
  Widget build(BuildContext context) {
    final color = sante == 'Excellente' || sante == 'Bonne' ? AppTheme.success
        : sante == 'Moyenne' ? AppTheme.warning : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(sante, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _CRRow extends StatelessWidget {
  final String label, sublabel;
  final double value, total;
  final Color color;
  const _CRRow(this.label, this.sublabel, this.value, this.color, this.total);
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          Text(sublabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmt.format(value)} F', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
        ]),
      ]),
    );
  }
}

class _CRTotalRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _CRTotalRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      Text('${_fmt.format(value)} F CFA', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
    ]),
  );
}

class _Insight {
  final String icon, text;
  final Color color;
  const _Insight(this.icon, this.text, this.color);
}

class _Recommendation {
  final String icon, title, text;
  final Color color;
  const _Recommendation(this.icon, this.title, this.text, this.color);
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 16),
          Text('Erreur de chargement', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}
