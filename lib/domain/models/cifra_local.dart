// lib/domain/models/cifra_local.dart

/// Cifra criada pelo usuário, uma linha de acordes por linha NÃO-VAZIA da
/// letra (em ordem). O tom habilita a transposição como nas oficiais.
class CifraLocal {
  final String tom;
  final List<String> acordesPorLinha;
  const CifraLocal({required this.tom, required this.acordesPorLinha});

  Map<String, dynamic> toJson() => {'tom': tom, 'acordes': acordesPorLinha};

  factory CifraLocal.fromJson(Map<String, dynamic> j) => CifraLocal(
        tom: (j['tom'] as String?) ?? '',
        // Entrada não-String (disco editado à mão) é descartada em vez de
        // derrubar o parse — a lista de acordes é o que a UI lê.
        acordesPorLinha: [
          for (final a in (j['acordes'] as List<dynamic>?) ?? const [])
            if (a is String) a,
        ],
      );

  /// Texto no formato interno da cifra (compassos separados por ';'):
  /// PERCORRE as linhas da [letra]; cada linha não-vazia consome a próxima
  /// entrada de [acordesPorLinha]; linhas vazias viram compasso vazio.
  /// Resultado tem UM compasso por linha da letra (pareamento posicional
  /// do alinhar() 1:1). Se acordesPorLinha tiver menos entradas que linhas
  /// não-vazias, as restantes viram vazias.
  String textoCifra(String letra) {
    // Mesma normalização de quebras do alinhar(): '\r\n' conta como UMA
    // linha, senão o pareamento posicional sairia do lugar.
    if (letra.isEmpty) return '';
    final linhas = letra.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final compassos = <String>[];
    var i = 0;
    for (final linha in linhas) {
      if (linha.trim().isEmpty) {
        compassos.add('');
      } else {
        compassos.add(i < acordesPorLinha.length ? acordesPorLinha[i] : '');
        i++;
      }
    }
    return compassos.join(';');
  }
}
