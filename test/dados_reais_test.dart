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

    final grupos = repo.agrupar();
    expect(grupos.keys.length, 181);
    var soma = 0;
    for (final porAutor in grupos.values) {
      for (final lista in porAutor.values) {
        soma += lista.length;
      }
    }
    expect(soma, 3087); // todo hino em exatamente um grupo
    expect(grupos['Mestre Irineu']!['O Cruzeiro Universal'], hasLength(134));
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
    final posicoes = resultado.map(todos.indexOf).toList();
    expect(posicoes, orderedEquals(List.of(posicoes)..sort()));
  });
}
