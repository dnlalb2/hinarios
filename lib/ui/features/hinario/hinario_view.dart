// lib/ui/features/hinario/hinario_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/bloco_hino.dart';
import '../../core/widgets/pinca_fonte.dart';
import '../configuracao/configuracao_view.dart';
import 'hinario_view_model.dart';

class HinarioView extends StatelessWidget {
  final String autor;
  final String hinario;
  const HinarioView({super.key, required this.autor, required this.hinario});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HinarioViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(hinario),
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
      body: PincaFonte(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('$autor · ${vm.hinos.length} hinos',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            for (final h in vm.hinos) BlocoHino(hino: h),
          ],
        ),
      ),
    );
  }
}
