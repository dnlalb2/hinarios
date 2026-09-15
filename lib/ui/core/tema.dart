// lib/ui/core/tema.dart
import 'package:flutter/material.dart';

/// Verde da logo do Céu de São José — identidade visual do app.
const _verde = Color(0xFF3F8F4F);

ThemeData temaClaro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _verde),
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6FAF6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6FAF6),
        surfaceTintColor: Colors.transparent,
      ),
    );

ThemeData temaEscuro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _verde,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
    );
