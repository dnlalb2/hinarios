/// No-op fora da web: o app nativo já carrega os assets do próprio pacote,
/// então não existe cache de service worker para aquecer.
void solicitarCacheCompleto() {}

/// No-op fora da web: não há cache de service worker para encher — o app
/// nativo lê os assets do próprio pacote. Não "baixar" nada é o comportamento
/// certo aqui, e é por isso que o view model nunca chega a montar a tela de
/// preparação neste lado (ver `arquivosDeAcervoEmCache`).
Future<void> baixarAsset(String caminhoRelativo) async {}

/// Fora da web não existe cache de service worker para contar: -1 avisa quem
/// perguntou que o número não se aplica (não é "zero arquivos em cache").
Future<int> arquivosDeAcervoEmCache() async => -1;

/// Fora da web o app não depende de rede para abrir: sempre "online".
bool get onlineAgora => true;
