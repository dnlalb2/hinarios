// lib/ui/features/biblioteca/biblioteca_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/bloco_hino.dart';
import '../../../data/repositories/hinos_repository.dart';
import '../../../domain/models/hino.dart';
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
        title: const Text('Hinário Cifrado CSJ'),
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
                      // Busca: resultados compactos (a letra inteira inundava a
                      // tela). Só o modo favoritos sem busca lista os hinos
                      // completos — ali a intenção é ler, não procurar.
                      if (vm.emBusca)
                        ..._secaoHinos(context, vm)
                      else
                        for (final r in vm.resultados)
                          InkWell(
                            onTap: () => _abrirHino(context, r.hino),
                            child: BlocoHino(hino: r.hino),
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

  /// Seção "Hinos (n)": os resultados da busca, um [ListTile] compacto cada —
  /// no lugar do bloco inteiro de letra/cifra que existia antes.
  List<Widget> _secaoHinos(BuildContext context, BibliotecaViewModel vm) {
    final resultados = vm.resultados;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text('Hinos (${resultados.length})',
            style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final r in resultados) _resultado(context, r),
    ];
  }

  /// Um resultado compacto: hino (num. nome), autor · hinário e — quando o
  /// casamento veio da letra — o trecho com o termo em destaque.
  Widget _resultado(BuildContext context, ResultadoBusca r) {
    final trecho = r.trecho;
    final inicio = r.destaqueInicio;
    final fim = r.destaqueFim;
    return ListTile(
      title: Text('${r.hino.num}. ${r.hino.nome}'),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.hino.autor} · ${r.hino.hinario}'),
          if (trecho != null && inicio != null && fim != null)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: trecho.substring(0, inicio)),
                TextSpan(
                  text: trecho.substring(inicio, fim),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: trecho.substring(fim)),
              ]),
              // Trecho longo não estica a linha: 2 linhas e reticências.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: () => _abrirHino(context, r.hino),
    );
  }

  /// Abre a página do hino (mesma navegação dos outros pontos da biblioteca).
  void _abrirHino(BuildContext context, Hino hino) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => HinoViewModel(
            hinos: context.read<HinosRepository>(),
            hino: hino,
          ),
          child: const HinoView(),
        ),
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
            // Contagem do AUTOR: os hinos dele, não o total global dos grupos
            // (num coletivo ele pode ter 1 de 43). Mesma normalização da
            // chave de [agrupar]: autor vazio vira 'Sem autor'.
            subtitle: Text(
                '${grupos[autor]!.expand((g) => g.hinos).where((h) => (h.autor.isEmpty ? 'Sem autor' : h.autor) == autor).length} hinos'),
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
