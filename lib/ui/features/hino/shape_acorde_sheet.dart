// lib/ui/features/hino/shape_acorde_sheet.dart
import 'package:flutter/material.dart';
import '../../../data/services/acordes_service.dart';
import '../../../domain/models/acorde_shape.dart';
import 'diagrama_acorde.dart';

/// Chave do título da folha: é ele que diz QUAL acorde está desenhado (o
/// mesmo nome aparece na cifra atrás da folha, então o teste precisa dos dois).
const Key chaveTituloAcorde = Key('acorde-titulo');

/// Abre a folha com o desenho do [acorde] no braço do violão. O acorde vem da
/// cifra, já transposto: 'Bm', 'D/F#', 'Bm7/5-' — a folha só mostra, quem
/// traduz o nome para o acervo é o [AcordesService].
void abrirShapeAcorde(BuildContext context, String acorde) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // O desenho pede altura de verdade: sem isto a folha fica presa nos 9/16
    // da tela e o violão sai cortado em tela baixa (o conteúdo rola).
    isScrollControlled: true,
    builder: (_) => _FolhaShapeAcorde(acorde: acorde),
  );
}

class _FolhaShapeAcorde extends StatefulWidget {
  final String acorde;
  const _FolhaShapeAcorde({required this.acorde});

  @override
  State<_FolhaShapeAcorde> createState() => _FolhaShapeAcordeState();
}

class _FolhaShapeAcordeState extends State<_FolhaShapeAcorde> {
  // Carrega uma vez só: trocar de posição não volta ao asset.
  final Future<Map<String, List<AcordeShape>>> _acervo =
      AcordesService.instancia.carregar();
  int _posicao = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: FutureBuilder<Map<String, List<AcordeShape>>>(
          future: _acervo,
          builder: (context, snap) {
            final posicoes = snap.hasData
                ? AcordesService.posicoesDe(snap.data!, widget.acorde)
                : const <AcordeShape>[];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.acorde,
                    key: chaveTituloAcorde,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // Enquanto o asset não chega: espaço do mesmo tamanho, sem
                  // pular a folha na tela.
                  if (!snap.hasData)
                    const SizedBox(
                      height: 216,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (posicoes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('Posição não disponível para este acorde'),
                    )
                  else ...[
                    DiagramaAcorde(shape: posicoes[_posicao], largura: 200),
                    if (posicoes.length > 1)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Posição anterior',
                            onPressed: _posicao > 0
                                ? () => setState(() => _posicao--)
                                : null,
                          ),
                          Text('${_posicao + 1}/${posicoes.length}'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Próxima posição',
                            onPressed: _posicao < posicoes.length - 1
                                ? () => setState(() => _posicao++)
                                : null,
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Posições: chords-db (MIT)',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
