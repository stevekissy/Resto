// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

// ═══════════════════════════════════════════════════════════════════════════
//  SOUND WEB IMPL — Web Audio API via dart:js
//  Génère 5 sonneries synthétisées directement en mémoire.
//  Aucun fichier externe requis — 100 % intégré.
//  v2 : intervalle configurable, volume sonnerie / vocal séparés
// ═══════════════════════════════════════════════════════════════════════════

bool _unlocked = false;
js.JsObject? _urgentTimer;

/// Retourne true si l'AudioContext est déverrouillé (après interaction utilisateur).
bool webAudioUnlocked() => _unlocked;

/// Déverrouille l'audio : à appeler lors d'une interaction utilisateur (tap).
void webUnlockAudio() {
  try {
    final ctx = js.JsObject(
      js.context['AudioContext'] as js.JsFunction? ??
      js.context['webkitAudioContext'] as js.JsFunction,
    );
    final buf = ctx.callMethod('createBuffer', [1, 1, 22050]);
    final src = ctx.callMethod('createBufferSource', []);
    src['buffer'] = buf;
    src.callMethod('connect', [ctx['destination']]);
    src.callMethod('start', [0]);
    _unlocked = true;
  } catch (_) {
    _unlocked = true;
  }
}

/// Joue un son synthétisé selon le type demandé.
/// Types : classic | restaurant | cash | urgent | discrete
void webPlaySound(String soundType, {double volume = 1.0}) {
  try {
    final script = _buildSoundScript(soundType, volume: volume);
    js.context.callMethod('eval', [script]);
    _unlocked = true;
  } catch (_) {}
}

/// Démarre une boucle urgente avec intervalle configurable.
/// [intervalMs] : intervalle en millisecondes (défaut 10 000ms = 10s)
void webPlayUrgentLoop(String soundType, {double volume = 1.0, int intervalMs = 10000}) {
  webStopUrgentLoop();
  try {
    // Premier son immédiat
    webPlaySound(soundType, volume: volume);
    // Répétition via setInterval JS avec intervalle configurable
    final fn = js.allowInterop(() {
      try {
        final script = _buildSoundScript(soundType, volume: volume);
        js.context.callMethod('eval', [script]);
      } catch (_) {}
    });
    _urgentTimer = js.JsObject.jsify(
      {'timerId': js.context.callMethod('setInterval', [fn, intervalMs])},
    );
  } catch (_) {}
}

/// Arrête la boucle urgente.
void webStopUrgentLoop() {
  try {
    if (_urgentTimer != null) {
      final id = _urgentTimer!['timerId'];
      if (id != null) js.context.callMethod('clearInterval', [id]);
      _urgentTimer = null;
    }
  } catch (_) {}
}

// ── Générateur de scripts Audio ──────────────────────────────────────────

String _buildSoundScript(String soundType, {double volume = 1.0}) {
  switch (soundType) {
    case 'restaurant': return _scriptRestaurant(volume);
    case 'cash':       return _scriptCash(volume);
    case 'urgent':     return _scriptUrgent(volume);
    case 'discrete':   return _scriptDiscrete(volume);
    default:           return _scriptClassic(volume);
  }
}

// ── Sonnerie classique : ding-dong professionnel ──────────────────────────
String _scriptClassic(double vol) => '''
(function(){
  try {
    var ac = new (window.AudioContext || window.webkitAudioContext)();
    var gain = ac.createGain();
    gain.gain.value = ${vol.clamp(0.0, 1.0)};
    gain.connect(ac.destination);
    function note(freq, start, dur) {
      var o = ac.createOscillator();
      var g = ac.createGain();
      o.type = 'sine';
      o.frequency.value = freq;
      g.gain.setValueAtTime(0.001, ac.currentTime + start);
      g.gain.linearRampToValueAtTime(0.8, ac.currentTime + start + 0.02);
      g.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + start + dur);
      o.connect(g); g.connect(gain);
      o.start(ac.currentTime + start);
      o.stop(ac.currentTime + start + dur + 0.05);
    }
    note(880, 0,    0.4);
    note(659, 0.45, 0.6);
    note(784, 1.1,  0.4);
    note(523, 1.55, 0.7);
    setTimeout(function(){ try{ ac.close(); } catch(e){} }, 3000);
  } catch(e) {}
})();
''';

