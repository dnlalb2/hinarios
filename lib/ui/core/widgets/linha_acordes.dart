// lib/ui/core/widgets/linha_acordes.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../features/hino/shape_acorde_sheet.dart';

/// Uma linha de acordes da cifra (já transposta) em que cada acorde é
/// tocável: o toque abre o desenho do violão (ver [abrirShapeAcorde]).
///
/// O texto é o MESMO de antes — um Text comum com um TextSpan por token,
/// espaços inclusive. A coluna de cada acorde não muda (o alinhamento com a
/// letra depende disso) e o texto puro do parágrafo continua idêntico, então
/// extensões e testes que leem a linha seguem valendo.
class LinhaAcordes extends StatefulWidget {
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
  State<LinhaAcordes> createState() => _LinhaAcordesState();
}

class _LinhaAcordesState extends State<LinhaAcordes> {
  // Cada acorde tocável tem o SEU reconhecedor; todos são descartados quando a
  // linha é reconstruída ou sai da tela — sem isso o gesto vaza (e o teste de
  // memória do Flutter acusa).
  final List<TapGestureRecognizer> _reconhecedores = [];
  late TextSpan _span;

  @override
  void initState() {
    super.initState();
    _span = _montar();
  }

  @override
  void didUpdateWidget(LinhaAcordes antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.texto != widget.texto) {
      _descartarReconhecedores();
      _span = _montar();
    }
  }

  @override
  void dispose() {
    _descartarReconhecedores();
    super.dispose();
  }

  void _descartarReconhecedores() {
    for (final r in _reconhecedores) {
      r.dispose();
    }
    _reconhecedores.clear();
  }

  TextSpan _montar() {
    final filhos = <TextSpan>[];
    for (final token in LinhaAcordes._tokens.allMatches(widget.texto)) {
      final texto = token[0]!;
      if (!LinhaAcordes.inicioDeAcorde.hasMatch(texto)) {
        filhos.add(TextSpan(text: texto));
        continue;
      }
      final reconhecedor = TapGestureRecognizer()
        ..onTap = () => abrirShapeAcorde(context, texto);
      _reconhecedores.add(reconhecedor);
      filhos.add(TextSpan(text: texto, recognizer: reconhecedor));
    }
    return TextSpan(children: filhos);
  }

  @override
  Widget build(BuildContext context) =>
      Text.rich(_span, style: widget.estilo);
}
