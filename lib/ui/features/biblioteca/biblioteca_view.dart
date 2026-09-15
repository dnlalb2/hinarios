// lib/ui/features/biblioteca/biblioteca_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/bloco_hino.dart';
import '../../../data/repositories/hinos_repository.dart';
import '../../core/preferencias_view_model.dart';
import '../hinario/hinario_view.dart';
import '../hinario/hinario_view_model.dart';
import '../hino/hino_view.dart';
import '../hino/hino_view_model.dart';
import '../configuracao/configuracao_view.dart';
import 'biblioteca_view_model.dart';

class BibliotecaView extends StatelessWidget {
  const BibliotecaView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BibliotecaViewModel>();
    context.watch<PreferenciasViewModel>(); // favoritos mudam os resultados filtrados

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hinários'),
        actions: [
          IconButton(
            icon: Icon(vm.soFavoritos ? Icons.star : Icons.star_border),
            tooltip: 'Favoritos',
            onPressed: vm.toggleSoFavoritos,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracaoView()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar hino, autor ou palavra da letra…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: vm.setQuery,
            ),
          ),
          // Seletor de visão: só quando a lista de navegação está visível.
          if (!(vm.emBusca || vm.soFavoritos))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: true, label: Text('Autores')),
                    ButtonSegment(value: false, label: Text('Hinários')),
                  ],
                  selected: {vm.visaoPorAutor},
                  onSelectionChanged: (_) => vm.alternarVisao(),
                ),
              ),
            ),
          Expanded(
            child: vm.emBusca || vm.soFavoritos
                ? ListView(
                    children: [
                      ..._secaoHinarios(context, vm),
                      for (final h in vm.resultados)
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider(
                                create: (_) => HinoViewModel(
                                  hinos: context.read<HinosRepository>(),
                                  hino: h,
                                ),
                                child: const HinoView(),
                              ),
                            ),
                          ),
                          child: BlocoHino(hino: h),
                        ),
                    ],
                  )
                : vm.visaoPorAutor
                    ? _arvore(context, vm.grupos)
                    : _listaDeHinarios(context, vm.gruposHinarios),
          ),
        ],
      ),
    );
  }

  /// Hinários que casam com a busca, acima dos hinos soltos. Só na busca
  /// (não no filtro "só favoritos") e quando há grupos.
  List<Widget> _secaoHinarios(BuildContext context, BibliotecaViewModel vm) {
    if (!vm.emBusca || vm.soFavoritos) return const [];
    final grupos = vm.hinariosEncontrados;
    if (grupos.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text('Hinários', style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final grupo in grupos)
        ListTile(
          leading: const Icon(Icons.menu_book),
          title: Text(grupo.rotulo),
          subtitle: Text('${grupo.autor} · ${grupo.hinos.length} hinos'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => HinarioViewModel(
                  hinos: grupo.hinos,
                  autor: grupo.autor,
                  hinario: grupo.rotulo,
                ),
                child: HinarioView(autor: grupo.autor, hinario: grupo.rotulo),
              ),
            ),
          ),
        ),
      const Divider(),
    ];
  }

  /// Árvore por autor: cada ExpansionTile lista os hinários GLOBAIS em que o
  /// autor tem ao menos um hino. Os grupos são os mesmos da lista plana — um
  /// coletivo aparece sob cada autor envolvido e abre o hinário completo.
  Widget _arvore(BuildContext context, Map<String, List<GrupoHinario>> grupos) {
    return ListView(
      children: [
        for (final autor in grupos.keys)
          ExpansionTile(
            title: Text(autor),
            subtitle: Text(
                '${grupos[autor]!.fold<int>(0, (a, g) => a + g.hinos.length)} hinos'),
            children: [
              for (final g in grupos[autor]!)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book),
                  title: Text(g.rotulo),
                  // O autor já é o cabeçalho do ExpansionTile — não se repete.
                  subtitle: Text('${g.hinos.length} hinos'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider(
                        create: (_) => HinarioViewModel(
                          hinos: g.hinos,
                          autor: g.autor,
                          hinario: g.rotulo,
                        ),
                        child: HinarioView(autor: g.autor, hinario: g.rotulo),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Visão "Hinários": todos os grupos achatados numa lista alfabética pelo
  /// rótulo (o autor vira subtítulo). Navega para o mesmo [HinarioView] da árvore.
  Widget _listaDeHinarios(BuildContext context, List<GrupoHinario> grupos) {
    return ListView(
      children: [
        for (final g in grupos)
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(g.rotulo),
            subtitle: Text('${g.autor} · ${g.hinos.length} hinos'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => HinarioViewModel(
                    hinos: g.hinos,
                    autor: g.autor,
                    hinario: g.rotulo,
                  ),
                  child: HinarioView(autor: g.autor, hinario: g.rotulo),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
