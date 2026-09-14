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
          Expanded(
            child: vm.emBusca || vm.soFavoritos
                ? ListView(
                    children: [
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
                : _arvore(context, vm.grupos),
          ),
        ],
      ),
    );
  }

  Widget _arvore(BuildContext context, Map<String, Map<String, List<Hino>>> grupos) {
    return ListView(
      children: [
        for (final autor in grupos.keys)
          ExpansionTile(
            title: Text(autor),
            subtitle: Text('${grupos[autor]!.values.fold<int>(0, (a, l) => a + l.length)} hinos'),
            children: [
              for (final hinario in grupos[autor]!.keys)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book),
                  title: Text(hinario),
                  subtitle: Text('${grupos[autor]![hinario]!.length} hinos'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider(
                        create: (_) => HinarioViewModel(
                          hinos: grupos[autor]![hinario]!,
                          autor: autor,
                          hinario: hinario,
                        ),
                        child: HinarioView(autor: autor, hinario: hinario),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
