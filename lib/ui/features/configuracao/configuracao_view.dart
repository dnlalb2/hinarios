// lib/ui/features/configuracao/configuracao_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/preferencias_view_model.dart';

class ConfiguracaoView extends StatelessWidget {
  const ConfiguracaoView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreferenciasViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tema escuro'),
            subtitle: const Text('Mais confortável na cerimônia'),
            value: vm.temaEscuro,
            onChanged: (_) => vm.toggleTema(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tamanho da fonte: ${vm.tamanhoFonte.toStringAsFixed(1)}'),
                Slider(
                  value: vm.tamanhoFonte,
                  min: 12,
                  max: 28,
                  divisions: 32,
                  label: vm.tamanhoFonte.toStringAsFixed(1),
                  onChanged: vm.setTamanhoFonte,
                ),
                Text('Pré-visualização',
                    style: TextStyle(
                        fontSize: vm.tamanhoFonte,
                        fontWeight: FontWeight.bold,
                        height: 1.5)),
                Text('Letra e cifra acompanham o tamanho escolhido.',
                    style: TextStyle(fontSize: vm.tamanhoFonte, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
