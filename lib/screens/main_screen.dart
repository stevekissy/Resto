// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
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
import 'admin/online_orders_admin_screen.dart';
import 'stock/cambuse_screen.dart';
import 'reservations/reservation_screen.dart';
import 'accounting/accounting_screen.dart';
import 'notifications/notification_screen.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

// ── Constante de version — badge discret dans le drawer ──
const String _kBuildCommit = '68df346';
const String _kBuildDate = '28/06 16:00';

/// Widget affiché quand un utilisateur tente d'accéder à un module interdit.
class _AccessDeniedScreen extends StatelessWidget {
  final String moduleName;
  const _AccessDeniedScreen({required this.moduleName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: Colors.red, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'Accès refusé',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Permission insuffisante pour accéder au module "$moduleName".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8888AA), fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'Contactez votre administrateur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8888AA), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NotificationService _notifSvc = NotificationService();

  @override
  void initState() {
    super.initState();
    _notifSvc.addListener(_onNotifChange);
    // Initialiser le service (charge les préférences persistées)
    _notifSvc.init();
    // Déverrouiller l'audio au premier geste utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_notifSvc.isAudioUnlocked) {
        _notifSvc.unlockAudio();
      }
    });
  }

  @override
  void dispose() {
    _notifSvc.removeListener(_onNotifChange);
    super.dispose();
  }

  void _onNotifChange() => setState(() {});


  /// Retourne les items de navigation autorisés selon les permissions Firestore
  List<_NavItem> _getNavItems(AppProvider provider) {
    final role = provider.currentUser?.role ?? UserRole.server;

    // Chaque item définit sa clé permission Firestore
    final all = [
      _NavItem(
        icon: Icons.dashboard, label: 'Tableau de bord',
        screen: const DashboardScreen(), permissionKey: 'dashboard',
      ),
      _NavItem(
        icon: Icons.receipt_long, label: 'Commandes',
        screen: const OrderScreen(), permissionKey: 'orders',
      ),
      _NavItem(
        icon: Icons.restaurant, label: 'Cuisine',
        screen: const KitchenScreen(), permissionKey: 'kitchen',
      ),
      _NavItem(
        icon: Icons.point_of_sale, label: 'Caisse',
        screen: const CashierScreen(), permissionKey: 'cashier',
      ),
      _NavItem(
        icon: Icons.inventory, label: 'Stock',
        screen: const StockScreen(), permissionKey: 'stock',
      ),
      _NavItem(
        icon: Icons.people, label: 'Personnel',
        screen: const StaffScreen(), permissionKey: 'personnel',
      ),
      _NavItem(
        icon: Icons.chat, label: 'Messages',
        screen: const MessagingScreen(), permissionKey: 'messages',
      ),
      _NavItem(
        icon: Icons.bar_chart, label: 'Statistiques',
        screen: const StatsScreen(), permissionKey: 'statistics',
      ),
      _NavItem(
        icon: Icons.local_shipping, label: 'Fournisseurs',
        screen: const SupplierScreen(), permissionKey: 'suppliers',
      ),
      _NavItem(
        icon: Icons.restaurant_menu, label: 'Produits',
        screen: const ProductsAdminScreen(), permissionKey: 'productManagement',
      ),
      _NavItem(
        icon: Icons.event_note, label: 'Réservations',
        screen: const ReservationScreen(), permissionKey: 'reservations',
      ),
      _NavItem(
        icon: Icons.calculate, label: 'Comptabilité',
        screen: const AccountingScreen(), permissionKey: 'accounting',
      ),
      _NavItem(
        icon: Icons.notifications, label: 'Notifications',
        screen: const NotificationScreen(), permissionKey: 'notifications',
      ),
      _NavItem(
        icon: Icons.admin_panel_settings, label: 'Gestion Admins',
        screen: const AdminManagementScreen(), permissionKey: 'adminManagement',
      ),
      _NavItem(
        icon: Icons.storefront_outlined, label: 'Commandes en ligne',
        screen: const OnlineOrdersAdminScreen(), permissionKey: 'onlineOrders',
      ),
      _NavItem(
        icon: Icons.liquor, label: 'Cambuse',
        screen: const CambuseScreen(), permissionKey: 'cambuse',
      ),
    ];

    return all.where((item) => provider.hasPermission(role, item.permissionKey)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final navItems = _getNavItems(provider);
    final currentIndex = _selectedIndex.clamp(0, navItems.length - 1);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        // Titre avec badge espace ADMIN (visible uniquement aux admins/managers)
        title: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8)),
              child: const Center(
                  child: Text('S',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16))),
            ),
            const SizedBox(width: 8),
            const Text('SANKADIOKRO',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2)),

          ],
        ),
        actions: [
          // Badge notifications sonores
          GestureDetector(
            onTap: () {
              _notifSvc.unlockAudio();
              _showNotificationsPanel(context, provider);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _notifSvc.urgentActive
                        ? Icons.notifications_active
                        : Icons.notifications_outlined,
                    color: _notifSvc.urgentActive
                        ? AppTheme.error
                        : Colors.white,
                  ),
                  onPressed: () {
                    _notifSvc.unlockAudio();
                    _showNotificationsPanel(context, provider);
                  },
                ),
                if (_notifSvc.unreadCount > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppTheme.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      child: Text(
                        _notifSvc.unreadCount > 99
                            ? '99+'
                            : '${_notifSvc.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _showProfileMenu(context, provider),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (provider.currentUser?.roleColor ?? AppTheme.primary)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    provider.currentUser?.name.isNotEmpty == true
                        ? provider.currentUser!.name[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                        color: provider.currentUser?.roleColor ??
                            AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, navItems, provider),
      // Guard : si la liste est vide (aucune permission), afficher accès refusé
      body: navItems.isEmpty
          ? const _AccessDeniedScreen(moduleName: 'Application')
          : navItems[currentIndex].screen,
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), Color(0xFF2196F3)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo officiel SANKADIOKRO dans le drawer
                Row(
                  children: [
                    const SankaLogo(size: 64),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SANKADIOKRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'Restaurant Africain',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
          // ── Badge DERNIÈRE VERSION (admin/manager uniquement) ──
          if (provider.currentUser?.role == UserRole.admin ||
              provider.currentUser?.role == UserRole.manager)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A3E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 10),
                    const SizedBox(width: 6),
                    Text(
                      'DERNIÈRE VERSION · $_kBuildCommit · $_kBuildDate',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    // Arrêter la boucle urgente si active
    if (_notifSvc.urgentActive) _notifSvc.acknowledgeUrgent();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final unread = _notifSvc.unreadNotifications;
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                // Handle
                Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF2A2A5A), borderRadius: BorderRadius.circular(2))),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(children: [
                    const Icon(Icons.notifications, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
                    if (unread.isNotEmpty)
                      TextButton(
                        onPressed: () { _notifSvc.markAllRead(); setModalState(() {}); },
                        child: const Text('Tout lire', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_notifSvc.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
                // État des alertes système
                if (provider.pendingOrders.isNotEmpty || provider.outOfStockItems.isNotEmpty || provider.lowStockItems.isNotEmpty || provider.readyOrders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(children: [
                      if (provider.pendingOrders.isNotEmpty)
                        _NotifTile(icon: Icons.hourglass_empty, title: '${provider.pendingOrders.length} commande(s) en attente', color: AppTheme.warning),
                      if (provider.outOfStockItems.isNotEmpty)
                        _NotifTile(icon: Icons.cancel, title: '${provider.outOfStockItems.length} produit(s) en rupture', color: AppTheme.error),
                      if (provider.lowStockItems.isNotEmpty)
                        _NotifTile(icon: Icons.warning, title: '${provider.lowStockItems.length} produit(s) à stock faible', color: AppTheme.warning),
                      if (provider.readyOrders.isNotEmpty)
                        _NotifTile(icon: Icons.check_circle, title: '${provider.readyOrders.length} commande(s) prête(s) à servir', color: AppTheme.success),
                      const Divider(color: Color(0xFF2A2A5A)),
                    ]),
                  ),
                // Liste notifications récentes
                Expanded(
                  child: unread.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Aucune nouvelle notification', style: TextStyle(color: AppTheme.textSecondary)),
                        ))
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: unread.take(20).length,
                          itemBuilder: (_, i) {
                            final n = unread[i];
                            return ListTile(
                              leading: Text(n.event.icon, style: const TextStyle(fontSize: 20)),
                              title: Text(n.message, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              subtitle: Text(_timeAgo(n.dateTime), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                              trailing: IconButton(
                                icon: const Icon(Icons.check, color: AppTheme.success, size: 18),
                                onPressed: () { _notifSvc.markRead(n.id); setModalState(() {}); },
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'À l\'instant';
    if (diff.inMinutes < 60)  return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)    return 'Il y a ${diff.inHours} h';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  void _showProfileMenu(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: (provider.currentUser?.roleColor ?? AppTheme.primary)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  provider.currentUser?.name.isNotEmpty == true
                      ? provider.currentUser!.name[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                      color: provider.currentUser?.roleColor ?? AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(provider.currentUser?.name ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            // Rôle utilisateur
            Text(provider.currentUser?.roleLabel ?? '',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            Text(provider.currentUser?.email ?? '',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
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
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
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
  final String permissionKey;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.screen,
    required this.permissionKey,
  });
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


