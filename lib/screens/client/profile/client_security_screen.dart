import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/client_provider.dart';
import '../../../utils/app_theme.dart';
import '../auth/client_auth_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SÉCURITÉ & MOT DE PASSE CLIENT
// ═══════════════════════════════════════════════════════════════════════════

class ClientSecurityScreen extends StatelessWidget {
  const ClientSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Sécurité & Mot de passe',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SecurityItem(
            icon: Icons.lock_outline,
            color: AppTheme.primary,
            title: 'Modifier le mot de passe',
            subtitle: 'Changer votre mot de passe actuel',
            onTap: () => _showChangePassword(context),
          ),
          _SecurityItem(
            icon: Icons.email_outlined,
            color: const Color(0xFF4CAF50),
            title: 'Modifier l\'email',
            subtitle: 'Mettre à jour votre adresse email',
            onTap: () => _showChangeEmail(context),
          ),
          _SecurityItem(
            icon: Icons.phone_outlined,
            color: const Color(0xFF00BCD4),
            title: 'Modifier le téléphone',
            subtitle: 'Mettre à jour votre numéro de téléphone',
            onTap: () => _showChangePhone(context),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFF2A2A5A),
          ),
          const SizedBox(height: 20),
          _SecurityItem(
            icon: Icons.devices_outlined,
            color: const Color(0xFFFF9800),
            title: 'Déconnexion de tous les appareils',
            subtitle: 'Mettre fin à toutes les sessions actives',
            onTap: () => _confirmSignOutAll(context),
          ),
          _SecurityItem(
            icon: Icons.delete_forever_outlined,
            color: AppTheme.error,
            title: 'Supprimer mon compte',
            subtitle: 'Action irréversible — toutes vos données seront supprimées',
            onTap: () => _confirmDeleteAccount(context),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Changer mot de passe ─────────────────────────────────────────────────

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  // ── Changer email ────────────────────────────────────────────────────────

  void _showChangeEmail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _ChangeEmailSheet(),
    );
  }

  // ── Changer téléphone ────────────────────────────────────────────────────

  void _showChangePhone(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _ChangePhoneSheet(),
    );
  }

  // ── Déconnexion tous appareils ───────────────────────────────────────────

  void _confirmSignOutAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.devices_outlined, color: Color(0xFFFF9800), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text('Déconnexion globale',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: const Text(
          'Vous serez déconnecté de tous vos appareils. Vous devrez vous reconnecter.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ctx.read<ClientProvider>().signOutAllDevices();
                if (ctx.mounted) {
                  Navigator.of(ctx).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ClientAuthScreen()),
                    (_) => false,
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Erreur : $e'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Déconnecter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Supprimer compte ─────────────────────────────────────────────────────

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(),
    );
  }
}

// ── Delete account dialog ────────────────────────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _pwdCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = context.read<ClientProvider>().client;
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Text('Supprimer mon compte',
              style: TextStyle(
                  color: AppTheme.error, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cette action est irréversible. Toutes vos données (commandes, adresses, points fidélité) seront supprimées définitivement.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text('Confirmez votre mot de passe :',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _pwdCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Mot de passe',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: _isLoading ? null : _delete,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Supprimer définitivement',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _delete() async {
    if (_pwdCtrl.text.isEmpty) {
      setState(() => _error = 'Mot de passe requis');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final provider = context.read<ClientProvider>();
      final email = provider.client?.email ?? '';
      await provider.reauthenticate(email, _pwdCtrl.text);
      await provider.deleteAccount();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ClientAuthScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Mot de passe incorrect ou erreur réseau';
      });
    }
  }
}

// ── Changer mot de passe ─────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const Text('Modifier le mot de passe',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 20),
            _PasswordField(
              controller: _currentPwdCtrl,
              label: 'Mot de passe actuel',
              show: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _newPwdCtrl,
              label: 'Nouveau mot de passe',
              show: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              validator: (v) => v == null || v.length < 6
                  ? 'Minimum 6 caractères'
                  : null,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmPwdCtrl,
              label: 'Confirmer le nouveau mot de passe',
              show: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              validator: (v) => v != _newPwdCtrl.text
                  ? 'Les mots de passe ne correspondent pas'
                  : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ClientProvider>();
      await provider.reauthenticate(
          provider.client?.email ?? '', _currentPwdCtrl.text);
      await provider.updatePassword(_newPwdCtrl.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mot de passe modifié avec succès'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Mot de passe actuel incorrect'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Changer email ─────────────────────────────────────────────────────────────

class _ChangeEmailSheet extends StatefulWidget {
  const _ChangeEmailSheet();

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showPwd = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const Text('Modifier l\'email',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nouvel email',
                prefixIcon: Icon(Icons.email_outlined,
                    color: AppTheme.textSecondary),
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Email invalide' : null,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _pwdCtrl,
              label: 'Mot de passe actuel',
              show: _showPwd,
              onToggle: () => setState(() => _showPwd = !_showPwd),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Un lien de vérification sera envoyé à votre nouvel email.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ClientProvider>();
      await provider.reauthenticate(
          provider.client?.email ?? '', _pwdCtrl.text);
      await provider.updateEmail(_emailCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vérification envoyée à votre nouvel email'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : mot de passe incorrect ou email déjà utilisé'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Changer téléphone ─────────────────────────────────────────────────────────

class _ChangePhoneSheet extends StatefulWidget {
  const _ChangePhoneSheet();

  @override
  State<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<_ChangePhoneSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const Text('Modifier le téléphone',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nouveau numéro de téléphone',
                prefixIcon:
                    Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
                hintText: '+225 XX XX XX XX',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Numéro requis' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await context
          .read<ClientProvider>()
          .updateProfile(phone: _phoneCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Téléphone mis à jour'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Widgets réutilisables ────────────────────────────────────────────────────

class _SecurityItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SecurityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.textSecondary, size: 18),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
