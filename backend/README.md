# Backend Flask

Esta etapa cria a base configurável do backend. A API de vendas, gastos, autenticação e relatórios será implementada nas etapas seguintes.

## Requisitos

- Python 3.10 ou superior.
- MySQL 8.0.16 ou superior.
- Um banco MySQL criado e inicializado conforme [`database/README.md`](../database/README.md).

## Configuração local no Windows

Na raiz do repositório, crie e ative um ambiente virtual e instale as dependências:

```powershell
py -3.12 -m venv backend\.venv
.\backend\.venv\Scripts\Activate.ps1
python -m pip install -r backend\requirements.txt
```

Copie o arquivo de exemplo e configure valores locais:

```powershell
Copy-Item .env.example .env
```

Edite `.env` com uma chave secreta aleatória e a URL do seu banco. Gere uma chave com:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Substitua `SUBSTITUA_POR_UMA_CHAVE_ALEATORIA` e `SUBSTITUA_A_SENHA`. Não use a senha `root` do MySQL na aplicação. Se a senha tiver caracteres especiais, codifique-os como URL antes de colocá-la em `DATABASE_URL`.

`.env` contém segredos locais e está excluído pelo `.gitignore`; somente `.env.example`, sem credenciais reais, deve ser versionado.

## Executar

Com o ambiente virtual ativo, o banco configurado e `.env` preenchido:

```powershell
python -m backend.run
```

O servidor de desenvolvimento do Flask fica acessível por padrão em `http://127.0.0.1:5000`. Ele não deve ser usado como servidor de produção.

## API inicial

`GET /api/health` verifica a conexão com o banco. Se o banco estiver indisponível, a API responde com HTTP 503 e uma mensagem JSON em português.

Erros HTTP e falhas inesperadas também são retornados em JSON. Detalhes de exceções internas são registrados no log do servidor, mas não enviados ao cliente. Corpos de requisição JSON são limitados a 1 MiB; os endpoints de negócio ainda serão acrescentados nas etapas seguintes.

## Testes

Instale as dependências de desenvolvimento e execute os testes da API:

```powershell
python -m pip install -r backend\requirements-dev.txt
python -m pytest backend\tests
```

Os testes usam SQLite em memória para isolar a camada HTTP e não substituem os testes de integração com MySQL. As configurações `FLASK_SECRET_KEY` e `DATABASE_URL` são obrigatórias ao iniciar normalmente; a fábrica permite substituí-las explicitamente em testes.

## Validação executada

O backend foi compilado e a conexão configurada por `DATABASE_URL` foi exercitada por PyMySQL contra uma instância MySQL 8.0.45 temporária e isolada; a consulta de versão retornou com sucesso. A instância e os dados temporários foram encerrados e removidos.
