// lib/domain/use_cases/alinhamento.dart
class LinhaHino {
  final String? acordes;
  final String texto;
  LinhaHino({this.acordes, required this.texto});
}

List<LinhaHino> alinhar(String letra, String textoCifra) {
  final linhas = letra.isEmpty
      ? const <String>[]
      : letra.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  // Compasso vazio (só espaços) vira '' para a detecção de vazio; compasso
  // não vazio preserva o texto original — o whitespace inicial codifica a
  // coluna do acorde (76% dos compassos do acervo começam com espaço).
  final compassos = textoCifra
      .replaceAll('\r', '')
      .split(';')
      .map((c) => c.trim().isEmpty ? '' : c)
      .toList();

  List<LinhaHino> pares;
  if (compassos.length == linhas.length) {
    pares = [
      for (var i = 0; i < linhas.length; i++)
        LinhaHino(
          acordes: compassos[i].isEmpty ? null : compassos[i],
          texto: linhas[i],
        ),
    ];
  } else {
    final naoVaziosC = compassos.where((c) => c.isNotEmpty).toList();
    var i = 0;
    pares = [
      for (final linha in linhas)
        if (linha.trim().isNotEmpty && i < naoVaziosC.length)
          LinhaHino(acordes: naoVaziosC[i++], texto: linha)
        else
          LinhaHino(texto: linha),
    ];
  }
  return pares;
}
