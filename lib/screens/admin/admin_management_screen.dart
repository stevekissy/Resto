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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nouvel utilisateur', style: TextStyle(color: Colors.white)),
      ),
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
class _UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final users = provider.users;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isCurrentUser = provider.currentUser?.id == user.id;
        return _UserCard(user: user, isCurrentUser: isCurrentUser);
      },
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
              // Actions
              if (!isCurrentUser)
                PopupMenuButton<String>(
                  color: AppTheme.surface,
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: AppTheme.primary, size: 18), SizedBox(width: 8), Text('Modifier', style: TextStyle(color: AppTheme.textPrimary))])),
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
                        provider.toggleUserActive(user.id);
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
          // Statut actif/inactif
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) {
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                provider.changeUserRole(user.id, selectedRole);
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
            onPressed: () {
              provider.deleteUser(user.id);
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
        ...UserRole.values.map((role) {
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

  static const Map<String, String> _moduleLabels = {
    'dashboard': 'Tableau de bord',
    'orders': 'Commandes',
    'kitchen': 'Cuisine',
    'cashier': 'Caisse',
    'stock': 'Stock',
    'staff': 'Personnel',
    'messaging': 'Messages',
    'stats': 'Statistiques',
    'suppliers': 'Fournisseurs',
    'products': 'Gestion Produits',
    'admin': 'Gestion Admins',
  };

  static const Map<String, IconData> _moduleIcons = {
    'dashboard': Icons.dashboard,
    'orders': Icons.receipt_long,
    'kitchen': Icons.restaurant,
    'cashier': Icons.point_of_sale,
    'stock': Icons.inventory,
    'staff': Icons.people,
    'messaging': Icons.chat,
    'stats': Icons.bar_chart,
    'suppliers': Icons.local_shipping,
    'products': Icons.restaurant_menu,
    'admin': Icons.admin_panel_settings,
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
                      activeColor: AppTheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        provider.setRolePermission(role, key, val);
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
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.server;
  bool _obscure = true;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameCtrl.text = widget.user!.name;
      _emailCtrl.text = widget.user!.email;
      _phoneCtrl.text = widget.user!.phone;
      _selectedRole = widget.user!.role;
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

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(
        isEditing ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur',
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
              decoration: InputDecoration(
                labelText: 'Nom complet',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.person, color: AppTheme.primary),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            // Email
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.email, color: AppTheme.primary),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            // Téléphone
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Téléphone',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.phone, color: AppTheme.primary),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            // Mot de passe (seulement pour création)
            if (!isEditing)
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.lock, color: AppTheme.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: AppTheme.cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            if (!isEditing) const SizedBox(height: 12),
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
                  items: UserRole.values.map((role) {
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
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nom et email obligatoires'), backgroundColor: AppTheme.error),
              );
              return;
            }
            if (isEditing) {
              provider.updateUser(
                widget.user!.id,
                name: _nameCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                role: _selectedRole,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utilisateur mis à jour'), backgroundColor: AppTheme.success),
              );
            } else {
              provider.addUser(
                name: _nameCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                password: _passwordCtrl.text,
                role: _selectedRole,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utilisateur créé avec succès'), backgroundColor: AppTheme.success),
              );
            }
            Navigator.pop(context);
          },
          child: Text(isEditing ? 'Modifier' : 'Créer', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
