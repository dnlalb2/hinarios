// lib/ui/features/hinario/hinario_view.dart
import 'package:flutter/material.dart';
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: vm.setQuery,
              ),
            ),
            Expanded(
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Center(
                        child: Text('Nenhum hino encontrado',
                            style: TextStyle(color: Theme.of(context).hintColor)),
                      ),
                    )
                  else
                    for (final h in hinos) BlocoHino(hino: h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
