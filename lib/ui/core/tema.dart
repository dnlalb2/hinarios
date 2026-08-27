// lib/ui/core/tema.dart
import 'package:flutter/material.dart';

ThemeData temaClaro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A6D3B)),
      brightness: Brightness.light,
    );

ThemeData temaEscuro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC9A961),
        brightness: Brightness.dark,
      ),
    );
