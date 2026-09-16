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

class BibliotecaView extends StatefulWidget {
  const BibliotecaView({super.key});

  @override
  State<BibliotecaView> createState() => _BibliotecaViewState();
}

class _BibliotecaViewState extends State<BibliotecaView> {
  /// Texto do campo de busca. O estado de verdade é do [BibliotecaViewModel] —
  /// o controller existe só para o botão de limpar poder esvaziar o campo.
  final _buscaCtrl = TextEditingController();

  /// Rolagem da lista de conteúdo do Expanded: resultados da busca, árvore por
  /// autor ou lista plana de hinários — a MESMA instância nas três (o widget
  /// troca, o controller não). Com controller próprio a lista não se pendura no
  /// [PrimaryScrollController]; `keepScrollOffset: false` porque a posição não
  /// deve ser lembrada entre visitas ao mesmo modo.
  final _scrollCtrl = ScrollController(keepScrollOffset: false);

  /// Chave da lista do Expanded: a assinatura do conteúdo exibido —
  /// (`emBusca`, `query`, `visaoPorAutor`, `soFavoritos`). Trocar a busca, a
  /// visão ou o filtro troca a chave, e o Flutter descarta a lista antiga
  /// inteira: a nova monta do zero, já no topo.
  ///
  /// Rolar de volta ao topo ([jumpTo]) depois da troca não serve: o
  /// [SliverList] da lista antiga guarda filhos em cache na altura anterior e
  /// o layout seguinte "corrige" o offset em alguns pixels, parando pouco
  /// abaixo do zero. Elemento novo não tem cache velho — e o topo é exato.
  /// A chave só muda quando o conteúdo muda de modo: favoritar, rolar ou
  /// redimensionar a tela preservam a posição. O record é comparado por valor
  /// ([ValueKey]), não por identidade: cada build cria um record novo.
  ValueKey<(bool, String, bool, bool)> _chaveDaLista(BibliotecaViewModel vm) =>
      ValueKey((vm.emBusca, vm.query, vm.visaoPorAutor, vm.soFavoritos));

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BibliotecaViewModel>();
    // Favoritos (hinos e hinários) mudam os resultados filtrados e as estrelas.
    final pref = context.watch<PreferenciasViewModel>();
    final chave = _chaveDaLista(vm);

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
              controller: _buscaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar hino, autor ou palavra da letra…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: vm.emBusca
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _buscaCtrl.clear();
                          vm.setQuery('');
                        },
                      )
                    : null,
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
                    ButtonSegment(value: false, label: Text('Hinários')),
                    ButtonSegment(value: true, label: Text('Autores')),
                  ],
                  selected: {vm.visaoPorAutor},
                  onSelectionChanged: (_) => vm.alternarVisao(),
                ),
              ),
            ),
          Expanded(
            child: vm.emBusca || vm.soFavoritos
                ? ListView(
                    key: chave,
                    controller: _scrollCtrl,
                    children: [
                      ..._secaoHinarios(context, vm, pref),
                      // Favoritos sem busca: os hinários estrelados vêm antes,
                      // como seção de leitura.
                      ..._secaoHinariosFavoritos(context, vm, pref),
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
                    ? _arvore(context, vm.grupos, pref, chave)
                    : _listaDeHinarios(context, vm.gruposHinarios, pref, chave),
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
      _cabecalho(context, 'Hinos (${resultados.length})'),
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

  /// Cabeçalho de seção da lista ('Hinários', 'Hinos (n)').
  Widget _cabecalho(BuildContext context, String titulo) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(titulo, style: Theme.of(context).textTheme.titleSmall),
      );

  /// Tile de um hinário (grupo global) na árvore, na lista plana e nas seções
  /// de busca/favoritos: abre o hinário completo e traz a estrela que
  /// favorita o grupo inteiro sem precisar abri-lo.
  Widget _tileHinario(
    BuildContext context,
    PreferenciasViewModel pref,
    GrupoHinario grupo, {
    required String subtitulo,
    bool dense = false,
  }) {
    return ListTile(
      dense: dense,
      leading: const Icon(Icons.menu_book),
      title: Text(grupo.rotulo),
      subtitle: Text(subtitulo),
      trailing: IconButton(
        icon: Icon(pref.hinariosFavoritos.contains(grupo.chave)
            ? Icons.star
            : Icons.star_border),
        tooltip: 'Favoritar hinário',
        onPressed: () => pref.toggleFavoritoHinario(grupo.chave),
      ),
      onTap: () => _abrirHinario(context, grupo),
    );
  }

  /// Abre a página do hinário completo do grupo (mesma navegação em toda a
  /// biblioteca). O grupo vai inteiro: o [HinarioViewModel] recebe também a
  /// chave, que a estrela da AppBar usa para favoritar o HINÁRIO.
  void _abrirHinario(BuildContext context, GrupoHinario grupo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => HinarioViewModel(
            hinos: grupo.hinos,
            autor: grupo.autor,
            hinario: grupo.rotulo,
            chave: grupo.chave,
          ),
          child: HinarioView(autor: grupo.autor, hinario: grupo.rotulo),
        ),
      ),
    );
  }

  /// Hinários que casam com a busca, acima dos hinos soltos. Só na busca
  /// (não no filtro "só favoritos") e quando há grupos.
  List<Widget> _secaoHinarios(
      BuildContext context, BibliotecaViewModel vm, PreferenciasViewModel pref) {
    if (!vm.emBusca || vm.soFavoritos) return const [];
    final grupos = vm.hinariosEncontrados;
    if (grupos.isEmpty) return const [];
    return [
      _cabecalho(context, 'Hinários'),
      for (final grupo in grupos)
        _tileHinario(context, pref, grupo,
            subtitulo: '${grupo.autor} · ${grupo.hinos.length} hinos'),
      const Divider(),
    ];
  }

  /// Seção 'Hinários' do modo favoritos (sem busca): os grupos estrelados,
  /// abertos pelo tile completo. Sem nenhum favoritado, a seção nem aparece —
  /// a tela fica só com os hinos favoritos, como antes.
  List<Widget> _secaoHinariosFavoritos(
      BuildContext context, BibliotecaViewModel vm, PreferenciasViewModel pref) {
    if (!vm.soFavoritos || vm.emBusca) return const [];
    final grupos = [
      for (final g in vm.gruposHinarios)
        if (pref.hinariosFavoritos.contains(g.chave)) g,
    ];
    if (grupos.isEmpty) return const [];
    return [
      _cabecalho(context, 'Hinários'),
      for (final grupo in grupos)
        _tileHinario(context, pref, grupo,
            subtitulo: '${grupo.autor} · ${grupo.hinos.length} hinos'),
      const Divider(),
    ];
  }

  /// Árvore por autor: cada ExpansionTile lista os hinários GLOBAIS em que o
  /// autor tem ao menos um hino. Os grupos são os mesmos da lista plana — um
  /// coletivo aparece sob cada autor envolvido e abre o hinário completo.
  Widget _arvore(BuildContext context, Map<String, List<GrupoHinario>> grupos,
      PreferenciasViewModel pref, Key chave) {
    return ListView(
      key: chave,
      controller: _scrollCtrl,
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
                _tileHinario(context, pref, g,
                    // O autor já é o cabeçalho do ExpansionTile — não se repete.
                    subtitulo: '${g.hinos.length} hinos',
                    dense: true),
            ],
          ),
      ],
    );
  }

  /// Visão "Hinários": todos os grupos achatados numa lista alfabética pelo
  /// rótulo (o autor vira subtítulo). Navega para o mesmo [HinarioView] da árvore.
  Widget _listaDeHinarios(BuildContext context, List<GrupoHinario> grupos,
      PreferenciasViewModel pref, Key chave) {
    return ListView(
      key: chave,
      controller: _scrollCtrl,
      children: [
        for (final g in grupos)
          _tileHinario(context, pref, g,
              subtitulo: '${g.autor} · ${g.hinos.length} hinos'),
      ],
    );
  }
}
