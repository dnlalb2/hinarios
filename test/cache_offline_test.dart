// test/cache_offline_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/ui/core/cache_offline.dart';

void main() {
  // Documenta o contrato: fora da web (VM de teste, Android, iOS) não existe
  // service worker, então a função é um no-op silencioso — chamá-la no boot
  // nunca pode derrubar o app.
  test('solicitarCacheCompleto é um no-op fora da web', () {
    expect(solicitarCacheCompleto, returnsNormally);
    expect(solicitarCacheCompleto, returnsNormally);
  });
}
