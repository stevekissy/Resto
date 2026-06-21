import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SALARY TAB — point d'entrée depuis staff_screen.dart
// ══════════════════════════════════════════════════════════════════════════════
class SalaryTab extends StatefulWidget {
  const SalaryTab({super.key});
  @override
  State<SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends State<SalaryTab> with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Période affichée (mois courant par défaut)
  int _annee = DateTime.now().year;
  int _mois  = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get _periodeLabel {
    final moisFr = const [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${moisFr[_mois]} $_annee';
  }

  void _prevMonth() => setState(() {
    _mois--;
    if (_mois < 1) { _mois = 12; _annee--; }
  });

  void _nextMonth() => setState(() {
    _mois++;
    if (_mois > 12) { _mois = 1; _annee++; }
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final salaries = provider.salariesForPeriod(_annee, _mois);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSalaryFormDialog(context, provider, annee: _annee, mois: _mois, periodeLabel: _periodeLabel),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle fiche'),
      ),
      body: Column(
        children: [
          // ── Sélecteur de période ────────────────────────────────────
          _PeriodeSelector(
            label: _periodeLabel,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),

          // ── Tabs ────────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tab,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Fiches de paie', icon: Icon(Icons.receipt_long, size: 15)),
                Tab(text: 'Tableau global',  icon: Icon(Icons.table_chart,  size: 15)),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _FichesList(salaries: salaries, annee: _annee, mois: _mois, periodeLabel: _periodeLabel),
                _GlobalTable(salaries: salaries),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sélecteur de période ───────────────────────────────────────────────────────
class _PeriodeSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PeriodeSelector({required this.label, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left, color: AppTheme.primary)),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right, color: AppTheme.primary)),
        ],
      ),
    );
  }
}

// ── Liste des fiches de paie ───────────────────────────────────────────────────
class _FichesList extends StatelessWidget {
  final List<EmployeeSalary> salaries;
  final int annee;
  final int mois;
  final String periodeLabel;
  const _FichesList({required this.salaries, required this.annee, required this.mois, required this.periodeLabel});

