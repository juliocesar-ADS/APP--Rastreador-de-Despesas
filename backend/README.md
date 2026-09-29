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

O servidor de desenvolvimento do Flask fica acessível por padrão em `http://127.0.0.1:5000`. Ele não deve ser usado como servidor de produção. Nesta etapa ainda não há rotas HTTP; os endpoints REST serão adicionados na etapa de API.

## Verificação da estrutura e da conexão SQLAlchemy

Este teste usa SQLite em memória apenas para confirmar que a fábrica Flask e a extensão SQLAlchemy inicializam. Ele não substitui a configuração nem os testes de integração com o MySQL:

```powershell
python -c "from sqlalchemy import text; from backend.app import create_app; from backend.app.extensions import db; app = create_app({'TESTING': True, 'SECRET_KEY': 'chave-local-de-teste', 'SQLALCHEMY_DATABASE_URI': 'sqlite://'}); app.app_context().push(); assert db.session.execute(text('SELECT 1')).scalar_one() == 1; print('Fabrica Flask e SQLAlchemy OK')"
```

As configurações `FLASK_SECRET_KEY` e `DATABASE_URL` são obrigatórias ao iniciar normalmente. A fábrica permite substituí-las explicitamente em testes.

## Validação executada

O backend foi compilado e a fábrica Flask/SQLAlchemy foi testada com uma consulta SQLite em memória. A conexão configurada por `DATABASE_URL` também foi exercitada por PyMySQL contra uma instância MySQL 8.0.45 temporária e isolada; a consulta de versão retornou com sucesso. A instância e os dados temporários foram encerrados e removidos. Os endpoints de negócio ainda não existem nesta etapa.
