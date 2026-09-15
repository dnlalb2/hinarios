// lib/data/repositories/hinos_repository.dart
import 'dart:convert';
import '../../domain/models/hino.dart';
import '../../domain/use_cases/busca.dart';
import '../services/hinos_service.dart';

/// Grupo de hinos de um mesmo hinário (autor + rótulo) devolvido pela busca.
class GrupoHinario {
  /// Identidade do grupo (urlhinario, ou o nome quando a url é vazia) — é a
  /// chave usada para favoritar o hinário inteiro. Independe do rótulo, que
  /// pode ganhar sufixo de colisão.
  final String chave;
  final String autor;
  final String rotulo; // rótulo do grupo (possivelmente com sufixo de colisão)
  final List<Hino> hinos;
  const GrupoHinario(
      {required this.chave, required this.autor, required this.rotulo, required this.hinos});
}

/// Um resultado da busca. A lista compacta da biblioteca mostra o título e o
/// autor/hinário; quando o casamento só foi fechado pela LETRA, mostra também
/// o [trecho] ao redor do termo, com [destaqueInicio]/[destaqueFim] marcando o
/// que realçar.
class ResultadoBusca {
  final Hino hino;
  /// Trecho da letra ao redor do termo, quando o casamento NÃO foi
  /// resolvido por nome+autor+hinário (ou seja, veio da letra).
  final String? trecho;
  /// Offsets [inicio, fim) do termo dentro de [trecho] (para destaque).
  final int? destaqueInicio;
  final int? destaqueFim;
  const ResultadoBusca({required this.hino, this.trecho, this.destaqueInicio, this.destaqueFim});
}

/// Fonte única de verdade dos hinários. Transforma o JSON bruto em
/// domain models, cacheia e oferece agrupamento/busca/filtro.
class HinosRepository {
  HinosRepository({required HinosService service}) : _service = service;

  final HinosService _service;
  List<Hino>? _hinos;
  /// Índice de busca (nome+autor+hinário+letra+tom, minúsculo e sem acentos)
  /// construído uma única vez em [carregar]. Sem ele, cada tecla digitada
  /// reconstruía ~3,4 MB de strings para os 3087 hinos.
  List<String>? _indice;
  /// Cabeçalho (nome+autor+hinário) normalizado por hino — pré-computado pelo
  /// mesmo motivo do [_indice]: decidir se o casamento foi resolvido pelo
  /// cabeçalho (sem trecho) é uma checagem por tecla, não por carregamento.
  List<String>? _indiceCabecalho;
  /// Cache do [gruposGlobais] (reagrupar 3087 hinos custa O(n log n) por
  /// build, não por tecla). Invalidado em [carregar], quando `_hinos` troca.
  List<GrupoHinario>? _gruposGlobaisCache;
  /// Cache do [agrupar] (autor → grupos globais): mesma razão.
  Map<String, List<GrupoHinario>>? _gruposCache;

  /// Contexto mostrado de cada lado do termo no trecho (em caracteres).
  static const _margem = 30;
  /// Quebras viram espaço 1:1 (o acervo é CRLF): o comprimento não muda, então
  /// os offsets do destaque continuam válidos. O '\t' dos 4 hinos tabulados
  /// entra junto — também estragaria a linha única do trecho.
  static final _quebras = RegExp(r'[\r\n\t]');

  Future<List<Hino>> carregar() async {
    if (_hinos != null) return _hinos!;
    _gruposGlobaisCache = null; // invalida antes de trocar _hinos
    _gruposCache = null;
    final texto = await _service.carregarJson();
    final lista = jsonDecode(texto) as List<dynamic>;
    _hinos = [for (final item in lista) Hino.fromJson(item as Map<String, dynamic>)];
    _indice = [for (final h in _hinos!) _textoDeBusca(h)];
    _indiceCabecalho = [for (final h in _hinos!) _cabecalhoDe(h)];
    return _hinos!;
  }

  /// Cabeçalho do hino (nome+autor+hinário) normalizado. É o que a busca
  /// considera "resolvido sem a letra" — logo, sem trecho para destacar.
  String _cabecalhoDe(Hino h) => normalizar('${h.nome} ${h.autor} ${h.hinario}');

  String _textoDeBusca(Hino h) => normalizar([
        h.nome,
        h.autor,
        h.hinario,
        h.letra,
        if (h.cifra != null) h.cifra!.tom,
      ].join(' '));

