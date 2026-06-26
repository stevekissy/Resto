import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) setState(() => _currentTab = _tabController.index);
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
      body: Column(
        children: [
          // En-tête
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.admin_panel_settings), text: 'Utilisateurs'),
                Tab(icon: Icon(Icons.lock_outline), text: 'Permissions'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UsersTab(),
                _PermissionsTab(),
              ],
            ),
          ),
        ],
      ),
      // FAB visible uniquement sur l'onglet Utilisateurs (index 0)
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () => _showAddUserDialog(context),
              backgroundColor: AppTheme.primary,
              tooltip: 'Nouvel utilisateur',
              mini: true,
              child: const Icon(Icons.person_add, color: Colors.white, size: 20),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _UserFormDialog(),
    );
  }
}

// =====================================================================
// ONGLET UTILISATEURS
// =====================================================================
class _UsersTab extends StatefulWidget {
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  // 0 = Personnel (staff), 1 = Clients
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allUsers = provider.users;

    // Séparer personnel et clients
    final staff = allUsers.where((u) => u.role != UserRole.client).toList();
    final clients = allUsers.where((u) => u.role == UserRole.client).toList();
    final users = _filterIndex == 0 ? staff : clients;

    return Column(
      children: [
        // ── Barre de filtre Personnel / Clients ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              _FilterChip(
                label: 'Personnel',
                icon: Icons.badge_outlined,
                count: staff.length,
                selected: _filterIndex == 0,
                onTap: () => setState(() => _filterIndex = 0),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Clients',
                icon: Icons.person_outline,
                count: clients.length,
                selected: _filterIndex == 1,
                onTap: () => setState(() => _filterIndex = 1),
              ),
            ],
          ),
        ),
        // ── Liste ──────────────────────────────────────────────────────
        Expanded(
          child: users.isEmpty
              ? EmptyState(
                  icon: _filterIndex == 0 ? Icons.badge_outlined : Icons.people_outline,
                  title: _filterIndex == 0
                      ? 'Aucun membre du personnel'
                      : 'Aucun client enregistré',
                  subtitle: _filterIndex == 0
                      ? 'Utilisez le bouton + pour créer un membre du personnel'
                      : 'Les clients s\'inscrivent depuis l\'Espace Client',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isCurrentUser = provider.currentUser?.id == user.id;
                    return _UserCard(user: user, isCurrentUser: isCurrentUser);
                  },
                ),
        ),
      ],
    );
  }
}

