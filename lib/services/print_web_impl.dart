// Implémentation Web uniquement — appelle window.print() via dart:js
// Ce fichier n'est importé que sur la plateforme web
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Lance window.print() directement — ouvre le dialogue d'impression du navigateur
void webPrint() {
  try {
    js.context.callMethod('print', []);
  } catch (e) {
    // Silencieux si JS non disponible
  }
}

/// Ouvre une nouvelle fenêtre avec le HTML du reçu et lance l'impression.
/// Utilise une Blob URL pour contourner le blocage de document.write()
/// par les navigateurs modernes (Chrome, Firefox, Safari).
void webOpenPrintWindow(String htmlContent) {
  try {
    // Encode le HTML en bytes UTF-8 via TextEncoder
    final encoder = js.JsObject(js.context['TextEncoder'] as js.JsFunction);
    final bytes = encoder.callMethod('encode', [htmlContent]);

    // Crée un Blob HTML depuis les bytes encodés
    final blobOptions = js.JsObject.jsify({'type': 'text/html; charset=utf-8'});
    final blob = js.JsObject(
      js.context['Blob'] as js.JsFunction,
      [
        js.JsArray.from([bytes]),
        blobOptions,
      ],
    );

    // Génère une URL objet temporaire pointant sur le Blob
    final url = js.context['URL'].callMethod('createObjectURL', [blob]) as String;

    // Ouvre le Blob URL dans un nouvel onglet — le navigateur l'affiche immédiatement
    final win = js.context.callMethod('open', [url, '_blank']);

    if (win != null) {
      // Déclenche l'impression après un court délai pour laisser le rendu se faire
      js.context.callMethod('setTimeout', [
        js.allowInterop(() {
          try {
            win.callMethod('print', []);
          } catch (_) {}
          // Libère la mémoire : révoque l'URL objet après usage
          try {
            js.context['URL'].callMethod('revokeObjectURL', [url]);
          } catch (_) {}
        }),
        800,
      ]);
    }
  } catch (e) {
    // Fallback : impression de la page courante si Blob API indisponible
    try {
      js.context.callMethod('print', []);
    } catch (_) {}
  }
}
