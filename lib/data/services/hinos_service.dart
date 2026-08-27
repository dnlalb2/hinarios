// lib/data/services/hinos_service.dart
import 'package:flutter/services.dart';

/// Acesso bruto ao arquivo de dados (raw API model — sem parse).
class HinosService {
  Future<String> carregarJson() => rootBundle.loadString('assets/dados.json');
}
