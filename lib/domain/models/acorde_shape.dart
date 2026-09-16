// lib/domain/models/acorde_shape.dart

/// Uma posição de acorde no braço do violão, do jeito que o chords-db publica:
/// [frets] e [fingers] têm uma entrada por corda, da 6ª (mais grave, à
/// esquerda no desenho) para a 1ª; [barres] são os trastes em que há pestana.
///
/// Convenções do dataset (validadas por tool/gerar_acordes.py):
///   * fret -1 = corda muda (X), 0 = corda solta (○);
///   * fret N > 0 é RELATIVO à janela: o traste de verdade é N + baseFret - 1.
///     Por isso o desenho sempre mostra 5 trastes a partir de [baseFret], e o
///     dedo N cai na N-ésima linha — independente de onde a janela começa.
class AcordeShape {
  final List<int> frets;
  final List<int> fingers;

  /// Primeiro traste da janela exibida (1 = pestana/braço aberto no topo).
  final int baseFret;

  /// Trastes (relativos, como em [frets]) com pestana.
  final List<int> barres;

  const AcordeShape({
    required this.frets,
    required this.fingers,
    required this.baseFret,
    required this.barres,
  });

  factory AcordeShape.fromJson(Map<String, dynamic> json) => AcordeShape(
        frets: (json['frets'] as List<dynamic>).cast<int>(),
        fingers: (json['fingers'] as List<dynamic>).cast<int>(),
        baseFret: json['baseFret'] as int,
        barres: (json['barres'] as List<dynamic>).cast<int>(),
      );

  Map<String, dynamic> toJson() => {
        'frets': frets,
        'fingers': fingers,
        'baseFret': baseFret,
        'barres': barres,
      };
}
