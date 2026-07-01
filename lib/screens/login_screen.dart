import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'main_screen.dart';
import 'client/auth/client_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Message d'erreur Firebase passé depuis main() si initializeApp() a échoué.
  final String? firebaseInitError;
  /// Vrai si on arrive depuis l'Espace Client (bouton "Passer en mode gestion").
  /// Affiche un bouton "Retour à l'espace client" en haut.
  final bool fromClientSpace;

  const LoginScreen({super.key, this.firebaseInitError, this.fromClientSpace = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading       = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset>  _slideAnim;
  late Animation<double>  _logoScaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
        ));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
        ));
    _logoScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
        ));
    _animController.forward();

    // Afficher l'erreur Firebase si présente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.firebaseInitError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠ Firebase non connecté : ${widget.firebaseInitError!.length > 80 ? '${widget.firebaseInitError!.substring(0, 80)}...' : widget.firebaseInitError}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty)    { _showError('Veuillez entrer votre email');        return; }
    if (password.isEmpty) { _showError('Veuillez entrer votre mot de passe'); return; }
    if (_isLoading)       return;

    setState(() => _isLoading = true);

    try {
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('[DIAG][login_screen.dart:97] _login() — appel loginWithFirebase');
      debugPrint('[DIAG][login_screen.dart:97]   email = $email');
      debugPrint('════════════════════════════════════════════════════════');
      // ────────────────────────────────────────────────────────────────
      final provider = context.read<AppProvider>();
      final success  = await provider.loginWithFirebase(email, password);
      if (!mounted) return;
      setState(() => _isLoading = false);

      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('[DIAG][login_screen.dart:103] loginWithFirebase retourné');
      debugPrint('[DIAG][login_screen.dart:103]   success = $success');
      debugPrint('[DIAG][login_screen.dart:103]   currentUser = ${provider.currentUser?.name ?? "NULL"}');
      debugPrint('[DIAG][login_screen.dart:103]   role = ${provider.currentUser?.role}');
      debugPrint('[DIAG][login_screen.dart:103]   isActive = ${provider.currentUser?.isActive}');
      debugPrint('[DIAG][login_screen.dart:103]   canLogin = ${provider.currentUser?.canLogin}');
      debugPrint('════════════════════════════════════════════════════════');
      // ────────────────────────────────────────────────────────────────

      if (success) {
        // ─── LOG DIAGNOSTIC ───────────────────────────────────────────
        debugPrint('[DIAG][login_screen.dart:110] ▶ Navigator.pushAndRemoveUntil vers MainScreen');
        // ──────────────────────────────────────────────────────────────
        // Animation de transition — logo Sankadiokro pendant la navigation
        SankadiokroLoader.show(context, label: 'Connexion en cours…');
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        SankadiokroLoader.hide(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        _showError(provider.errorMessage ?? 'Email ou mot de passe incorrect.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('[LoginScreen] Exception: $e');
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg.length > 120 ? msg.substring(0, 120) : msg);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      // Pas de SafeArea ici — on gère manuellement le padding pour éviter la bande noire
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Gradient bleu plein écran, de haut en bas
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1), // Bleu foncé officiel en haut
              Color(0xFF1565C0), // Transition
              Color(0xFF2196F3), // Bleu clair officiel au milieu
              Color(0xFF1976D2), // Légèrement plus foncé
              Color(0xFF0D47A1), // Bleu foncé officiel en bas
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height,
            ),
            child: Padding(
              // padding top pour compenser la status bar
              padding: EdgeInsets.fromLTRB(
                isWide ? size.width * 0.25 : 24,
                MediaQuery.of(context).padding.top + (isWide ? 60 : 40),
                isWide ? size.width * 0.25 : 24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── LOGO OFFICIEL SANKADIOKRO ──
                    ScaleTransition(
                      scale: _logoScaleAnim,
                      child: Column(
                        children: [
                          // Ombre portée sous le logo
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/logo_sankadiokro.png',
                                width: isWide ? 160 : 130,
                                height: isWide ? 160 : 130,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: isWide ? 160 : 130,
                                  height: isWide ? 160 : 130,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'S',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 72,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Nom du restaurant
                          const Text(
                            'SANKADIOKRO',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 5,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  offset: Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Sous-titre professionnel
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'Système Professionnel de Gestion Restaurant',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 44),

                    // ── FORMULAIRE DE CONNEXION ──
                    SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titre du formulaire
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.lock_person_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Connexion',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Entrez vos identifiants',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Champ email
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),

                              // Champ mot de passe
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Mot de passe',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                onSubmitted: (_) => _login(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white60,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Bouton de connexion
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppTheme.primaryDark,
                                    disabledBackgroundColor:
                                        Colors.white.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                    shadowColor:
                                        Colors.black.withValues(alpha: 0.3),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              AppTheme.primaryDark,
                                            ),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.login_rounded, size: 20),
                                            SizedBox(width: 10),
                                            Text(
                                              'Se connecter',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── LIEN ESPACE CLIENT ──
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClientAuthScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront_outlined, color: Colors.white.withValues(alpha: 0.8), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Vous êtes client ? Commander en ligne',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.white,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
