/// No-op fora da web (Android/iOS terão share/import nativos depois).
void baixarTexto(String nomeArquivo, String conteudo) {}

/// Fora da web não há seletor de arquivo (retorna null).
Future<String?> escolherArquivoTexto() async => null;
