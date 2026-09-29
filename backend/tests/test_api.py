import pytest
from sqlalchemy.exc import OperationalError

from backend.app.api import routes


def test_health_checks_database(client):
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.get_json() == {
        "status": "ok",
        "mensagem": "API e banco de dados disponíveis.",
    }


def test_health_reports_database_unavailable(client, monkeypatch):
    def fail_database_check():
        raise OperationalError("SELECT 1", {}, OSError("conexão recusada"))

    monkeypatch.setattr(routes, "check_database", fail_database_check)
    response = client.get("/api/health")

    assert response.status_code == 503
    assert response.get_json() == {
        "erro": {
            "codigo": "banco_indisponivel",
            "mensagem": "Não foi possível conectar ao banco de dados.",
        }
    }


def test_http_errors_use_json_and_portuguese_messages(client):
    response = client.get("/api/rota-inexistente")

    assert response.status_code == 404
    assert response.get_json() == {
        "erro": {
            "codigo": "recurso_nao_encontrado",
            "mensagem": "O recurso solicitado não foi encontrado.",
        }
    }

    response = client.post("/api/health")

    assert response.status_code == 405
    assert response.is_json


def test_unexpected_errors_are_logged_and_not_exposed(app, client, caplog):
    @app.get("/api/teste-erro-interno")
    def trigger_internal_error():
        raise RuntimeError("detalhe interno")

    response = client.get("/api/teste-erro-interno")

    assert response.status_code == 500
    assert response.get_json() == {
        "erro": {
            "codigo": "erro_interno",
            "mensagem": "Ocorreu um erro interno. Tente novamente.",
        }
    }
    assert "detalhe interno" in caplog.text


def test_json_requests_are_validated(client):
    response = client.post("/api/teste-json", json={"descricao": "Venda"})

    assert response.status_code == 200
    assert response.get_json() == {"descricao": "Venda"}

    response = client.post(
        "/api/teste-json",
        data="nao-json",
        content_type="application/json",
    )

    assert response.status_code == 400
    assert response.get_json()["erro"]["codigo"] == "json_invalido"

    response = client.post("/api/teste-json", json=["lista"])

    assert response.status_code == 400
    assert response.get_json()["erro"]["codigo"] == "objeto_json_esperado"

    response = client.post(
        "/api/teste-json",
        data="{}",
        content_type="text/plain",
    )

    assert response.status_code == 415
    assert response.get_json()["erro"]["codigo"] == "tipo_de_conteudo_invalido"

    response = client.post(
        "/api/teste-json",
        data="x" * 33,
        content_type="application/json",
    )

    assert response.status_code == 413
    assert response.get_json()["erro"]["codigo"] == "conteudo_muito_grande"
