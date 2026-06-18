import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Personnel', icon: Icon(Icons.people, size: 16)),
                Tab(text: 'Présences', icon: Icon(Icons.how_to_reg, size: 16)),
                Tab(text: 'Accès & Admin', icon: Icon(Icons.admin_panel_settings, size: 16)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _PersonnelTab(),
                _AttendanceTab(),
                _AccessTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================== PERSONNEL TAB ===================
class _PersonnelTab extends StatelessWidget {
  const _PersonnelTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context, provider),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.users.length,
        itemBuilder: (context, i) => _UserCard(user: provider.users[i], provider: provider),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, AppProvider provider) {
    final nameCtrl     = TextEditingController();
    final emailCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    UserRole role = UserRole.server;
    bool obscurePassword = true;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Ajouter un membre'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () => setS(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  value: role,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: AppTheme.cardBg,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: UserRole.values.map((r) {
                    const labels = ['Administrateur', 'Manager', 'Caissier(ère)', 'Cuisine', 'Serveur(se)'];
                    return DropdownMenuItem(value: r, child: Text(labels[r.index]));
                  }).toList(),
                  onChanged: (v) => setS(() => role = v!),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final name     = nameCtrl.text.trim();
                final email    = emailCtrl.text.trim();
                final password = passwordCtrl.text;

                if (name.isEmpty || email.isEmpty || password.isEmpty) {
                  setS(() => errorMsg = 'Nom, email et mot de passe obligatoires.');
                  return;
                }
                if (password.length < 6) {
                  setS(() => errorMsg = 'Le mot de passe doit comporter au moins 6 caractères.');
                  return;
                }
                setS(() => errorMsg = null);
                try {
                  await provider.addUser(
                    name: name,
                    email: email,
                    password: password,
                    role: role,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setS(() => errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), ''));
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final AppProvider provider;

  const _UserCard({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: user.isActive ? user.roleColor.withValues(alpha: 0.3) : const Color(0xFF2A2A5A)),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: user.isActive ? user.roleColor.withValues(alpha: 0.2) : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(color: user.isActive ? user.roleColor : AppTheme.textSecondary, fontSize: 20, fontWeight: FontWeight.w800),
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
                    Text(user.name, style: TextStyle(color: user.isActive ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 14)),
                    if (user.isOnline) ...[
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                    ],
                  ],
                ),
                Text(user.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text(user.phone, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(label: user.roleLabel, color: user.roleColor, fontSize: 10),
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showEditDialog(context, user, provider),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit, color: AppTheme.primary, size: 14),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => provider.toggleUserActive(user.id), // async fire-and-forget
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: user.isActive ? AppTheme.error.withValues(alpha: 0.15) : AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(user.isActive ? Icons.block : Icons.check_circle, color: user.isActive ? AppTheme.error : AppTheme.success, size: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, AppUser user, AppProvider provider) {
    UserRole selectedRole = user.role;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Modifier ${user.name}'),
          content: DropdownButtonFormField<UserRole>(
            value: selectedRole,
            style: const TextStyle(color: Colors.white),
            dropdownColor: AppTheme.cardBg,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: UserRole.values.map((r) {
              final labels = ['Administrateur', 'Manager', 'Caissier(ère)', 'Cuisine', 'Serveur(se)'];
              return DropdownMenuItem(value: r, child: Text(labels[r.index]));
            }).toList(),
            onChanged: (v) => setS(() => selectedRole = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                await provider.updateUser(
                  user.id,
                  name: user.name,
                  email: user.email,
                  phone: user.phone,
                  role: selectedRole,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== ATTENDANCE TAB ===================
class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final todayAttendances = provider.getAttendanceForDate(_selectedDate);
    final allStaff = provider.users.where((u) => u.isActive).toList();

    return Column(
      children: [
        // Date selector
        GlassCard(
          margin: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              IconButton(
                onPressed: _selectedDate.day < DateTime.now().day
                  ? () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)))
                  : null,
                icon: Icon(Icons.chevron_right, color: _selectedDate.day < DateTime.now().day ? AppTheme.primary : AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(child: StatCard(
                title: 'Présents Matin',
                value: todayAttendances.where((a) => a.morningPresent).length.toString(),
                icon: Icons.wb_sunny_outlined,
                color: AppTheme.warning,
              )),
              const SizedBox(width: 10),
              Expanded(child: StatCard(
                title: 'Présents Soir',
                value: todayAttendances.where((a) => a.eveningPresent).length.toString(),
                icon: Icons.nights_stay_outlined,
                color: AppTheme.primary,
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Staff list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: allStaff.length,
            itemBuilder: (context, i) {
              final user = allStaff[i];
              final attendance = todayAttendances.firstWhere(
                (a) => a.userId == user.id,
                orElse: () => Attendance(id: '', userId: user.id, userName: user.name, date: _selectedDate),
              );
              return _AttendanceCard(user: user, attendance: attendance, provider: provider, isToday: _selectedDate.day == DateTime.now().day);
            },
          ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AppUser user;
  final Attendance attendance;
  final AppProvider provider;
  final bool isToday;

  const _AttendanceCard({required this.user, required this.attendance, required this.provider, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: user.roleColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(user.name[0].toUpperCase(), style: TextStyle(color: user.roleColor, fontWeight: FontWeight.w800, fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(user.roleLabel, style: TextStyle(color: user.roleColor, fontSize: 11)),
              ],
            ),
          ),
          Row(
            children: [
              _AttendanceBtn(
                icon: Icons.wb_sunny,
                label: 'Matin',
                isPresent: attendance.morningPresent,
                time: attendance.morningTime,
                onTap: isToday ? () => provider.markAttendance(user.id, AttendanceType.morning) : null,
              ),
              const SizedBox(width: 8),
              _AttendanceBtn(
                icon: Icons.nights_stay,
                label: 'Soir',
                isPresent: attendance.eveningPresent,
                time: attendance.eveningTime,
                onTap: isToday ? () => provider.markAttendance(user.id, AttendanceType.evening) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPresent;
  final DateTime? time;
  final VoidCallback? onTap;

  const _AttendanceBtn({required this.icon, required this.label, required this.isPresent, this.time, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isPresent ? AppTheme.success : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isPresent ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isPresent ? AppTheme.success.withValues(alpha: 0.5) : const Color(0xFF2A2A5A)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
            if (time != null) Text('${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: color, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// =================== ACCESS & ADMIN TAB ===================
class _AccessTab extends StatelessWidget {
  const _AccessTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final admins = provider.users.where((u) => u.role == UserRole.admin || u.role == UserRole.manager).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Administrateurs & Managers', icon: Icons.shield),
          const SizedBox(height: 12),
          ...admins.map((u) => GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            border: Border.all(color: u.roleColor.withValues(alpha: 0.3)),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: u.roleColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(u.name[0].toUpperCase(), style: TextStyle(color: u.roleColor, fontWeight: FontWeight.w800, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(u.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                StatusBadge(label: u.roleLabel, color: u.roleColor),
              ],
            ),
          )),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Niveaux d\'Accès', icon: Icons.lock_open),
          const SizedBox(height: 12),
          ...UserRole.values.map((role) {
            final roleLabels = ['Administrateur', 'Manager', 'Caissier(ère)', 'Cuisine', 'Serveur(se)'];
            final permissions = _getRolePermissions(role);
            final count = provider.users.where((u) => u.role == role).length;
            final user = AppUser(id: '', name: roleLabels[role.index], email: '', phone: '', role: role);
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              border: Border.all(color: user.roleColor.withValues(alpha: 0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: user.roleColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.person, color: user.roleColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(roleLabels[role.index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('$count membre(s)', style: TextStyle(color: user.roleColor, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: permissions.map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: user.roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: user.roleColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: user.roleColor, size: 10),
                          const SizedBox(width: 4),
                          Text(p, style: TextStyle(color: user.roleColor, fontSize: 10)),
                        ],
                      ),
                    )).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<String> _getRolePermissions(UserRole role) {
    switch (role) {
      case UserRole.admin: return ['Tableau de bord', 'Commandes', 'Cuisine', 'Caisse', 'Stock', 'Personnel', 'Messagerie', 'Statistiques', 'Fournisseurs', 'Gestion complète'];
      case UserRole.manager: return ['Tableau de bord', 'Commandes', 'Statistiques', 'Personnel', 'Stock', 'Fournisseurs'];
      case UserRole.cashier: return ['Commandes', 'Caisse', 'Facturation', 'Messagerie'];
      case UserRole.kitchen: return ['Écran Cuisine', 'Messagerie'];
      case UserRole.server: return ['Commandes', 'Consultation Tables', 'Messagerie'];
    }
  }
}
