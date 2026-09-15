// lib/ui/core/arquivo_web.dart
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Dispara o download de [conteudo] como arquivo (Blob + <a download>).
void baixarTexto(String nomeArquivo, String conteudo) {
  final blob = web.Blob(
    [conteudo.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final ancora = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nomeArquivo;
  ancora.click();
  web.URL.revokeObjectURL(url);
}

/// Abre o seletor de arquivos do navegador e devolve o texto escolhido.
/// Fica pendente enquanto o usuário não escolher nada nem cancelar.
Future<String?> escolherArquivoTexto() {
  final completer = Completer<String?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = '.json,application/json'
    ..style.display = 'none';
  input.onchange = (web.Event _) {
    final arquivos = input.files;
    if (arquivos == null || arquivos.length == 0) {
      completer.complete(null);
      return;
    }
    _lerTexto(arquivos.item(0)!)
        .then((texto) => completer.complete(texto))
        .catchError((_) => completer.complete(null));
  }.toJS;
  input.click();
  return completer.future;
}

Future<String?> _lerTexto(web.File arquivo) async =>
    (await arquivo.text().toDart).toDart;
