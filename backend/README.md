# Backend Flask

API REST da aplicação. O servidor mantém os dados financeiros no MySQL e exige autenticação nas rotas privadas.

## Requisitos e configuração

- Python 3.10 ou superior.
- MySQL 8.0.16 ou superior, inicializado conforme [`database/README.md`](../database/README.md).

Na raiz do repositório, crie o ambiente virtual, instale as dependências e configure o arquivo de ambiente:

```powershell
py -3.12 -m venv backend\.venv
.\backend\.venv\Scripts\Activate.ps1
python -m pip install -r backend\requirements-dev.txt
Copy-Item .env.example .env
```

Edite `.env` com a URL do banco e duas chaves independentes com pelo menos 32 bytes. Gere cada chave com:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Não use credenciais de exemplo nem a conta `root` do MySQL. `.env` está excluído do Git.

`DATABASE_URL` aceita `mysql+pymysql://usuario:senha@host:porta/banco`; URLs MySQL que começam com `mysql://` são ajustadas para o driver PyMySQL instalado. Quando a URL exige TLS (`ssl-mode=REQUIRED` ou `sslmode=REQUIRED`), informe também `DATABASE_SSL_CA` com o caminho do certificado CA do provedor. O backend valida o certificado e a identidade do servidor; sem o CA, a inicialização falha explicitamente.

## Executar localmente

Com o banco configurado e o ambiente virtual ativo:

```powershell
python -m backend.run
```

O servidor de desenvolvimento fica em `http://127.0.0.1:5000` e não deve ser usado em produção. Para testar com o emulador Android:

```powershell
python -m flask --app backend.run run --host=0.0.0.0 --port=5000
```

Use `http://10.0.2.2:5000/api` como `API_BASE_URL` no emulador. Em produção, publique a API atrás de HTTPS e use um servidor WSGI apropriado.

## Endpoints

- `GET /api/health`: verifica a conexão com o banco.
- `POST /api/usuarios`: cria uma conta e suas categorias iniciais.
- `POST /api/auth/login`: valida e-mail/senha e retorna um token JWT Bearer com validade de 30 minutos.
- `GET /api/categorias/gastos` e `POST /api/categorias/gastos`: lista ou cria categorias da conta.
- `/api/vendas`: `GET` lista, `POST` cria, `GET /<id>` consulta, `PUT /<id>` edita e `DELETE /<id>` exclui vendas.
- `/api/gastos`: `GET` lista, `POST` cria, `GET /<id>` consulta, `PUT /<id>` edita e `DELETE /<id>` exclui gastos.
- `GET /api/relatorios/hoje` e `GET /api/relatorios/ontem`: totais e lançamentos do dia no fuso configurado.
- `GET /api/relatorios/dia?data=AAAA-MM-DD`: relatório de um dia.
- `GET /api/relatorios/periodo?inicio=AAAA-MM-DD&fim=AAAA-MM-DD`: período inclusivo.
- `GET /api/relatorios/mes/<ano>/<mes>`: resumo e lançamentos do mês.
- `GET /api/dashboard`: resumos de hoje e do mês e séries diárias/mensais para os gráficos.

As listagens de vendas aceitam os parâmetros opcionais `inicio`, `fim` e `forma_pagamento`. As listagens de gastos aceitam `inicio`, `fim` e `categoria_id`. Os limites de data são inclusivos e usam `AAAA-MM-DD`.

Rotas privadas usam `Authorization: Bearer <token>`. Senhas são armazenadas com hash; as consultas são limitadas à conta autenticada. Formas de pagamento aceitas: `dinheiro`, `pix`, `cartao_debito`, `cartao_credito` e `outro`. O campo `valor` deve ser enviado como texto decimal (por exemplo, `"850.00"`); valores não positivos ou com mais de duas casas são rejeitados.

## Testes

```powershell
python -m pytest backend\tests
```

Os testes HTTP usam SQLite em memória e não substituem a validação de integração com MySQL. As configurações `FLASK_SECRET_KEY`, `JWT_SECRET_KEY` e `DATABASE_URL` são obrigatórias para iniciar a API normalmente.

## Validação

Os testes automatizados cobrem cadastro, autenticação, isolamento por conta, validação, vendas, gastos, categorias, edição/exclusão, filtros, cálculos, relatórios e dashboard. Os fluxos financeiros e os relatórios também foram exercitados em instâncias MySQL 8.0.45 temporárias e isoladas.
