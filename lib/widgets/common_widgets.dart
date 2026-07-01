import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// ══════════════════════════════════════════════════════════════════════
///  SankaLogo — Logo officiel SANKADIOKRO réutilisable
///  Utilise l'asset local avec fallback sur un logo SVG inline
/// ══════════════════════════════════════════════════════════════════════
class SankaLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool circular;

  const SankaLogo({
    super.key,
    this.size = 60,
    this.showText = false,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoWidget = ClipRRect(
      borderRadius: circular
          ? BorderRadius.circular(size / 2)
          : BorderRadius.circular(size * 0.15),
      child: Image.asset(
        'assets/images/logo_sankadiokro.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _FallbackLogo(size: size),
      ),
    );

    if (!showText) return logoWidget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        const SizedBox(height: 8),
        Text(
          'SANKADIOKRO',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.25,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

/// Fallback si l'asset n'est pas disponible (Web service worker cache)
class _FallbackLogo extends StatelessWidget {
  final double size;
  const _FallbackLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF2196F3)],
        ),
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Center(
        child: Text(
          'S',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double borderRadius;
  final VoidCallback? onTap;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius = 16,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppTheme.cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: const Color(0xFF2A2A5A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(subtitle!, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const StatusBadge({super.key, required this.label, required this.color, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  final IconData? icon;

  const SectionHeader({super.key, required this.title, this.action, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
            ],
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ],
        ),
        if (action != null) action!,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final bool isFullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppTheme.primary,
        minimumSize: isFullWidth ? const Size(double.infinity, 52) : null,
      ),
      child: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label),
              ],
            ),
    );
    return isFullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;

  const AnimatedCounter({super.key, required this.value, this.style});

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _oldValue = widget.value;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = (_oldValue + (_animation.value * (widget.value - _oldValue))).round();
        return Text(current.toString(), style: widget.style);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SankadiokroLoader — Animation de chargement avec logo Sankadiokro
//  Utilisé pour les transitions importantes : login, logout, commande…
//
//  Usage (méthode recommandée — overlay non-bloquant) :
//
//    // Afficher l'overlay (minimum 700ms automatiquement)
//    SankadiokroLoader.show(context, label: 'Connexion en cours…');
//
//    // Exécuter l'action async
//    await monAction();
//
//    // Masquer l'overlay
//    SankadiokroLoader.hide(context);
//
//  Ou via la méthode tout-en-un (attend la future + le minimum 700ms) :
//
//    await SankadiokroLoader.run(
//      context,
//      future: monAction(),
//      label: 'Envoi en cuisine…',
//    );
// ══════════════════════════════════════════════════════════════════════

class SankadiokroLoader {
  // ── Route overlay actuellement affichée ──────────────────────────
  static OverlayEntry? _entry;
  static DateTime? _shownAt;
  static const _minDurationMs = 700; // durée minimale visible

  /// Affiche l'overlay par-dessus toute l'application.
  /// [label] : texte affiché sous le logo (ex: 'Connexion en cours…')
  static void show(BuildContext context, {String label = 'Chargement…'}) {
    hide(context); // sécurité : évite les doublons
    final overlay = Overlay.of(context, rootOverlay: true);
    _shownAt = DateTime.now();
    _entry = OverlayEntry(
      builder: (_) => _SankaLoaderOverlay(label: label),
    );
    overlay.insert(_entry!);
  }

  /// Masque l'overlay en respectant la durée minimale [_minDurationMs].
  static void hide(BuildContext context) {
    if (_entry == null) return;
    final shown = _shownAt;
    final entry = _entry!;
    _entry = null;
    _shownAt = null;

    if (shown == null) {
      entry.remove();
      return;
    }
    final elapsed = DateTime.now().difference(shown).inMilliseconds;
    final remaining = _minDurationMs - elapsed;

    if (remaining <= 0) {
      entry.remove();
    } else {
      Future.delayed(Duration(milliseconds: remaining), () {
        try { entry.remove(); } catch (_) {}
      });
    }
  }

  /// Lance [future] puis masque l'overlay (minimum 700ms garanti).
  /// Retourne le résultat de la future.
  static Future<T> run<T>(
    BuildContext context, {
    required Future<T> future,
    String label = 'Chargement…',
  }) async {
    show(context, label: label);
    try {
      return await future;
    } finally {
      if (context.mounted) hide(context);
    }
  }
}

// ── Widget overlay interne ────────────────────────────────────────────

class _SankaLoaderOverlay extends StatefulWidget {
  final String label;
  const _SankaLoaderOverlay({required this.label});

  @override
  State<_SankaLoaderOverlay> createState() => _SankaLoaderOverlayState();
}

class _SankaLoaderOverlayState extends State<_SankaLoaderOverlay>
    with TickerProviderStateMixin {
  // Fade d'entrée
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Zoom d'entrée (spring)
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  // Pulsation continue du logo
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // ── Fade entrée ─────────────────────────────────────────────────
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // ── Zoom spring ─────────────────────────────────────────────────
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );

    // ── Pulsation douce ─────────────────────────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl.forward();
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        // Fond dégradé brun-noir (couleurs Sankadiokro)
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0A00), // brun très sombre
              Color(0xFF2D1200), // brun profond
              Color(0xFF0A0500), // presque noir
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnim, _pulseAnim]),
          builder: (context, _) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo avec zoom + pulsation ───────────────────
                  Transform.scale(
                    scale: _scaleAnim.value * _pulseAnim.value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB5451B).withValues(alpha: 0.45),
                            blurRadius: 48 * _pulseAnim.value,
                            spreadRadius: 6 * _pulseAnim.value,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/images/logo_sankadiokro.png',
                          width: 130,
                          height: 130,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB5451B),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Nom du restaurant ────────────────────────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: const Text(
                      'RESTAURANT SANKADIOKRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.5,
                        shadows: [
                          Shadow(
                            color: Color(0xFFB5451B),
                            blurRadius: 12,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ── Slogan ───────────────────────────────────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Text(
                      'Les meilleurs plats africains sont chez nous',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Label action + indicateur discret ───────────
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFB5451B).withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
