import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../models/client_models.dart';
import '../../../providers/client_provider.dart';
import '../../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AIDE & SUPPORT CLIENT
// ═══════════════════════════════════════════════════════════════════════════

class ClientSupportScreen extends StatefulWidget {
  const ClientSupportScreen({super.key});

  @override
  State<ClientSupportScreen> createState() => _ClientSupportScreenState();
}

class _ClientSupportScreenState extends State<ClientSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Infos restaurant SANKADIOKRO
  static const _restaurantWhatsApp = '+2250707042947';
  static const _restaurantPhone = '07 07 04 29 47';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientProvider>().startTicketsStream();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Aide & Support',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Contact'),
            Tab(text: 'Mes tickets'),
            Tab(text: 'FAQ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ContactTab(
            whatsApp: _restaurantWhatsApp,
            phone: _restaurantPhone,
            onNewTicket: () => _showNewTicket(context),
          ),
          _TicketsTab(),
          const _FaqTab(),
        ],
      ),
    );
  }

  void _showNewTicket(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _NewTicketSheet(),
    );
  }
}

// ── Tab Contact ───────────────────────────────────────────────────────────────

class _ContactTab extends StatelessWidget {
  final String whatsApp;
  final String phone;
  final VoidCallback onNewTicket;

  const _ContactTab({
    required this.whatsApp,
    required this.phone,
    required this.onNewTicket,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        // Bannière aide rapide
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.support_agent, color: Colors.white, size: 32),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Besoin d\'aide ?',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    SizedBox(height: 4),
                    Text(
                      'Notre équipe est disponible pour vous aider',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ContactButton(
          icon: Icons.chat_rounded,
          color: const Color(0xFF25D366),
          title: 'WhatsApp',
          subtitle: 'Discuter en direct avec le restaurant',
          onTap: () => _launchWhatsApp(context, whatsApp),
        ),
        _ContactButton(
          icon: Icons.phone_outlined,
          color: const Color(0xFF4CAF50),
          title: 'Appeler le restaurant',
          subtitle: phone,
          onTap: () => _callPhone(context, phone),
        ),
        _ContactButton(
          icon: Icons.send_outlined,
          color: AppTheme.primary,
          title: 'Envoyer un message au support',
          subtitle: 'Créer un ticket de support',
          onTap: onNewTicket,
        ),
        const SizedBox(height: 20),
        // Horaires d'ouverture
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A5A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time_outlined,
                      color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Disponibilité du support',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              _HoursRow('Tous les jours', '08h00 – 00h00'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchWhatsApp(BuildContext context, String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$clean?text=Bonjour%2C%20j\'ai%20besoin%20d\'aide%20avec%20ma%20commande.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('WhatsApp non disponible sur cet appareil'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _callPhone(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Appel non disponible sur cet appareil'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _HoursRow extends StatelessWidget {
  final String day, hours;
  const _HoursRow(this.day, this.hours);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          Text(hours,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }
}

// ── Tab Tickets ───────────────────────────────────────────────────────────────

class _TicketsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tickets = context.watch<ClientProvider>().tickets;
    return tickets.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined,
                    color: AppTheme.textSecondary, size: 64),
                const SizedBox(height: 16),
                const Text('Aucun ticket de support',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15)),
                const SizedBox(height: 8),
                const Text('Vos demandes d\'aide apparaîtront ici',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (ctx, i) => _TicketCard(ticket: tickets[i]),
          );
  }
}

