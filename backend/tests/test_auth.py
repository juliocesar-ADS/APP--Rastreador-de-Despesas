from sqlalchemy import text
from werkzeug.security import check_password_hash

from backend.app.extensions import db


def register_account(client, email="cliente@example.com", password="senha-segura-1"):
    return client.post(
        "/api/usuarios",
        json={
            "nome": "Cliente de Teste",
            "email": email,
            "senha": password,
        },
    )


def test_registration_hashes_password_and_creates_default_categories(app, client):
    response = register_account(client)

    assert response.status_code == 201
    assert response.get_json()["email"] == "cliente@example.com"
    assert "senha" not in response.get_json()

    with app.app_context():
        user = db.session.execute(
            text("SELECT id, senha_hash FROM usuarios WHERE email = :email"),
            {"email": "cliente@example.com"},
        ).mappings().one()
        categories = db.session.execute(
            text(
                "SELECT nome FROM categorias_gastos "
                "WHERE usuario_id = :usuario_id ORDER BY nome"
            ),
            {"usuario_id": user["id"]},
        ).scalars().all()

    assert user["senha_hash"] != "senha-segura-1"
    assert check_password_hash(user["senha_hash"], "senha-segura-1")
    assert categories == sorted(
        [
            "Compras",
            "Funcionários",
            "Transporte",
            "Manutenção",
            "Contas",
            "Aluguel",
            "Materiais",
            "Outros",
        ]
    )


def test_duplicate_email_is_rejected_case_insensitively(client):
    assert register_account(client, email="cliente@example.com").status_code == 201

    response = register_account(client, email="CLIENTE@example.com")

    assert response.status_code == 409
    assert response.get_json()["erro"]["codigo"] == "email_ja_cadastrado"


def test_login_returns_bearer_token_and_rejects_wrong_password(client):
    register_account(client)

    response = client.post(
        "/api/auth/login",
        json={"email": "CLIENTE@example.com", "senha": "senha-segura-1"},
    )

    assert response.status_code == 200
    assert response.get_json()["token_type"] == "Bearer"
    assert response.get_json()["access_token"]

    response = client.post(
        "/api/auth/login",
        json={"email": "cliente@example.com", "senha": "senha-incorreta"},
    )

    assert response.status_code == 401
    assert response.get_json()["erro"]["mensagem"] == "E-mail ou senha incorretos."


def test_registration_validates_email_and_password(client):
    response = client.post(
        "/api/usuarios",
        json={
            "nome": "Cliente",
            "email": "email-invalido",
            "senha": "senha-segura-1",
        },
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "email_invalido"

    response = client.post(
        "/api/usuarios",
        json={
            "nome": "Cliente",
            "email": "cliente@example.com",
            "senha": "curta",
        },
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "senha_invalida"

    response = client.post(
        "/api/auth/login",
        json={
            "email": "cliente@example.com",
            "senha": "x" * 129,
        },
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "credenciais_invalidas"


def test_sales_route_requires_a_valid_token(client):
    response = client.get("/api/vendas")

    assert response.status_code == 401
    assert response.get_json()["erro"]["codigo"] == "token_ausente"

    response = client.get(
        "/api/vendas",
        headers={"Authorization": "Bearer token-invalido"},
    )

    assert response.status_code == 401
    assert response.get_json()["erro"]["codigo"] == "token_invalido"
