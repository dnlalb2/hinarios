// lib/domain/models/cifra_local.dart

/// Cifra criada pelo usuário, escrita em ChordPro: cada acorde vai entre
/// colchetes imediatamente antes da sílaba que ele acompanha
/// (`[Am]Quem não [E7]anda`). O tom habilita a transposição como nas oficiais.
class CifraLocal {
  final String tom;

  /// Texto ChordPro — formato primário: é o que o editor lê e grava.
  final String texto;

  /// LEGADO (só leitura): uma linha de acordes por linha NÃO-VAZIA da letra,
  /// em ordem, com a coluna do acorde codificada em espaços. Só existe para
  /// ler o que ficou gravado no formato antigo — o editor converte para
  /// ChordPro na primeira edição (ver textoChordPro).
  final List<String> acordesPorLinha;

  const CifraLocal({
    required this.tom,
    this.texto = '',
    this.acordesPorLinha = const [],
  });

  /// Formato novo. O legado NUNCA é gravado: quem salva migra.
  Map<String, dynamic> toJson() => {'tom': tom, 'texto': texto};

  /// Aceita os dois formatos: `{'tom', 'texto'}` (novo) e
  /// `{'tom', 'acordes': [...]}` (legado, de onde veio).
  factory CifraLocal.fromJson(Map<String, dynamic> j) {
    final texto = j['texto'];
    return CifraLocal(
      tom: (j['tom'] as String?) ?? '',
      texto: texto is String ? texto : '',
      // Entrada não-String (disco editado à mão) é descartada em vez de
      // derrubar o parse — a lista de acordes é o que a UI lê.
      acordesPorLinha: [
        for (final a in (j['acordes'] as List<dynamic>?) ?? const [])
          if (a is String) a,
      ],
    );
  }

  /// Texto ChordPro da cifra. Havendo [texto] é ele mesmo; senão o formato
  /// legado é convertido usando a [letra] (só o legado precisa dela: lá a
  /// coluna do acorde é um número de espaços sobre a letra do acervo).
  String textoChordPro(String letra) {
    if (texto.isNotEmpty) return texto;
    if (acordesPorLinha.isEmpty) return '';

    // Mesma normalização de quebras do alinhar().
    final linhas = letra.isEmpty
        ? const <String>[]
        : letra.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    var i = 0;
    final saida = <String>[];
    for (final linha in linhas) {
      // Linha vazia não consome acorde (pareamento posicional do legado).
      if (linha.trim().isEmpty) {
        saida.add(linha);
        continue;
      }
      final acordes = i < acordesPorLinha.length ? acordesPorLinha[i] : '';
      i++;
      saida.add(_marcarAcordes(linha, acordes));
    }
    return saida.join('\n');
  }

  /// Insere `[acorde]` na [linha] nas colunas em que o formato legado os
  /// posicionou: o espaço ANTES do token é a coluna (vários espaços contam).
  static String _marcarAcordes(String linha, String acordes) {
    // Colunas de início de cada token (sequência sem espaços).
    final inicios = <int>[];
    var aposEspaco = true;
    for (var i = 0; i < acordes.length; i++) {
      if (acordes[i] == ' ') {
        aposEspaco = true;
        continue;
      }
      if (aposEspaco) inicios.add(i);
      aposEspaco = false;
    }

    var saida = linha;
    // Da DIREITA para a esquerda: inserir não desloca as colunas anteriores.
    for (final inicio in inicios.reversed) {
      final fim = acordes.indexOf(' ', inicio);
      final token = acordes.substring(inicio, fim < 0 ? acordes.length : fim);
      // Acorde depois do fim da letra (trecho instrumental): a letra ganha os
      // espaços que faltam para a coluna existir — e o parse o traz de volta.
      if (inicio > saida.length) saida = saida.padRight(inicio);
      saida =
          '${saida.substring(0, inicio)}[$token]${saida.substring(inicio)}';
    }
    return saida;
  }
}
