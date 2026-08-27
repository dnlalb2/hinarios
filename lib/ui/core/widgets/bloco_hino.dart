// lib/ui/core/widgets/bloco_hino.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/models/hino.dart';
import '../../../domain/use_cases/alinhamento.dart';
import '../../../domain/use_cases/transposicao.dart';
import '../preferencias_view_model.dart';
import '../../features/hino/partitura.dart';

class BlocoHino extends StatelessWidget {
  final Hino hino;
  const BlocoHino({super.key, required this.hino});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreferenciasViewModel>();
    final shift = vm.deslocamentoDe(hino.slug);
    final tamanhoFonte = vm.tamanhoFonte;

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
            if (hino.cifra != null)
              Row(
                children: [
                  Text('Cifra em ',
                      style: TextStyle(fontSize: tamanhoFonte * 0.8, color: Theme.of(context).hintColor)),
                  Text(transporAcorde(hino.cifra!.tom, shift),
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
                ],
              ),
            if (hino.cifra != null) ..._linhasCifra(context, hino, shift),
            const SizedBox(height: 6),
            Text(hino.letra, style: TextStyle(fontSize: tamanhoFonte, height: 1.5)),
          ],
        ),
      ),
    );
  }

  List<Widget> _linhasCifra(BuildContext context, Hino hino, int shift) {
    final estilo = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        );
    return [
      for (final par in alinhar(hino.letra, hino.cifra!.texto))
        if (par.texto.isNotEmpty || par.acordes != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (par.acordes != null)
                Text(
                  par.acordes!.split(' ').map((a) => transporAcorde(a, shift)).join(' '),
                  style: estilo,
                ),
              Text(par.texto, style: TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
    ];
  }
}
