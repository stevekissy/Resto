import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Message d'erreur Firebase passé depuis main() si initializeApp() a échoué.
  /// Affiché dans l'UI pour aider au diagnostic.
  final String? firebaseInitError;

  const LoginScreen({super.key, this.firebaseInitError});

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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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
                    '⚠ Firebase non connecté : ${widget.firebaseInitError!.length > 80 ? widget.firebaseInitError!.substring(0, 80) + "..." : widget.firebaseInitError}',
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
      final provider = context.read<AppProvider>();
      final success  = await provider.loginWithFirebase(email, password);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        // pushAndRemoveUntil : nettoie toute la pile de navigation
        // Évite que "retour" revienne sur LoginScreen après connexion
        // Évite les routes orphelines qui causent des 404 sur Netlify
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
      // Afficher le vrai message d'erreur pour faciliter le diagnostic
      debugPrint('[LoginScreen] Exception: $e');
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg.length > 120 ? msg.substring(0, 120) : msg);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1A), Color(0xFF0D47A1), Color(0xFF0A0A1A)],
            stops: [0.0, 0.5, 1.0],
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
                  children: [
                    const SizedBox(height: 40),

                    // ── Logo ──
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 5)],
                      ),
                      child: const Center(
                        child: Text('S', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('SANKADIOKRO',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
                    const SizedBox(height: 6),
                    const Text('Système de Gestion Restaurant',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 50),

                    // ── Formulaire ──
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connexion',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 4),
                          const Text('Entrez vos identifiants',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppTheme.textSecondary),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Se connecter',
                            icon: Icons.login,
                            isLoading: _isLoading,
                            isFullWidth: true,
                            onPressed: _login,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text('Version 1.0.0 © 2025 SANKADIOKRO',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


