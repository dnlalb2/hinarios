// lib/ui/features/configuracao/configuracao_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/arquivo.dart';
import '../../core/cifras_locais_view_model.dart';
import '../../core/preferencias_view_model.dart';

class ConfiguracaoView extends StatelessWidget {
  const ConfiguracaoView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreferenciasViewModel>();
    final cifras = context.watch<CifrasLocaisViewModel>();
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Minhas cifras',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('${cifras.cifras.length} cifra(s) criada(s) neste aparelho'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download),
                      label: const Text('Exportar cifras'),
                      // Sem cifras locais não há o que exportar.
                      onPressed: cifras.cifras.isEmpty
                          ? null
                          : () {
                              baixarTexto(
                                  'cifras-hinario-csj.json', cifras.exportarJson());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Cifras exportadas')),
                              );
                            },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Importar cifras'),
                      onPressed: () => _importar(context, cifras),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Letras e cifras extraídas de estudofino.org — uso comunitário.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Fora da web (Android/iOS) o seletor devolve null e nada acontece.
  static Future<void> _importar(
      BuildContext context, CifrasLocaisViewModel cifras) async {
    // Capturado antes do await para não usar o context depois do gap.
    final messenger = ScaffoldMessenger.of(context);
    final texto = await escolherArquivoTexto();
    if (texto == null) return;
    try {
      final n = cifras.importar(texto);
      messenger.showSnackBar(SnackBar(content: Text('$n cifras importadas')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Arquivo inválido')),
      );
    }
  }
}
