/// No-op fora da web: o app nativo já carrega os assets do próprio pacote,
/// então não existe cache de service worker para aquecer.
void solicitarCacheCompleto() {}

/// Fora da web não existe cache de service worker para contar: -1 avisa quem
/// perguntou que o número não se aplica (não é "zero arquivos em cache").
Future<int> arquivosDeAcervoEmCache() async => -1;

/// Fora da web o app não depende de rede para abrir: sempre "online".
bool get onlineAgora => true;
