// lib/ui/features/hinario/hinario_view_model.dart
import 'package:flutter/foundation.dart';
import '../../../data/repositories/hinos_repository.dart';
import '../../../domain/models/hino.dart';

class HinarioViewModel extends ChangeNotifier {
  HinarioViewModel({
    required HinosRepository hinos,
    required this.urlhinario,
    required this.autor,
    required this.hinario,
  }) : _hinos = hinos;

  final HinosRepository _hinos;
  final String urlhinario;
  final String autor;
  final String hinario;

  List<Hino> get hinos => _hinos.hinosDoHinario(urlhinario);
}
