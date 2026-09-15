// test/arquivo_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/ui/core/arquivo.dart';

void main() {
  // Documenta o contrato: fora da web (VM de teste, Android, iOS) não há
  // download nem seletor de arquivo — as funções não podem lançar.
  test('baixarTexto é um no-op fora da web', () {
    expect(() => baixarTexto('cifras-hinario-csj.json', '{}'), returnsNormally);
    expect(() => baixarTexto('vazio.json', ''), returnsNormally);
  });

  test('escolherArquivoTexto devolve null fora da web', () async {
    expect(await escolherArquivoTexto(), isNull);
  });
}
