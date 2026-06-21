// Stub pour les plateformes non-web (Android, iOS, Desktop)
// Ces fonctions ne font rien — dart:js n'est pas disponible sur ces plateformes

void africanSpeak(String text, double rate, double pitch, double volume) {
  // No-op sur Android/iOS
}

void africanStop() {
  // No-op sur Android/iOS
}

bool africanIsSpeaking() {
  return false;
}

/// Stub — pas d'effet sur Android/iOS
void setTTSConfig(String voiceName, double rate, double pitch, double volume) {
  // No-op
}

/// Stub — retourne une liste vide sur Android/iOS
String getTTSVoiceList() {
  return '[]';
}

/// Stub — pas de voix africaine disponible sur Android/iOS via ce pont
bool isTTSAfricanAvailable() {
  return false;
}
