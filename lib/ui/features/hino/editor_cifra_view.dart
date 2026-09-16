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

/// Instrução do formato, mostrada no topo do editor.
const String instrucaoChordPro =
    'Escreva os acordes entre colchetes antes da palavra. '
    'Ex.: [Am]Quem não [E7]anda no caminho';

/// Acorde no formato ChordPro: '[' + nota (A-G) + o resto + ']'.
final RegExp acordeChordPro = RegExp(r'\[[A-G][^\]]*\]');

void abrirEditorCifra(BuildContext context, Hino hino) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => EditorCifraView(hino: hino)),
  );
}

/// Editor da cifra própria do hino: um campo único em ChordPro — o acorde vai
/// entre colchetes, colado na sílaba que ele acompanha. O alinhamento é
/// estrutural (não há colunas para contar nem espaços a acertar).
class EditorCifraView extends StatefulWidget {
  final Hino hino;
  const EditorCifraView({super.key, required this.hino});

  @override
  State<EditorCifraView> createState() => _EditorCifraViewState();
}

class _EditorCifraViewState extends State<EditorCifraView> {
  late final TextEditingController _texto;
  String? _tom;
  /// Já existe cifra própria deste hino? (habilita o botão de remover)
  late final bool _editando;

  @override
  void initState() {
    super.initState();
    final existente =
        context.read<CifrasLocaisViewModel>().cifraDe(widget.hino.slug);
    _editando = existente != null;
    // Sem cifra própria o campo abre com a LETRA do acervo, pronta para
    // receber os colchetes (quebras normalizadas: a do acervo vem com CRLF).
    // Com cifra, abre com ela — convertendo o formato antigo quando for o caso.
    _texto = TextEditingController(
      text: existente == null
          ? _normalizarQuebras(widget.hino.letra)
          : existente.textoChordPro(widget.hino.letra),
    );
    // Tom fora da lista (import de outro dispositivo com 'Bb', p.ex.) não pode
    // derrubar o DropdownButtonFormField, que exige um item com o mesmo valor.
    _tom = tonsDoEditor.contains(existente?.tom) ? existente!.tom : null;
  }

  static String _normalizarQuebras(String texto) =>
      texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _salvar() {
    final tom = _tom;
    final texto = _texto.text;
    if (tom == null || !acordeChordPro.hasMatch(texto)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escolha o tom e escreva ao menos um acorde entre colchetes'),
        ),
      );
      return;
    }
    // Capturados antes do pop: depois o context da rota já saiu da árvore.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    context.read<CifrasLocaisViewModel>().salvar(
          widget.hino.slug,
          CifraLocal(tom: tom, texto: texto),
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
    // Mesma métrica monoespaçada e mesmo tamanho do bloco do hino: o campo é
    // um preview fiel do que a música vai mostrar.
    final tamanhoFonte = context.read<PreferenciasViewModel>().tamanhoFonte;
    final estiloMono = TextStyle(
      fontFamily: 'MonoAcervo',
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 12),
            Text(
              instrucaoChordPro,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _texto,
                style: estiloMono,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                // Sem hintText: a instrução acima já traz o exemplo, e o campo
                // ou vem preenchido (letra/cifra) ou o usuário sabe o formato.
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
