// Stub non-web — toutes les fonctions sont des no-ops sur Android/iOS
void webPlaySound(String soundType, {double volume = 1.0}) {}
void webPlayUrgentLoop(String soundType, {double volume = 1.0}) {}
void webStopUrgentLoop() {}
bool webAudioUnlocked() => false;
void webUnlockAudio() {}