// ── Sonnerie restaurant : carillon de bienvenue ───────────────────────────
String _scriptRestaurant(double vol) => '''
(function(){
  try {
    var ac = new (window.AudioContext || window.webkitAudioContext)();
    var gain = ac.createGain();
    gain.gain.value = ${vol.clamp(0.0, 1.0)};
    gain.connect(ac.destination);
    var notes = [523.25, 659.25, 783.99, 1046.50, 783.99, 659.25, 523.25];
    var times = [0, 0.18, 0.36, 0.54, 0.75, 0.93, 1.11];
    for(var i=0;i<notes.length;i++){
      (function(freq, t){
        var o = ac.createOscillator();
        var g = ac.createGain();
        o.type = 'triangle';
        o.frequency.value = freq;
        g.gain.setValueAtTime(0.001, ac.currentTime + t);
        g.gain.linearRampToValueAtTime(0.7, ac.currentTime + t + 0.02);
        g.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + t + 0.35);
        o.connect(g); g.connect(gain);
        o.start(ac.currentTime + t);
        o.stop(ac.currentTime + t + 0.4);
      })(notes[i], times[i]);
    }
    setTimeout(function(){ try{ ac.close(); } catch(e){} }, 3000);
  } catch(e) {}
})();
''';

// ── Sonnerie caisse : bip-bip validation paiement ─────────────────────────
String _scriptCash(double vol) => '''
(function(){
  try {
    var ac = new (window.AudioContext || window.webkitAudioContext)();
    var gain = ac.createGain();
    gain.gain.value = ${vol.clamp(0.0, 1.0)};
    gain.connect(ac.destination);
    function bip(freq, start, dur) {
      var o = ac.createOscillator();
      var g = ac.createGain();
      o.type = 'square';
      o.frequency.value = freq;
      g.gain.setValueAtTime(0.001, ac.currentTime + start);
      g.gain.linearRampToValueAtTime(0.5, ac.currentTime + start + 0.01);
      g.gain.linearRampToValueAtTime(0.5, ac.currentTime + start + dur - 0.02);
      g.gain.linearRampToValueAtTime(0.001, ac.currentTime + start + dur);
      o.connect(g); g.connect(gain);
      o.start(ac.currentTime + start);
      o.stop(ac.currentTime + start + dur + 0.02);
    }
    bip(1047, 0,    0.12);
    bip(1319, 0.15, 0.12);
    bip(1568, 0.30, 0.25);
    setTimeout(function(){ try{ ac.close(); } catch(e){} }, 2000);
  } catch(e) {}
})();
''';

// ── Sonnerie urgente : alarme insistante ──────────────────────────────────
String _scriptUrgent(double vol) => '''
(function(){
  try {
    var ac = new (window.AudioContext || window.webkitAudioContext)();
    var gain = ac.createGain();
    gain.gain.value = ${vol.clamp(0.0, 1.0)};
    gain.connect(ac.destination);
    function alarm(start) {
      var o = ac.createOscillator();
      var g = ac.createGain();
      o.type = 'sawtooth';
      o.frequency.setValueAtTime(440, ac.currentTime + start);
      o.frequency.linearRampToValueAtTime(880, ac.currentTime + start + 0.15);
      o.frequency.linearRampToValueAtTime(440, ac.currentTime + start + 0.30);
      g.gain.setValueAtTime(0.001, ac.currentTime + start);
      g.gain.linearRampToValueAtTime(0.9, ac.currentTime + start + 0.02);
      g.gain.setValueAtTime(0.9, ac.currentTime + start + 0.28);
      g.gain.linearRampToValueAtTime(0.001, ac.currentTime + start + 0.32);
      o.connect(g); g.connect(gain);
      o.start(ac.currentTime + start);
      o.stop(ac.currentTime + start + 0.35);
    }
    for(var i=0;i<4;i++) alarm(i * 0.38);
    setTimeout(function(){ try{ ac.close(); } catch(e){} }, 3000);
  } catch(e) {}
})();
''';

// ── Sonnerie discrète : léger bip doux ────────────────────────────────────
String _scriptDiscrete(double vol) => '''
(function(){
  try {
    var ac = new (window.AudioContext || window.webkitAudioContext)();
    var gain = ac.createGain();
    gain.gain.value = ${(vol * 0.6).clamp(0.0, 1.0)};
    gain.connect(ac.destination);
    var o = ac.createOscillator();
    var g = ac.createGain();
    o.type = 'sine';
    o.frequency.value = 660;
    g.gain.setValueAtTime(0.001, ac.currentTime);
    g.gain.linearRampToValueAtTime(0.5, ac.currentTime + 0.03);
    g.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.4);
    o.connect(g); g.connect(gain);
    o.start(ac.currentTime);
    o.stop(ac.currentTime + 0.45);
    setTimeout(function(){ try{ ac.close(); } catch(e){} }, 1000);
  } catch(e) {}
})();
''';
