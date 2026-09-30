# Rastreador de Despesas

Aplicativo Android para controlar vendas e gastos em um só lugar.

## Para que serve

O aplicativo permite:

- cadastrar vendas e despesas;
- organizar despesas por categoria;
- acompanhar faturamento, gastos e resultado líquido;
- consultar histórico e relatórios;
- editar ou excluir lançamentos;
- proteger os dados com login de usuário.

## Como instalar

### Instalar uma versão pronta

Baixe diretamente o [APK da versão 1.0.0](https://github.com/juliocesar-ADS/APP--Rastreador-de-Despesas/releases/download/v1.0.0/app-release.apk) no Android e toque no arquivo para instalar. Também é possível consultar a página de [Releases](https://github.com/juliocesar-ADS/APP--Rastreador-de-Despesas/releases) para ver outras versões.

Se o Android solicitar, permita a instalação de aplicativos da fonte usada para baixar o arquivo. Ative essa permissão apenas durante a instalação.

> A instalação é feita pelo link acima, mas o aplicativo precisa de uma API acessível para fazer login, salvar vendas e consultar despesas. Para usar gratuitamente sem hospedagem, siga o [guia de uso local](DEPLOYMENT_LOCAL.md) antes de compilar uma versão apontada para a sua API.

### Compilar e instalar pelo código

É necessário ter:

- computador com Flutter estável;
- JDK 17;
- Android SDK;
- celular Android ou emulador.

Baixe o projeto:

```bash
git clone https://github.com/juliocesar-ADS/APP--Rastreador-de-Despesas.git
cd APP--Rastreador-de-Despesas
```

Instale as dependências do aplicativo:

```bash
cd app
flutter pub get
```

Gere e valide o APK informando o endereço da API:

```bash
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://SEU-ENDERECO/api
```

O arquivo será criado em:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

Transfira o APK para o celular e abra o arquivo para instalar.

## Uso gratuito e local

O projeto também pode ser usado sem hospedagem paga. Nesse modo, a API Flask roda localmente e os dados ficam em um banco SQLite no dispositivo ou no computador.

Siga o guia [DEPLOYMENT_LOCAL.md](DEPLOYMENT_LOCAL.md) para:

1. instalar o Termux;
2. baixar o projeto no Android;
3. criar o banco local;
4. iniciar a API;
5. gerar o APK apontando para a API local.

Limitações do modo local:

- a API precisa estar ligada para o aplicativo funcionar;
- os dados não são sincronizados entre aparelhos;
- não existe backup automático;
- o modo local não deve ser exposto na internet.

## Observação sobre a API

O aplicativo depende da API Flask para login, vendas, despesas e relatórios. O GitHub armazena o código, mas não executa a API. Para uso pessoal e gratuito, utilize o modo local documentado acima.

## Links

- [Guia de uso local](DEPLOYMENT_LOCAL.md)
- [Código do aplicativo](app/)
- [Código da API](backend/)
- [Banco de dados](database/)
