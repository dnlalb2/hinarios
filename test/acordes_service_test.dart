// test/acordes_service_test.dart
// Sanidade do acervo REAL (assets/acordes.json, gerado do chords-db):
// o teste roda contra o asset de verdade, não contra um fake — é ele que
// garante que a geração (tool/gerar_acordes.py) cobriu o vocabulário.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/services/acordes_service.dart';
import 'package:hinarios_app/domain/models/acorde_shape.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shape = AcordeShape(frets: [0], fingers: [0], baseFret: 1, barres: []);

  test('acervo real: >100 acordes, com Am e C#m7b5', () async {
    final acervo = await AcordesService.instancia.carregar();
    expect(acervo.length, greaterThan(100));
    expect(acervo['Am'], isNotEmpty);
    expect(acervo['C#m7b5'], isNotEmpty);
    expect(acervo['Am']!.first.frets, hasLength(6)); // 6 cordas
    expect(acervo['Am']!.first.fingers, hasLength(6));
  });

  // O vocabulário das cifras do acervo tem variantes que o chords-db não
  // conhece: meio-diminuto escrito como 'm7/5-', 'm7/-5', 'm7(b5)', 'ø' e o
  // ordinal 'º' do teclado. Todas precisam cair na MESMA chave do acervo.
  test('chaveDe traduz o vocabulário das cifras para a chave do acervo', () {
    expect(AcordesService.chaveDe('Am'), 'Am');
    expect(AcordesService.chaveDe('Bb'), 'A#'); // nosso acervo é com sustenidos
    expect(AcordesService.chaveDe('Ebm7'), 'D#m7');
    expect(AcordesService.chaveDe('Bm7/5-'), 'Bm7b5');
    expect(AcordesService.chaveDe('Bm7/-5'), 'Bm7b5');
    expect(AcordesService.chaveDe('Bm7(b5)'), 'Bm7b5');
    expect(AcordesService.chaveDe('Aø'), 'Am7b5');
    expect(AcordesService.chaveDe('Eº'), 'E°');
    expect(AcordesService.chaveDe('D/F#'), 'D/F#');
  });

  test('posicoesDe acha o acorde transposto e cai para a base sem baixo', () {
    final acervo = {
      'C': [shape],
      'Cm7b5': [shape],
      'A#': [shape],
    };
    expect(AcordesService.posicoesDe(acervo, 'C'), hasLength(1));
    expect(AcordesService.posicoesDe(acervo, 'Bb'), hasLength(1)); // bemol -> A#
    expect(AcordesService.posicoesDe(acervo, 'Cm7/5-'), hasLength(1)); // alias
    expect(AcordesService.posicoesDe(acervo, 'Bb7'), isEmpty); // sem par no acervo
    // 'C/G' não existe no acervo, mas o C existe: mostra o C.
    expect(AcordesService.posicoesDe(acervo, 'C/G'), hasLength(1));
    // Base desconhecida: nada.
    expect(AcordesService.posicoesDe(acervo, 'Dn'), isEmpty);
    expect(AcordesService.posicoesDe(acervo, ''), isEmpty);
  });

  // O acervo é gerado, mas vai versionado no repositório: um JSON truncado
  // (ou de formato inesperado) tem que virar acervo vazio, não exceção — a
  // folha do acorde mostra 'não disponível' em vez de derrubar o app.
  test('asset ausente/corrompido vira acervo vazio, não exceção', () {
    expect(AcordesService.mapaDeJson('{'), isEmpty);
    expect(AcordesService.mapaDeJson('{"C": 3}'), isEmpty);
    expect(AcordesService.mapaDeJson('{"C": [{"frets": [0]}]}'), isEmpty); // shape inválida
    // Uma entrada ruim não leva as boas junto.
    expect(
      AcordesService.mapaDeJson(
          '{"C": [{"frets": [0]}] , "Am": [${jsonEncode(shape.toJson())}]}'),
      hasLength(1),
    );
  });
}
