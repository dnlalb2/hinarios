// lib/ui/core/cifras_locais_view_model.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/services/cifras_locais_service.dart';
import '../../domain/models/cifra_local.dart';

/// Cifras próprias do usuário (por dispositivo), indexadas pelo slug do hino.
class CifrasLocaisViewModel extends ChangeNotifier {
  CifrasLocaisViewModel({required CifrasLocaisService service}) : _service = service;

  final CifrasLocaisService _service;
  final Map<String, CifraLocal> _cifras = {};

  Map<String, CifraLocal> get cifras => Map.unmodifiable(_cifras);
  CifraLocal? cifraDe(String slug) => _cifras[slug];

  Future<void> restaurar() async {
    final lidas = await _service.restaurar();
    _cifras
      ..clear()
      ..addAll(lidas);
    notifyListeners();
  }

  void salvar(String slug, CifraLocal v) {
    _cifras[slug] = v;
    notifyListeners();
    _persistir();
  }

  void remover(String slug) {
    _cifras.remove(slug);
    notifyListeners();
    _persistir();
  }

  /// Mapa slug→cifra em JSON (mesmo formato do disco), para o backup/export
  /// da Fase 2.
  String exportarJson() =>
      jsonEncode({for (final e in _cifras.entries) e.key: e.value.toJson()});

  /// Mescla um JSON exportado (de outro dispositivo), sobrescrevendo por slug.
  /// Devolve quantas cifras entraram; texto inválido devolve 0 sem mexer no
  /// que já existe.
  int importar(String json) {
    final lidas = CifrasLocaisService.mapaDeJson(json);
    if (lidas.isEmpty) return 0;
    _cifras.addAll(lidas);
    notifyListeners();
    _persistir();
    return lidas.length;
  }

  void _persistir() => _service.salvar(_cifras); // fire-and-forget
}
