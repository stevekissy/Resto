// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/client_models.dart';
import '../../../providers/client_provider.dart';
import '../../../services/client_firebase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import '../client_main_screen.dart';
import '../../login_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ÉCRAN AUTH CLIENT — Inscription, Connexion, Mot de passe oublié
// ═══════════════════════════════════════════════════════════════════════════

class ClientAuthScreen extends StatefulWidget {
  /// Affiche le bouton discret "Accès gestion" en bas de l'écran.
  /// Activé uniquement quand l'app est ouverte sans session (accueil principal).
  final bool showManagementButton;
  const ClientAuthScreen({
    super.key,
    this.showManagementButton = false,
  });

  @override
  State<ClientAuthScreen> createState() => _ClientAuthScreenState();
}

enum _AuthMode { login, register, forgotPassword }

class _ClientAuthScreenState extends State<ClientAuthScreen>
    with TickerProviderStateMixin {
  _AuthMode _mode = _AuthMode.login;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _referralCtrl = TextEditingController();

  // null = non vérifié, true = valide, false = invalide
  bool? _referralValid;
  bool  _referralChecking = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      // Réinitialiser l'état parrainage à chaque changement de mode
      _referralValid    = null;
      _referralChecking = false;
    });
    _referralCtrl.clear();
    _animCtrl.reset();
    _animCtrl.forward();
  }

  // ── Connexion ─────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final svc = ClientFirebaseService();
      final cred = await svc.loginWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final uid = cred.user!.uid;
      // Vérifier que c'est bien un client (pas un staff)
      final clientProfile = await svc.getClientProfile(uid);
      if (clientProfile == null) {
        await svc.signOut();
        _showError('Aucun compte client trouvé pour cet email.\nSi vous êtes un employé, utilisez l\'application de gestion.');
        return;
      }
      if (!clientProfile.isActive) {
        await svc.signOut();
        _showError('Votre compte a été désactivé. Contactez le restaurant.');
        return;
      }
      // Charger le provider
      if (mounted) {
        final provider = context.read<ClientProvider>();
        await provider.init(uid);
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const ClientMainScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } catch (e) {
      _showError('Erreur de connexion. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Inscription ──────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // ── Vérification code parrainage avant inscription ────────────────────
    final referralCode = _referralCtrl.text.trim().toUpperCase();
    if (referralCode.isNotEmpty) {
      // Si le code a été tapé mais invalide → bloquer
      if (_referralValid == false) {
        _showError('Code parrainage invalide. Vérifiez le code ou laissez le champ vide.');
        return;
      }
      // Si encore en cours de vérification → attendre
      if (_referralChecking || _referralValid == null) {
        setState(() => _isLoading = true);
        try {
          final svc    = ClientFirebaseService();
          final result = await svc.checkReferralCode(referralCode);
          if (!mounted) return;
          if (result == null) {
            setState(() => _isLoading = false);
            _showError('Code parrainage invalide. Vérifiez le code ou laissez le champ vide.');
            return;
          }
        } catch (_) {
          if (mounted) setState(() => _isLoading = false);
          _showError('Impossible de vérifier le code. Réessayez.');
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      final svc  = ClientFirebaseService();
      final cred = await svc.registerWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final uid = cred.user!.uid;

      // Créer le profil client dans Firestore
      final client = ClientUser(
        id:    uid,
        name:  _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      await svc.createClientProfile(client);

      // ── Appliquer le code parrainage si présent et valide ───────────────
      if (referralCode.isNotEmpty && _referralValid == true) {
        final errMsg = await svc.applyReferralCode(
          newClientId:  uid,
          referralCode: referralCode,
        );
        if (errMsg != null) {
          // Ne bloque pas l'inscription — juste un avertissement
          debugPrint('[register] Parrainage non appliqué: $errMsg');
        } else {
          // Écrire aussi referralCodeUsed dans le profil client
          await svc.updateClientProfile(uid, {
            'referralCodeUsed': referralCode,
            'referredBy':       await _getReferrerId(svc, referralCode),
            'createdAt':        DateTime.now().millisecondsSinceEpoch,
          });
          debugPrint('[register] ✅ Parrainage appliqué: $referralCode → $uid');
        }
      }

      // Initialiser le code de parrainage propre pour ce nouveau client
      await svc.initReferralCode(uid);

      if (mounted) {
        final provider = context.read<ClientProvider>();
        await provider.init(uid);
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const ClientMainScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } catch (e) {
      _showError('Erreur lors de l\'inscription. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Récupère l'ID du parrain depuis son code parrainage
  Future<String> _getReferrerId(ClientFirebaseService svc, String code) async {
    try {
      final result = await svc.checkReferralCode(code);
      return result?['id'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  // ── Mot de passe oublié ──────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Entrez votre email.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ClientFirebaseService().sendPasswordResetEmail(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de réinitialisation envoyé !'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        _switchMode(_AuthMode.login);
      }
    } catch (_) {
      _showError('Impossible d\'envoyer l\'email. Vérifiez votre adresse.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error, duration: const Duration(seconds: 4)),
    );
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':       return 'Aucun compte avec cet email.';
      case 'wrong-password':       return 'Mot de passe incorrect.';
      case 'email-already-in-use': return 'Cet email est déjà utilisé.';
      case 'weak-password':        return 'Mot de passe trop faible (6 caractères min).';
      case 'invalid-email':        return 'Adresse email invalide.';
      case 'too-many-requests':    return 'Trop de tentatives. Attendez un moment.';
      case 'invalid-credential':   return 'Email ou mot de passe incorrect.';
      default:                     return 'Erreur d\'authentification. Réessayez.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── Bouton discret "Accès gestion" en bas (accueil sans session) ──
      bottomNavigationBar: widget.showManagementButton
          ? _ManagementAccessButton()
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1), // haut : bleu
              Color(0xFF061428), // milieu : bleu foncé
              Color(0xFF0A0A0A), // bas : noir
            ],
            stops: [0.0, 0.40, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Bouton Retour (masqué quand showManagementButton,
                    //    car c'est l'écran racine — rien à pop) ───────────
                    if (!widget.showManagementButton)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, color: Colors.white70, size: 14),
                              SizedBox(width: 6),
                              Text('Accès gestion',
                                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Logo
                    _buildLogo(),
                    const SizedBox(height: 40),
                    // Card formulaire
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTitle(),
                            const SizedBox(height: 24),
                            _buildFields(),
                            const SizedBox(height: 24),
                            _buildSubmitButton(),
                            const SizedBox(height: 16),
                            _buildLinks(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ── Pied de page ───────────────────────────────────
                    _buildFooter(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Version 1.0.0  ©  2025  Restaurant Sankadiokro',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          'Yopougon Millionnaire  •  Abidjan, Côte d\'Ivoire',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.22),
            fontSize: 10,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // ── Vrai logo PNG du restaurant (coins arrondis, même taille) ──
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/logo_sankadiokro.png',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SankaLogo(size: 80),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('SANKADIOKRO', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
        const SizedBox(height: 4),
        Text(
          _mode == _AuthMode.register ? 'Créez votre compte' : 'Commander en ligne',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    final titles = {
      _AuthMode.login: ('Connexion', Icons.login),
      _AuthMode.register: ('Inscription', Icons.person_add),
      _AuthMode.forgotPassword: ('Mot de passe oublié', Icons.lock_reset),
    };
    final (title, icon) = titles[_mode]!;
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        if (_mode == _AuthMode.register) ...[
          _ClientTextField(
            controller: _nameCtrl,
            label: 'Nom complet *',
            icon: Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Entrez votre nom' : null,
          ),
          const SizedBox(height: 14),
          _ClientTextField(
            controller: _phoneCtrl,
            label: 'Téléphone *',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Entrez votre numéro' : null,
          ),
          const SizedBox(height: 14),
        ],
        _ClientTextField(
          controller: _emailCtrl,
          label: 'Email *',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Entrez votre email';
            if (!v.contains('@')) return 'Email invalide';
            return null;
          },
        ),
        if (_mode != _AuthMode.forgotPassword) ...[
          const SizedBox(height: 14),
          _ClientTextField(
            controller: _passCtrl,
            label: 'Mot de passe *',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) => (v == null || v.length < 6) ? '6 caractères minimum' : null,
          ),
        ],
        if (_mode == _AuthMode.register) ...[
          const SizedBox(height: 14),
          _ClientTextField(
            controller: _confirmCtrl,
            label: 'Confirmer le mot de passe *',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary, size: 20),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) => v != _passCtrl.text ? 'Les mots de passe ne correspondent pas' : null,
          ),
          const SizedBox(height: 14),
          // ── Champ code parrainage ─────────────────────────────────────
          _ReferralField(
            controller: _referralCtrl,
            isValid: _referralValid,
            isChecking: _referralChecking,
            onChanged: _onReferralChanged,
          ),
        ],
      ],
    );
  }

  // ── Vérification live du code parrainage ──────────────────────────────
  Future<void> _onReferralChanged(String value) async {
    final code = value.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() { _referralValid = null; _referralChecking = false; });
      return;
    }
    // Attendre que le code ait au moins 6 caractères (format SKR-XXXXXX = 10)
    if (code.length < 4) {
      setState(() { _referralValid = null; _referralChecking = false; });
      return;
    }
    setState(() => _referralChecking = true);
    try {
      final svc    = ClientFirebaseService();
      final result = await svc.checkReferralCode(code);
      if (!mounted) return;
      setState(() {
        _referralValid    = result != null;
        _referralChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _referralValid = null; _referralChecking = false; });
    }
  }

  Widget _buildSubmitButton() {
    final labels = {
      _AuthMode.login: 'Se connecter',
      _AuthMode.register: 'Créer mon compte',
      _AuthMode.forgotPassword: 'Envoyer le lien',
    };
    final actions = {
      _AuthMode.login: _login,
      _AuthMode.register: _register,
      _AuthMode.forgotPassword: _resetPassword,
    };
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isLoading ? null : actions[_mode],
        child: _isLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(labels[_mode]!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _buildLinks() {
    return Column(
      children: [
        if (_mode == _AuthMode.login) ...[
          TextButton(
            onPressed: () => _switchMode(_AuthMode.forgotPassword),
            child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Pas encore de compte ?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              TextButton(
                onPressed: () => _switchMode(_AuthMode.register),
                child: const Text('S\'inscrire', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ] else if (_mode == _AuthMode.register) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Déjà un compte ?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              TextButton(
                onPressed: () => _switchMode(_AuthMode.login),
                child: const Text('Se connecter', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ] else ...[
          TextButton(
            onPressed: () => _switchMode(_AuthMode.login),
            child: const Text('← Retour à la connexion', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON DISCRET « ACCÈS GESTION »
// Affiché en bas de ClientAuthScreen quand showManagementButton = true.
// Ouvre LoginScreen sans perturber le flux client.
// ─────────────────────────────────────────────────────────────────────────────
class _ManagementAccessButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginScreen(fromClientSpace: true),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 6),
                Text(
                  'Accès gestion',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget champ code parrainage ─────────────────────────────────────────────
// Affiche un indicateur visuel selon l'état de validation :
//   • spinner  → vérification en cours
//   • ✓ vert   → code valide
//   • ✗ rouge  → code invalide

class _ReferralField extends StatelessWidget {
  final TextEditingController controller;
  final bool? isValid;       // null=non vérifié, true=ok, false=invalide
  final bool  isChecking;
  final void Function(String) onChanged;

  const _ReferralField({
    required this.controller,
    required this.isValid,
    required this.isChecking,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Couleur de la bordure selon l'état
    Color borderColor;
    if (isValid == true)       { borderColor = const Color(0xFF4CAF50); }  // vert
    else if (isValid == false) { borderColor = AppTheme.error; }           // rouge
    else                       { borderColor = const Color(0xFF2A2A5A); }  // défaut

    // Icône de suffixe
    Widget? suffix;
    if (isChecking) {
      suffix = const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
        ),
      );
    } else if (isValid == true) {
      suffix = const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 20);
    } else if (isValid == false) {
      suffix = Icon(Icons.cancel_outlined, color: AppTheme.error, size: 20);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.2),
          onChanged: onChanged,
          // Pas de validator obligatoire — champ optionnel
          decoration: InputDecoration(
            labelText: 'Code parrainage (optionnel)',
            prefixIcon: Icon(Icons.card_giftcard_outlined, color: AppTheme.primary, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isValid == true ? const Color(0xFF4CAF50) : AppTheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.error, width: 2),
            ),
            labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true,
          ),
        ),
        // Message d'erreur si code invalide
        if (isValid == false)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Code parrainage invalide',
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
        // Message de confirmation si code valide
        if (isValid == true)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Code valide ✓',
              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
            ),
          ),
      ],
    );
  }
}

// ── Widget champ texte client ────────────────────────────────────────────────

class _ClientTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _ClientTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A5A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
    );
  }
}
