# Controle de Gastos

Aplicativo Android em português brasileiro para registrar vendas e gastos, acompanhar o resultado líquido e consultar relatórios. A solução usa Flutter/Dart, API REST Flask e banco MySQL; lançamentos e totais vêm do servidor, sem dados de demonstração ou sincronização offline.

## Funcionalidades

- Cadastro de conta, login e token de acesso guardado no armazenamento seguro do Android.
- Painel com faturamento, gastos e resultado líquido de hoje e do mês.
- Gráficos de vendas e gastos por dia e evolução dos últimos seis meses.
- Cadastro, edição, consulta e exclusão de vendas e gastos.
- Categorias de gastos, formas de pagamento e histórico com filtro de período.
- Relatórios mensais com os lançamentos correspondentes.
- API com valores decimais exatos, autenticação e isolamento de dados por usuário.

## Estrutura

- `app/`: aplicativo Flutter para Android.
- `backend/`: API REST Flask.
- `database/`: esquema MySQL.
- `docs/`: decisões de arquitetura.

## Banco de dados e API local

Requisitos: Python 3.10+, MySQL 8.0.16+ e um banco criado conforme [`database/README.md`](database/README.md).

Na raiz do repositório, no PowerShell:

```powershell
py -3.12 -m venv backend\.venv
.\backend\.venv\Scripts\Activate.ps1
python -m pip install -r backend\requirements-dev.txt
Copy-Item .env.example .env
```

Edite `.env` com as credenciais do MySQL e duas chaves aleatórias independentes. Gere cada chave com `python -c "import secrets; print(secrets.token_urlsafe(48))"`. Nunca use os valores de exemplo em produção nem versione `.env`.

Para iniciar o servidor de desenvolvimento:

```powershell
python -m backend.run
```

O endereço local padrão é `http://127.0.0.1:5000`. Para acessar pelo emulador Android, inicie a API vinculada à rede local:

```powershell
python -m flask --app backend.run run --host=0.0.0.0 --port=5000
```

O emulador Android acessa a máquina hospedeira em `10.0.2.2`. A permissão para tráfego HTTP sem TLS existe apenas na configuração de depuração do Android; builds de produção devem usar HTTPS. Não exponha o servidor Flask de desenvolvimento na internet.

## Aplicativo Android

Instale Flutter estável, JDK 17 e Android SDK. No diretório `app/`, instale as dependências e execute a análise e os testes:

```powershell
flutter pub get
flutter analyze
flutter test
```

Inicie o app no emulador apontando para a API local:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

`API_BASE_URL` deve terminar em `/api`. Para compilar uma versão de produção, use a URL HTTPS da API implantada:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://seu-dominio/api
```

O APK gerado fica em `app/build/app/outputs/flutter-apk/app-release.apk`. A distribuição pública exige primeiro implantar a API e o MySQL em um provedor externo; o GitHub não hospeda esse backend. O código está publicado em [juliocesar-ADS/aplicativo-de-gastos](https://github.com/juliocesar-ADS/aplicativo-de-gastos), mas a URL da API de produção ainda não foi configurada.

## Endpoints principais

- `POST /api/usuarios` e `POST /api/auth/login`: cadastro e autenticação.
- `/api/vendas`: listar, filtrar, cadastrar, editar e excluir vendas.
- `/api/gastos` e `/api/categorias/gastos`: gastos e categorias da conta.
- `/api/relatorios/hoje`, `/api/relatorios/ontem`, `/api/relatorios/dia`, `/api/relatorios/periodo` e `/api/relatorios/mes/<ano>/<mes>`: relatórios.
- `GET /api/dashboard`: resumos e séries para os gráficos.

As rotas privadas recebem `Authorization: Bearer <token>`. Valores monetários devem ser enviados como texto decimal com até duas casas, por exemplo `"850.00"`.

## Hospedagem de produção

O GitHub não executa a API nem fornece um MySQL de produção. Como opção recomendada, a DigitalOcean documenta o deploy Python pelo App Platform e oferece MySQL gerenciado; o `Procfile` e o `requirements.txt` da raiz preparam o comando WSGI. Em 29/09/2026, os menores recursos consultados somavam aproximadamente **US$ 20/mês** (serviço web de US$ 5 e banco MySQL de US$ 15, sem alta disponibilidade, impostos ou excedentes). Confirme o preço antes de contratar: [planos do App Platform](https://docs.digitalocean.com/products/app-platform/details/pricing/) e [preços do MySQL](https://docs.digitalocean.com/products/databases/mysql/details/pricing/).

Antes de disponibilizar o app para uso em produção, crie o banco gerenciado, aplique [`database/schema.sql`](database/schema.sql) nele e configure no serviço as variáveis `DATABASE_URL`, `DATABASE_SSL_CA`, `FLASK_SECRET_KEY`, `JWT_SECRET_KEY`, `APP_TIMEZONE=America/Sao_Paulo` e `FLASK_DEBUG=false`. O backend aceita a URL padrão `mysql://` e seleciona PyMySQL. Para uma URL com TLS obrigatório, configure `DATABASE_SSL_CA` com o certificado do provedor; a API valida o certificado e a identidade do servidor. Restrinja o acesso ao MySQL à API, habilite HTTPS e então compile o APK com a URL de produção. Não inclua credenciais no app nem no repositório. Nenhum serviço de produção foi criado: ainda é necessário provisionar a API e o banco e configurar o domínio da API.

## Testes

Na raiz do repositório, com o ambiente virtual ativo:

```powershell
python -m pytest backend\tests
```

No diretório `app/`:

```powershell
flutter analyze
flutter test
```

Os testes automatizados do backend usam SQLite em memória; testes de integração com MySQL são descritos em [`backend/README.md`](backend/README.md).
