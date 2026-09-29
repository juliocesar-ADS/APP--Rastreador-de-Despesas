# Backend Flask

Backend Flask da aplicação, com autenticação, vendas, gastos e categorias já disponíveis. Os endpoints de relatórios serão acrescentados nas próximas etapas.

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

Edite `.env` com duas chaves secretas independentes e a URL do seu banco. Gere uma chave aleatória para cada segredo com:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Substitua `SUBSTITUA_POR_UMA_CHAVE_ALEATORIA`, `SUBSTITUA_POR_OUTRA_CHAVE_ALEATORIA` e `SUBSTITUA_A_SENHA`. Não use a senha `root` do MySQL na aplicação. Se a senha tiver caracteres especiais, codifique-os como URL antes de colocá-la em `DATABASE_URL`.

`.env` contém segredos locais e está excluído pelo `.gitignore`; somente `.env.example`, sem credenciais reais, deve ser versionado.

## Executar

Com o ambiente virtual ativo, o banco configurado e `.env` preenchido:

```powershell
python -m backend.run
```

O servidor de desenvolvimento do Flask fica acessível por padrão em `http://127.0.0.1:5000`. Ele não deve ser usado como servidor de produção.

## API inicial

`GET /api/health` verifica a conexão com o banco. Se o banco estiver indisponível, a API responde com HTTP 503 e uma mensagem JSON em português.

Erros HTTP e falhas inesperadas também são retornados em JSON. Detalhes de exceções internas são registrados no log do servidor, mas não enviados ao cliente. Corpos de requisição JSON são limitados a 1 MiB.

## Contas e vendas

- `POST /api/usuarios`: cria uma conta e suas categorias padrão. Senhas são armazenadas com hash; o endpoint não retorna a senha. Campos: `nome`, `email` e `senha`.
- `POST /api/auth/login`: valida e-mail e senha e retorna um token Bearer com validade de 30 minutos.
- `GET /api/vendas`: lista as vendas da conta autenticada.
- `GET /api/vendas/<id>`: consulta uma venda pertencente à conta autenticada.
- `POST /api/vendas`: cadastra uma venda com `descricao`, `valor`, `data_venda`, `hora_venda`, `forma_pagamento` e `observacao` opcional.
- `GET /api/categorias/gastos`: lista as categorias ativas da conta.
- `POST /api/categorias/gastos`: cria uma categoria adicional informando `nome`.
- `GET /api/gastos`: lista os gastos da conta autenticada.
- `GET /api/gastos/<id>`: consulta um gasto pertencente à conta autenticada.
- `POST /api/gastos`: cadastra um gasto com `descricao`, `categoria_id`, `valor`, `data_gasto`, `hora_gasto` e `observacao` opcional. O `categoria_id` deve vir da lista de categorias da conta.
- `GET /api/relatorios/hoje`: apresenta as movimentações e os totais de hoje no fuso configurado.
- `GET /api/relatorios/ontem`: apresenta as movimentações e os totais do dia anterior no mesmo fuso.
- `GET /api/relatorios/dia?data=AAAA-MM-DD`: consulta um dia específico.
- `GET /api/relatorios/periodo?inicio=AAAA-MM-DD&fim=AAAA-MM-DD`: consulta um intervalo com as duas datas incluídas.
- `GET /api/relatorios/mes/<ano>/<mes>`: consulta o resumo e os lançamentos cronológicos de um mês.

As rotas de vendas exigem `Authorization: Bearer <token>`. O campo `valor` deve ser enviado como texto decimal (por exemplo, `"850.00"`), evitando perda de precisão; valores iguais a zero, negativos ou com mais de duas casas decimais são rejeitados. Atualização e exclusão serão adicionadas na etapa prevista no plano.

Todas as rotas privadas exigem `Authorization: Bearer <token>`. A API confere a conta do token em cada consulta e não aceita categorias de outra conta. Formas de pagamento aceitas: `dinheiro`, `pix`, `cartao_debito`, `cartao_credito` e `outro`. A data deve usar `AAAA-MM-DD`; o horário deve usar `HH:MM` ou `HH:MM:SS`.

## Cálculos financeiros

O serviço `backend.app.services.financial.calculate_financial_summary` calcula os totais de vendas e gastos com `Decimal`, além do faturamento bruto, resultado líquido e quantidades. O intervalo interno usa início inclusivo e fim exclusivo, e todos os cálculos são restritos à conta autenticada. Os relatórios diários e mensais já usam esse serviço; o dashboard será ligado a ele na próxima etapa.

## Testes

Instale as dependências de desenvolvimento e execute os testes da API:

```powershell
python -m pip install -r backend\requirements-dev.txt
python -m pytest backend\tests
```

Os testes usam SQLite em memória para isolar a camada HTTP e não substituem os testes de integração com MySQL. As configurações `FLASK_SECRET_KEY`, `JWT_SECRET_KEY` e `DATABASE_URL` são obrigatórias ao iniciar normalmente; a fábrica permite substituí-las explicitamente em testes.

## Validação executada

Os 52 testes automatizados passaram. Os fluxos de conta, login, vendas, categorias, gastos, cálculo financeiro e relatórios diários/mensais foram validados. A integração de relatórios foi exercitada contra MySQL 8.0.45, incluindo fevereiro bissexto e limites de período; as instâncias temporárias foram encerradas e seus dados removidos.
