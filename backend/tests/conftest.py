import pytest
from sqlalchemy import text

from backend.app import create_app
from backend.app.api.requests import require_json_object
from backend.app.extensions import db


@pytest.fixture
def app():
    app = create_app(
        {
            "TESTING": True,
            "SECRET_KEY": "chave-flask-local-de-teste-com-mais-de-32-bytes",
            "JWT_SECRET_KEY": "chave-jwt-local-de-teste-com-mais-de-32-bytes",
            "SQLALCHEMY_DATABASE_URI": "sqlite://",
            "MAX_CONTENT_LENGTH": 2048,
        }
    )
    with app.app_context():
        db.session.execute(text("PRAGMA foreign_keys = ON"))
        db.session.execute(
            text(
                "CREATE TABLE usuarios ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "nome VARCHAR(120) NOT NULL, "
                "email VARCHAR(254) NOT NULL UNIQUE, "
                "senha_hash VARCHAR(255) NOT NULL, "
                "criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)"
            )
        )
        db.session.execute(
            text(
                "CREATE TABLE categorias_gastos ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "usuario_id INTEGER NOT NULL, "
                "nome VARCHAR(80) NOT NULL, "
                "ativa BOOLEAN NOT NULL DEFAULT 1, "
                "criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "
                "UNIQUE (usuario_id, nome), "
                "UNIQUE (usuario_id, id), "
                "FOREIGN KEY (usuario_id) REFERENCES usuarios (id))"
            )
        )
        db.session.execute(
            text(
                "CREATE TABLE vendas ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "usuario_id INTEGER NOT NULL, "
                "descricao VARCHAR(255) NOT NULL, "
                "valor NUMERIC(13, 2) NOT NULL CHECK (valor > 0), "
                "data_venda DATE NOT NULL, "
                "hora_venda TIME NOT NULL, "
                "forma_pagamento VARCHAR(32) NOT NULL, "
                "observacao TEXT, "
                "criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "
                "FOREIGN KEY (usuario_id) REFERENCES usuarios (id))"
            )
        )
        db.session.commit()

    @app.post("/api/teste-json")
    def json_body_for_test():
        return require_json_object()

    return app


@pytest.fixture
def client(app):
    return app.test_client()
