// test/dados_reais_test.dart
// Teste de integração com o acervo real (assets/dados.json), não com um fake:
// garante que o parse, o agrupamento e a busca funcionam na escala real.
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/domain/use_cases/transposicao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('acervo real: 3087 hinos e agrupamento íntegro', () async {
    final repo = HinosRepository(service: HinosService());
    final hinos = await repo.carregar();
    expect(hinos, hasLength(3087));

    // GLOBAL por urlhinario: 84 hinários (84 urls — o site mostra 84), dos
    // quais 35 são coletivos (hinos de autores diferentes num grupo só).
    final grupos = repo.gruposGlobais();
    expect(grupos, hasLength(84));
    expect(grupos.fold<int>(0, (soma, g) => soma + g.hinos.length), 3087);
    expect(grupos.where((g) => g.autor == 'Diversos'), hasLength(35));

    final cruzeiro = grupos.firstWhere((g) => g.rotulo == 'O Cruzeiro Universal');
    expect(cruzeiro.autor, 'Mestre Irineu');
    expect(cruzeiro.hinos, hasLength(134));

    // Coletivo real: 'caboclo guerreiro' tem 43 hinos de 41 autores — antes
    // fragmentava em 41 grupos de 1 hino.
    final caboclo = grupos.firstWhere((g) => g.rotulo == 'Caboclo Guerreiro');
    expect(caboclo.autor, 'Diversos');
    expect(caboclo.hinos, hasLength(43));
    expect(repo.hinosDoGrupo(caboclo.hinos.first), hasLength(43));

    // A árvore por autor segue com os 181 autores do acervo.
    expect(repo.agrupar().keys, hasLength(181));
  });

  // C1: 179 cifras usam NBSP como preenchimento; o parse normaliza para
  // espaço ASCII para que a transposição alcance todos os acordes.
  test('acervo real: nenhum NBSP escapa do parse', () async {
    final repo = HinosRepository(service: HinosService());
    final hinos = await repo.carregar();
    final comNbsp = hinos
        .where((h) => h.letra.contains('\u00A0') || (h.cifra?.texto.contains('\u00A0') ?? false))
        .toList();
    expect(comNbsp, isEmpty);
  });

  // C1 (caso real do review): o compasso de abertura do 'Fardamento' usa
  // runs de NBSP entre os acordes. Antes do fix o split por espaço simples
  // devolvia 1 token (e nada transpúnha).
  test('acervo real: compasso com NBSP do Fardamento transpõe todos os acordes',
      () async {
    final repo = HinosRepository(service: HinosService());
    final hinos = await repo.carregar();
    // O slug real tem tabs à direita no acervo — casa pelo prefixo.
    final h = hinos.firstWhere((x) => x.slug.startsWith('alex-polari/3/fardamento'));
    final tokens = h.cifra!.texto
        .split(';')
        .first
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    expect(tokens, ['D', 'A', 'D']); // antes do fix: 1 token com NBSPs
    for (final t in tokens) {
      expect(transporAcorde(t, 1), isNot(t)); // todo acorde move
    }
  });

  // I4: a busca usa o índice pré-computado, mas mantém a ordem do acervo.
  test('acervo real: busca por termo mantém a ordem original', () async {
    final repo = HinosRepository(service: HinosService());
    final todos = await repo.carregar();
    expect(repo.buscar(''), hasLength(3087));
    final resultado = repo.buscar('cruzeiro');
    expect(resultado, isNotEmpty);
    final posicoes = resultado.map((r) => todos.indexOf(r.hino)).toList();
    expect(posicoes, orderedEquals(List.of(posicoes)..sort()));
  });

  // O acervo é CRLF (3068 letras): o trecho da lista compacta precisa sair
  // numa linha só e com o destaque caindo exatamente sobre o termo buscado.
  test('acervo real: trecho da busca é uma janela da letra, sem quebras', () async {
    final repo = HinosRepository(service: HinosService());
    await repo.carregar();
    final comTrecho = repo.buscar('cruzeiro').where((r) => r.trecho != null).toList();
    expect(comTrecho, isNotEmpty); // 'cruzeiro' aparece na letra de vários hinos
    for (final r in comTrecho) {
      final trecho = r.trecho!;
      expect(trecho.contains('\r'), isFalse);
      expect(trecho.contains('\n'), isFalse);
      expect(r.destaqueInicio, greaterThanOrEqualTo(0));
      expect(r.destaqueFim, lessThanOrEqualTo(trecho.length));
      // O destaque cobre o termo na letra ORIGINAL (o índice do texto
      // normalizado vale na letra: a normalização é 1 caractere → 1).
      expect(trecho.substring(r.destaqueInicio!, r.destaqueFim!).toLowerCase(),
          'cruzeiro');
      // O trecho (sem as reticências) é um recorte contíguo da letra.
      expect(r.hino.letra.replaceAll(RegExp('[\r\n\t]'), ' '),
          contains(trecho.replaceAll('…', '')));
    }
  });
}
