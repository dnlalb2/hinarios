// lib/ui/features/hinario/hinario_view_model.dart
import 'package:flutter/foundation.dart';
import '../../../domain/models/hino.dart';
import '../../../domain/use_cases/busca.dart';

/// Recebe a lista do grupo pronta da navegação (a árvore já a tem:
/// `grupos[autor][hinario]`) — sem re-buscar por url, o que quebrava
/// grupos sem url hinario.
class HinarioViewModel extends ChangeNotifier {
  HinarioViewModel({
    required List<Hino> hinos,
    required this.autor,
    required this.hinario,
    required this.chave,
  }) : _hinos = hinos;

  final List<Hino> _hinos;
  final String autor;
  final String hinario;

  /// Chave do grupo global (`GrupoHinario.chave`) — é o que a estrela da
  /// AppBar favorita. Vem à parte do rótulo, que pode ter sufixo de colisão.
  final String chave;

  /// Texto da busca INTERNA do hinário (80+ hinos pedem filtro próprio).
  String _query = '';

  /// Filtro memoizado: a lista é reconstruída uma vez por consulta, não a cada
  /// build (a pinça de fonte e a estrela rebuildam a página sem mudar a busca).
  List<Hino>? _filtrados;
  String? _queryDoFiltro;

  List<Hino> get hinos => _hinos;

  String get query => _query;

  /// Hinos deste hinário filtrados pela busca interna: casa nome, número ou
  /// qualquer trecho da letra, acento-insensível e com todos os tokens — a
  /// mesma semântica da busca principal ([casaBusca]). Busca vazia → a lista
  /// inteira recebida.
  List<Hino> get hinosFiltrados {
    if (_query.isEmpty) return _hinos;
    if (_queryDoFiltro == _query) return _filtrados!;
    final filtrados = [
      for (final h in _hinos)
        if (casaBusca(_query, '${h.nome} ${h.letra} ${h.num}')) h,
    ];
    _queryDoFiltro = _query;
    return _filtrados = filtrados;
  }

  void setQuery(String v) {
    _query = v;
    notifyListeners();
  }
}