  @override
  Widget build(BuildContext context) {
    if (salaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 52, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text('Aucune fiche pour $periodeLabel', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Appuyez sur "Nouvelle fiche" pour commencer.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: salaries.length,
      itemBuilder: (ctx, i) => _SalaryCard(salary: salaries[i], periodeLabel: periodeLabel),
    );
  }
}

// ── Carte fiche de paie ────────────────────────────────────────────────────────
class _SalaryCard extends StatelessWidget {
  final EmployeeSalary salary;
  final String periodeLabel;
  const _SalaryCard({required this.salary, required this.periodeLabel});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final st = salary.paymentStatus;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: st.color.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    salary.employeeName.isNotEmpty ? salary.employeeName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(salary.employeeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(salary.poste, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    if (salary.matricule.isNotEmpty)
                      Text('Matricule : ${salary.matricule}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(label: st.label, color: st.color, fontSize: 10),
                  const SizedBox(height: 4),
                  Text(
                    '${NumberFormat('#,###', 'fr_FR').format(salary.netAPayer)} F',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text('Net à payer', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFF2A2A5A)),
          const SizedBox(height: 8),
          // ── Résumé chiffres ──
          Row(
            children: [
              _MiniStat(label: 'Brut',     value: salary.brut,          color: AppTheme.primary),
              _MiniStat(label: 'Retenues', value: salary.totalRetenues, color: AppTheme.error),
              _MiniStat(label: 'Payé',     value: salary.montantPaye,   color: AppTheme.success),
              if (salary.resteAPayer > 0)
                _MiniStat(label: 'Reste', value: salary.resteAPayer, color: AppTheme.warning),
            ],
          ),
          const SizedBox(height: 8),
          // ── Actions ──
          Row(
            children: [
              _ActionBtn(icon: Icons.visibility, label: 'Détail', color: AppTheme.primary,
                  onTap: () => _showDetail(context, salary, provider)),
              const SizedBox(width: 6),
              if (salary.paymentStatus != PaymentStatus.paye)
                _ActionBtn(icon: Icons.payments, label: 'Payer', color: AppTheme.success,
                    onTap: () => _showPaymentDialog(context, salary, provider)),
              const SizedBox(width: 6),
              _ActionBtn(icon: Icons.print, label: 'PDF', color: const Color(0xFF7C4DFF),
                  onTap: () => PrintService().printPayslip(salary: salary)),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(context, salary, provider),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: AppTheme.error, size: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, EmployeeSalary s, AppProvider provider) {
    showDialog(context: context, builder: (_) => _SalaryDetailDialog(salary: s, provider: provider));
  }

  void _showPaymentDialog(BuildContext context, EmployeeSalary s, AppProvider provider) {
    showDialog(context: context, builder: (_) => _PaymentDialog(salary: s, provider: provider));
  }

  void _confirmDelete(BuildContext context, EmployeeSalary s, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Supprimer la fiche ?', style: TextStyle(color: Colors.white)),
        content: Text('La fiche de ${s.employeeName} pour ${s.periode} sera supprimée.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () { provider.deleteSalary(s.id); Navigator.pop(context); },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(NumberFormat('#,###', 'fr_FR').format(value), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
            Text(label, style: TextStyle(color: color, fontSize: 8)),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Tableau global ─────────────────────────────────────────────────────────────
class _GlobalTable extends StatelessWidget {
  final List<EmployeeSalary> salaries;
  const _GlobalTable({required this.salaries});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    if (salaries.isEmpty) {
      return const Center(
        child: Text('Aucune donnée pour cette période.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final totalBrut      = salaries.fold<double>(0, (s, e) => s + e.brut);
    final totalPrimes    = salaries.fold<double>(0, (s, e) => s + e.primes);
    final totalRetenues  = salaries.fold<double>(0, (s, e) => s + e.totalRetenues);
    final totalNet       = salaries.fold<double>(0, (s, e) => s + e.netAPayer);
    final totalPaye      = salaries.fold<double>(0, (s, e) => s + e.montantPaye);
    final resteAPayer    = totalNet - totalPaye;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // ── Totaux ──
          _TotauxRow(
            totalBrut: totalBrut, totalPrimes: totalPrimes,
            totalRetenues: totalRetenues, totalNet: totalNet,
            totalPaye: totalPaye, resteAPayer: resteAPayer,
          ),
          const SizedBox(height: 14),

          // ── Tableau détaillé ──
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A2550),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Employé',      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Salaire base', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Net à payer',  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Payé',         style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Statut',       style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                ...salaries.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.transparent : AppTheme.surfaceLight.withValues(alpha: 0.4),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.employeeName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            Text(s.poste, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
                          ],
                        )),
                        Expanded(flex: 2, child: Text(fmt.format(s.salaryBase), style: const TextStyle(color: Colors.white, fontSize: 10))),
                        Expanded(flex: 2, child: Text(fmt.format(s.netAPayer),  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
                        Expanded(flex: 2, child: Text(fmt.format(s.montantPaye), style: TextStyle(color: s.paymentStatus == PaymentStatus.paye ? AppTheme.success : AppTheme.warning, fontSize: 10))),
                        Expanded(flex: 2, child: StatusBadge(label: s.paymentStatus.label, color: s.paymentStatus.color, fontSize: 8)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotauxRow extends StatelessWidget {
  final double totalBrut, totalPrimes, totalRetenues, totalNet, totalPaye, resteAPayer;
  const _TotauxRow({
    required this.totalBrut, required this.totalPrimes, required this.totalRetenues,
    required this.totalNet, required this.totalPaye, required this.resteAPayer,
  });
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        _TotalChip(label: 'Total Bruts',    value: fmt.format(totalBrut),     color: AppTheme.primary),
        _TotalChip(label: 'Total Primes',   value: fmt.format(totalPrimes),   color: const Color(0xFF7C4DFF)),
        _TotalChip(label: 'Total Retenues', value: fmt.format(totalRetenues), color: AppTheme.error),
        _TotalChip(label: 'Total Net',      value: fmt.format(totalNet),      color: Colors.white),
        _TotalChip(label: 'Total Payé',     value: fmt.format(totalPaye),     color: AppTheme.success),
        _TotalChip(label: 'Reste à payer',  value: fmt.format(resteAPayer),   color: AppTheme.warning),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$value F', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── Dialog détail + historique paiements ─────────────────────────────────────
class _SalaryDetailDialog extends StatelessWidget {
  final EmployeeSalary salary;
  final AppProvider provider;
  const _SalaryDetailDialog({required this.salary, required this.provider});

  @override
  Widget build(BuildContext context) {
    final fmt    = NumberFormat('#,###', 'fr_FR');
    final dateFmt = DateFormat('dd/MM/yyyy');
    final payments = provider.paymentsForSalary(salary.id);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titre
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(salary.employeeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('${salary.poste} — ${salary.periode}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                StatusBadge(label: salary.paymentStatus.label, color: salary.paymentStatus.color),
              ],
            ),
            if (salary.matricule.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Matricule : ${salary.matricule}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
            const SizedBox(height: 16),

            // Tableau gains
            _SectionTitle(title: 'GAINS', icon: Icons.add_circle_outline, color: AppTheme.success),
            const SizedBox(height: 6),
            _DetailRow(label: 'Salaire de base',       value: fmt.format(salary.salaryBase)),
            _DetailRow(label: 'Heures supplémentaires', value: fmt.format(salary.heuresSup)),
            _DetailRow(label: 'Primes',                value: fmt.format(salary.primes)),
            _DetailRow(label: 'Indemnités',            value: fmt.format(salary.indemnites)),
            _SumRow(label: 'SALAIRE BRUT', value: fmt.format(salary.brut), color: AppTheme.success),
            const SizedBox(height: 12),

            // Tableau retenues
            _SectionTitle(title: 'RETENUES', icon: Icons.remove_circle_outline, color: AppTheme.error),
            const SizedBox(height: 6),
            _DetailRow(label: 'CNPS',             value: fmt.format(salary.cnps)),
            _DetailRow(label: 'ITS',              value: fmt.format(salary.its)),
            _DetailRow(label: 'Autres retenues',  value: fmt.format(salary.autresRetenues)),
            _DetailRow(label: 'Avances salaire',  value: fmt.format(salary.avances)),
            _SumRow(label: 'TOTAL RETENUES', value: fmt.format(salary.totalRetenues), color: AppTheme.error),
            const SizedBox(height: 12),

            // Net à payer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('NET À PAYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
                  Text('${fmt.format(salary.netAPayer)} F CFA', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _DetailRow(label: 'Déjà payé',    value: '${fmt.format(salary.montantPaye)} F'),
            if (salary.resteAPayer > 0)
              _DetailRow(label: 'Reste à payer', value: '${fmt.format(salary.resteAPayer)} F',
                  color: AppTheme.warning),

            // Historique paiements
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionTitle(title: 'HISTORIQUE PAIEMENTS', icon: Icons.history, color: AppTheme.primary),
              const SizedBox(height: 6),
              ...payments.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments, color: AppTheme.success, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${fmt.format(p.montant)} F — ${p.mode.label}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('${dateFmt.format(p.date)} — ${p.responsable}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                          if (p.note.isNotEmpty)
                            Text(p.note, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 16),

            // Boutons
            Row(
              children: [
                if (salary.paymentStatus != PaymentStatus.paye)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                      icon: const Icon(Icons.payments, size: 16),
                      label: const Text('Payer', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(context: context, builder: (_) => _PaymentDialog(salary: salary, provider: provider));
                      },
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('PDF', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(context);
                      PrintService().printPayslip(salary: salary);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle({required this.title, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _DetailRow({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SumRow({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        Text('$value F CFA', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

// ── Dialog paiement ─────────────────────────────────────────────────────────
class _PaymentDialog extends StatefulWidget {
  final EmployeeSalary salary;
  final AppProvider provider;
  const _PaymentDialog({required this.salary, required this.provider});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _montantCtrl = TextEditingController();
  final _noteCtrl    = TextEditingController();
  PaymentMode _mode  = PaymentMode.especes;
  bool _payTotal     = true;
  bool _loading      = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _montantCtrl.text = widget.salary.resteAPayer.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Paiement salaire', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  _DetailRow(label: 'Employé',    value: widget.salary.employeeName),
                  _DetailRow(label: 'Net à payer', value: '${fmt.format(widget.salary.netAPayer)} F'),
                  _DetailRow(label: 'Reste',       value: '${fmt.format(widget.salary.resteAPayer)} F', color: AppTheme.warning),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Toggle total/partiel
            Row(
              children: [
                _ModeChip(label: 'Paiement total',   selected: _payTotal,  onTap: () { setState(() { _payTotal = true; _montantCtrl.text = widget.salary.resteAPayer.toStringAsFixed(0); }); }),
                const SizedBox(width: 8),
                _ModeChip(label: 'Paiement partiel', selected: !_payTotal, onTap: () => setState(() => _payTotal = false)),
              ],
            ),
            const SizedBox(height: 10),
            // Montant
            TextField(
              controller: _montantCtrl,
              enabled: !_payTotal,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Montant (F CFA)',
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.primary, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
            const SizedBox(height: 10),
            // Mode de paiement
            DropdownButtonFormField<PaymentMode>(
              value: _mode,
              dropdownColor: AppTheme.cardBg,
              decoration: const InputDecoration(
                labelText: 'Mode de paiement',
                prefixIcon: Icon(Icons.payment, color: AppTheme.primary, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: PaymentMode.values.map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.label),
              )).toList(),
              onChanged: (v) => setState(() => _mode = v!),
            ),
            const SizedBox(height: 10),
            // Note
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                prefixIcon: Icon(Icons.note, color: AppTheme.primary, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          icon: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16),
          label: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          onPressed: _loading ? null : _confirm,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final montant = double.tryParse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', ''));
    if (montant == null || montant <= 0) {
      setState(() => _error = 'Montant invalide.');
      return;
    }
    if (montant > widget.salary.resteAPayer + 1) {
      setState(() => _error = 'Montant supérieur au reste dû (${NumberFormat('#,###','fr_FR').format(widget.salary.resteAPayer)} F).');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.provider.paySalary(
        salary: widget.salary,
        montant: montant,
        mode: _mode,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppTheme.primary : Colors.white12),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: selected ? AppTheme.primary : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  DIALOG FORMULAIRE — Nouvelle fiche / Modifier
// ══════════════════════════════════════════════════════════════════════════════
void _showSalaryFormDialog(
  BuildContext context,
  AppProvider provider, {
  required int annee,
  required int mois,
  required String periodeLabel,
  EmployeeSalary? existing,
}) {
  showDialog(
    context: context,
    builder: (_) => _SalaryFormDialog(
      annee: annee,
      mois: mois,
      periodeLabel: periodeLabel,
      provider: provider,
      existing: existing,
    ),
  );
}

class _SalaryFormDialog extends StatefulWidget {
  final int annee;
  final int mois;
  final String periodeLabel;
  final AppProvider provider;
  final EmployeeSalary? existing;
  const _SalaryFormDialog({
    required this.annee, required this.mois, required this.periodeLabel,
    required this.provider, this.existing,
  });
  @override
  State<_SalaryFormDialog> createState() => _SalaryFormDialogState();
}

class _SalaryFormDialogState extends State<_SalaryFormDialog> {
  AppUser? _selectedEmployee;
  final _matriculeCtrl     = TextEditingController();
  final _baseCtrl          = TextEditingController(text: '0');
  final _heuresSupCtrl     = TextEditingController(text: '0');
  final _primesCtrl        = TextEditingController(text: '0');
  final _indemnitesCtrl    = TextEditingController(text: '0');
  final _cnpsCtrl          = TextEditingController(text: '0');
  final _itsCtrl           = TextEditingController(text: '0');
  final _autresCtrl        = TextEditingController(text: '0');
  final _avancesCtrl       = TextEditingController(text: '0');
  final _commentCtrl       = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _matriculeCtrl.text     = e.matricule;
      _baseCtrl.text          = e.salaryBase.toStringAsFixed(0);
      _heuresSupCtrl.text     = e.heuresSup.toStringAsFixed(0);
      _primesCtrl.text        = e.primes.toStringAsFixed(0);
      _indemnitesCtrl.text    = e.indemnites.toStringAsFixed(0);
      _cnpsCtrl.text          = e.cnps.toStringAsFixed(0);
      _itsCtrl.text           = e.its.toStringAsFixed(0);
      _autresCtrl.text        = e.autresRetenues.toStringAsFixed(0);
      _avancesCtrl.text       = e.avances.toStringAsFixed(0);
      _commentCtrl.text       = e.commentaire;
      _selectedEmployee = widget.provider.users.firstWhere(
        (u) => u.id == e.employeeId,
        orElse: () => AppUser(id: e.employeeId, name: e.employeeName, email: '', phone: '', role: UserRole.server),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [_matriculeCtrl, _baseCtrl, _heuresSupCtrl, _primesCtrl, _indemnitesCtrl, _cnpsCtrl, _itsCtrl, _autresCtrl, _avancesCtrl, _commentCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double _val(TextEditingController c) => double.tryParse(c.text.replaceAll(' ', '').replaceAll(',', '')) ?? 0;

  double get _brut => _val(_baseCtrl) + _val(_heuresSupCtrl) + _val(_primesCtrl) + _val(_indemnitesCtrl);
  double get _retenues => _val(_cnpsCtrl) + _val(_itsCtrl) + _val(_autresCtrl) + _val(_avancesCtrl);
  double get _net => _brut - _retenues;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final employees = widget.provider.users.where((u) => u.isActive).toList();

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              widget.existing == null ? 'Nouvelle fiche de paie — ${widget.periodeLabel}' : 'Modifier la fiche',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 16),

            // Sélection employé
            DropdownButtonFormField<AppUser>(
              value: _selectedEmployee,
              dropdownColor: AppTheme.cardBg,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Employé *',
                prefixIcon: Icon(Icons.person, color: AppTheme.primary, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: employees.map((u) => DropdownMenuItem(
                value: u,
                child: Text(u.name, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() {
                _selectedEmployee = v;
                // Auto-remplir avec le contrat actif si disponible
                final contracts = widget.provider.contracts.where((c) => c.employeeId == v!.id && c.computedStatus == ContractStatus.actif).toList();
                if (contracts.isNotEmpty) {
                  final c = contracts.first;
                  if (_baseCtrl.text == '0') _baseCtrl.text = c.salary.toStringAsFixed(0);
                  _matriculeCtrl.text = c.employeeId.substring(0, 6).toUpperCase();
                }
              }),
            ),
            const SizedBox(height: 8),

            // Matricule
            _FormField(label: 'Matricule', ctrl: _matriculeCtrl, icon: Icons.badge),
            const SizedBox(height: 14),

            // Gains
            _FormSection(title: 'GAINS', color: AppTheme.success),
            const SizedBox(height: 6),
            _FormField(label: 'Salaire de base (F CFA)',       ctrl: _baseCtrl,       icon: Icons.account_balance_wallet, numeric: true, onChanged: () => setState(() {})),
            _FormField(label: 'Heures supplémentaires (F CFA)', ctrl: _heuresSupCtrl, icon: Icons.access_time,            numeric: true, onChanged: () => setState(() {})),
            _FormField(label: 'Primes (F CFA)',                 ctrl: _primesCtrl,    icon: Icons.star_outline,           numeric: true, onChanged: () => setState(() {})),
            _FormField(label: 'Indemnités (F CFA)',             ctrl: _indemnitesCtrl,icon: Icons.card_giftcard,          numeric: true, onChanged: () => setState(() {})),
            const SizedBox(height: 4),
            _CalcPreview(label: 'Salaire Brut', value: fmt.format(_brut), color: AppTheme.success),
            const SizedBox(height: 14),

            // Retenues
            _FormSection(title: 'RETENUES', color: AppTheme.error),
            const SizedBox(height: 6),
            _FormField(label: 'CNPS (F CFA)',            ctrl: _cnpsCtrl,  icon: Icons.health_and_safety, numeric: true, onChanged: () => setState(() {})),
            _FormField(label: 'ITS (F CFA)',             ctrl: _itsCtrl,   icon: Icons.account_balance,   numeric: true, onChanged: () => setState(() {})),
            _FormField(label: 'Autres retenues (F CFA)', ctrl: _autresCtrl,icon: Icons.remove_circle,     numeric: true, onChanged: () => setState(() {})),
            _FormField(label: 'Avances salaire (F CFA)', ctrl: _avancesCtrl,icon: Icons.money_off,        numeric: true, onChanged: () => setState(() {})),
            const SizedBox(height: 4),
            _CalcPreview(label: 'Total Retenues', value: fmt.format(_retenues), color: AppTheme.error),
            const SizedBox(height: 14),

            // Net
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('NET À PAYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  Text('${fmt.format(_net)} F CFA', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Commentaire
            TextField(
              controller: _commentCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                prefixIcon: Icon(Icons.note, color: AppTheme.primary, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
            ],
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  icon: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 16),
                  label: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                  onPressed: _loading ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedEmployee == null) {
      setState(() => _error = 'Sélectionnez un employé.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final emp = _selectedEmployee!;
      if (widget.existing == null) {
        final s = EmployeeSalary(
          id: '',
          employeeId: emp.id,
          employeeName: emp.name,
          poste: widget.provider.contracts
              .where((c) => c.employeeId == emp.id)
              .map((c) => c.poste)
              .firstWhere((_) => true, orElse: () => ''),
          matricule: _matriculeCtrl.text.trim(),
          periode: widget.periodeLabel,
          annee: widget.annee,
          mois: widget.mois,
          salaryBase: _val(_baseCtrl),
          heuresSup: _val(_heuresSupCtrl),
          primes: _val(_primesCtrl),
          indemnites: _val(_indemnitesCtrl),
          cnps: _val(_cnpsCtrl),
          its: _val(_itsCtrl),
          autresRetenues: _val(_autresCtrl),
          avances: _val(_avancesCtrl),
          commentaire: _commentCtrl.text.trim(),
          createdBy: widget.provider.currentUser?.name ?? '',
        );
        await widget.provider.addSalary(s);
      } else {
        final e = widget.existing!;
        e.salaryBase     = _val(_baseCtrl);
        e.heuresSup      = _val(_heuresSupCtrl);
        e.primes         = _val(_primesCtrl);
        e.indemnites     = _val(_indemnitesCtrl);
        e.cnps           = _val(_cnpsCtrl);
        e.its            = _val(_itsCtrl);
        e.autresRetenues = _val(_autresCtrl);
        e.avances        = _val(_avancesCtrl);
        e.commentaire    = _commentCtrl.text.trim();
        await widget.provider.updateSalary(e);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }
}

// ── Widgets formulaire ─────────────────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final String title;
  final Color color;
  const _FormSection({required this.title, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(title, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
  );
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final bool numeric;
  final VoidCallback? onChanged;
  const _FormField({required this.label, required this.ctrl, required this.icon, this.numeric = false, this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: ctrl,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      onChanged: onChanged != null ? (_) => onChanged!() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 17),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    ),
  );
}

class _CalcPreview extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CalcPreview({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        Text('$value F CFA', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
