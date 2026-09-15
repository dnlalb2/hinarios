// lib/ui/features/biblioteca/biblioteca_view_model.dart
import 'package:flutter/foundation.dart';
import '../../../data/repositories/hinos_repository.dart';
import '../../../domain/models/hino.dart';
import '../../core/preferencias_view_model.dart';

class BibliotecaViewModel extends ChangeNotifier {
  BibliotecaViewModel({required HinosRepository hinos, required PreferenciasViewModel preferencias})
      : _hinos = hinos,
        _preferencias = preferencias;

  final HinosRepository _hinos;
  final PreferenciasViewModel _preferencias;

  String _query = '';
  bool _soFavoritos = false;
  /// Visão da home: `true` = árvore por autor; `false` = lista plana por nome.
  /// Só de sessão — não é persistida nas preferências.
  bool _visaoPorAutor = true;

  String get query => _query;
  bool get soFavoritos => _soFavoritos;
  bool get emBusca => _query.trim().isNotEmpty;
  bool get visaoPorAutor => _visaoPorAutor;

  Map<String, Map<String, List<Hino>>> get grupos => _hinos.agrupar();

  /// Grupos achatados e ordenados pelo rótulo (visão "Hinários").
  List<GrupoHinario> get gruposPorNome => _hinos.gruposPorNome();

  /// Hinários (grupos) cujo rótulo ou autor casam com a busca.
  List<GrupoHinario> get hinariosEncontrados => _hinos.buscarGrupos(_query);

  List<Hino> get resultados {
    var r = _hinos.buscar(_query);
    if (_soFavoritos) {
      r = r.where((h) => _preferencias.favoritos.contains(h.slug)).toList();
    }
    return r;
  }

  void setQuery(String v) {
    _query = v;
    notifyListeners();
  }

  void toggleSoFavoritos() {
    _soFavoritos = !_soFavoritos;
    notifyListeners();
  }

  /// Alterna a visão da home entre autores (árvore) e hinários (lista plana).
  void alternarVisao() {
    _visaoPorAutor = !_visaoPorAutor;
    notifyListeners();
  }
}
