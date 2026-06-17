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

/// Ouvre une nouvelle fenêtre avec le HTML du reçu et lance l'impression
void webOpenPrintWindow(String htmlContent) {
  try {
    final printWindow = js.context.callMethod('open', ['', '_blank', 'width=400,height=700']);
    if (printWindow != null) {
      printWindow.callMethod('document.write', [htmlContent]);
      printWindow['document'].callMethod('close', []);
      // Délai pour laisser le rendu se faire avant print()
      js.context.callMethod('setTimeout', [
        js.allowInterop(() {
          try {
            printWindow.callMethod('print', []);
          } catch (_) {}
        }),
        500,
      ]);
    }
  } catch (e) {
    // Fallback : simple window.print() sur la page courante
    try {
      js.context.callMethod('print', []);
    } catch (_) {}
  }
}
