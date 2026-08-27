import 'package:flutter/foundation.dart';
import '../../data/services/preferencias_service.dart';

class PreferenciasViewModel extends ChangeNotifier {
  PreferenciasViewModel({required PreferenciasService service}) : _service = service;

  final PreferenciasService _service;
  bool _temaEscuro = false;
  double _tamanhoFonte = 16;
  final Set<String> _favoritos = {};
  final Map<String, int> _deslocamentos = {};

  bool get temaEscuro => _temaEscuro;
  double get tamanhoFonte => _tamanhoFonte;
  Set<String> get favoritos => Set.unmodifiable(_favoritos);
  int deslocamentoDe(String slug) => _deslocamentos[slug] ?? 0;

  Future<void> restaurar() async {
    final p = await _service.restaurar();
    _temaEscuro = p.temaEscuro;
    _tamanhoFonte = p.tamanhoFonte;
    _favoritos
      ..clear()
      ..addAll(p.favoritos);
    _deslocamentos
      ..clear()
      ..addAll(p.deslocamentos);
    notifyListeners();
  }

  void toggleTema() {
    _temaEscuro = !_temaEscuro;
    notifyListeners();
    _persistir();
  }

  void setTamanhoFonte(double v) {
    _tamanhoFonte = v;
    notifyListeners();
    _persistir();
  }

  void toggleFavorito(String slug) {
    if (!_favoritos.remove(slug)) _favoritos.add(slug);
    notifyListeners();
    _persistir();
  }

  void transpor(String slug, int delta) {
    final atual = deslocamentoDe(slug);
    _deslocamentos[slug] = ((atual + delta) % 12 + 12) % 12;
    notifyListeners();
    _persistir();
  }

  void _persistir() {
    _service.salvar(
      temaEscuro: _temaEscuro,
      tamanhoFonte: _tamanhoFonte,
      favoritos: _favoritos,
      deslocamentos: _deslocamentos,
    ); // fire-and-forget
  }
}