/// Chip de filtre compact pour la barre Personnel/Clients
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isCurrentUser;

  const _UserCard({required this.user, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final permissions = provider.getUserPermissions(user.role);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: user.roleColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: user.roleColor.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: user.roleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Vous', style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    Text(user.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    // Badge rôle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: user.roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: user.roleColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        user.roleLabel,
                        style: TextStyle(
                          color: user.roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions (menu différent pour clients et personnel)
              if (!isCurrentUser)
                PopupMenuButton<String>(
                  color: AppTheme.surface,
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  itemBuilder: (_) => [
                    // "Modifier" uniquement pour le personnel (pas les clients)
                    if (user.role != UserRole.client)
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: AppTheme.primary, size: 18), SizedBox(width: 8), Text('Modifier', style: TextStyle(color: AppTheme.textPrimary))])),
                    // "Changer rôle" uniquement pour le personnel
                    if (user.role != UserRole.client)
                      const PopupMenuItem(value: 'role', child: Row(children: [Icon(Icons.swap_horiz, color: AppTheme.warning, size: 18), SizedBox(width: 8), Text('Changer rôle', style: TextStyle(color: AppTheme.textPrimary))])),
                    const PopupMenuItem(value: 'toggle', child: Row(children: [Icon(Icons.block, color: Colors.orange, size: 18), SizedBox(width: 8), Text('Activer/Désactiver', style: TextStyle(color: AppTheme.textPrimary))])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: AppTheme.error, size: 18), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppTheme.error))])),
                  ],
                  onSelected: (val) {
                    switch (val) {
                      case 'edit':
                        showDialog(context: context, builder: (_) => _UserFormDialog(user: user));
                        break;
                      case 'role':
                        _showChangeRoleDialog(context, user, provider);
                        break;
                      case 'toggle':
                        provider.toggleUserActive(user.id); // async fire-and-forget
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(user.isActive ? '${user.name} désactivé' : '${user.name} activé'),
                            backgroundColor: user.isActive ? Colors.orange : AppTheme.success,
                          ),
                        );
                        break;
                      case 'delete':
                        _confirmDelete(context, user, provider);
                        break;
                    }
                  },
                ),
            ],
          ),
          // Statut actif/inactif + badge accès application
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: user.isActive ? AppTheme.success : AppTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                user.isActive ? 'Compte actif' : 'Compte désactivé',
                style: TextStyle(
                  color: user.isActive ? AppTheme.success : AppTheme.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              // Badge accès application
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: user.hasAppAccess
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: user.hasAppAccess
                        ? AppTheme.primary.withValues(alpha: 0.35)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user.hasAppAccess ? Icons.lock_open : Icons.lock_outline,
                      size: 9,
                      color: user.hasAppAccess ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      user.hasAppAccess ? 'Accès app' : 'Sans connexion',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: user.hasAppAccess ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Nombre de permissions
              Text(
                '${permissions.length} modules accessibles',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(BuildContext context, AppUser user, AppProvider provider) {
    UserRole selectedRole = user.role;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Rôle de ${user.name}', style: const TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Exclure le rôle client — réservé à l'inscription via Espace Client
              children: UserRole.values
                  .where((r) => r != UserRole.client)
                  .map((role) {
                final tempUser = AppUser(id: '', name: '', email: '', phone: '', role: role);
                return RadioListTile<UserRole>(
                  value: role,
                  groupValue: selectedRole,
                  activeColor: AppTheme.primary,
                  title: Text(tempUser.roleLabel, style: const TextStyle(color: AppTheme.textPrimary)),
                  onChanged: (v) => setS(() => selectedRole = v!),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                await provider.changeUserRole(user.id, selectedRole);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Rôle mis à jour'), backgroundColor: AppTheme.success),
                );
              },
              child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppUser user, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Supprimer l\'utilisateur', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Voulez-vous vraiment supprimer ${user.name} ?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              await provider.deleteUser(user.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user.name} supprimé'), backgroundColor: AppTheme.error),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ONGLET PERMISSIONS
// =====================================================================
class _PermissionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Définissez les modules accessibles pour chaque rôle',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        // Exclure UserRole.client des permissions configurables
        ...UserRole.values.where((r) => r != UserRole.client).map((role) {
          final tempUser = AppUser(id: '', name: '', email: '', phone: '', role: role);
          return _RolePermissionCard(
            role: role,
            roleLabel: tempUser.roleLabel,
            roleColor: tempUser.roleColor,
            permissions: provider.getRolePermissions(role),
            provider: provider,
          );
        }),
      ],
    );
  }
}

class _RolePermissionCard extends StatelessWidget {
  final UserRole role;
  final String roleLabel;
  final Color roleColor;
  final Map<String, bool> permissions;
  final AppProvider provider;

  const _RolePermissionCard({
    required this.role,
    required this.roleLabel,
    required this.roleColor,
    required this.permissions,
    required this.provider,
  });

  // Clés exactement alignées avec les champs Firestore (role_permissions)
  static const Map<String, String> _moduleLabels = {
    'dashboard': 'Tableau de bord',
    'orders': 'Commandes',
    'kitchen': 'Cuisine',
    'cashier': 'Caisse',
    'stock': 'Stock',
    'personnel': 'Personnel',
    'messages': 'Messages',
    'statistics': 'Statistiques',
    'suppliers': 'Fournisseurs',
    'productManagement': 'Gestion Produits',
    'reservations': 'Réservations',
    'accounting': 'Comptabilité',
    'notifications': 'Notifications',
    'adminManagement': 'Gestion Admins',
    'onlineOrders': 'Commandes en ligne',
    'cambuse': 'Cambuse',
  };

