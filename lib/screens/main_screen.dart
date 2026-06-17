import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/models.dart';
import 'dashboard/dashboard_screen.dart';
import 'orders/order_screen.dart';
import 'kitchen/kitchen_screen.dart';
import 'cashier/cashier_screen.dart';
import 'stock/stock_screen.dart';
import 'staff/staff_screen.dart';
import 'messaging/messaging_screen.dart';
import 'stats/stats_screen.dart';
import 'suppliers/supplier_screen.dart';
import 'admin/products_admin_screen.dart';
import 'admin/admin_management_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_NavItem> _getNavItems(UserRole role) {
    final all = [
      _NavItem(icon: Icons.dashboard, label: 'Tableau de bord', screen: const DashboardScreen(), roles: UserRole.values.toSet()),
      _NavItem(icon: Icons.receipt_long, label: 'Commandes', screen: const OrderScreen(), roles: {UserRole.admin, UserRole.manager, UserRole.cashier, UserRole.server}),
      _NavItem(icon: Icons.restaurant, label: 'Cuisine', screen: const KitchenScreen(), roles: {UserRole.admin, UserRole.manager, UserRole.kitchen}),
      _NavItem(icon: Icons.point_of_sale, label: 'Caisse', screen: const CashierScreen(), roles: {UserRole.admin, UserRole.manager, UserRole.cashier}),
      _NavItem(icon: Icons.inventory, label: 'Stock', screen: const StockScreen(), roles: {UserRole.admin, UserRole.manager}),
      _NavItem(icon: Icons.people, label: 'Personnel', screen: const StaffScreen(), roles: {UserRole.admin, UserRole.manager}),
      _NavItem(icon: Icons.chat, label: 'Messages', screen: const MessagingScreen(), roles: UserRole.values.toSet()),
      _NavItem(icon: Icons.bar_chart, label: 'Statistiques', screen: const StatsScreen(), roles: {UserRole.admin, UserRole.manager}),
      _NavItem(icon: Icons.local_shipping, label: 'Fournisseurs', screen: const SupplierScreen(), roles: {UserRole.admin, UserRole.manager}),
      _NavItem(icon: Icons.restaurant_menu, label: 'Produits', screen: const ProductsAdminScreen(), roles: {UserRole.admin, UserRole.manager}),
      _NavItem(icon: Icons.admin_panel_settings, label: 'Gestion Admins', screen: const AdminManagementScreen(), roles: {UserRole.admin}),
    ];
    return all.where((item) => item.roles.contains(role)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final role = provider.currentUser?.role ?? UserRole.server;
    final navItems = _getNavItems(role);
    final currentIndex = _selectedIndex.clamp(0, navItems.length - 1);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
            ),
            const SizedBox(width: 8),
            const Text('SANKADIOKRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          // Order counter badges
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showNotificationsPanel(context, provider),
              ),
              if (provider.pendingOrders.isNotEmpty || provider.lowStockItems.isNotEmpty)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _showProfileMenu(context, provider),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (provider.currentUser?.roleColor ?? AppTheme.primary).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    provider.currentUser?.name.isNotEmpty == true ? provider.currentUser!.name[0].toUpperCase() : 'U',
                    style: TextStyle(color: provider.currentUser?.roleColor ?? AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, navItems, provider),
      body: navItems[currentIndex].screen,
      bottomNavigationBar: navItems.length <= 5
        ? BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            items: navItems.take(5).map((item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            )).toList(),
          )
        : null,
    );
  }

  Widget _buildDrawer(BuildContext context, List<_NavItem> navItems, AppProvider provider) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryDark, AppTheme.primary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(height: 10),
                const Text('SANKADIOKRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
                const Text('Restaurant Africain', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: (provider.currentUser?.roleColor ?? Colors.white).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            provider.currentUser?.name.isNotEmpty == true ? provider.currentUser!.name[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(provider.currentUser?.name ?? 'Utilisateur', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(provider.currentUser?.roleLabel ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item = navItems[i];
                final isSelected = _selectedIndex == i || (_selectedIndex >= navItems.length && i == navItems.length - 1);
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 20),
                  ),
                  title: Text(item.label, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal, fontSize: 14)),
                  selected: isSelected,
                  selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(color: Color(0xFF2A2A5A)),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.logout, color: AppTheme.error, size: 18),
            ),
            title: const Text('Déconnexion', style: TextStyle(color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context); // ferme le drawer d'abord
              await provider.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            if (provider.pendingOrders.isNotEmpty)
              _NotifTile(icon: Icons.hourglass_empty, title: '${provider.pendingOrders.length} commande(s) en attente', color: AppTheme.warning),
            if (provider.outOfStockItems.isNotEmpty)
              _NotifTile(icon: Icons.cancel, title: '${provider.outOfStockItems.length} produit(s) en rupture', color: AppTheme.error),
            if (provider.lowStockItems.isNotEmpty)
              _NotifTile(icon: Icons.warning, title: '${provider.lowStockItems.length} produit(s) à stock faible', color: AppTheme.warning),
            if (provider.readyOrders.isNotEmpty)
              _NotifTile(icon: Icons.check_circle, title: '${provider.readyOrders.length} commande(s) prête(s) à servir', color: AppTheme.success),
            if (provider.pendingOrders.isEmpty && provider.outOfStockItems.isEmpty && provider.lowStockItems.isEmpty && provider.readyOrders.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucune notification', style: TextStyle(color: AppTheme.textSecondary)))),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: (provider.currentUser?.roleColor ?? AppTheme.primary).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  provider.currentUser?.name.isNotEmpty == true ? provider.currentUser!.name[0].toUpperCase() : 'U',
                  style: TextStyle(color: provider.currentUser?.roleColor ?? AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(provider.currentUser?.name ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            Text(provider.currentUser?.roleLabel ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Text(provider.currentUser?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await provider.logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget screen;
  final Set<UserRole> roles;

  const _NavItem({required this.icon, required this.label, required this.screen, required this.roles});
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _NotifTile({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}
