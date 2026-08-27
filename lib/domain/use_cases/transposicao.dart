// lib/domain/use_cases/transposicao.dart
const List<String> _notas = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];
const Map<String, String> _bemoles = {
  'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
};
final RegExp _acorde = RegExp(r'^([A-G])([#b]?)(.*)$');

String transporAcorde(String acorde, int meiosTons) {
  if (acorde.isEmpty) return acorde;
  if (acorde.contains('/')) {
    return acorde.split('/').map((p) => transporAcorde(p, meiosTons)).join('/');
  }
  final m = _acorde.firstMatch(acorde);
  if (m == null) return acorde;
  var nota = m.group(1)! + (m.group(2) ?? '');
  if (!_notas.contains(nota)) nota = _bemoles[nota] ?? nota;
  if (!_notas.contains(nota)) return acorde;
  final idx = (_notas.indexOf(nota) + meiosTons) % 12;
  final ajustado = (idx + 12) % 12;
  return _notas[ajustado] + (m.group(3) ?? '');
}
