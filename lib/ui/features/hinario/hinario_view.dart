// lib/ui/features/hinario/hinario_view.dart
import 'package:flutter/material.dart';
// ScrollDirection não vem no material.dart (mora no rendering).
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../core/preferencias_view_model.dart';
import '../../core/widgets/bloco_hino.dart';
import '../../core/widgets/pinca_fonte.dart';
import '../configuracao/configuracao_view.dart';
import 'hinario_view_model.dart';

class HinarioView extends StatefulWidget {
  final String autor;
  final String hinario;
  const HinarioView({super.key, required this.autor, required this.hinario});

  @override
  State<HinarioView> createState() => _HinarioViewState();
}

class _HinarioViewState extends State<HinarioView> {
  /// Texto do campo de busca. O estado de verdade é do [HinarioViewModel] —
  /// o controller existe só para o botão de limpar poder esvaziar o campo
  /// (mesmo padrão da BibliotecaView).
  final _buscaCtrl = TextEditingController();

  /// A busca interna está à mostra? Rolar a lista para baixo esconde, rolar
  /// para cima traz de volta — o mesmo comportamento dos filtros da
  /// BibliotecaView.
  bool _mostrarBusca = true;

  /// Última consulta vista pelo [build]: mudar a busca por fora do gesto (o X
  /// do campo, por exemplo) reexibe o campo, que a rolagem tinha escondido.
  String? _ultimaQuery;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HinarioViewModel>();
    final pref = context.watch<PreferenciasViewModel>();
    final filtrando = vm.query.isNotEmpty;
    final hinos = vm.hinosFiltrados;
    // Busca nova (digitada, limpa pelo X): o campo volta, mesmo que o usuário
    // o tenha escondido rolando. Atribuição direta — já estamos no build que
    // vai desenhar o resultado.
    if (_ultimaQuery != vm.query) {
      _ultimaQuery = vm.query;
      _mostrarBusca = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hinario),
        actions: [
          IconButton(
            icon: Icon(pref.hinariosFavoritos.contains(vm.chave)
                ? Icons.star
                : Icons.star_border),
            tooltip: 'Favoritar hinário',
            onPressed: () => pref.toggleFavoritoHinario(vm.chave),
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
      body: PincaFonte(
        child: Column(
          children: [
            // Busca interna: encolhe a zero quando o usuário rola a lista para
            // baixo e volta quando ele rola para cima. O campo segue MONTADO —
            // o ClipRect só corta o que passa da altura 0, e o texto digitado
            // (e o foco) sobrevivem ao sumiço.
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                heightFactor: _mostrarBusca ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Column(
                  // O pai (Column do body) dá altura ilimitada: sem o min o
                  // Column interno tentaria ocupar o infinito.
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: TextField(
                        controller: _buscaCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Buscar neste hinário…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: filtrando
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Limpar busca',
                                  onPressed: () {
                                    _buscaCtrl.clear();
                                    vm.setQuery('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: vm.setQuery,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              // Só gesto do USUÁRIO esconde a busca: rolagem programática não
              // emite UserScrollNotification.
              child: NotificationListener<UserScrollNotification>(
                onNotification: (n) {
                  if (n.direction == ScrollDirection.reverse && _mostrarBusca) {
                    setState(() => _mostrarBusca = false);
                  } else if (n.direction == ScrollDirection.forward &&
                      !_mostrarBusca) {
                    setState(() => _mostrarBusca = true);
                  }
                  return false;
                },
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        // Buscando, o cabeçalho mostra quantos dos hinos do
                        // hinário sobraram ('3 de 160 hinos').
                        filtrando
                            ? '${widget.autor} · ${hinos.length} de ${vm.hinos.length} hinos'
                            : '${widget.autor} · ${vm.hinos.length} hinos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (filtrando && hinos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        child: Center(
                          child: Text('Nenhum hino encontrado',
                              style:
                                  TextStyle(color: Theme.of(context).hintColor)),
                        ),
                      )
                    else
                      for (final h in hinos) BlocoHino(hino: h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