class _TicketCard extends StatelessWidget {
  final ClientSupportTicket ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: ticket.status.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ticket.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(ticket.status.label,
                      style: TextStyle(
                          color: ticket.status.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Text(fmt.format(ticket.createdAt),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            Text(ticket.subject,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(ticket.message,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (ticket.adminResponse != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, color: AppTheme.primary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(ticket.adminResponse!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TicketDetailSheet(ticket: ticket),
    );
  }
}

class _TicketDetailSheet extends StatelessWidget {
  final ClientSupportTicket ticket;
  const _TicketDetailSheet({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(ticket.subject,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ticket.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(ticket.status.label,
                    style: TextStyle(
                        color: ticket.status.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(fmt.format(ticket.createdAt),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A5A)),
          const SizedBox(height: 12),
          const Text('Votre message',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(ticket.message,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (ticket.adminResponse != null) ...[
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2A2A5A)),
            const SizedBox(height: 12),
            const Text('Réponse du support',
                style: TextStyle(
                    color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(ticket.adminResponse!,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab FAQ ───────────────────────────────────────────────────────────────────

class _FaqTab extends StatefulWidget {
  const _FaqTab();

  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> {
  int? _expanded;

  static const _faqs = [
    (
      'Comment passer une commande ?',
      'Rendez-vous dans l\'onglet Menu, ajoutez les plats souhaités à votre panier, puis appuyez sur "Voir le panier" pour valider votre commande.'
    ),
    (
      'Quels modes de paiement sont acceptés ?',
      'Nous acceptons le paiement à la livraison, Orange Money, MTN Money, Moov Money, Wave et les cartes bancaires.'
    ),
    (
      'Comment fonctionne le programme fidélité ?',
      'Vous gagnez 1 point pour chaque 100 FCFA dépensés. Ces points peuvent être convertis en réductions sur vos prochaines commandes (1 point = 5 FCFA).'
    ),
    (
      'Puis-je modifier ou annuler une commande ?',
      'Vous pouvez annuler une commande uniquement si son statut est "Reçue". Une fois en préparation, l\'annulation n\'est plus possible. Contactez le support pour toute aide.'
    ),
    (
      'Quels sont les délais de livraison ?',
      'Le délai estimé est de 30 à 45 minutes selon votre localisation. Vous pouvez suivre votre commande en temps réel dans l\'onglet Commandes.'
    ),
    (
      'Comment ajouter une adresse de livraison ?',
      'Dans l\'onglet Profil → Mes Adresses → bouton "+ Ajouter". Vous pouvez enregistrer plusieurs adresses et en définir une par défaut.'
    ),
    (
      'Qu\'est-ce qu\'un acompte ?',
      'Pour certains modes de paiement, un acompte (avance) de 30% est requis pour confirmer votre commande. Le reste est payé à la livraison.'
    ),
    (
      'Comment contacter le restaurant ?',
      'Utilisez les boutons WhatsApp ou Appel dans l\'onglet Contact ci-dessous, ou créez un ticket de support.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _faqs.length,
      itemBuilder: (ctx, i) {
        final isOpen = _expanded == i;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen
                  ? AppTheme.primary.withValues(alpha: 0.4)
                  : const Color(0xFF2A2A5A),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                onTap: () =>
                    setState(() => _expanded = isOpen ? null : i),
                title: Text(_faqs[i].$1,
                    style: TextStyle(
                        color: isOpen ? AppTheme.primary : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                trailing: Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isOpen ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
              if (isOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(_faqs[i].$2,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Nouveau ticket ────────────────────────────────────────────────────────────

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isLoading = false;
  String _category = 'Commande';

  static const _categories = [
    'Commande',
    'Paiement',
    'Livraison',
    'Fidélité',
    'Autre'
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Nouveau ticket de support',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 16),
              // Catégorie
              const Text('Catégorie',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _categories.map((cat) {
                  final isSelected = cat == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF2A2A5A),
                        ),
                      ),
                      child: Text(cat,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subjectCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sujet *',
                  prefixIcon: Icon(Icons.subject_outlined,
                      color: AppTheme.textSecondary),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Sujet requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message *',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 56),
                    child: Icon(Icons.message_outlined,
                        color: AppTheme.textSecondary),
                  ),
                  hintText: 'Décrivez votre problème en détail…',
                ),
                validator: (v) =>
                    v == null || v.length < 10
                        ? 'Message trop court (10 caractères min.)'
                        : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Envoyer le ticket'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ClientProvider>();
      final ticket = ClientSupportTicket(
        id: '',
        clientId: provider.client?.id ?? '',
        clientName: provider.client?.name ?? '',
        subject: '[$_category] ${_subjectCtrl.text.trim()}',
        message: _messageCtrl.text.trim(),
      );
      await provider.createTicket(ticket);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ticket envoyé — nous vous répondrons rapidement'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
