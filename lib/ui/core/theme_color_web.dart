import 'package:web/web.dart' as web;

/// Atualiza a meta `theme-color` — cor da barra de status no PWA.
void atualizarThemeColor(int corArgb) {
  final meta =
      web.document.querySelector('meta[name="theme-color"]') as web.HTMLMetaElement?;
  final rgb = corArgb & 0xFFFFFF;
  meta?.content = '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
