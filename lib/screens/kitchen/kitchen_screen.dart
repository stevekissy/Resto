import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/tts_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  late Timer _timer;
  final TtsService _tts = TtsService();
  Set<String> _announcedOrders = {};

  @override
  void initState() {
    super.initState();
    _tts.init();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.onNewOrder = (order) {
        if (!_announcedOrders.contains(order.id)) {
          _announcedOrders.add(order.id);
          _tts.announceNewOrder(order);
        }
      };
      provider.onOrderDelayed = (order) {
        _tts.announceDelay(order);
      };
      // Démarrer les rappels périodiques automatiques (toutes les 5 minutes)
      _tts.startPeriodicReminders(provider, intervalMinutes: 5);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _tts.stopPeriodicReminders();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final activeOrders = provider.orders
      .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
      .toList()
      ..sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });

    final readyOrders = provider.readyOrders;

    return Scaffold(
      body: Column(
        children: [
          _KitchenHeader(provider: provider, tts: _tts),
          Expanded(
            child: activeOrders.isEmpty && readyOrders.isEmpty
              ? const EmptyState(icon: Icons.restaurant, title: 'Aucune commande active', subtitle: 'En attente de nouvelles commandes...')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeOrders.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.fire_truck, color: AppTheme.preparing, size: 18),
                            const SizedBox(width: 8),
                            Text('Commandes Actives (${activeOrders.length})',
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.7,
                          ),
                          itemCount: activeOrders.length,
                          itemBuilder: (context, i) => _KitchenOrderCard(
                            order: activeOrders[i],
                            provider: provider,
                            tts: _tts,
                          ),
                        ),
                      ],
                      if (readyOrders.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.ready, size: 18),
                            const SizedBox(width: 8),
                            Text('Prêtes à servir (${readyOrders.length})',
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...readyOrders.map((o) => _ReadyOrderCard(order: o, provider: provider)),
                      ],
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _KitchenHeader extends StatefulWidget {
  final AppProvider provider;
  final TtsService tts;

  const _KitchenHeader({required this.provider, required this.tts});

  @override
  State<_KitchenHeader> createState() => _KitchenHeaderState();
}

class _KitchenHeaderState extends State<_KitchenHeader> {
  @override
  Widget build(BuildContext context) {
    final remindersOn = widget.tts.isRemindersActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: const Color(0xFF2A2A5A))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ÉCRAN CUISINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
                  Text('SANKADIOKRO', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _StatBubble(value: widget.provider.pendingOrders.length.toString(), label: 'Attente', color: AppTheme.pending),
                  const SizedBox(width: 8),
                  _StatBubble(value: widget.provider.preparingOrders.length.toString(), label: 'Prépa', color: AppTheme.preparing),
                  const SizedBox(width: 8),
                  _StatBubble(value: widget.provider.readyOrders.length.toString(), label: 'Prêt', color: AppTheme.ready),
                  const SizedBox(width: 8),
                  // Bouton rappel immédiat
                  GestureDetector(
                    onTap: () => widget.tts.triggerImmediateReminder(widget.provider),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5))),
                      child: const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barre rappels périodiques
          Row(
            children: [
              Icon(Icons.timer, color: remindersOn ? AppTheme.success : AppTheme.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                remindersOn ? 'Rappels vocaux actifs (toutes les 5 min)' : 'Rappels vocaux inactifs',
                style: TextStyle(color: remindersOn ? AppTheme.success : AppTheme.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (remindersOn) {
                    widget.tts.stopPeriodicReminders();
                  } else {
                    widget.tts.startPeriodicReminders(widget.provider, intervalMinutes: 5);
                  }
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: remindersOn ? AppTheme.error.withValues(alpha: 0.15) : AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: remindersOn ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.success.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    remindersOn ? 'Désactiver' : 'Activer',
                    style: TextStyle(color: remindersOn ? AppTheme.error : AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBubble({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

class _KitchenOrderCard extends StatefulWidget {
  final Order order;
  final AppProvider provider;
  final TtsService tts;

  const _KitchenOrderCard({required this.order, required this.provider, required this.tts});

  @override
  State<_KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends State<_KitchenOrderCard> {
  late Timer _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _elapsed = widget.order.elapsedMinutes;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = widget.order.elapsedMinutes;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color get _timerColor {
    if (_elapsed >= 20) return AppTheme.error;
    if (_elapsed >= 15) return AppTheme.warning;
    return AppTheme.success;
  }

  String get _exactTime {
    final t = widget.order.createdAt;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isLate = _elapsed >= 20;
    final elapsedSecs = DateTime.now().difference(order.createdAt).inSeconds;
    final mins = elapsedSecs ~/ 60;
    final secs = elapsedSecs % 60;

    // Estimate max cook time from items
    final maxCookTime = order.items.isEmpty ? 20 : order.items.fold<double>(0, (m, i) {
      final product = widget.provider.products.firstWhere((p) => p.id == i.productId, orElse: () => Product(id: '', name: '', category: '', price: 0, prepTime: 20));
      return product.prepTime > m ? product.prepTime : m;
    });
    final remainingMins = (maxCookTime - mins).clamp(0, maxCookTime.toInt());
    final progressValue = (mins / maxCookTime).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLate ? AppTheme.error : (order.isUrgent ? AppTheme.warning : order.statusColor.withValues(alpha: 0.5)),
          width: isLate || order.isUrgent ? 2 : 1,
        ),
        boxShadow: isLate ? [BoxShadow(color: AppTheme.error.withValues(alpha: 0.3), blurRadius: 15)] : null,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: order.statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order.orderNumber}', style: TextStyle(color: order.statusColor, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('Table ${order.tableNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (order.isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(8)),
                        child: const Text('🚨 URGENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    const SizedBox(height: 4),
                    Text('Passé à $_exactTime', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    StatusBadge(label: order.statusLabel, color: order.statusColor, fontSize: 10),
                  ],
                ),
              ],
            ),
          ),

          // Timer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: _timerColor.withValues(alpha: 0.08),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: _timerColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                          style: TextStyle(color: _timerColor, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace'),
                        ),
                        if (isLate) Text('  ⚠ RETARD', style: TextStyle(color: _timerColor, fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Text('Reste: ~${remainingMins}min', style: TextStyle(color: _timerColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),

          // Items (récapitulatif avec modification de quantité)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: order.items.length,
              itemBuilder: (context, i) {
                final item = order.items[i];
                return _KitchenItemRow(
                  item: item,
                  onChangeQty: (newQty) {
                    widget.provider.updateOrderItemQuantity(order.id, item.productId, newQty);
                  },
                );
              },
            ),
          ),

          if (order.specialInstructions != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppTheme.warning.withValues(alpha: 0.08),
              child: Text('📝 ${order.specialInstructions}',
                style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontStyle: FontStyle.italic)),
            ),
          ],

          // Actions
          Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.tts.announceOrder(order),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.record_voice_over, color: AppTheme.primary, size: 16),
                              SizedBox(width: 6),
                              Text('Écouter', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (order.status == OrderStatus.pending) {
                            widget.provider.updateOrderStatus(order.id, OrderStatus.preparing);
                          } else {
                            widget.provider.updateOrderStatus(order.id, OrderStatus.ready);
                            widget.tts.announceOrderReady(order);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: order.status == OrderStatus.pending ? AppTheme.preparing : AppTheme.ready,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              order.status == OrderStatus.pending ? 'Commencer' : '✓ Prêt!',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenItemRow extends StatelessWidget {
  final OrderItem item;
  final Function(int) onChangeQty;

  const _KitchenItemRow({required this.item, required this.onChangeQty});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${item.productName}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              // Quantity control for kitchen
              Row(
                children: [
                  GestureDetector(
                    onTap: () => onChangeQty(item.quantity - 1),
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.remove, size: 12, color: AppTheme.error),
                    ),
                  ),
                  Container(
                    width: 30,
                    alignment: Alignment.center,
                    child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  GestureDetector(
                    onTap: () => onChangeQty(item.quantity + 1),
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.add, size: 12, color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.specialComment != null) ...[
            const SizedBox(height: 2),
            Text('💬 ${item.specialComment}', style: const TextStyle(color: AppTheme.warning, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _ReadyOrderCard extends StatelessWidget {
  final Order order;
  final AppProvider provider;

  const _ReadyOrderCard({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      border: Border.all(color: AppTheme.ready.withValues(alpha: 0.5), width: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.ready.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle, color: AppTheme.ready, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commande #${order.orderNumber} - Table ${order.tableNumber}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                Text('${order.items.fold(0, (s, i) => s + i.quantity)} articles',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            children: [
              const Text('PRÊTE!', style: TextStyle(color: AppTheme.ready, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () => provider.updateOrderStatus(order.id, OrderStatus.served),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ready, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                child: const Text('Servie', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
