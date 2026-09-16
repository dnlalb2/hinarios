// lib/ui/core/widgets/linha_acordes.dart
import 'package:flutter/material.dart';
import '../../features/hino/shape_acorde_sheet.dart';

/// Uma linha de acordes da cifra (já transposta) em que cada acorde é
/// tocável: o toque abre o desenho do violão (ver [abrirShapeAcorde]).
///
/// O texto é um `Text` comum com a MESMA string de sempre — espaços de
/// alinhamento inclusive: a coluna de cada acorde não muda (o alinhamento com
/// a letra depende disso) e o texto puro do parágrafo continua idêntico, então
/// extensões e testes que leem a linha seguem valendo.
///
/// O toque NÃO passa por `TextSpan.recognizer`: no motor web (CanvasKit) o
/// reconhecedor do span não despacha o gesto e o acorde ficava morto no app
/// publicado, com o teste de widget passando. Aqui a posição do toque é
/// resolvida contra um [TextPainter] montado com o MESMO texto, o mesmo estilo
/// efetivo e a MESMA largura do `Text` — logo a mesma disposição de linha —,
/// e o token que contém o offset é o acorde. Só depende de hit-test do
/// Flutter, igual em todos os motores.
class LinhaAcordes extends StatelessWidget {
  final String texto;
  final TextStyle estilo;

  const LinhaAcordes({super.key, required this.texto, required this.estilo});

  /// Token que COMEÇA um acorde: nota (com acidente) na primeira coluna.
  /// 'D', 'A#m7', 'F#°', 'Bm7/5-', 'C/F#' entram; 'e', '2°vez' e as palavras
  /// da letra não (a linha de acordes não tem letra, mas cifra digitada à mão
  /// traz de tudo — melhor não ser tocável do que abrir o acorde errado).
  static final RegExp inicioDeAcorde = RegExp(r'^[A-G](#|b)?');

  /// Quebra em tokens e espaços, preservando os dois (as colunas da cifra).
  static final RegExp _tokens = RegExp(r'\S+|\s+');

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder: o pintor do toque precisa da MESMA largura com que o
    // `Text` quebra as linhas — numa cifra de compasso longo o texto passa da
    // tela e a posição do toque só bate se a quebra for a mesma.
    return LayoutBuilder(
      builder: (contexto, restricoes) => GestureDetector(
        // O detector é o pai direto do `Text` e tem exatamente o tamanho dele:
        // localPosition já está no sistema de coordenadas do texto (mesma
        // origem que o pintor usa para desenhar).
        onTapUp: (detalhe) =>
            _abrirSeAcorde(contexto, detalhe.localPosition, restricoes.maxWidth),
        child: Text(texto, style: estilo),
      ),
    );
  }

  void _abrirSeAcorde(BuildContext context, Offset posicao, double largura) {
    final acorde = _acordeEm(context, posicao, largura);
    if (acorde != null) {
      abrirShapeAcorde(context, acorde);
    }
  }

  /// O acorde sob [posicao] (coordenadas locais do `Text`), ou `null` quando o
  /// toque caiu em espaço, em token que não é acorde ou fora do texto.
  String? _acordeEm(BuildContext context, Offset posicao, double largura) {
    final pintor = _pintor(context, largura);
    try {
      final noTexto = pintor.getPositionForOffset(posicao);
      // O motor devolve a BORDA mais próxima do toque (e a afinidade diz de que
      // lado ela foi escolhida), não o caractere sob o dedo: com `upstream` a
      // borda é o FIM do caractere anterior. É o que separa tocar no meio de um
      // espaço (não abre nada) de tocar na coluna do acorde seguinte — e o fim
      // de uma linha quebrada da primeira coluna da linha de baixo, que sem
      // isso abriria o acorde errado.
      final indice = noTexto.affinity == TextAffinity.upstream
          ? noTexto.offset - 1
          : noTexto.offset;
      if (indice < 0 || indice >= texto.length) {
        return null;
      }
      for (final token in _tokens.allMatches(texto)) {
        if (indice < token.start) {
          break;
        }
        if (indice >= token.end) {
          continue;
        }
        final candidato = token[0]!;
        // O espaço em branco depois do fim da linha não é do acorde anterior:
        // a posição é clampada ao fim da linha, não basta o índice.
        return inicioDeAcorde.hasMatch(candidato) && _sobOToken(pintor, token, posicao.dx)
            ? candidato
            : null;
      }
      return null;
    } finally {
      pintor.dispose();
    }
  }

  /// O toque está sobre os glifos do [token] (o vazio à direita de uma linha
  /// quebrada fica de fora)? As caixas vêm do avanço das fontes, não da tinta
  /// — o espaço tem caixa, mesmo sem desenho.
  static bool _sobOToken(TextPainter pintor, RegExpMatch token, double x) {
    final caixas = pintor.getBoxesForSelection(
      TextSelection(baseOffset: token.start, extentOffset: token.end),
    );
    return caixas.any((caixa) => x >= caixa.left && x <= caixa.right);
  }

  /// [TextPainter] com a disposição do `Text` desta linha. Repete o que o
  /// `Text.build` faz para chegar ao estilo efetivo (merge com o
  /// `DefaultTextStyle`, boldText do sistema, escala de texto do
  /// `MediaQuery`): um pixel de diferença na métrica joga o toque no token
  /// vizinho.
  TextPainter _pintor(BuildContext context, double largura) {
    final padrao = DefaultTextStyle.of(context);
    var efetivo = estilo;
    if (estilo.inherit) {
      efetivo = padrao.style.merge(estilo);
    }
    if (MediaQuery.boldTextOf(context)) {
      efetivo = efetivo.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return TextPainter(
      text: TextSpan(text: texto, style: efetivo),
      textDirection: Directionality.of(context),
      textAlign: padrao.textAlign ?? TextAlign.start,
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: padrao.maxLines,
      textWidthBasis: padrao.textWidthBasis,
      textHeightBehavior:
          padrao.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context),
      // Sem quebra automática o RenderParagraph dispõe numa linha só (largura
      // infinita); o pintor tem que fazer o mesmo para o toque bater.
    )..layout(maxWidth: padrao.softWrap ? largura : double.infinity);
  }
}
