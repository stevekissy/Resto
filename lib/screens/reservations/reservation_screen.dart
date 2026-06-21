// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/print_service.dart';

// ── Formateurs globaux ────────────────────────────────────────────────────
final _fmtNum  = NumberFormat('#,###', 'fr_FR');
final _fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');
final _fmtDateFull = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');

// ════════════════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL RÉSERVATIONS
// ════════════════════════════════════════════════════════════════════════════
class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key});
  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() => setState(() => _tabIndex = _tabCtrl.index));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final alerts   = provider.unreadReservationAlerts;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Réservations & Événements',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          // Cloche alertes
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => _showAlertsPanel(context, provider),
              ),
              if (alerts.isNotEmpty)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${alerts.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Tableau'),
            Tab(icon: Icon(Icons.list_alt_outlined,  size: 18), text: 'Liste'),
            Tab(icon: Icon(Icons.calendar_month,     size: 18), text: 'Calendrier'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Rapports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DashboardTab(provider: provider),
          _ListTab(provider: provider),
          _CalendarTab(provider: provider),
          _ReportsTab(provider: provider),
        ],
      ),
      floatingActionButton: _tabIndex < 2
          ? (MediaQuery.of(context).size.width >= 600
              ? FloatingActionButton.extended(
                  backgroundColor: AppTheme.primary,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle réservation'),
                  onPressed: () => _showReservationForm(context, provider),
                )
              : FloatingActionButton(
                  backgroundColor: AppTheme.primary,
                  onPressed: () => _showReservationForm(context, provider),
                  child: const Icon(Icons.add),
                ))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showAlertsPanel(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AlertsPanel(provider: provider),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TABLEAU DE BORD
// ════════════════════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  final AppProvider provider;
  const _DashboardTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final today     = provider.reservationsToday;
    final aVenir    = provider.reservationsAVenir;
    final confirmees= provider.reservationsConfirmees;
    final attente   = provider.reservationsEnAttente;
    final annulees  = provider.reservationsAnnulees;
    final attendu   = provider.reservationsMontantAttendu;
    final encaisse  = provider.reservationsMontantEncaisse;
    final solde     = provider.reservationsSoldeRestant;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI principal
          GlassCard(
            child: Row(
              children: [
                Expanded(child: _KpiTile(label: "Aujourd'hui", value: today.length.toString(),
                    icon: Icons.today, color: AppTheme.primary)),
                _vDivider(),
                Expanded(child: _KpiTile(label: 'À venir', value: aVenir.length.toString(),
                    icon: Icons.upcoming_outlined, color: AppTheme.warning)),
                _vDivider(),
                Expanded(child: _KpiTile(label: 'Confirmées', value: confirmees.length.toString(),
                    icon: Icons.check_circle_outline, color: AppTheme.success)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            child: Row(
              children: [
                Expanded(child: _KpiTile(label: 'En attente', value: attente.length.toString(),
                    icon: Icons.hourglass_empty, color: AppTheme.warning)),
                _vDivider(),
                Expanded(child: _KpiTile(label: 'Annulées', value: annulees.length.toString(),
                    icon: Icons.cancel_outlined, color: AppTheme.error)),
                _vDivider(),
                Expanded(child: _KpiTile(label: 'Total', value: provider.reservations.length.toString(),
                    icon: Icons.event_note, color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Financier
          SectionHeader(title: 'Finances', icon: Icons.account_balance_wallet_outlined),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _FinCard(label: 'Montant attendu', value: attendu, color: AppTheme.primary)),
            const SizedBox(width: 8),
            Expanded(child: _FinCard(label: 'Déjà encaissé', value: encaisse, color: AppTheme.success)),
          ]),
          const SizedBox(height: 8),
          _FinCard(label: 'Solde restant à encaisser', value: solde, color: AppTheme.error,
              fullWidth: true),
          // Assistant IA
          const SizedBox(height: 16),
          SectionHeader(title: 'Assistant IA', icon: Icons.psychology_outlined),
          const SizedBox(height: 8),
          _IaInsightCard(provider: provider),
          // Réservations du jour
          if (today.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(title: "Événements d'aujourd'hui", icon: Icons.today),
            const SizedBox(height: 8),
            ...today.map((r) => _ReservationCard(
              reservation: r,
              onTap: () => _showReservationDetail(context, r, provider),
            )),
          ],
          // Prochains 7 jours
          const SizedBox(height: 16),
          SectionHeader(title: 'Prochains événements', icon: Icons.upcoming_outlined),
          const SizedBox(height: 8),
          ...aVenir
              .where((r) => r.daysUntil >= 0 && r.daysUntil <= 30)
              .take(5)
              .map((r) => _ReservationCard(
                reservation: r,
                onTap: () => _showReservationDetail(context, r, provider),
              )),
          if (aVenir.where((r) => r.daysUntil >= 0 && r.daysUntil <= 30).isEmpty)
            const EmptyState(icon: Icons.event_available, title: 'Aucun événement dans les 30 prochains jours'),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 50, color: const Color(0xFF2A2A5A));
}

// ════════════════════════════════════════════════════════════════════════════
// LISTE AVEC FILTRES
// ════════════════════════════════════════════════════════════════════════════
class _ListTab extends StatefulWidget {
  final AppProvider provider;
  const _ListTab({required this.provider});
  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  String _filter = 'tous';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Reservation> get _filtered {
    var list = widget.provider.reservations;
    // Filtre temporel / statut
    final now = DateTime.now();
    switch (_filter) {
      case 'auj':      list = list.where((r) => r.isToday).toList(); break;
      case 'semaine':
        final end = now.add(const Duration(days: 7));
        list = list.where((r) => !r.dateEvenement.isBefore(now) && r.dateEvenement.isBefore(end)).toList();
        break;
      case 'mois':
        list = list.where((r) => r.dateEvenement.year == now.year && r.dateEvenement.month == now.month).toList();
        break;
      case 'confirmees': list = list.where((r) => r.status == ReservationStatus.confirme).toList(); break;
      case 'payees':     list = list.where((r) => r.paymentStatus == ReservationPaymentStatus.paye).toList(); break;
      case 'impayes':    list = list.where((r) => r.paymentStatus == ReservationPaymentStatus.nonPaye && r.status != ReservationStatus.annule).toList(); break;
      case 'annulees':   list = list.where((r) => r.status == ReservationStatus.annule).toList(); break;
    }
    // Recherche texte
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
          r.nomClient.toLowerCase().contains(q) ||
          r.telephone.contains(q) ||
          r.typeEvenement.label.toLowerCase().contains(q) ||
          r.salle.toLowerCase().contains(q)).toList();
    }
    // Tri par date événement
    list.sort((a, b) => a.dateEvenement.compareTo(b.dateEvenement));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        // Recherche
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher client, type, salle…',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
              suffixIcon: _search.isNotEmpty ? IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 16),
                onPressed: () { setState(() => _search = ''); _searchCtrl.clear(); },
              ) : null,
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        // Filtres chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _filterChip('tous',       'Tous'),
              _filterChip('auj',        "Aujourd'hui"),
              _filterChip('semaine',    'Cette semaine'),
              _filterChip('mois',       'Ce mois'),
              _filterChip('confirmees', 'Confirmées'),
              _filterChip('payees',     'Payées'),
              _filterChip('impayes',    'Impayées'),
              _filterChip('annulees',   'Annulées'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(icon: Icons.event_busy, title: 'Aucune réservation', subtitle: 'Aucun résultat pour ce filtre')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _ReservationCard(
                    reservation: filtered[i],
                    onTap: () => _showReservationDetail(ctx, filtered[i], widget.provider),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final sel = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primary : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? AppTheme.primary : const Color(0xFF2A2A5A)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CALENDRIER MENSUEL
// ════════════════════════════════════════════════════════════════════════════
class _CalendarTab extends StatefulWidget {
  final AppProvider provider;
  const _CalendarTab({required this.provider});
  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _displayed = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  List<Reservation> _forDay(DateTime d) =>
      widget.provider.reservations.where((r) =>
          r.dateEvenement.year == d.year &&
          r.dateEvenement.month == d.month &&
          r.dateEvenement.day == d.day &&
          r.status != ReservationStatus.annule).toList();

  List<Reservation> get _selectedReservations =>
      _selectedDay != null ? _forDay(_selectedDay!) : [];

  @override
  Widget build(BuildContext context) {
    final firstDay  = DateTime(_displayed.year, _displayed.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_displayed.year, _displayed.month);
    final startWeekday = firstDay.weekday % 7; // 0=dim, 1=lun…

    return Column(
      children: [
        // Navigation mois
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => setState(() =>
                    _displayed = DateTime(_displayed.year, _displayed.month - 1)),
              ),
              Text(
                DateFormat('MMMM yyyy', 'fr_FR').format(_displayed),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => setState(() =>
                    _displayed = DateTime(_displayed.year, _displayed.month + 1)),
              ),
            ],
          ),
        ),
        // En-têtes jours
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'].map((d) =>
                Expanded(child: Center(child: Text(d,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600))))
            ).toList(),
          ),
        ),
        const SizedBox(height: 4),
        // Grille
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startWeekday) return const SizedBox();
              final day = DateTime(_displayed.year, _displayed.month, i - startWeekday + 1);
              final evts = _forDay(day);
              final isToday = day.year == DateTime.now().year &&
                  day.month == DateTime.now().month && day.day == DateTime.now().day;
              final isSelected = _selectedDay != null &&
                  _selectedDay!.year == day.year && _selectedDay!.month == day.month &&
                  _selectedDay!.day == day.day;
              // Couleur dominante des événements du jour
              Color? evtColor;
              if (evts.isNotEmpty) {
                if (evts.any((r) => r.paymentStatus == ReservationPaymentStatus.nonPaye)) {
                  evtColor = AppTheme.error;
                } else if (evts.any((r) => r.paymentStatus == ReservationPaymentStatus.partiel)) {
                  evtColor = AppTheme.warning;
                } else if (evts.any((r) => r.paymentStatus == ReservationPaymentStatus.paye)) {
                  evtColor = AppTheme.success;
                } else {
                  evtColor = AppTheme.primary;
                }
              }
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.3)
                        : isToday ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: AppTheme.primary, width: 1.5) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}', style: TextStyle(
                          color: isSelected || isToday ? Colors.white : AppTheme.textPrimary,
                          fontSize: 12, fontWeight: isToday ? FontWeight.w800 : FontWeight.normal)),
                      if (evtColor != null)
                        Container(width: 6, height: 6,
                            decoration: BoxDecoration(color: evtColor, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Légende
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppTheme.success, label: 'Payé'),
              const SizedBox(width: 12),
              _LegendDot(color: AppTheme.warning, label: 'Partiel'),
              const SizedBox(width: 12),
              _LegendDot(color: AppTheme.error, label: 'Impayé'),
              const SizedBox(width: 12),
              _LegendDot(color: AppTheme.primary, label: 'Confirmé'),
            ],
          ),
        ),
        // Liste événements du jour sélectionné
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              Text(_fmtDateFull.format(_selectedDay!),
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
          Expanded(
            child: _selectedReservations.isEmpty
                ? const Center(child: Text('Aucun événement ce jour',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _selectedReservations.map((r) => _ReservationCard(
                      reservation: r,
                      onTap: () => _showReservationDetail(context, r, widget.provider),
                    )).toList(),
                  ),
          ),
        ] else
          const Expanded(child: Center(child: Text('Sélectionnez un jour pour voir les événements',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RAPPORTS
// ════════════════════════════════════════════════════════════════════════════
class _ReportsTab extends StatelessWidget {
  final AppProvider provider;
  const _ReportsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final all       = provider.reservations;
    final now       = DateTime.now();
    final thisMo    = all.where((r) => r.dateEvenement.year == now.year && r.dateEvenement.month == now.month).toList();
    final thisYear  = all.where((r) => r.dateEvenement.year == now.year).toList();
    final payees    = all.where((r) => r.paymentStatus == ReservationPaymentStatus.paye).toList();
    final impayes   = all.where((r) => r.paymentStatus == ReservationPaymentStatus.nonPaye && r.status != ReservationStatus.annule).toList();

    // CA
    final caMois  = thisMo.fold<double>(0, (s, r) => s + r.montantNet);
    final caAnnee = thisYear.fold<double>(0, (s, r) => s + r.montantNet);
    final encaisse = all.fold<double>(0, (s, r) => s + r.montantPaye);
    final reste    = all.where((r) => r.status != ReservationStatus.annule)
        .fold<double>(0, (s, r) => s + r.soldeRestant);

    // Top types d'événements
    final typeCounts = <EventType, int>{};
    for (final r in all) {
      typeCounts[r.typeEvenement] = (typeCounts[r.typeEvenement] ?? 0) + 1;
    }
    final topTypes = typeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Réservations du mois', icon: Icons.date_range),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: StatCard(title: 'Ce mois', value: '${thisMo.length}',
                icon: Icons.event, color: AppTheme.primary)),
            const SizedBox(width: 8),
            Expanded(child: StatCard(title: 'Cette année', value: '${thisYear.length}',
                icon: Icons.calendar_today, color: AppTheme.warning)),
          ]),
          const SizedBox(height: 16),
          SectionHeader(title: "Chiffre d'affaires réservations", icon: Icons.trending_up),
          const SizedBox(height: 8),
          _ReportRow(label: "CA mois (${DateFormat('MMMM', 'fr_FR').format(now)})",
              value: '${_fmtNum.format(caMois)} F', color: AppTheme.primary),
          _ReportRow(label: 'CA année ${now.year}',
              value: '${_fmtNum.format(caAnnee)} F', color: AppTheme.primary),
          _ReportRow(label: 'Montants encaissés (total)',
              value: '${_fmtNum.format(encaisse)} F', color: AppTheme.success),
          _ReportRow(label: 'Montants restants à encaisser',
              value: '${_fmtNum.format(reste)} F', color: AppTheme.error),
          const SizedBox(height: 16),
          SectionHeader(title: 'Statuts paiements', icon: Icons.payment),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: StatCard(title: 'Payées', value: '${payees.length}',
                icon: Icons.check_circle, color: AppTheme.success)),
            const SizedBox(width: 8),
            Expanded(child: StatCard(title: 'Impayées', value: '${impayes.length}',
                icon: Icons.cancel, color: AppTheme.error)),
          ]),
          const SizedBox(height: 16),
          SectionHeader(title: 'Top types d\'événements', icon: Icons.emoji_events),
          const SizedBox(height: 8),
          if (topTypes.isEmpty)
            const Text('Aucune donnée', style: TextStyle(color: AppTheme.textSecondary))
          else
            ...topTypes.take(5).map((e) => _TopTypeRow(type: e.key, count: e.value, total: all.length)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ASSISTANT IA
// ════════════════════════════════════════════════════════════════════════════
class _IaInsightCard extends StatelessWidget {
  final AppProvider provider;
  const _IaInsightCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final insights = _buildInsights();
    return GlassCard(
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Analyse IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          if (insights.isEmpty)
            const Text('Aucune réservation à analyser pour le moment.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          else
            ...insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900)),
                  Expanded(child: Text(i, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                ],
              ),
            )),
        ],
      ),
    );
  }

  List<String> _buildInsights() {
    final insights = <String>[];
    final all = provider.reservations;
    if (all.isEmpty) return insights;

    final now = DateTime.now();
    // Semaine
    final semaine = all.where((r) =>
        r.dateEvenement.difference(now).inDays >= 0 &&
        r.dateEvenement.difference(now).inDays <= 7 &&
        r.status != ReservationStatus.annule).length;
    if (semaine > 0) insights.add('$semaine événement(s) prévu(s) cette semaine.');

    // Impayés
    final impayes = all.where((r) =>
        r.paymentStatus == ReservationPaymentStatus.nonPaye &&
        r.status != ReservationStatus.annule);
    final totalImpaye = impayes.fold<double>(0, (s, r) => s + r.soldeRestant);
    if (impayes.isNotEmpty) {
      insights.add('${impayes.length} réservation(s) présente(nt) un solde impayé de ${_fmtNum.format(totalImpaye)} F CFA.');
    }

    // Mois prochain
    final moisP = all.where((r) =>
        r.dateEvenement.year == (now.month == 12 ? now.year + 1 : now.year) &&
        r.dateEvenement.month == (now.month == 12 ? 1 : now.month + 1)).length;
    if (moisP > 0) insights.add('Le mois prochain affiche déjà $moisP réservation(s).');

    // Clients réguliers
    final clientCount = <String, int>{};
    for (final r in all) { clientCount[r.nomClient] = (clientCount[r.nomClient] ?? 0) + 1; }
    final reguliers = clientCount.entries.where((e) => e.value >= 2).toList();
    if (reguliers.isNotEmpty) {
      insights.add('${reguliers.length} client(s) régulier(s) identifié(s) (${reguliers.first.key}…).');
    }

    // Top type
    final typeCounts = <EventType, int>{};
    for (final r in all) { typeCounts[r.typeEvenement] = (typeCounts[r.typeEvenement] ?? 0) + 1; }
    if (typeCounts.isNotEmpty) {
      final top = typeCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add('Type d\'événement le plus réservé : ${top.key.label} (${top.value} fois).');
    }

    return insights;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PANNEAU ALERTES
// ════════════════════════════════════════════════════════════════════════════
class _AlertsPanel extends StatelessWidget {
  final AppProvider provider;
  const _AlertsPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    final alerts = provider.reservationAlerts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Alertes réservations',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              if (alerts.any((a) => !a.isRead))
                TextButton(
                  onPressed: () { provider.markAllReservationAlertsRead(); Navigator.pop(context); },
                  child: const Text('Tout lire', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Aucune alerte active', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            SizedBox(
              height: 280,
              child: ListView.builder(
                itemCount: alerts.length,
                itemBuilder: (_, i) {
                  final a = alerts[i];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _alertColor(a.typeAlerte).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_alertIcon(a.typeAlerte), color: _alertColor(a.typeAlerte), size: 16),
                    ),
                    title: Text(a.message, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    subtitle: Text(_fmtDate.format(a.dateAlerte),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    trailing: !a.isRead
                        ? IconButton(
                            icon: const Icon(Icons.check, color: AppTheme.success, size: 16),
                            onPressed: () => provider.markReservationAlertRead(a.id),
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'impaye': return AppTheme.error;
      case 'auj':
      case '24h':    return AppTheme.warning;
      case '3j':     return AppTheme.warning;
      default:       return AppTheme.primary;
    }
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'impaye': return Icons.warning_amber;
      case 'auj':    return Icons.today;
      case '24h':    return Icons.alarm;
      default:       return Icons.notifications;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CARTE RÉSERVATION
// ════════════════════════════════════════════════════════════════════════════
class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onTap;
  const _ReservationCard({required this.reservation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r  = reservation;
    final st = r.status;
    final ps = r.paymentStatus;
    final isComing = r.daysUntil >= 0 && r.daysUntil <= 3;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      border: Border.all(color: st.color.withValues(alpha: 0.25)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: st.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(r.typeEvenement.emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.nomClient, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(r.typeEvenement.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                StatusBadge(label: st.label, color: st.color, fontSize: 9),
                const SizedBox(height: 4),
                StatusBadge(label: ps.label, color: ps.color, fontSize: 9),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 12),
              const SizedBox(width: 4),
              Text(_fmtDate.format(r.dateEvenement),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              if (r.heureDebut.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.access_time, color: AppTheme.textSecondary, size: 12),
                const SizedBox(width: 4),
                Text('${r.heureDebut}${r.heureFin.isNotEmpty ? " – ${r.heureFin}" : ""}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
              const Spacer(),
              const Icon(Icons.people, color: AppTheme.textSecondary, size: 12),
              const SizedBox(width: 4),
              Text('${r.nombrePersonnes} pers.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total : ${_fmtNum.format(r.montantNet)} F',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                if (r.soldeRestant > 0)
                  Text('Reste : ${_fmtNum.format(r.soldeRestant)} F',
                      style: TextStyle(color: ps.color, fontWeight: FontWeight.w700, fontSize: 11)),
              ])),
              if (isComing && r.status != ReservationStatus.annule)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.daysUntil == 0 ? "Aujourd'hui !" :
                    r.daysUntil == 1 ? 'Demain' : 'Dans ${r.daysUntil}j',
                    style: const TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DÉTAIL RÉSERVATION
// ════════════════════════════════════════════════════════════════════════════
void _showReservationDetail(BuildContext context, Reservation r, AppProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cardBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, sc) => _ReservationDetailSheet(
          reservation: r, provider: provider, scrollController: sc),
    ),
  );
}

class _ReservationDetailSheet extends StatelessWidget {
  final Reservation reservation;
  final AppProvider provider;
  final ScrollController scrollController;
  const _ReservationDetailSheet(
      {required this.reservation, required this.provider, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final payments = provider.paymentsForReservation(r.id);

    return Column(
      children: [
        // Poignée
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: const Color(0xFF444466), borderRadius: BorderRadius.circular(2))),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(children: [
                  Text(r.typeEvenement.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.nomClient, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(r.typeEvenement.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ])),
                  Column(children: [
                    StatusBadge(label: r.status.label, color: r.status.color),
                    const SizedBox(height: 4),
                    StatusBadge(label: r.paymentStatus.label, color: r.paymentStatus.color),
                  ]),
                ]),
                const Divider(color: Color(0xFF2A2A5A), height: 24),

                // Infos client
                _SecTitle('Informations client'),
                _InfoRow(Icons.person_outline, 'Nom', r.nomClient),
                _InfoRow(Icons.phone, 'Tél. principal', r.telephone),
                if (r.telephoneSecondaire.isNotEmpty)
                  _InfoRow(Icons.phone_outlined, 'Tél. secondaire', r.telephoneSecondaire),
                if (r.email.isNotEmpty) _InfoRow(Icons.email_outlined, 'Email', r.email),
                if (r.adresse.isNotEmpty) _InfoRow(Icons.location_on_outlined, 'Adresse', r.adresse),

                const Divider(color: Color(0xFF2A2A5A), height: 20),
                // Infos événement
                _SecTitle('Événement'),
                _InfoRow(Icons.calendar_today, 'Date', _fmtDateFull.format(r.dateEvenement)),
                if (r.heureDebut.isNotEmpty) _InfoRow(Icons.access_time, 'Horaires', '${r.heureDebut}${r.heureFin.isNotEmpty ? " – ${r.heureFin}" : ""}'),
                _InfoRow(Icons.people, 'Personnes', '${r.nombrePersonnes}'),
                if (r.salle.isNotEmpty) _InfoRow(Icons.room_outlined, 'Salle', r.salle),
                if (r.responsableCommercial.isNotEmpty)
                  _InfoRow(Icons.badge_outlined, 'Responsable', r.responsableCommercial),
                if (r.description.isNotEmpty) _InfoRow(Icons.notes, 'Description', r.description),

                const Divider(color: Color(0xFF2A2A5A), height: 20),
                // Finances
                _SecTitle('Finances'),
                _InfoRow(Icons.receipt, 'Montant total', '${_fmtNum.format(r.montantTotal)} F CFA'),
                if (r.remise > 0) _InfoRow(Icons.discount, 'Remise', '- ${_fmtNum.format(r.remise)} F CFA'),
                _InfoRow(Icons.price_check, 'Montant net', '${_fmtNum.format(r.montantNet)} F CFA'),
                _InfoRow(Icons.payments, 'Déjà payé', '${_fmtNum.format(r.montantPaye)} F CFA'),
                _InfoRow(Icons.warning_amber, 'Solde restant', '${_fmtNum.format(r.soldeRestant)} F CFA',
                    valueColor: r.soldeRestant > 0 ? AppTheme.error : AppTheme.success),

                // Historique paiements
                const Divider(color: Color(0xFF2A2A5A), height: 20),
                _SecTitle('Historique des paiements'),
                if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucun paiement enregistré',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  )
                else
                  ...payments.map((p) => _PaymentHistoryRow(payment: p)),

                // Actions
                const SizedBox(height: 16),
                _SecTitle('Actions'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (r.paymentStatus != ReservationPaymentStatus.paye)
                    _ActionButton(
                      icon: Icons.payments, label: 'Enregistrer paiement',
                      color: AppTheme.success,
                      onTap: () => _showPaymentDialog(context, r, provider),
                    ),
                  _ActionButton(
                    icon: Icons.edit_outlined, label: 'Modifier',
                    color: AppTheme.primary,
                    onTap: () { Navigator.pop(context); _showReservationForm(context, provider, existing: r); },
                  ),
                  _ActionButton(
                    icon: Icons.description_outlined, label: 'Devis PDF',
                    color: const Color(0xFF7C4DFF),
                    onTap: () => PrintService().printReservationQuote(reservation: r),
                  ),
                  _ActionButton(
                    icon: Icons.article_outlined, label: 'Contrat PDF',
                    color: const Color(0xFF00BCD4),
                    onTap: () => PrintService().printReservationContract(reservation: r),
                  ),
                  if (r.status == ReservationStatus.enAttente)
                    _ActionButton(
                      icon: Icons.check_circle_outline, label: 'Confirmer',
                      color: AppTheme.primary,
                      onTap: () async {
                        await provider.updateReservation(r.copyWith(status: ReservationStatus.confirme));
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  _ActionButton(
                    icon: Icons.cancel_outlined, label: 'Annuler',
                    color: AppTheme.error,
                    onTap: () async {
                      await provider.updateReservation(r.copyWith(status: ReservationStatus.annule));
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DIALOGUE PAIEMENT
// ════════════════════════════════════════════════════════════════════════════
void _showPaymentDialog(BuildContext context, Reservation r, AppProvider provider) {
  showDialog(context: context, builder: (_) => _PaymentDialog(reservation: r, provider: provider));
}

class _PaymentDialog extends StatefulWidget {
  final Reservation reservation;
  final AppProvider provider;
  const _PaymentDialog({required this.reservation, required this.provider});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _montantCtrl = TextEditingController();
  final _obsCtrl     = TextEditingController();
  String _mode       = 'Espèces';
  String _type       = 'complement';
  bool   _loading    = false;

  final _modes  = ['Espèces', 'Mobile Money', 'Virement', 'Chèque', 'Carte bancaire'];
  final _types  = {'acompte': 'Acompte', 'complement': 'Complément', 'final': 'Paiement final', 'autre': 'Autre'};

  @override
  void initState() {
    super.initState();
    _montantCtrl.text = widget.reservation.soldeRestant.toStringAsFixed(0);
  }

  @override
  void dispose() { _montantCtrl.dispose(); _obsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('Enregistrer un paiement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField('Montant (F CFA)', _montantCtrl, isNum: true),
          const SizedBox(height: 12),
          _dialogDropdown('Type de versement', _type, _types.keys.toList(),
              (v) => setState(() => _type = v), labelMap: _types),
          const SizedBox(height: 12),
          _dialogDropdown('Mode de paiement', _mode, _modes,
              (v) => setState(() => _mode = v)),
          const SizedBox(height: 12),
          _dialogField('Observation', _obsCtrl),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Solde actuel :', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text('${_fmtNum.format(widget.reservation.soldeRestant)} F',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Enregistrer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final montant = double.tryParse(_montantCtrl.text.trim()) ?? 0;
    if (montant <= 0) return;
    setState(() => _loading = true);
    try {
      await widget.provider.addReservationPayment(ReservationPayment(
        id: '',
        reservationId: widget.reservation.id,
        nomClient: widget.reservation.nomClient,
        montant: montant,
        modePaiement: _mode,
        date: DateTime.now(),
        observation: _obsCtrl.text.trim(),
        typeVersement: _type,
        caissier: widget.provider.currentUser?.name ?? '',
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FORMULAIRE CRÉATION / ÉDITION
// ════════════════════════════════════════════════════════════════════════════
void _showReservationForm(BuildContext context, AppProvider provider, {Reservation? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cardBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ReservationForm(provider: provider, existing: existing),
    ),
  );
}

class _ReservationForm extends StatefulWidget {
  final AppProvider provider;
  final Reservation? existing;
  const _ReservationForm({required this.provider, this.existing});
  @override
  State<_ReservationForm> createState() => _ReservationFormState();
}

class _ReservationFormState extends State<_ReservationForm> {
  final _form    = GlobalKey<FormState>();
  bool  _loading = false;

  // Contrôleurs
  final _nom      = TextEditingController();
  final _tel      = TextEditingController();
  final _tel2     = TextEditingController();
  final _email    = TextEditingController();
  final _adresse  = TextEditingController();
  final _salle    = TextEditingController();
  final _resp     = TextEditingController();
  final _desc     = TextEditingController();
  final _montant  = TextEditingController();
  final _acompte  = TextEditingController();
  final _remise   = TextEditingController();
  final _nbPerso  = TextEditingController();
  final _hDeb     = TextEditingController();
  final _hFin     = TextEditingController();

  EventType  _type   = EventType.autre;
  ReservationStatus _status = ReservationStatus.enAttente;
  DateTime _dateEvenement    = DateTime.now().add(const Duration(days: 7));
  DateTime _dateReservation  = DateTime.now();

  double get _solde {
    final t = double.tryParse(_montant.text) ?? 0;
    final a = double.tryParse(_acompte.text) ?? 0;
    final r = double.tryParse(_remise.text)  ?? 0;
    return (t - r) - a;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nom.text     = e.nomClient;
      _tel.text     = e.telephone;
      _tel2.text    = e.telephoneSecondaire;
      _email.text   = e.email;
      _adresse.text = e.adresse;
      _salle.text   = e.salle;
      _resp.text    = e.responsableCommercial;
      _desc.text    = e.description;
      _montant.text = e.montantTotal.toStringAsFixed(0);
      _acompte.text = e.acompteVerse.toStringAsFixed(0);
      _remise.text  = e.remise.toStringAsFixed(0);
      _nbPerso.text = e.nombrePersonnes.toString();
      _hDeb.text    = e.heureDebut;
      _hFin.text    = e.heureFin;
      _type         = e.typeEvenement;
      _status       = e.status;
      _dateEvenement   = e.dateEvenement;
      _dateReservation = e.dateReservation;
    }
    _montant.addListener(() => setState(() {}));
    _acompte.addListener(() => setState(() {}));
    _remise.addListener(()  => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_nom, _tel, _tel2, _email, _adresse, _salle, _resp, _desc,
        _montant, _acompte, _remise, _nbPerso, _hDeb, _hFin]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: const Color(0xFF444466), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isEdit ? 'Modifier la réservation' : 'Nouvelle réservation',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Client
                _FormSec('Informations client'),
                _tf('Nom complet *', _nom, required: true),
                _tf('Téléphone principal *', _tel, required: true, keyboardType: TextInputType.phone),
                _tf('Téléphone secondaire', _tel2, keyboardType: TextInputType.phone),
                _tf('Email', _email, keyboardType: TextInputType.emailAddress),
                _tf('Adresse', _adresse),

                // Événement
                _FormSec('Informations événement'),
                // Type
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<EventType>(
                    value: _type,
                    dropdownColor: AppTheme.cardBg,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDeco('Type d\'événement *'),
                    items: EventType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text('${t.emoji} ${t.label}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
                // Dates
                Row(children: [
                  Expanded(child: _DateField(label: 'Date réservation', date: _dateReservation,
                      onPick: (d) => setState(() => _dateReservation = d))),
                  const SizedBox(width: 8),
                  Expanded(child: _DateField(label: 'Date événement *', date: _dateEvenement,
                      onPick: (d) => setState(() => _dateEvenement = d))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _tf('Heure début', _hDeb, hint: '09:00')),
                  const SizedBox(width: 8),
                  Expanded(child: _tf('Heure fin', _hFin, hint: '22:00')),
                ]),
                _tf('Nb. de personnes', _nbPerso, keyboardType: TextInputType.number, hint: '50'),
                _tf('Salle / espace réservé', _salle),
                _tf('Responsable commercial', _resp),
                _tf('Description / remarques', _desc, maxLines: 2),

                // Statut
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<ReservationStatus>(
                    value: _status,
                    dropdownColor: AppTheme.cardBg,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDeco('Statut'),
                    items: ReservationStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label),
                    )).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),

                // Montants
                _FormSec('Montants'),
                _tf('Montant total devis *', _montant, required: true, keyboardType: TextInputType.number, hint: '0'),
                _tf('Acompte versé', _acompte, keyboardType: TextInputType.number, hint: '0'),
                _tf('Remise éventuelle', _remise, keyboardType: TextInputType.number, hint: '0'),

                // Aperçu solde
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Solde restant :', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Text('${_fmtNum.format(_solde.clamp(0, double.infinity))} F CFA',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'Enregistrer les modifications' : 'Créer la réservation',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = Reservation(
        id:                    widget.existing?.id ?? '',
        nomClient:             _nom.text.trim(),
        telephone:             _tel.text.trim(),
        telephoneSecondaire:   _tel2.text.trim(),
        email:                 _email.text.trim(),
        adresse:               _adresse.text.trim(),
        typeEvenement:         _type,
        dateReservation:       _dateReservation,
        dateEvenement:         _dateEvenement,
        heureDebut:            _hDeb.text.trim(),
        heureFin:              _hFin.text.trim(),
        nombrePersonnes:       int.tryParse(_nbPerso.text.trim()) ?? 1,
        salle:                 _salle.text.trim(),
        responsableCommercial: _resp.text.trim(),
        description:           _desc.text.trim(),
        montantTotal:          double.tryParse(_montant.text.trim()) ?? 0,
        acompteVerse:          double.tryParse(_acompte.text.trim()) ?? 0,
        remise:                double.tryParse(_remise.text.trim()) ?? 0,
        status:                _status,
        paymentStatus:         widget.existing?.paymentStatus ?? ReservationPaymentStatus.nonPaye,
        montantPaye:           widget.existing?.montantPaye ?? 0,
        createdBy:             widget.provider.currentUser?.name ?? '',
      );
      if (widget.existing != null) {
        await widget.provider.updateReservation(res);
      } else {
        await widget.provider.addReservation(res);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Widget _tf(String label, TextEditingController ctrl,
      {bool required = false, TextInputType keyboardType = TextInputType.text,
       int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: _inputDeco(label, hint: hint),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null : null,
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
    filled: true,
    fillColor: AppTheme.surfaceLight,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS HELPERS
// ════════════════════════════════════════════════════════════════════════════

class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiTile({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
          textAlign: TextAlign.center),
    ]),
  );
}

class _FinCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool fullWidth;
  const _FinCard({required this.label, required this.value, required this.color, this.fullWidth = false});
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      const SizedBox(height: 4),
      Text('${_fmtNum.format(value)} F CFA',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: fullWidth ? 18 : 15)),
    ]),
  );
}

class _SecTitle extends StatelessWidget {
  final String title;
  const _SecTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, color: AppTheme.textSecondary, size: 14),
      const SizedBox(width: 8),
      SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
      Expanded(child: Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _PaymentHistoryRow extends StatelessWidget {
  final ReservationPayment payment;
  const _PaymentHistoryRow({required this.payment});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppTheme.success.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle, color: AppTheme.success, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_fmtNum.format(payment.montant)} F CFA',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        Text('${payment.modePaiement} · ${_fmtDate.format(payment.date)} · ${payment.caissier}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ])),
      StatusBadge(label: payment.typeVersement, color: AppTheme.primary, fontSize: 9),
    ]),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _FormSec extends StatelessWidget {
  final String title;
  const _FormSec(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    ]),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateField({required this.label, required this.date, required this.onPick});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppTheme.primary),
          ),
          child: child!,
        ),
      );
      if (picked != null) onPick(picked);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today, color: AppTheme.primary, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          Text(_fmtDate.format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ])),
      ]),
    ),
  );
}

class _ReportRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ReportRow({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
    ]),
  );
}

class _TopTypeRow extends StatelessWidget {
  final EventType type;
  final int count, total;
  const _TopTypeRow({required this.type, required this.count, required this.total});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Row(children: [
          Text(type.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(type.label, style: const TextStyle(color: Colors.white, fontSize: 12))),
          Text('$count réservation(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFF2A2A5A),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
  ]);
}

// Helpers dialogues
Widget _dialogField(String label, TextEditingController ctrl, {bool isNum = false}) =>
    TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

Widget _dialogDropdown(String label, String value, List<String> items, ValueChanged<String> onChange,
    {Map<String, String>? labelMap}) =>
    DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppTheme.cardBg,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.map((i) => DropdownMenuItem(
        value: i, child: Text(labelMap?[i] ?? i),
      )).toList(),
      onChanged: (v) { if (v != null) onChange(v); },
    );
