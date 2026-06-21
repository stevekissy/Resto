import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/client_models.dart';
import '../../../providers/client_provider.dart';
import '../../../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS CLIENT — Préférences de notifications
// ═══════════════════════════════════════════════════════════════════════════

class ClientNotificationsScreen extends StatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  State<ClientNotificationsScreen> createState() =>
      _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState
    extends State<ClientNotificationsScreen> {
  late ClientNotificationSettings _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<ClientProvider>();
    await provider.loadNotifSettings();
    setState(() {
      _settings = ClientNotificationSettings(
        clientId: provider.notifSettings.clientId,
        orderNotifications: provider.notifSettings.orderNotifications,
        paymentNotifications: provider.notifSettings.paymentNotifications,
        deliveryNotifications: provider.notifSettings.deliveryNotifications,
        promoNotifications: provider.notifSettings.promoNotifications,
        soundEnabled: provider.notifSettings.soundEnabled,
        vibrationEnabled: provider.notifSettings.vibrationEnabled,
      );
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<ClientProvider>().saveNotifSettings(_settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Préférences enregistrées'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Enregistrer',
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle(
                    icon: Icons.notifications_outlined,
                    title: 'Types de notifications'),
                const SizedBox(height: 12),
                _buildToggleCard(
                  icon: Icons.receipt_long_outlined,
                  color: AppTheme.primary,
                  title: 'Commandes',
                  subtitle: 'Confirmations, mises à jour et annulations',
                  value: _settings.orderNotifications,
                  onChanged: (v) =>
                      setState(() => _settings.orderNotifications = v),
                ),
                _buildToggleCard(
                  icon: Icons.payment_outlined,
                  color: const Color(0xFF4CAF50),
                  title: 'Paiements',
                  subtitle: 'Acomptes, paiements et remboursements',
                  value: _settings.paymentNotifications,
                  onChanged: (v) =>
                      setState(() => _settings.paymentNotifications = v),
                ),
                _buildToggleCard(
                  icon: Icons.delivery_dining,
                  color: const Color(0xFF9C27B0),
                  title: 'Livraison',
                  subtitle: 'Suivi en temps réel et arrivée',
                  value: _settings.deliveryNotifications,
                  onChanged: (v) =>
                      setState(() => _settings.deliveryNotifications = v),
                ),
                _buildToggleCard(
                  icon: Icons.local_offer_outlined,
                  color: const Color(0xFFFF9800),
                  title: 'Promotions',
                  subtitle: 'Offres spéciales et nouveautés',
                  value: _settings.promoNotifications,
                  onChanged: (v) =>
                      setState(() => _settings.promoNotifications = v),
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                    icon: Icons.volume_up_outlined, title: 'Son & Vibration'),
                const SizedBox(height: 12),
                _buildToggleCard(
                  icon: Icons.music_note_outlined,
                  color: const Color(0xFF00BCD4),
                  title: 'Sonnerie',
                  subtitle: 'Activer le son pour les notifications',
                  value: _settings.soundEnabled,
                  onChanged: (v) =>
                      setState(() => _settings.soundEnabled = v),
                ),
                _buildToggleCard(
                  icon: Icons.vibration,
                  color: const Color(0xFF607D8B),
                  title: 'Vibration',
                  subtitle: 'Activer la vibration pour les notifications',
                  value: _settings.vibrationEnabled,
                  onChanged: (v) =>
                      setState(() => _settings.vibrationEnabled = v),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? color.withValues(alpha: 0.4)
              : const Color(0xFF2A2A5A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ],
    );
  }
}
