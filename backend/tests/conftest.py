import pytest

from backend.app import create_app
from backend.app.api.requests import require_json_object


@pytest.fixture
def app():
    app = create_app(
        {
            "TESTING": True,
            "SECRET_KEY": "chave-local-de-teste",
            "SQLALCHEMY_DATABASE_URI": "sqlite://",
            "MAX_CONTENT_LENGTH": 32,
        }
    )

    @app.post("/api/teste-json")
    def json_body_for_test():
        return require_json_object()

    return app


@pytest.fixture
def client(app):
    return app.test_client()
