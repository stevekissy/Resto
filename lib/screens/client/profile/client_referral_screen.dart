import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/client_provider.dart';
import '../../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ÉCRAN PARRAINAGE CLIENT — Système de parrainage SANKADIOKRO
//
// Fonctionnalités :
//   1. Afficher le code parrainage unique du client (SKR-XXXXXX)
//   2. Saisir le code d'un parrain (lors de la première commande)
//   3. Voir les avantages du programme
//   4. Copier / Partager le code
// ═══════════════════════════════════════════════════════════════════════════

class ClientReferralScreen extends StatefulWidget {
  const ClientReferralScreen({super.key});

  @override
  State<ClientReferralScreen> createState() => _ClientReferralScreenState();
}

class _ClientReferralScreenState extends State<ClientReferralScreen> {
  bool _loadingCode = false;
  bool _applyingCode = false;
  String? _myReferralCode;
  final _referralCodeCtrl = TextEditingController();
  String? _applyError;
  String? _applySuccess;

  @override
  void initState() {
    super.initState();
    _loadMyCode();
  }

  @override
  void dispose() {
    _referralCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyCode() async {
    final prov = context.read<ClientProvider>();
    // Si déjà dans le profil
    final existing = prov.client?.referralCode;
    if (existing != null && existing.isNotEmpty) {
      setState(() => _myReferralCode = existing);
      return;
    }
    // Sinon, initialiser
    setState(() => _loadingCode = true);
    try {
      final code = await prov.initReferralCode();
      if (mounted) setState(() => _myReferralCode = code);
    } catch (e) {
      if (mounted) setState(() => _myReferralCode = null);
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  Future<void> _applyReferralCode() async {
    final code = _referralCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _applyError = 'Veuillez entrer un code de parrainage');
      return;
    }
    if (code == _myReferralCode) {
      setState(() => _applyError = 'Vous ne pouvez pas utiliser votre propre code');
      return;
    }

    setState(() {
      _applyingCode = true;
      _applyError = null;
      _applySuccess = null;
    });

    try {
      final prov = context.read<ClientProvider>();
      // Vérifier d'abord que le code existe
      final referrerInfo = await prov.checkReferralCode(code);
      if (referrerInfo == null) {
        setState(() => _applyError = 'Code de parrainage invalide ou inexistant');
        return;
      }

      final error = await prov.applyReferralCode(code);
      if (error != null) {
        setState(() => _applyError = error);
      } else {
        setState(() {
          _applySuccess = 'Code appliqué ! Vous êtes maintenant parrainé par ${referrerInfo['name']}. '
              'Passez votre première commande pour débloquer vos bonus !';
          _referralCodeCtrl.clear();
        });
      }
    } catch (e) {
      setState(() => _applyError = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _applyingCode = false);
    }
  }

  void _copyCode() {
    if (_myReferralCode == null) return;
    Clipboard.setData(ClipboardData(text: _myReferralCode!));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Code copié dans le presse-papier !'),
      ]),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClientProvider>();
    final client = prov.client;
    final alreadyReferred = client?.referredBy != null && (client?.referredBy?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Parrainage',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hero : présentation du programme ────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.3),
                    const Color(0xFF6A00F4).withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Programme de Parrainage',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invitez vos amis et gagnez des points fidélité ensemble !',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Avantages ────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.stars_rounded,
              title: 'Vos avantages',
              child: Column(
                children: [
                  _BenefitRow(
                    icon: '🎯',
                    title: 'Vous (parrain)',
                    subtitle: '+50 points fidélité dès que votre filleul passe sa première commande payée',
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 12),
                  _BenefitRow(
                    icon: '🎁',
                    title: 'Votre filleul',
                    subtitle: '+30 points fidélité après sa première commande payée et livrée',
                    color: AppTheme.success,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text('💡', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '1 point = 5 FCFA de réduction\n50 points = 250 FCFA offerts !',
                            style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Mon code parrainage ──────────────────────────────────────
            _SectionCard(
              icon: Icons.qr_code_rounded,
              title: 'Mon code de parrainage',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Partagez ce code avec vos amis pour qu\'ils puissent vous parrainer :',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingCode)
                    const Center(child: CircularProgressIndicator())
                  else if (_myReferralCode == null)
                    ElevatedButton.icon(
                      onPressed: _loadMyCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Générer mon code'),
                    )
                  else
                    GestureDetector(
                      onTap: _copyCode,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6), width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _myReferralCode!,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.copy, color: AppTheme.primary, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_myReferralCode != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Appuyez pour copier le code',
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Appliquer un code parrainage ─────────────────────────────
            if (!alreadyReferred) ...[
              _SectionCard(
                icon: Icons.card_giftcard,
                title: 'Entrer un code de parrainage',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vous avez été invité ? Entrez le code de votre parrain pour bénéficier du bonus après votre première commande :',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _referralCodeCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'SKR-XXXXXX',
                              hintStyle: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                letterSpacing: 2,
                              ),
                              prefixIcon: const Icon(Icons.code, color: AppTheme.primary, size: 18),
                              filled: true,
                              fillColor: AppTheme.cardBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF2A2A5A)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.6)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => setState(() {
                              _applyError = null;
                              _applySuccess = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _applyingCode
                            ? const SizedBox(
                                width: 44, height: 44,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : ElevatedButton(
                                onPressed: _applyReferralCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text(
                                  'Valider',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                      ],
                    ),
                    if (_applyError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.error, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _applyError!,
                                style: const TextStyle(color: AppTheme.error, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_applySuccess != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _applySuccess!,
                                style: const TextStyle(color: AppTheme.success, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Déjà parrainé — afficher le statut
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppTheme.success, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vous êtes parrainé ! ✓',
                            style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Passez votre première commande payée pour débloquer vos 30 points bonus.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Comment ça marche ────────────────────────────────────────
            _SectionCard(
              icon: Icons.help_outline,
              title: 'Comment ça marche ?',
              child: Column(
                children: [
                  _StepRow(
                    step: '1',
                    text: 'Partagez votre code de parrainage avec un ami',
                    color: AppTheme.primary,
                  ),
                  _StepRow(
                    step: '2',
                    text: 'Votre ami entre votre code lors de son inscription',
                    color: AppTheme.primary,
                  ),
                  _StepRow(
                    step: '3',
                    text: 'Il passe et paie sa première commande',
                    color: AppTheme.primary,
                  ),
                  _StepRow(
                    step: '4',
                    text: 'Vous recevez 50 points, lui 30 points automatiquement',
                    color: Colors.amber,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String icon, title, subtitle;
  final Color color;
  const _BenefitRow({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step, text;
  final Color color;
  final bool isLast;
  const _StepRow({required this.step, required this.text, required this.color, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Center(
              child: Text(step, style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: TextStyle(
                  color: isLast ? Colors.amber : Colors.white,
                  fontSize: 12,
                  fontWeight: isLast ? FontWeight.w700 : FontWeight.w400,
                  height: 1.3)),
            ),
          ),
        ],
      ),
    );
  }
}