  static const Map<String, IconData> _moduleIcons = {
    'dashboard': Icons.dashboard,
    'orders': Icons.receipt_long,
    'kitchen': Icons.restaurant,
    'cashier': Icons.point_of_sale,
    'stock': Icons.inventory,
    'personnel': Icons.people,
    'messages': Icons.chat,
    'statistics': Icons.bar_chart,
    'suppliers': Icons.local_shipping,
    'productManagement': Icons.restaurant_menu,
    'reservations': Icons.event_note,
    'accounting': Icons.calculate,
    'notifications': Icons.notifications,
    'adminManagement': Icons.admin_panel_settings,
    'onlineOrders': Icons.storefront_outlined,
    'cambuse': Icons.liquor,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête rôle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                ),
                child: Text(roleLabel, style: TextStyle(color: roleColor, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const Spacer(),
              // Compter les permissions actives
              Text(
                '${permissions.values.where((v) => v).length}/${permissions.length} actifs',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12),
          // Liste des modules avec toggle
          ..._moduleLabels.entries.map((entry) {
            final key = entry.key;
            final label = entry.value;
            final icon = _moduleIcons[key] ?? Icons.settings;
            final isEnabled = permissions[key] ?? false;
            // Admin ne peut pas être modifié pour certains rôles
            final isLocked = role == UserRole.admin;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: isEnabled ? AppTheme.primary : AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (isLocked)
                    const Icon(Icons.lock, size: 14, color: AppTheme.textSecondary)
                  else
                    Switch(
                      value: isEnabled,
                      activeThumbColor: AppTheme.primary,
                      activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) async {
                        await provider.setRolePermission(role, key, val);
                      },
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// =====================================================================
// FORMULAIRE AJOUT / MODIFICATION UTILISATEUR
// =====================================================================
class _UserFormDialog extends StatefulWidget {
  final AppUser? user;
  const _UserFormDialog({this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.server;
  bool _canLogin  = false; // autorise la connexion (Firebase Auth)
  bool _isActive  = true;  // employé actif dans l'établissement
  bool _obscure = true;
  String? _errorMsg;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameCtrl.text  = widget.user!.name;
      _emailCtrl.text = widget.user!.email;
      _phoneCtrl.text = widget.user!.phone;
      // Si c'est un client, ne pas assigner UserRole.client dans le formulaire staff
      _selectedRole = widget.user!.role == UserRole.client
          ? UserRole.server
          : widget.user!.role;
      _canLogin       = widget.user!.canLogin;
      _isActive       = widget.user!.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppTheme.textSecondary),
    prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
    filled: true,
    fillColor: AppTheme.cardBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(
        isEditing ? "Modifier l'utilisateur" : 'Nouvel utilisateur',
        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nom
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('Nom complet', Icons.person),
            ),
            const SizedBox(height: 12),
            // Email (non modifiable en édition)
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !isEditing,
              style: TextStyle(
                color: isEditing ? AppTheme.textSecondary : AppTheme.textPrimary,
              ),
              decoration: _inputDeco('Email', Icons.email),
            ),
            const SizedBox(height: 12),
            // Téléphone
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('Téléphone', Icons.phone),
            ),
            const SizedBox(height: 12),
            // Rôle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<UserRole>(
                  value: _selectedRole,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                  // Exclure UserRole.client — rôle réservé à l'inscription client
                  items: UserRole.values.where((r) => r != UserRole.client).map((role) {
                    final tmp = AppUser(id: '', name: '', email: '', phone: '', role: role);
                    return DropdownMenuItem(
                      value: role,
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(color: tmp.roleColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(tmp.roleLabel),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- CAS CRÉATION uniquement ----
            if (!isEditing) ...[
              // Toggle Autoriser connexion
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _canLogin
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _canLogin
                        ? AppTheme.primary.withValues(alpha: 0.4)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _canLogin ? Icons.lock_open : Icons.lock_outline,
                      color: _canLogin ? AppTheme.primary : AppTheme.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Autoriser connexion',
                            style: TextStyle(
                              color: _canLogin ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _canLogin
                                ? 'Compte Firebase Auth créé'
                                : "Cet employé n'a pas d'accès de connexion",
                            style: TextStyle(
                              color: _canLogin ? AppTheme.primary : AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _canLogin,
                      activeThumbColor: AppTheme.primary,
                      activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() {
                        _canLogin = v;
                        if (!v) _passwordCtrl.clear();
                      }),
                    ),
                  ],
                ),
              ),
              // Toggle Actif
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isActive
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isActive
                        ? AppTheme.success.withValues(alpha: 0.4)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: _isActive ? AppTheme.success : AppTheme.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(
                          color: _isActive ? AppTheme.success : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      activeThumbColor: AppTheme.success,
                      activeTrackColor: AppTheme.success.withValues(alpha: 0.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
              // Mot de passe — visible uniquement si connexion autorisée
              if (_canLogin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe (obligatoire)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.lock, color: AppTheme.primary, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ],

            // ---- Bandeau info en mode ÉDITION ----
            if (isEditing) ...[
              const SizedBox(height: 4),
              // Bandeau connexion
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.user!.canLogin
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.user!.canLogin
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.user!.canLogin ? Icons.lock_open : Icons.lock_outline,
                      color: widget.user!.canLogin ? AppTheme.primary : AppTheme.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.user!.canLogin
                          ? "Connexion autorisée"
                          : "Cet employé n'a pas d'accès de connexion",
                      style: TextStyle(
                        color: widget.user!.canLogin ? AppTheme.primary : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Bandeau actif/inactif
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.user!.isActive
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.user!.isActive
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.user!.isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: widget.user!.isActive ? AppTheme.success : AppTheme.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.user!.isActive ? 'Employé actif' : 'Employé inactif',
                      style: TextStyle(
                        color: widget.user!.isActive ? AppTheme.success : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Erreur
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(_errorMsg!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: () async {
            final name  = _nameCtrl.text.trim();
            final email = _emailCtrl.text.trim();
            final phone = _phoneCtrl.text.trim();

            if (name.isEmpty || email.isEmpty) {
              setState(() => _errorMsg = 'Nom et email obligatoires.');
              return;
            }

            if (isEditing) {
              // Modification : pas de changement d'accès Auth
              await provider.updateUser(
                widget.user!.id,
                name: name, email: email, phone: phone, role: _selectedRole,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Utilisateur mis à jour'),
                  backgroundColor: AppTheme.success,
                ),
              );
            } else if (_canLogin) {
              // CAS 2 — Connexion autorisée : mot de passe obligatoire
              final password = _passwordCtrl.text;
              if (password.isEmpty) {
                setState(() => _errorMsg = "Le mot de passe est obligatoire pour autoriser la connexion.");
                return;
              }
              if (password.length < 6) {
                setState(() => _errorMsg = 'Le mot de passe doit comporter au moins 6 caractères.');
                return;
              }
              setState(() => _errorMsg = null);
              try {
                await provider.addUser(
                  name: name, email: email, password: password,
                  phone: phone, role: _selectedRole, isActive: _isActive,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Utilisateur créé avec accès application (Auth + Firestore)'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              } catch (e) {
                setState(() => _errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), ''));
              }
            } else {
              // CAS 1 — Personnel simple : Firestore uniquement
              setState(() => _errorMsg = null);
              try {
                await provider.addStaff(
                  name: name, email: email, phone: phone,
                  role: _selectedRole, isActive: _isActive,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Personnel enregistré sans accès de connexion'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              } catch (e) {
                setState(() => _errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), ''));
              }
            }
          },
          child: Text(isEditing ? 'Modifier' : 'Créer', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
