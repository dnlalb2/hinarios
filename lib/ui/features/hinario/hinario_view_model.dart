// lib/ui/features/hinario/hinario_view_model.dart
import 'package:flutter/foundation.dart';
import '../../../domain/models/hino.dart';

/// Recebe a lista do grupo pronta da navegação (a árvore já a tem:
/// `grupos[autor][hinario]`) — sem re-buscar por url, o que quebrava
/// grupos sem url hinario.
class HinarioViewModel extends ChangeNotifier {
  HinarioViewModel({required List<Hino> hinos, required this.autor, required this.hinario})
      : _hinos = hinos;

  final List<Hino> _hinos;
  final String autor;
  final String hinario;

  List<Hino> get hinos => _hinos;
}
