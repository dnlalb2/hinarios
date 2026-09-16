// Fora da web não existe "instalar atalho": o app já É o app instalado — não há
// navegador nenhum oferecendo um. Tudo aqui responde como um aparelho onde não
// falta nada a instalar, e é assim que o banner nunca aparece no nativo.

/// O app já está instalado? No nativo, sempre: ele veio do pacote.
bool get appInstalado => true;

/// Aparelho iOS? Só faz sentido junto com o banner, que não existe aqui.
bool get aparelhoIos => false;

/// O navegador já ofereceu a instalação? Não há navegador.
bool get instalacaoDisponivel => false;

/// No-op: não há `beforeinstallprompt` para escutar.
void observarInstalacao() {}

/// No-op: nunca haverá aviso de instalação para dar.
void avisarQuandoInstalavel(void Function() aoAtualizar) {}

/// Sem prompt nativo, não há instalação a pedir.
Future<bool> pedirInstalacao() async => false;
