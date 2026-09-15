// lib/ui/features/hino/hino_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/bloco_hino.dart';
import '../configuracao/configuracao_view.dart';
import '../hinario/hinario_view.dart';
import '../hinario/hinario_view_model.dart';
import 'hino_view_model.dart';

class HinoView extends StatelessWidget {
  const HinoView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HinoViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(vm.hino.nome),
        actions: [
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
      body: ListView(
        children: [
          BlocoHino(hino: vm.hino),
          if (vm.doHinario.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => HinarioViewModel(
                        hinos: vm.doHinario,
                        autor: vm.hino.autor,
                        hinario: vm.hino.hinario,
                      ),
                      child: HinarioView(
                        autor: vm.hino.autor,
                        hinario: vm.hino.hinario,
                      ),
                    ),
                  ),
                ),
                child: const Text('ver no hinário'),
              ),
            ),
        ],
      ),
    );
  }
}