  /// Todos os hinários como grupos GLOBAIS por urlhinario (hinos sem url: o
  /// nome), independentemente de quem recebeu cada hino. Memoizado.
  ///
  /// É a unidade real do site: 35 dos 84 hinários são coletivos (hinos
  /// recebidos por canais/autores diferentes) — o grupo 'caboclo-guerreiro',
  /// por exemplo, tem 43 hinos de 41 autores. O campo [GrupoHinario.autor] é o
  /// autor único quando todos os hinos o compartilham, senão 'Diversos'.
  List<GrupoHinario> gruposGlobais() {
    final cache = _gruposGlobaisCache;
    if (cache != null) return cache;
    // 1. Identidade do hinário = urlhinario (hinos sem url: o nome).
    final porChave = <String, List<Hino>>{};
    for (final h in _hinos!) {
      porChave.putIfAbsent(chaveDe(h), () => []).add(h);
    }
    // 2. Rótulo = nome de hinário mais comum no grupo (tie-break alfabético).
    final rotuloPorChave = <String, String>{
      for (final chave in porChave.keys) chave: _rotuloMaisComum(porChave[chave]!),
    };
    // 3. Colisão de rótulo (duas chaves, mesmo rótulo): o grupo de menor
    //    contagem GLOBAL recebe o sufixo ' (chave)'; o maior fica com o puro.
    final porRotulo = <String, List<String>>{};
    for (final chave in porChave.keys) {
      porRotulo.putIfAbsent(rotuloPorChave[chave]!, () => []).add(chave);
    }
    final comRotulo = <String, List<Hino>>{};
    // Rótulo final → chave do grupo: o sufixo de colisão esconde a chave, mas
    // ela segue sendo a identidade (é o que se favorita).
    final chaveDoRotulo = <String, String>{};
    for (final rotulo in porRotulo.keys) {
      final chaves = porRotulo[rotulo]!;
      if (chaves.length == 1) {
        comRotulo[rotulo] = porChave[chaves.first]!;
        chaveDoRotulo[rotulo] = chaves.first;
      } else {
        chaves.sort((a, b) {
          final c = porChave[a]!.length.compareTo(porChave[b]!.length);
          return c != 0 ? c : a.compareTo(b);
        });
        for (final chave in chaves) {
          final rotuloFinal = chave == chaves.last ? rotulo : '$rotulo ($chave)';
          comRotulo[rotuloFinal] = porChave[chave]!;
          chaveDoRotulo[rotuloFinal] = chave;
        }
      }
    }
    // 4. Ordenação: rótulo normalizado (sem acento, senão 'Índio' cai depois
    //    de todo nome sem acento), empate → autor normalizado; hinos por num
    //    (tie-break nome).
    final lista = <GrupoHinario>[
      for (final rotulo in comRotulo.keys)
        GrupoHinario(
          chave: chaveDoRotulo[rotulo]!,
          autor: _autorDoGrupo(comRotulo[rotulo]!),
          rotulo: rotulo,
          hinos: comRotulo[rotulo]!
            ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome)),
        ),
    ];
    lista.sort((a, b) {
      final c = normalizar(a.rotulo).compareTo(normalizar(b.rotulo));
      return c != 0 ? c : normalizar(a.autor).compareTo(normalizar(b.autor));
    });
    return _gruposGlobaisCache = lista;
  }

  /// Autor do grupo: o único autor quando TODOS os hinos o compartilham, senão
  /// 'Diversos' (hinário coletivo). Vazio vira 'Sem autor'.
  String _autorDoGrupo(List<Hino> hinos) {
    final primeiro = _autorDe(hinos.first);
    for (final h in hinos.skip(1)) {
      if (_autorDe(h) != primeiro) return 'Diversos';
    }
    return primeiro;
  }

  String _autorDe(Hino h) => h.autor.isEmpty ? 'Sem autor' : h.autor;

  /// Autor → os hinários GLOBAIS em que ele tem ao menos um hino, ordenados
  /// por rótulo normalizado. Os grupos são os mesmos de [gruposGlobais]
  /// (contagem global, abrem o hinário completo).
  Map<String, List<GrupoHinario>> agrupar() {
    final cache = _gruposCache;
    if (cache != null) return cache;
    final resultado = <String, List<GrupoHinario>>{};
    for (final grupo in gruposGlobais()) {
      for (final h in grupo.hinos) {
        resultado.putIfAbsent(_autorDe(h), () => []).add(grupo);
      }
    }
    final autores = resultado.keys.toList()
      ..sort((a, b) {
        final c = normalizar(a).compareTo(normalizar(b));
        return c != 0 ? c : a.compareTo(b);
      });
    return _gruposCache = <String, List<GrupoHinario>>{
      for (final autor in autores) autor: _semRepetir(resultado[autor]!),
    };
  }

  /// Remove grupos repetidos (um autor com vários hinos no mesmo hinário).
  List<GrupoHinario> _semRepetir(List<GrupoHinario> grupos) {
    final vistos = <GrupoHinario>{};
    return [for (final g in grupos) if (vistos.add(g)) g];
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

  /// Busca por tokens (normalizados, substring, todos presentes). Query vazia →
  /// todos os hinos, nenhum com trecho. Quando o cabeçalho (nome+autor+hinário)
  /// sozinho não fecha o casamento, ele veio da letra e o resultado traz o
  /// trecho ao redor do termo, com os offsets para destaque na lista compacta.
  List<ResultadoBusca> buscar(String query) {
    // Mesma regra do [casaBusca] (todos os tokens, substring), mas casada
    // contra o índice JÁ normalizado: chamar casaBusca aqui normalizaria os
    // ~3,4 MB do acervo a cada tecla — exatamente o que o índice evita.
    final tokens = tokenizar(query);
    final hinos = _hinos!;
    final indice = _indice!;
    final cabecalhos = _indiceCabecalho!;
    return [
      for (var i = 0; i < hinos.length; i++)
        if (tokens.every(indice[i].contains)) _resultado(hinos[i], tokens, cabecalhos[i]),
    ];
  }

  /// Monta o resultado: sem trecho quando [cabecalho] (já normalizado) satisfaz
  /// todos os tokens — a lista compacta acha o hino pelo nome, autor ou
  /// hinário. Senão o que fechou o casamento foi a letra (ou o tom da cifra,
  /// que não rende trecho), e a janela sai ao redor do primeiro token que só a
  /// letra explica.
  ResultadoBusca _resultado(Hino h, List<String> tokens, String cabecalho) {
    if (tokens.every(cabecalho.contains)) return ResultadoBusca(hino: h);
    // normalizar troca 1 caractere por 1 (não há NFD por aqui): o índice no
    // texto normalizado É o índice na letra original — dá para recortar a
    // letra ORIGINAL usando a posição achada no texto normalizado.
    final normalizada = normalizar(h.letra);
    for (final token in tokens) {
      if (cabecalho.contains(token)) continue; // já explicado pelo cabeçalho
      final idx = normalizada.indexOf(token);
      if (idx == -1) continue; // casou pelo tom da cifra
      return _comTrecho(h, token, idx);
    }
    return ResultadoBusca(hino: h);
  }

  /// Trecho de ~30 caracteres de cada lado do termo, em uma linha só (o acervo
  /// é CRLF: 3068 das 3087 letras têm '\r\n'), com '…' nas pontas cortadas e o
  /// destaque ajustado pelo deslocamento do recorte.
  ResultadoBusca _comTrecho(Hino h, String token, int idx) {
    final inicio = idx > _margem ? idx - _margem : 0;
    final fimBruto = idx + token.length + _margem;
    final fim = fimBruto < h.letra.length ? fimBruto : h.letra.length;
    final trecho = '${inicio > 0 ? '…' : ''}'
        '${h.letra.substring(inicio, fim).replaceAll(_quebras, ' ')}'
        '${fim < h.letra.length ? '…' : ''}';
    final destaqueInicio = idx - inicio + (inicio > 0 ? 1 : 0);
    return ResultadoBusca(
      hino: h,
      trecho: trecho,
      destaqueInicio: destaqueInicio,
      destaqueFim: destaqueInicio + token.length,
    );
  }

  /// Grupos GLOBAIS cujo rótulo OU autor casam todos os tokens da consulta
  /// (normalizada). Query vazia → lista vazia.
  /// Os grupos vêm do [gruposGlobais] memoizado: o acervo real tem 84 hinários,
  /// e o que pesava era o reagrupamento dos 3087 hinos — agora pago uma única
  /// vez por carga, então nenhum índice por grupo é necessário.
  List<GrupoHinario> buscarGrupos(String query) {
    final tokens = tokenizar(query);
    if (tokens.isEmpty) return const [];
    final resultado = <GrupoHinario>[];
    for (final grupo in gruposGlobais()) {
      final alvo = normalizar('${grupo.rotulo} ${grupo.autor}');
      if (tokens.every(alvo.contains)) resultado.add(grupo);
    }
    return resultado;
  }

  /// Chave de agrupamento do hino: urlhinario, ou o nome quando a url é vazia.
  String chaveDe(Hino h) => h.urlhinario.isEmpty ? h.hinario : h.urlhinario;

  /// Todos os hinos do hinário GLOBAL do hino (mesma urlhinario; hinos sem url:
  /// o nome), de quaisquer autores, ordenados por num (tie-break nome). É o
  /// grupo que a navegação abre — o coletivo completo, não o recorte do autor.
  List<Hino> hinosDoGrupo(Hino h) {
    final chave = chaveDe(h);
    return _hinos!
        .where((x) => chaveDe(x) == chave)
        .toList()
      ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome));
  }

  List<Hino> hinosDoHinario(String urlhinario) {
    final lista = _hinos!.where((h) => h.urlhinario == urlhinario).toList()
      ..sort((a, b) => a.num.compareTo(b.num));
    return lista;
  }
}
