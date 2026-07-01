// ─────────────────────────────────────────────────────────────────────────────
// time_utils.dart — Utilitaires de formatage du temps (global, réutilisable)
// ─────────────────────────────────────────────────────────────────────────────
//
// Fonctions exportées :
//   • formatDurationHuman(DateTime from)  → "il y a 1h 30min", "il y a 2j 3h"…
//   • formatElapsedCompact(Duration d)    → "45:23" (MM:SS) pour le timer cuisine
//   • formatRemainingMins(int mins)       → "~5 min", "~1h 10min"
//

/// Retourne une chaîne humaine décrivant le temps écoulé depuis [from].
///
/// Exemples :
///   < 60 s   → "à l'instant"
///   1 min    → "il y a 1 min"
///   30 min   → "il y a 30 min"
///   90 min   → "il y a 1h 30min"
///   1j 2h    → "il y a 1j 2h"
///   1 mois 3j → "il y a 1 mois 3j"
///   1 an 2 mois → "il y a 1 an 2 mois"
String formatDurationHuman(DateTime from) {
  final diff = DateTime.now().difference(from);
  return _humanDiff(diff);
}

/// Variante à partir d'une [Duration] déjà calculée.
String formatDurationHumanFromDiff(Duration diff) => _humanDiff(diff);

String _humanDiff(Duration diff) {
  final totalSeconds = diff.inSeconds;
  if (totalSeconds < 60) return "à l'instant";

  final totalMinutes = diff.inMinutes;
  if (totalMinutes < 60) {
    return 'il y a $totalMinutes min';
  }

  final totalHours = diff.inHours;
  if (totalHours < 24) {
    final remMins = totalMinutes % 60;
    if (remMins == 0) return 'il y a ${totalHours}h';
    return 'il y a ${totalHours}h ${remMins}min';
  }

  final totalDays = diff.inDays;
  if (totalDays < 30) {
    final remHours = totalHours % 24;
    if (remHours == 0) return 'il y a ${totalDays}j';
    return 'il y a ${totalDays}j ${remHours}h';
  }

  final months = totalDays ~/ 30;
  if (months < 12) {
    final remDays = totalDays % 30;
    if (remDays == 0) {
      return months == 1 ? 'il y a 1 mois' : 'il y a $months mois';
    }
    final moisLabel = months == 1 ? '1 mois' : '$months mois';
    return 'il y a $moisLabel ${remDays}j';
  }

  final years = months ~/ 12;
  final remMonths = months % 12;
  final anLabel = years == 1 ? '1 an' : '$years ans';
  if (remMonths == 0) return 'il y a $anLabel';
  final moisLabel = remMonths == 1 ? '1 mois' : '$remMonths mois';
  return 'il y a $anLabel $moisLabel';
}

/// Timer cuisine : durée au format MM:SS (ex. "04:37").
/// [elapsed] — durée écoulée depuis le début de la commande.
String formatElapsedCompact(Duration elapsed) {
  final mins = elapsed.inMinutes;
  final secs = elapsed.inSeconds % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// Temps restant estimé pour la cuisine (ex. "~5 min", "~1h 10min").
/// [mins] — nombre de minutes restantes (peut être 0 si dépassé).
String formatRemainingMins(int mins) {
  if (mins <= 0) return 'dépassé';
  if (mins < 60) return '~$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  if (m == 0) return '~${h}h';
  return '~${h}h ${m}min';
}

/// Temps écoulé en minutes pour la voix (texte naturel).
/// [minutes] — nombre de minutes.
String formatMinutesVoice(int minutes) {
  if (minutes <= 0) return 'quelques secondes';
  if (minutes == 1) return '1 minute';
  if (minutes < 60) return '$minutes minutes';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return h == 1 ? 'une heure' : '$h heures';
  return h == 1 ? 'une heure et $m minutes' : '$h heures et $m minutes';
}
