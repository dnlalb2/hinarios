// lib/ui/features/hino/hino_view_model.dart
import 'package:flutter/foundation.dart';
import '../../../data/repositories/hinos_repository.dart';
import '../../../domain/models/hino.dart';

class HinoViewModel extends ChangeNotifier {
  HinoViewModel({required HinosRepository hinos, required this.hino}) : _hinos = hinos;

  final HinosRepository _hinos;
  final Hino hino;

  List<Hino> get doHinario => _hinos.hinosDoHinario(hino.urlhinario);
}
