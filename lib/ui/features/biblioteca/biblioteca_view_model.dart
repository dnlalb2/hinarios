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

  String get query => _query;
  bool get soFavoritos => _soFavoritos;
  bool get emBusca => _query.trim().isNotEmpty;

  Map<String, Map<String, List<Hino>>> get grupos => _hinos.agrupar();

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
}
