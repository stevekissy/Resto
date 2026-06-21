// Implémentation Web uniquement — appelle les fonctions JS de index.html
// Ce fichier n'est importé que sur la plateforme web (dart.library.js disponible)
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void africanSpeak(String text, double rate, double pitch, double volume) {
  try {
    js.context.callMethod('africanSpeak', [text, rate, pitch, volume]);
  } catch (e) {
    // Silencieux si JS non disponible
  }
}

void africanStop() {
  try {
    js.context.callMethod('africanStop', []);
  } catch (e) {
    // Silencieux
  }
}

bool africanIsSpeaking() {
  try {
    final result = js.context.callMethod('africanIsSpeaking', []);
    return result as bool? ?? false;
  } catch (e) {
    return false;
  }
}

/// Applique la configuration vocale depuis Flutter vers le moteur JS.
/// [voiceName] : nom exact de la voix choisie par l'utilisateur ('' = auto)
/// [rate]      : vitesse de parole (0.6 – 1.2)
/// [pitch]     : hauteur (1.0 – 1.4)
/// [volume]    : volume (0.0 – 1.0)
void setTTSConfig(String voiceName, double rate, double pitch, double volume) {
  try {
    js.context.callMethod('setTTSConfig', [voiceName, rate, pitch, volume]);
  } catch (e) {
    // Silencieux si JS non disponible
  }
}

/// Retourne la liste des voix françaises disponibles en JSON.
/// Format : [{"name":"...", "lang":"..."}, ...]
String getTTSVoiceList() {
  try {
    final result = js.context.callMethod('getTTSVoiceList', []);
    return result as String? ?? '[]';
  } catch (e) {
    return '[]';
  }
}

/// Retourne true si une voix africaine francophone native est disponible.
bool isTTSAfricanAvailable() {
  try {
    final result = js.context.callMethod('isTTSAfricanAvailable', []);
    return result as bool? ?? false;
  } catch (e) {
    return false;
  }
}
