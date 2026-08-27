// lib/data/repositories/hinos_repository.dart
import 'dart:convert';
import '../../domain/models/hino.dart';
import '../services/hinos_service.dart';

/// Fonte única de verdade dos hinários. Transforma o JSON bruto em
/// domain models, cacheia e oferece agrupamento/busca/filtro.
class HinosRepository {
  HinosRepository({required HinosService service}) : _service = service;

  final HinosService _service;
  List<Hino>? _hinos;

  Future<List<Hino>> carregar() async {
    if (_hinos != null) return _hinos!;
    final texto = await _service.carregarJson();
    final lista = jsonDecode(texto) as List<dynamic>;
    _hinos = [for (final item in lista) Hino.fromJson(item as Map<String, dynamic>)];
    return _hinos!;
  }

  Map<String, Map<String, List<Hino>>> agrupar() {
    final autores = <String, Map<String, List<Hino>>>{};
    for (final h in _hinos!) {
      final autor = h.autor.isEmpty ? 'Sem autor' : h.autor;
      final hinario = h.hinario.isEmpty ? 'Sem hinário' : h.hinario;
      autores.putIfAbsent(autor, () => {}).putIfAbsent(hinario, () => []).add(h);
    }
    for (final porAutor in autores.values) {
      for (final lista in porAutor.values) {
        lista.sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome));
      }
    }
    return autores;
  }

  List<Hino> buscar(String query) {
    final tokens = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return _hinos!;
    return _hinos!.where((h) {
      final alvo = [
        h.nome, h.autor, h.hinario, h.letra,
        if (h.cifra != null) h.cifra!.tom,
      ].join(' ').toLowerCase();
      return tokens.every(alvo.contains);
    }).toList();
  }

  List<Hino> hinosDoHinario(String urlhinario) {
    final lista = _hinos!.where((h) => h.urlhinario == urlhinario).toList()
      ..sort((a, b) => a.num.compareTo(b.num));
    return lista;
  }
}
