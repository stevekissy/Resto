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
