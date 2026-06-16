import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_emailController.text.isEmpty) {
      _showError('Veuillez entrer votre email');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final success = provider.login(_emailController.text.trim(), _passwordController.text);

    if (success) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      _showError('Email non reconnu. Contactez l\'administrateur.');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
    );
  }

  void _quickLogin(String email) {
    _emailController.text = email;
    _passwordController.text = '1234';
    _login();
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
                    // Logo
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 5),
                        ],
                      ),
                      child: const Center(
                        child: Text('S', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SANKADIOKRO',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Système de Gestion Restaurant', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 50),
                    // Login Form
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connexion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 4),
                          const Text('Entrez vos identifiants', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
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
                    // Quick access
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Accès rapide (Démo)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _QuickLoginBtn(label: 'Admin', email: 'admin@sankadio.com', color: AppTheme.primary, onTap: _quickLogin),
                              _QuickLoginBtn(label: 'Caisse', email: 'aya@sankadio.com', color: AppTheme.success, onTap: _quickLogin),
                              _QuickLoginBtn(label: 'Cuisine', email: 'mamadou@sankadio.com', color: const Color(0xFFFF6B00), onTap: _quickLogin),
                              _QuickLoginBtn(label: 'Serveur', email: 'fatou@sankadio.com', color: AppTheme.accent, onTap: _quickLogin),
                              _QuickLoginBtn(label: 'Manager', email: 'ibrahim@sankadio.com', color: const Color(0xFF9C27B0), onTap: _quickLogin),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text('Version 1.0.0 © 2025 SANKADIOKRO', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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

class _QuickLoginBtn extends StatelessWidget {
  final String label;
  final String email;
  final Color color;
  final Function(String) onTap;

  const _QuickLoginBtn({required this.label, required this.email, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(email),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
