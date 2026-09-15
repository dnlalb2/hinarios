// test/theme_color_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/ui/core/theme_color.dart';

void main() {
  // Documenta o contrato: fora da web (VM de teste, Android, iOS) a função é
  // um no-op — a barra de status é responsabilidade do tema nativo.
  test('atualizarThemeColor é um no-op fora da web', () {
    expect(() => atualizarThemeColor(0xFFF6FAF6), returnsNormally);
    expect(() => atualizarThemeColor(0xFF101010), returnsNormally);
    // ARGB com canal alfa cheio é mascarado para RGB — não deve lançar.
    expect(() => atualizarThemeColor(0x00FFFFFF), returnsNormally);
  });
}
