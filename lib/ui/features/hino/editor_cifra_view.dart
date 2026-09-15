// lib/ui/features/hino/editor_cifra_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/models/cifra_local.dart';
import '../../../domain/models/hino.dart';
import '../../core/cifras_locais_view_model.dart';
import '../../core/preferencias_view_model.dart';

/// Mesma lista de tons usada pela transposição do acervo (12 maiores + 12
/// menores): o tom escolhido aqui precisa ser transponível como nas oficiais.
const List<String> tonsDoEditor = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  'Am', 'A#m', 'Bm', 'Cm', 'C#m', 'Dm', 'D#m', 'Em', 'Fm', 'F#m', 'Gm', 'G#m',
];

void abrirEditorCifra(BuildContext context, Hino hino) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => EditorCifraView(hino: hino)),
  );
}

/// Editor da cifra própria do hino: um campo de acordes por linha NÃO-VAZIA
/// da letra (o pareamento com a letra é posicional — ver CifraLocal).
class EditorCifraView extends StatefulWidget {
  final Hino hino;
  const EditorCifraView({super.key, required this.hino});

  @override
  State<EditorCifraView> createState() => _EditorCifraViewState();
}

class _EditorCifraViewState extends State<EditorCifraView> {
  /// Linhas NÃO-VAZIAS da letra, na ordem — as que ganham campo de acordes.
  late final List<String> _linhas;
  late final List<TextEditingController> _controllers;
  String? _tom;
  /// Já existe cifra própria deste hino? (habilita o botão de remover)
  late final bool _editando;

  @override
  void initState() {
    super.initState();
    final existente = context.read<CifrasLocaisViewModel>().cifraDe(widget.hino.slug);
    _editando = existente != null;
    _linhas = _linhasNaoVazias(widget.hino.letra);
    _controllers = [
      for (var i = 0; i < _linhas.length; i++)
        TextEditingController(
          text: existente != null && i < existente.acordesPorLinha.length
              ? existente.acordesPorLinha[i]
              : '',
        ),
    ];
    // Tom fora da lista (import de outro dispositivo com 'Bb', p.ex.) não pode
    // derrubar o DropdownButtonFormField, que exige um item com o mesmo valor.
    _tom = tonsDoEditor.contains(existente?.tom) ? existente!.tom : null;
  }

  static List<String> _linhasNaoVazias(String letra) {
    // Mesma normalização de quebras do alinhar()/textoCifra().
    if (letra.isEmpty) return const [];
    return [
      for (final linha
          in letra.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n'))
        if (linha.trim().isNotEmpty) linha.trim(),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _salvar() {
    final tom = _tom;
    // Espaços à ESQUERDA posicionam o acorde sobre a sílaba da letra (mesma
    // convenção do acervo, ver alinhar()) — só os da direita podem sair.
    final acordes = [for (final c in _controllers) c.text.trimRight()];
    if (tom == null || acordes.every((a) => a.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha o tom e preencha ao menos uma linha')),
      );
      return;
    }
    // Capturados antes do pop: depois o context da rota já saiu da árvore.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    context.read<CifrasLocaisViewModel>().salvar(
          widget.hino.slug,
          CifraLocal(tom: tom, acordesPorLinha: acordes),
        );
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Cifra salva')));
  }

  Future<void> _remover() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover cifra'),
        content: const Text('A cifra desta música será apagada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    context.read<CifrasLocaisViewModel>().remover(widget.hino.slug);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Cifra removida')));
  }

  @override
  Widget build(BuildContext context) {
    final corDica = Theme.of(context).hintColor;
    // O formulário é um preview 1:1 da exibição: acordes e a régua de letra
    // acima de cada campo usam a MESMA métrica monoespaçada e o MESMO tamanho
    // do bloco do hino. Em fonte proporcional (default do TextField) o usuário
    // posiciona o acorde contando colunas que não existem e a cifra sai
    // desalinhada na exibição.
    final tamanhoFonte = context.read<PreferenciasViewModel>().tamanhoFonte;
    // letterSpacing 0 explícito: sem ele o tema injeta espaçamentos DIFERENTES
    // em cada widget (bodyMedium 0.25 na régua, bodyLarge 0.5 no TextField) e a
    // coluna N do campo deixa de cair sob a coluna N da régua.
    final estiloMono = TextStyle(
      fontFamily: 'monospace',
      fontSize: tamanhoFonte,
      letterSpacing: 0,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Cifra — ${widget.hino.nome}'),
        actions: [
          if (_editando)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remover cifra',
              onPressed: _remover,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Salvar cifra',
            onPressed: _salvar,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _tom,
            decoration: const InputDecoration(
              labelText: 'Tom',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in tonsDoEditor) DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => _tom = v,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _linhas.length; i++) ...[
            Text(_linhas[i], style: estiloMono.copyWith(color: corDica)),
            const SizedBox(height: 4),
            TextField(
              controller: _controllers[i],
              style: estiloMono,
              // contentPadding zero: o padding interno do campo (herdado,
              // ~16px à esquerda) empurrava a coluna 0 do texto digitado para
              // a direita da régua logo acima — o usuário alinhava o acorde na
              // régua e o render, sem padding, saía deslocado para a ESQUERDA.
              // A borda inferior mantém a pista visual sem deslocar o texto.
              decoration: const InputDecoration(
                hintText: 'acordes desta linha',
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
