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
    // 1. Identidade do hinário = urlhinario (hinos sem url: o nome).
    final porAutor = <String, Map<String, List<Hino>>>{};
    for (final h in _hinos!) {
      final autor = h.autor.isEmpty ? 'Sem autor' : h.autor;
      final chave = h.urlhinario.isEmpty ? h.hinario : h.urlhinario;
      porAutor.putIfAbsent(autor, () => {}).putIfAbsent(chave, () => []).add(h);
    }
    final resultado = <String, Map<String, List<Hino>>>{};
    for (final autor in porAutor.keys) {
      final grupos = porAutor[autor]!;
      // 2. Rótulo = nome de hinário mais comum no grupo (tie-break alfabético).
      final rotuloPorChave = <String, String>{
        for (final chave in grupos.keys) chave: _rotuloMaisComum(grupos[chave]!),
      };
      // 3. Colisão de rótulo (duas chaves, mesmo rótulo): o grupo de menor
      //    contagem recebe o sufixo ' (chave)'; o maior fica com o rótulo puro.
      final porRotulo = <String, List<String>>{};
      for (final chave in grupos.keys) {
        porRotulo.putIfAbsent(rotuloPorChave[chave]!, () => []).add(chave);
      }
      final comRotulo = <String, List<Hino>>{};
      for (final rotulo in porRotulo.keys) {
        final chaves = porRotulo[rotulo]!;
        if (chaves.length == 1) {
          comRotulo[rotulo] = grupos[chaves.first]!;
        } else {
          chaves.sort((a, b) {
            final c = grupos[a]!.length.compareTo(grupos[b]!.length);
            return c != 0 ? c : a.compareTo(b);
          });
          for (final chave in chaves) {
            final rotuloFinal = chave == chaves.last ? rotulo : '$rotulo ($chave)';
            comRotulo[rotuloFinal] = grupos[chave]!;
          }
        }
      }
      // 4. Ordenação: autores e rótulos alfabéticos; hinos por num (tie-break nome).
      final ordenado = <String, List<Hino>>{};
      for (final rotulo in comRotulo.keys.toList()..sort()) {
        final lista = comRotulo[rotulo]!
          ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome));
        ordenado[rotulo] = lista;
      }
      resultado[autor] = ordenado;
    }
    final autores = resultado.keys.toList()..sort();
    return <String, Map<String, List<Hino>>>{
      for (final autor in autores) autor: resultado[autor]!,
    };
  }

  /// Nome de hinário mais comum no grupo; empate → ordem alfabética.
  /// Nome vazio vira 'Sem hinário' (fallback do agrupamento antigo).
  String _rotuloMaisComum(List<Hino> hinos) {
    final contagem = <String, int>{};
    for (final h in hinos) {
      contagem[h.hinario] = (contagem[h.hinario] ?? 0) + 1;
    }
    final nome = contagem.keys.reduce((a, b) {
      final ca = contagem[a]!, cb = contagem[b]!;
      if (ca != cb) return ca > cb ? a : b;
      return a.compareTo(b) < 0 ? a : b;
    });
    return nome.isEmpty ? 'Sem hinário' : nome;
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

  /// Chave de agrupamento do hino: urlhinario, ou o nome quando a url é vazia.
  String chaveDe(Hino h) => h.urlhinario.isEmpty ? h.hinario : h.urlhinario;

  /// Todos os hinos do mesmo grupo do hino (mesma chave e mesmo autor),
  /// ordenados por num (tie-break nome). Espelha o agrupamento da árvore.
  List<Hino> hinosDoGrupo(Hino h) {
    final chave = chaveDe(h);
    return _hinos!
        .where((x) => x.autor == h.autor && chaveDe(x) == chave)
        .toList()
      ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome));
  }

  List<Hino> hinosDoHinario(String urlhinario) {
    final lista = _hinos!.where((h) => h.urlhinario == urlhinario).toList()
      ..sort((a, b) => a.num.compareTo(b.num));
    return lista;
  }
}
