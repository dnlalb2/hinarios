// lib/ui/core/widgets/bloco_hino.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/models/cifra_local.dart';
import '../../../domain/models/hino.dart';
import '../../../domain/use_cases/alinhamento.dart';
import '../../../domain/use_cases/chordpro.dart';
import '../../../domain/use_cases/transposicao.dart';
import '../cifras_locais_view_model.dart';
import '../preferencias_view_model.dart';
import 'linha_acordes.dart';
import '../../features/hino/editor_cifra_view.dart';
import '../../features/hino/partitura.dart';

class BlocoHino extends StatelessWidget {
  final Hino hino;
  const BlocoHino({super.key, required this.hino});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreferenciasViewModel>();
    final shift = vm.deslocamentoDe(hino.slug);
    final tamanhoFonte = vm.tamanhoFonte;
    // Cifra própria do usuário tem precedência sobre a oficial: foi ele quem
    // a escreveu para ESTE hino (removê-la devolve a oficial, quando existe).
    final local = context.watch<CifrasLocaisViewModel>().cifraDe(hino.slug);
    final (cifra, letra) = _efetivas(hino, local);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${hino.num}. ${hino.nome}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: tamanhoFonte + 2)),
                ),
                IconButton(
                  icon: Icon(vm.favoritos.contains(hino.slug) ? Icons.star : Icons.star_border),
                  tooltip: 'Favorito',
                  onPressed: () => vm.toggleFavorito(hino.slug),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in [hino.ritmo, hino.autor, hino.hinario].where((t) => t.isNotEmpty))
                  Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (hino.abc != null)
                  IconButton(
                    icon: const Icon(Icons.music_note, size: 20),
                    tooltip: 'Partitura',
                    onPressed: () => abrirPartitura(context, hino),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (cifra != null)
              Row(
                children: [
                  Text('Cifra em ',
                      style: TextStyle(fontSize: tamanhoFonte * 0.8, color: Theme.of(context).hintColor)),
                  Text(transporAcorde(cifra.tom, shift),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Meio tom abaixo',
                    onPressed: () => vm.transpor(hino.slug, -1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Meio tom acima',
                    onPressed: () => vm.transpor(hino.slug, 1),
                  ),
                  if (local != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar cifra',
                      onPressed: () => abrirEditorCifra(context, hino),
                    ),
                ],
              ),
            if (cifra != null) ..._linhasCifra(context, cifra, letra, shift, tamanhoFonte),
            const SizedBox(height: 6),
            // Com cifra, a letra já aparece intercalada com os acordes —
            // renderizar de novo duplicaria a música inteira.
            if (cifra == null) ...[
              Text(letra, style: TextStyle(fontSize: tamanhoFonte, height: 1.5)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.music_note, size: 18),
                  label: const Text('Adicionar cifra'),
                  onPressed: () => abrirEditorCifra(context, hino),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Cifra a exibir e a letra que ela acompanha. Cifra própria do usuário tem
  /// precedência sobre a oficial e entra no MESMO pipeline (alinhar → render →
  /// transpor) das do acervo: o ChordPro vira (letra limpa, linha de acordes
  /// posicional) aqui, uma vez. Com cifra própria a letra exibida é a do
  /// usuário — a que ele escreveu no editor —, não a do acervo.
  static (Cifra?, String) _efetivas(Hino hino, CifraLocal? local) {
    if (local == null) return (hino.cifra, hino.letra);
    final linhas = parsearChordPro(local.textoChordPro(hino.letra));
    return (
      Cifra(
        tom: local.tom,
        texto: [for (final l in linhas) l.acordes].join(';'),
      ),
      [for (final l in linhas) l.letra].join('\n'),
    );
  }

  List<Widget> _linhasCifra(
      BuildContext context, Cifra cifra, String letra, int shift, double tamanhoFonte) {
    // Cifra e letra usam a MESMA métrica: mesma família monoespaçada, mesmo
    // tamanho (escolhido em Configurações) e mesma altura de linha. Assim uma
    // coluna da linha de acordes é exatamente uma coluna da linha de letra e o
    // acorde fica sobre a sílaba — inclusive com os espaços de posicionamento
    // digitados no formulário.
    // letterSpacing 0 explícito: o bodyMedium do tema traz 0.25, um pitch
    // DIFERENTE do letterSpacing 0 da régua/campo do editor — a coluna N da
    // exibição anda 0.25px por caractere em relação ao preview do formulário
    // (o "sai um pouco para a esquerda" que o usuário via). Zero dos dois
    // lados = mesma coluna no formulário e na exibição.
    final estiloAcorde = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: tamanhoFonte,
          height: 1.4,
          letterSpacing: 0,
        );
    final estiloLetra = estiloAcorde.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w400,
    );
    return [
      for (final par in alinhar(letra, cifra.texto))
        if (par.texto.isNotEmpty || par.acordes != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (par.acordes != null)
                LinhaAcordes(
                  texto: par.acordes!.split(' ').map((a) => transporAcorde(a, shift)).join(' '),
                  estilo: estiloAcorde,
                ),
              Text(par.texto, style: estiloLetra),
            ],
          ),
    ];
  }
}
