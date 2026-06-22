import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../providers/client_provider.dart';
import '../../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// À PROPOS — Restaurant Sankadiokro
// ═══════════════════════════════════════════════════════════════════════════

class ClientAboutScreen extends StatefulWidget {
  const ClientAboutScreen({super.key});

  @override
  State<ClientAboutScreen> createState() => _ClientAboutScreenState();
}

class _ClientAboutScreenState extends State<ClientAboutScreen> {
  String _version = '…';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      setState(() => _version = '1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ClientProvider>().settings;

    final phone = settings.restaurantPhone.isNotEmpty
        ? settings.restaurantPhone
        : '07 07 04 29 47';
    final address = settings.restaurantAddress.isNotEmpty
        ? settings.restaurantAddress
        : 'Yopougon Millionnaire, Abidjan';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('À propos',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête restaurant
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1A1A2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Center(
                    child: Text('🍽️', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Restaurant Sankadiokro',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'La cuisine ivoirienne authentique à votre porte',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Description
          _InfoCard(
            title: 'Notre restaurant',
            content:
                'Restaurant Sankadiokro est un établissement spécialisé dans la cuisine ivoirienne traditionnelle. '
                'Nous proposons des plats locaux authentiques préparés avec des produits frais, '
                'des commandes en ligne avec livraison à domicile et un service traiteur.',
          ),
          const SizedBox(height: 16),

          // Infos pratiques
          _SectionTitle(icon: Icons.info_outline, title: 'Informations pratiques'),
          const SizedBox(height: 12),

          _InfoRow(
            icon: Icons.location_on_outlined,
            color: AppTheme.error,
            label: 'Adresse',
            value: address,
            onTap: () => _openMaps(address),
          ),
          _InfoRow(
            icon: Icons.phone_outlined,
            color: const Color(0xFF4CAF50),
            label: 'Téléphone',
            value: phone,
            onTap: () => _callPhone(phone),
          ),
          _InfoRow(
            icon: Icons.email_outlined,
            color: AppTheme.primary,
            label: 'Email',
            value: 'restaurantsankadiokro@gmail.com',
            onTap: () => _sendEmail('restaurantsankadiokro@gmail.com'),
          ),
          const SizedBox(height: 20),

          // Horaires
          _SectionTitle(icon: Icons.access_time_outlined, title: 'Horaires d\'ouverture'),
          const SizedBox(height: 12),
          _HoursCard(settings: settings),
          const SizedBox(height: 20),

          // Version app
          _SectionTitle(icon: Icons.smartphone_outlined, title: 'Application'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A5A)),
            ),
            child: Column(
              children: [
                _AppInfoRow('Version', _buildNumber.isNotEmpty
                    ? '$_version (build $_buildNumber)'
                    : _version),
                const Divider(height: 16, color: Color(0xFF2A2A5A)),
                _AppInfoRow('Plateforme', Theme.of(context).platform == TargetPlatform.iOS
                    ? 'iOS'
                    : Theme.of(context).platform == TargetPlatform.android
                        ? 'Android'
                        : 'Web'),
                const Divider(height: 16, color: Color(0xFF2A2A5A)),
                _AppInfoRow('Développeur', 'Sankadiokro Digital'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Liens légaux
          _LegalButton(
            label: 'Conditions d\'utilisation',
            onTap: () => _showLegal(context, 'Conditions d\'utilisation', _termsContent),
          ),
          _LegalButton(
            label: 'Politique de confidentialité',
            onTap: () => _showLegal(context, 'Confidentialité', _privacyContent),
          ),
          const SizedBox(height: 40),

          // Copyright
          const Center(
            child: Text(
              '© 2024 Restaurant Sankadiokro\nTous droits réservés',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _openMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://maps.google.com/?q=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showLegal(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
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
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
            const SizedBox(height: 16),
            Text(content,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.6)),
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
      ),
    );
  }

  static const _termsContent = '''
Les présentes conditions régissent l\'utilisation de l\'application mobile Restaurant Sankadiokro.

1. COMMANDES
Toute commande passée via l\'application est soumise à la disponibilité des produits et à la zone de livraison. Le restaurant se réserve le droit d\'annuler une commande en cas d\'indisponibilité.

2. PAIEMENTS
Les acomptes versés sont non remboursables en cas d\'annulation par le client. En cas d\'annulation par le restaurant, le remboursement intégral sera effectué.

3. LIVRAISON
Les délais de livraison sont indicatifs et peuvent varier selon les conditions météorologiques et la distance.

4. PROGRAMME FIDÉLITÉ
Les points de fidélité sont crédités après livraison confirmée. Ils ne sont pas échangeables contre de l\'argent.

5. DONNÉES PERSONNELLES
Vos données sont utilisées uniquement pour la gestion de vos commandes et ne sont pas partagées avec des tiers.
''';

  static const _privacyContent = '''
Restaurant Sankadiokro s\'engage à protéger vos données personnelles.

DONNÉES COLLECTÉES
- Nom, prénom, email, téléphone
- Adresses de livraison
- Historique des commandes
- Points de fidélité

UTILISATION
Ces données sont utilisées pour :
- Traiter vos commandes
- Vous contacter concernant vos commandes
- Améliorer nos services
- Vous envoyer des promotions (avec votre accord)

CONSERVATION
Vos données sont conservées aussi longtemps que votre compte est actif. Vous pouvez demander leur suppression à tout moment.

DROITS
Vous avez le droit d\'accéder, de corriger ou de supprimer vos données en contactant notre support.

CONTACT
Pour toute question : restaurantsankadiokro@gmail.com
''';
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title, content;
  const _InfoCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
        subtitle: Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.open_in_new,
            color: AppTheme.textSecondary, size: 16),
      ),
    );
  }
}

class _HoursCard extends StatelessWidget {
  final dynamic settings;
  const _HoursCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        children: [
          _HRow('Tous les jours', '08h00 – 00h00'),
        ],
      ),
    );
  }
}

class _HRow extends StatelessWidget {
  final String day, hours;
  const _HRow(this.day, this.hours);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          Text(hours,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  final String label, value;
  const _AppInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }
}

class _LegalButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        tileColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.article_outlined, color: AppTheme.textSecondary, size: 18),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }
}
