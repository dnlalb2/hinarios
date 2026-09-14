// lib/domain/models/hino.dart
/// Modelo de domínio — imutável. Fonte: dados.json (extraído de estudofino.org).
class Cifra {
  final String tom;
  final String texto;
  Cifra({required this.tom, required this.texto});

  /// NBSP (U+00A0) é usado como preenchimento de coluna em 179 cifras do
  /// acervo. Normalizar no parse (NBSP → espaço ASCII) preserva o
  /// alinhamento e faz o split por espaço da UI enxergar cada acorde.
  factory Cifra.fromJson(Map<String, dynamic> j) => Cifra(
        tom: (j['tom'] as String?) ?? '',
        texto: ((j['texto'] as String?) ?? '').replaceAll(' ', ' '),
      );
}

class Hino {
  final String slug, nome, autor, autorFull, hinario, urlhinario, ritmo, letra;
  final int num;
  final Cifra? cifra;
  final String? abc;

  Hino({
    required this.slug,
    required this.nome,
    required this.autor,
    required this.autorFull,
    required this.hinario,
    required this.urlhinario,
    required this.ritmo,
    required this.letra,
    required this.num,
    this.cifra,
    this.abc,
  });

  factory Hino.fromJson(Map<String, dynamic> j) {
    final cifraJson = j['cifra'];
    final abc = (j['abc'] as String?)?.trim();
    return Hino(
      slug: (j['slug'] as String?) ?? '',
      num: (j['num'] as int?) ?? 0,
      nome: (j['nome'] as String?) ?? '',
      autor: (j['autor'] as String?) ?? '',
      autorFull: (j['autor_full'] as String?) ?? '',
      hinario: (j['hinario'] as String?) ?? '',
      urlhinario: (j['urlhinario'] as String?) ?? '',
      ritmo: (j['ritmo'] as String?) ?? '',
      letra: ((j['letra'] as String?) ?? '').replaceAll(' ', ' '),
      cifra: cifraJson is Map<String, dynamic> ? Cifra.fromJson(cifraJson) : null,
      abc: (abc == null || abc.isEmpty) ? null : abc,
    );
  }
}
