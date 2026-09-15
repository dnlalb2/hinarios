// test/busca_test.dart
// Normalização e casamento da busca — extraídos do repositório para o domínio
// justamente para poderem ser testados sozinhos (a busca principal e a busca
// interna do hinário compartilham esta semântica).
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/use_cases/busca.dart';

void main() {
  test('normalizar: minúsculas e sem acentos (pt-BR)', () {
    // Caso real: 'chaveirao' precisa achar 'Chaveirão'.
    expect(normalizar('Chaveirão'), 'chaveirao');
    expect(normalizar('ÁÉÍÓÚÇ'), 'aeiouc');
    expect(normalizar('TRÊS'), 'tres');
    // ª/º são indicadores ordinais, não letras com acento: '1ª VEZ' casa '1a vez'.
    expect(normalizar('1ª VEZ e 2º'), '1a vez e 2o');
    // Idempotente: normalizar um texto já normalizado não muda nada.
    expect(normalizar(normalizar('Chaveirão')), 'chaveirao');
  });

  test('casaBusca: casa sem acento e sem caixa nos dois lados', () {
    expect(casaBusca('chaveirao', 'Grupo Chaveirão'), isTrue);
    expect(casaBusca('CHAVEIRÃO', 'grupo chaveirao'), isTrue);
  });

  test('casaBusca: TODOS os tokens precisam casar (substring)', () {
    expect(casaBusca('terra', 'Terra e mar'), isTrue);
    expect(casaBusca('terra mar', 'Terra e mar'), isTrue);
    // Um token que não está no alvo derruba o casamento inteiro.
    expect(casaBusca('terra ceu', 'Terra e mar'), isFalse);
    // Substring vale no meio da palavra ('eir' dentro de 'Chaveirão').
    expect(casaBusca('eir', 'Chaveirão'), isTrue);
  });

  test('casaBusca: query vazia (ou só espaços) casa tudo', () {
    expect(casaBusca('', 'qualquer coisa'), isTrue);
    expect(casaBusca('   ', 'qualquer coisa'), isTrue);
  });

  test('casaBusca: casa o número do hino quando o alvo o inclui', () {
    expect(casaBusca('2', 'Um Letra do Um 2'), isTrue);
    expect(casaBusca('7', 'Um Letra do Um 2'), isFalse);
  });
}
