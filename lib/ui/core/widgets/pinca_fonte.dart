// lib/ui/core/widgets/pinca_fonte.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../preferencias_view_model.dart';

/// Ajusta o tamanho da fonte com pinça (2 dedos). A rolagem de 1 dedo
/// continua funcionando: o recognizer só processa o gesto quando há 2+
/// ponteiros, então a arena de gestos deixa o scroll vencer com 1 dedo.
class PincaFonte extends StatefulWidget {
  final Widget child;
  const PincaFonte({super.key, required this.child});

  @override
  State<PincaFonte> createState() => _PincaFonteState();
}

/// [ScaleGestureRecognizer] que não reivindica o arrasto de 1 dedo.
///
/// Só os MOVIMENTOS de um dedo são descartados. Down/up/cancel seguem para o
/// `super` porque `pointerCount` é derivado da fila interna de ponteiros
/// (`_pointerQueue`), alimentada apenas dentro de `handleEvent`: descartar
/// também os downs deixaria `pointerCount` preso em 0 e a pinça nunca
/// começaria. Como nenhum evento de 1 dedo chega a `_advanceStateMachine`,
/// não há `resolve(accepted)` e o scroll do ListView vence a arena.
class _PincaRecognizer extends ScaleGestureRecognizer {
  @override
  void handleEvent(PointerEvent event) {
    if (pointerCount < 2 && event is PointerMoveEvent) return;
    super.handleEvent(event);
  }
}

class _PincaFonteState extends State<PincaFonte> {
  /// Faixa aceita pelo Slider de Configurações e por PreferenciasService.
  static const _fonteMinima = 12.0;
  static const _fonteMaxima = 28.0;

  /// Fonte antes da pinça: a escala do gesto é sempre relativa a ela.
  double _base = 16;
  double _fonteVisivel = 16;
  bool _gestoAtivo = false;

  void _iniciar(ScaleStartDetails _) {
    final vm = context.read<PreferenciasViewModel>();
    _base = vm.tamanhoFonte;
    setState(() {
      _fonteVisivel = vm.tamanhoFonte;
      _gestoAtivo = true;
    });
  }

  void _atualizar(ScaleUpdateDetails detalhes) {
    if (!mounted) return;
    final vm = context.read<PreferenciasViewModel>();
    final nova = (_base * detalhes.scale).clamp(_fonteMinima, _fonteMaxima);
    vm.setTamanhoFonte(nova);
    setState(() => _fonteVisivel = nova);
  }

  void _encerrar(ScaleEndDetails _) {
    if (!mounted) return;
    setState(() => _gestoAtivo = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Expand: o filho recebe as mesmas restrições que receberia sem a
      // PincaFonte. Com StackFit.loose um scroll que se dimensiona pelo
      // conteúdo (ex.: SingleChildScrollView) encolheria e ficaria sem área
      // de toque.
      fit: StackFit.expand,
      children: [
        RawGestureDetector(
          // Opaque: pega a pinça também nas áreas vazias abaixo dos blocos.
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _PincaRecognizer:
                GestureRecognizerFactoryWithHandlers<_PincaRecognizer>(
              _PincaRecognizer.new,
              (r) => r
                ..onStart = _iniciar
                ..onUpdate = _atualizar
                ..onEnd = _encerrar,
            ),
          },
          child: widget.child,
        ),
        if (_gestoAtivo) _indicador(context),
      ],
    );
  }

  /// Aviso discreto do valor atual enquanto os dedos estão na tela.
  Widget _indicador(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cores.inverseSurface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Fonte: ${_fonteVisivel.round()}',
              style: TextStyle(
                color: cores.onInverseSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
