# Uso local no Android com Termux e SQLite

Este guia mostra como executar a API e armazenar os dados localmente, sem contratar hospedagem.

## Como funciona

- o aplicativo Flutter é instalado no Android;
- a API Flask é executada no Termux;
- o banco SQLite fica em um arquivo local do aparelho;
- o aplicativo acessa a API pela rede local;
- os dados não são enviados para um servidor externo.

Este modo é indicado para uso pessoal e testes. Se o Termux for desinstalado ou o arquivo do banco for apagado, os dados poderão ser perdidos. Faça cópias do arquivo `aplicativo_gastos.db` quando necessário.

## 1. Instalar o Termux

Instale o Termux por uma fonte confiável:

- [F-Droid](https://f-droid.org/packages/com.termux/)
- [GitHub oficial do Termux](https://github.com/termux/termux-app/releases)

Abra o Termux e atualize os pacotes:

```bash
pkg update
pkg upgrade
pkg install git python
```

## 2. Baixar o projeto

```bash
git clone https://github.com/juliocesar-ADS/APP--Rastreador-de-Despesas.git
cd APP--Rastreador-de-Despesas
```

## 3. Criar o banco SQLite

Na raiz do projeto, execute:

```bash
python - <<'PY'
import sqlite3

connection = sqlite3.connect("aplicativo_gastos.db")
connection.executescript("""
CREATE TABLE IF NOT EXISTS usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    senha_hash TEXT NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS categorias_gastos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id INTEGER NOT NULL,
    nome TEXT NOT NULL,
    ativa BOOLEAN NOT NULL DEFAULT 1,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (usuario_id, nome),
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
);

CREATE TABLE IF NOT EXISTS vendas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id INTEGER NOT NULL,
    descricao TEXT NOT NULL,
    valor DECIMAL(13, 2) NOT NULL,
    data_venda DATE NOT NULL,
    hora_venda TIME NOT NULL,
    forma_pagamento TEXT NOT NULL,
    observacao TEXT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
);

CREATE TABLE IF NOT EXISTS gastos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id INTEGER NOT NULL,
    categoria_id INTEGER NOT NULL,
    descricao TEXT NOT NULL,
    valor DECIMAL(13, 2) NOT NULL,
    data_gasto DATE NOT NULL,
    hora_gasto TIME NOT NULL,
    observacao TEXT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    FOREIGN KEY (categoria_id) REFERENCES categorias_gastos (id)
);
""")
connection.commit()
connection.close()
print("Banco local criado.")
PY
```

## 4. Configurar e iniciar a API

Crie o ambiente Python:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Crie o arquivo `.env`:

```bash
cat > .env <<'ENV'
FLASK_SECRET_KEY=SUBSTITUA_POR_UMA_CHAVE_LONGA
JWT_SECRET_KEY=SUBSTITUA_POR_OUTRA_CHAVE_LONGA
DATABASE_URL=sqlite:///aplicativo_gastos.db
APP_TIMEZONE=America/Sao_Paulo
FLASK_DEBUG=false
ENV
```

Gere duas chaves diferentes e substitua os valores no `.env`:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Inicie a API:

```bash
python -m backend.run
```

Mantenha essa sessão do Termux aberta enquanto usa o aplicativo.

## 5. Compilar o APK

A compilação do aplicativo Flutter é feita em um computador com Flutter, JDK 17 e Android SDK:

```bash
cd app
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=http://ENDERECO_DA_API:5000/api
```

O endereço depende de onde a API está sendo executada:

- emulador Android com API no computador: `http://10.0.2.2:5000/api`;
- celular físico com API no computador: `http://IP_DO_COMPUTADOR:5000/api`;
- API no Termux do próprio celular: use o endereço local indicado pelo Android/Termux.

O APK será criado em `app/build/app/outputs/flutter-apk/app-release.apk`. Transfira-o para o Android e instale-o.

## 6. Executar a API pela rede local

Quando a API estiver no computador e o celular precisar acessá-la, inicie-a escutando na rede:

```bash
python -m flask --app backend.run run --host=0.0.0.0 --port=5000
```

O computador e o celular precisam estar na mesma rede. Libere a porta 5000 no firewall apenas para essa rede privada.

## Limitações

- a API precisa estar em execução para o aplicativo funcionar;
- o banco não é sincronizado entre aparelhos;
- não há backup automático;
- o modo HTTP local não deve ser exposto na internet;
- para uso público ou multiusuário, hospede a API e o banco com HTTPS e credenciais protegidas.
