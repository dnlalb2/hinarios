// lib/ui/core/widgets/precache_gate.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../precache_view_model.dart';

/// Cobre o app com a tela de preparação enquanto o acervo offline baixa.
///
/// Fica no topo da `home` e observa o [PrecacheViewModel]: quando não há nada
/// para mostrar (já baixou, não se aplica ou o usuário dispensou), devolve o
/// [child] puro, sem nenhum widget extra na árvore. Enquanto mostra, o app
/// segue montado embaixo — a opacidade é que esconde — para o usuário cair
/// direto na biblioteca quando a tela sair.
class PrecacheGate extends StatelessWidget {
  const PrecacheGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PrecacheViewModel>();
    if (!vm.mostrar) return child;

    final tema = Theme.of(context);
    final progresso = vm.total == 0
        ? null // ainda contando os arquivos: barra indefinida
        : (vm.baixados / vm.total).clamp(0.0, 1.0);
    return Stack(
      children: [
        child,
        // Opaco e por cima de tudo: o app embaixo não recebe toque nenhum
        // enquanto a preparação está na frente.
        Positioned.fill(
          child: ColoredBox(
            color: tema.colorScheme.surface,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 56,
                        color: tema.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hinário Cifrado CSJ',
                        style: tema.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preparando o hinário para uso offline…',
                        style: tema.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(value: progresso),
                      const SizedBox(height: 12),
                      Text(
                        '${vm.baixados} de ${vm.total} arquivos',
                        style: tema.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: vm.continuarSemBaixar,
                        child: const Text('Continuar sem baixar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
