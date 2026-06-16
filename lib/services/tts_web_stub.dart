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
