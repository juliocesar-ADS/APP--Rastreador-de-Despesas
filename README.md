# Controle de Gastos

Aplicativo Android em português brasileiro para registrar vendas e gastos, acompanhar o resultado líquido e consultar relatórios.

O projeto contém:

- aplicativo Android feito com Flutter;
- API REST feita com Flask;
- banco de dados MySQL para ambientes com servidor;
- suporte a SQLite para uso local e pessoal;
- testes automatizados do backend e do aplicativo.

## Importante antes de instalar

Este repositório contém o **código-fonte**, não um APK pronto anexado ao GitHub. Portanto, há duas formas de usar o aplicativo:

1. baixar um APK publicado na área **Releases**, quando existir;
2. compilar o APK seguindo as instruções deste documento.

O aplicativo precisa de uma API para funcionar. A API não é hospedada pelo GitHub. Para usar sem pagar hospedagem, execute a API localmente com SQLite, conforme a seção [Uso gratuito e local](#uso-gratuito-e-local).

## Funcionalidades

- cadastro e login de usuários;
- painel com faturamento, gastos e resultado líquido;
- gráficos por dia e evolução dos últimos seis meses;
- cadastro, edição, consulta e exclusão de vendas e gastos;
- categorias de gastos e formas de pagamento;
- histórico com filtros de período;
- relatórios mensais;
- autenticação por token e isolamento dos dados entre usuários.

## Estrutura do repositório

```text
app/       Aplicativo Flutter para Android
backend/   API REST Flask
database/  Schema e documentação do banco
docs/      Decisões de arquitetura
```

## Opção 1: instalar um APK publicado

Quando houver um APK publicado, acesse a aba [Releases](https://github.com/juliocesar-ADS/APP--Rastreador-de-Despesas/releases), baixe o arquivo `.apk` no Android e abra-o para instalar.

O Android pode solicitar autorização para instalar aplicativos de fontes desconhecidas. Habilite essa permissão somente para o navegador ou gerenciador de arquivos usado para abrir o APK e desative-a depois da instalação.

Um APK só funciona corretamente quando foi compilado com uma URL de API acessível pelo aparelho. Se não houver uma Release publicada ou uma API configurada, use a opção 2.

## Opção 2: compilar o aplicativo pelo código

### Requisitos

- Flutter estável;
- JDK 17;
- Android SDK com as licenças aceitas;
- um computador Windows, macOS ou Linux;
- um celular Android ou emulador para testar.

Na pasta do projeto, execute:

```bash
cd app
flutter pub get
flutter analyze
flutter test
```

Para gerar um APK:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://SEU-ENDERECO/api
```

No Windows PowerShell, use o comando em uma linha:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://SEU-ENDERECO/api
```

O arquivo gerado ficará em:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

Transfira esse arquivo para o celular e abra-o para instalar.

> A URL informada em `API_BASE_URL` deve terminar em `/api` e precisa estar acessível pelo celular. Não use `localhost` no APK instalado no celular para acessar uma API que está no computador.

## Uso gratuito e local

Para não contratar hospedagem, é possível executar a API no próprio Android usando Termux e SQLite. Nesse cenário:

- os dados ficam no arquivo SQLite local do dispositivo;
- não há servidor MySQL remoto;
- o aplicativo depende da API estar em execução no Termux;
- o uso é indicado para uma pessoa ou para testes;
- não há backup automático nem sincronização entre aparelhos.

O passo a passo completo está em [DEPLOYMENT_LOCAL.md](DEPLOYMENT_LOCAL.md).

Resumo do fluxo:

1. instalar o Termux;
2. clonar este repositório no Termux;
3. criar o banco SQLite e o ambiente Python;
4. iniciar a API Flask;
5. compilar o APK apontando `API_BASE_URL` para o endereço local do Android;
6. instalar o APK no mesmo aparelho.

Para uso local em um emulador Android, a API pode ser executada no computador e o app pode usar:

```text
http://10.0.2.2:5000/api
```

Para um celular físico, computador e celular precisam estar na mesma rede Wi-Fi e o APK deve usar o IP local do computador, por exemplo:

```text
http://192.168.0.10:5000/api
```

O endereço exato varia conforme a rede. A API deve ser iniciada escutando na rede local:

```bash
python -m flask --app backend.run run --host=0.0.0.0 --port=5000
```

Não exponha essa API de desenvolvimento diretamente na internet.

## Executar o backend localmente

### Requisitos

- Python 3.10 ou superior;
- SQLite para uso local ou MySQL 8.0.16 ou superior para servidor.

Crie um ambiente virtual e instale as dependências:

```powershell
py -3.12 -m venv backend\.venv
backend\.venv\Scripts\python.exe -m pip install -r backend\requirements-dev.txt
Copy-Item .env.example .env
```

Edite `.env` e defina duas chaves secretas diferentes. Elas podem ser geradas com:

```powershell
backend\.venv\Scripts\python.exe -c "import secrets; print(secrets.token_urlsafe(48))"
```

Para SQLite local, use:

```dotenv
DATABASE_URL=sqlite:///aplicativo_gastos.db
APP_TIMEZONE=America/Sao_Paulo
FLASK_DEBUG=true
```

O schema usado pelo SQLite local está documentado em [DEPLOYMENT_LOCAL.md](DEPLOYMENT_LOCAL.md). Para MySQL, consulte [database/README.md](database/README.md) e [database/schema.sql](database/schema.sql).

Inicie a API:

```powershell
backend\.venv\Scripts\python.exe -m backend.run
```

A API ficará disponível em `http://127.0.0.1:5000`.

## Testes

Backend:

```powershell
backend\.venv\Scripts\python.exe -m pytest backend\tests
```

Flutter:

```powershell
cd app
flutter analyze
flutter test
```

## API

Principais endpoints:

- `POST /api/usuarios`: cadastro;
- `POST /api/auth/login`: login;
- `/api/vendas`: vendas;
- `/api/gastos`: gastos;
- `/api/categorias/gastos`: categorias;
- `/api/relatorios/...`: relatórios;
- `GET /api/dashboard`: painel financeiro.

Rotas privadas exigem o cabeçalho `Authorization` com o token recebido no login. Valores monetários devem ser enviados como texto decimal com até duas casas, por exemplo `"850.00"`.

## Produção e segurança

O setup local é destinado a uso pessoal e desenvolvimento. Para disponibilizar o sistema para várias pessoas, é necessário hospedar a API e o banco em um provedor externo, usar HTTPS, configurar segredos fora do Git e compilar o APK com a URL de produção.

Não versione:

- `.env`;
- senhas;
- tokens;
- certificados privados;
- chaves de assinatura do Android.

Consulte também:

- [app/README.md](app/README.md)
- [backend/README.md](backend/README.md)
- [database/README.md](database/README.md)
- [DEPLOYMENT_LOCAL.md](DEPLOYMENT_LOCAL.md)
