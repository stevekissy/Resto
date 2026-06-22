import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/client_provider.dart';
import '../../sandbox/sandbox_provider.dart';
import '../../utils/app_theme.dart';
import 'home/client_home_screen.dart';
import 'menu/client_menu_screen.dart';
import 'orders/client_orders_screen.dart';
import 'profile/client_profile_screen.dart';
import '../login_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT MAIN SCREEN — Navigation principale de l'espace client
// 4 onglets : Accueil | Menu | Commandes | Profil
// ═══════════════════════════════════════════════════════════════════════════

class ClientMainScreen extends StatefulWidget {
  final bool isSandbox;
  /// Affiche le bouton discret "Passer en mode gestion" dans la barre de navigation.
  /// Utilisé uniquement quand l'app démarre sans session (première ouverture).
  final bool showManagementButton;
  const ClientMainScreen({
    super.key,
    this.isSandbox = false,
    this.showManagementButton = false,
  });

  @override
  State<ClientMainScreen> createState() => _ClientMainScreenState();
}

class _ClientMainScreenState extends State<ClientMainScreen> {
  int _currentIndex = 0;

  void _goHome() => setState(() => _currentIndex = 0);

  List<Widget> get _screens => [
    const ClientHomeScreen(),
    ClientMenuScreen(onGoHome: _goHome),
    ClientOrdersScreen(onGoHome: _goHome),
    ClientProfileScreen(onGoHome: _goHome),
  ];

  @override
  Widget build(BuildContext context) {
    // En mode sandbox, on lit depuis SandboxProvider ; sinon ClientProvider
    final int cartCount;
    final int activeOrders;
    if (widget.isSandbox) {
      final sb = context.watch<SandboxProvider>();
      cartCount = sb.cartCount;
      activeOrders = sb.activeOrders.length;
    } else {
      final provider = context.watch<ClientProvider>();
      cartCount = provider.cartCount;
      activeOrders = provider.activeOrders.length;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Bouton discret "Passer en mode gestion" (première ouverture uniquement) ──
          if (widget.showManagementButton && !widget.isSandbox)
            _ManagementModeButton(),
          // ── Barre de navigation principale (design inchangé) ──────────────────
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Accueil',
                      index: 0,
                      currentIndex: _currentIndex,
                      onTap: () => setState(() => _currentIndex = 0),
                    ),
                    _NavItem(
                      icon: Icons.restaurant_menu_outlined,
                      activeIcon: Icons.restaurant_menu,
                      label: 'Menu',
                      index: 1,
                      currentIndex: _currentIndex,
                      badge: cartCount > 0 ? cartCount.toString() : null,
                      badgeColor: AppTheme.warning,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                    _NavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long,
                      label: 'Commandes',
                      index: 2,
                      currentIndex: _currentIndex,
                      badge: activeOrders > 0 ? activeOrders.toString() : null,
                      badgeColor: AppTheme.success,
                      onTap: () => setState(() => _currentIndex = 2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profil',
                      index: 3,
                      currentIndex: _currentIndex,
                      onTap: () => setState(() => _currentIndex = 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON DISCRET « PASSER EN MODE GESTION »
// Affiché uniquement lors de la première ouverture (aucune session active).
// Ouvre LoginScreen sans connecter automatiquement.
// ─────────────────────────────────────────────────────────────────────────────
class _ManagementModeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(
              fromClientSpace: true,
            ),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'Passer en mode gestion',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
