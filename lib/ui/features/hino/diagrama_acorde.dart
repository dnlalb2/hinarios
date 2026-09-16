// lib/ui/features/hino/diagrama_acorde.dart
import 'package:flutter/material.dart';
import '../../../domain/models/acorde_shape.dart';

/// Desenho do braço do violão para UMA posição de acorde: 6 cordas em pé,
/// janela de 5 trastes a partir de [AcordeShape.baseFret], X nas cordas mudas,
/// ○ nas soltas, bolinhas com o número do dedo e barra na pestana.
///
/// As cores saem do tema (claro/escuro): nada de preto fixo que suma no fundo.
class DiagramaAcorde extends StatelessWidget {
  final AcordeShape shape;
  final double largura;

  const DiagramaAcorde({super.key, required this.shape, this.largura = 200});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size(largura, largura * _alturaRelativa),
      painter: PintorAcorde(
        shape: shape,
        corda: cores.onSurface,
        destaque: cores.primary,
        sobreDestaque: cores.onPrimary,
        // X e ○ são texto auxiliar: um tom abaixo do desenho em si.
        marcador: cores.onSurfaceVariant,
      ),
    );
  }
}

/// Altura / largura do desenho. A largura manda: a folha pede ~200 px.
const double _alturaRelativa = 1.08;

/// Desenha o desenho inteiro. Exposto para o teste de pintura poder montar um
/// canvas na mão se precisar — na prática quem usa é o [DiagramaAcorde].
class PintorAcorde extends CustomPainter {
  final AcordeShape shape;
  final Color corda;
  final Color destaque;
  final Color sobreDestaque;
  final Color marcador;

  static const _cordas = 6;
  static const _trastes = 5; // janela desenhada, começando no baseFret

  const PintorAcorde({
    required this.shape,
    required this.corda,
    required this.destaque,
    required this.sobreDestaque,
    required this.marcador,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Margens proporcionais: o desenho cresce junto com a largura pedida.
    // À esquerda cabe o rótulo '9fr'; em cima, a fileira de X e ○.
    final esquerda = size.width * 0.12;
    final direita = size.width * 0.05;
    final topo = size.width * 0.15;
    final base = size.height - topo * 0.25;

    final larguraBraco = size.width - esquerda - direita;
    final alturaBraco = base - topo;
    final passo = larguraBraco / (_cordas - 1); // entre cordas
    final passoTraste = alturaBraco / _trastes;

    // Cordas (verticais) e trastes (horizontais). A linha 0 é o baseFret.
    final tinta = Paint()
      ..color = corda.withValues(alpha: 0.45)
      ..strokeWidth = size.width * 0.006
      ..strokeCap = StrokeCap.round;
    for (var c = 0; c < _cordas; c++) {
      final cx = _x(c, esquerda, passo);
      canvas.drawLine(Offset(cx, topo), Offset(cx, base), tinta);
    }
    for (var t = 0; t <= _trastes; t++) {
      final ty = topo + t * passoTraste;
      canvas.drawLine(
          Offset(_x(0, esquerda, passo), ty), Offset(_x(_cordas - 1, esquerda, passo), ty), tinta);
    }

    // Pestana: a barra grossa no topo separa o braço aberto (baseFret 1, a
    // pestana à vista) de uma janela no meio do braço — que ganha o rótulo.
    final aberto = shape.baseFret == 1;
    canvas.drawLine(
      Offset(_x(0, esquerda, passo), topo),
      Offset(_x(_cordas - 1, esquerda, passo), topo),
      Paint()
        ..color = corda
        ..strokeWidth = aberto ? size.width * 0.022 : size.width * 0.008,
    );
    if (!aberto) {
      _rotulo(canvas, '${shape.baseFret}fr', esquerda - 4, topo + passoTraste / 2, size.width * 0.085);
    }

    _marcadores(canvas, size, esquerda, passo, topo, passoTraste);
    _bolinhas(canvas, size, esquerda, passo, topo, passoTraste);
  }

  /// X (muda) e ○ (solta) acima da pestana.
  void _marcadores(Canvas canvas, Size size, double esquerda, double passo,
      double topo, double passoTraste) {
    final fonte = size.width * 0.085;
    final centroY = topo - passoTraste * 0.55;
    for (var c = 0; c < _cordas; c++) {
      final fret = shape.frets[c];
      if (fret > 0) continue;
      final cx = _x(c, esquerda, passo);
      if (fret == -1) {
        final tp = TextPainter(
          text: TextSpan(text: 'X', style: _estilo(marcador, fonte)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, centroY - tp.height / 2));
      } else {
        // ○ vazado, do tamanho da fonte do X.
        canvas.drawCircle(
          Offset(cx, centroY),
          fonte * 0.32,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.006
            ..color = marcador,
        );
      }
    }
  }

  /// Pestanas e bolinhas com o número do dedo.
  void _bolinhas(Canvas canvas, Size size, double esquerda, double passo,
      double topo, double passoTraste) {
    final raio = passo * 0.36 < passoTraste * 0.40 ? passo * 0.36 : passoTraste * 0.40;
    final fonte = raio * 1.15;

    // Pestana primeiro: as cordas cobertas por ela não ganham bolinha própria
    // (o dedo é um só, desenhado no meio da barra).
    final naPestana = <int>{};
    for (final barre in shape.barres) {
      final cobertas = [
        for (var c = 0; c < _cordas; c++)
          if (shape.frets[c] == barre) c,
      ];
      if (cobertas.length < 2) continue; // um dedo só não é pestana
      naPestana.addAll(cobertas);
      final meio = (cobertas.first + cobertas.last) / 2;
      final centroY = topo + (barre - 0.5) * passoTraste;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(_x(meio, esquerda, passo), centroY),
            width: passo * (cobertas.last - cobertas.first) + raio * 2,
            height: raio * 2,
          ),
          Radius.circular(raio),
        ),
        Paint()..color = destaque,
      );
      _dedo(canvas, shape.fingers[cobertas.first],
          _x(meio, esquerda, passo), centroY, fonte);
    }

    for (var c = 0; c < _cordas; c++) {
      final fret = shape.frets[c];
      if (fret <= 0 || naPestana.contains(c)) continue;
      final cx = _x(c, esquerda, passo);
      final centroY = topo + (fret - 0.5) * passoTraste;
      canvas.drawCircle(Offset(cx, centroY), raio, Paint()..color = destaque);
      _dedo(canvas, shape.fingers[c], cx, centroY, fonte);
    }
  }

  /// Número do dedo dentro da bolinha (dedo 0 = pestana sem numeração).
  void _dedo(Canvas canvas, int dedo, double cx, double cy, double fonte) {
    if (dedo <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: '$dedo', style: _estilo(sobreDestaque, fonte)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  /// Rótulo à esquerda do braço ('3fr'), terminando em [fimX].
  void _rotulo(Canvas canvas, String texto, double fimX, double centroY, double fonte) {
    final tp = TextPainter(
      text: TextSpan(text: texto, style: _estilo(marcador, fonte)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(fimX - tp.width, centroY - tp.height / 2));
  }

  static TextStyle _estilo(Color cor, double fonte) =>
      TextStyle(color: cor, fontSize: fonte, fontWeight: FontWeight.w600);

  double _x(num corda, double esquerda, double passo) =>
      esquerda + corda.toDouble() * passo;

  @override
  bool shouldRepaint(PintorAcorde antigo) =>
      antigo.shape != shape ||
      antigo.corda != corda ||
      antigo.destaque != destaque ||
      antigo.sobreDestaque != sobreDestaque ||
      antigo.marcador != marcador;
}
