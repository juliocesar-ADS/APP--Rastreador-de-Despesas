import pytest

from backend.app import create_app
from backend.app.config import load_config


@pytest.mark.parametrize(
    ("secret_key", "jwt_secret_key"),
    [
        ("chave-curta", "chave-jwt-local-de-teste-com-mais-de-32-bytes"),
        (
            "chave-flask-local-de-teste-com-mais-de-32-bytes",
            "SUBSTITUA_POR_OUTRA_CHAVE_ALEATORIA",
        ),
    ],
)
def test_app_rejects_short_or_example_secrets(secret_key, jwt_secret_key):
    with pytest.raises(RuntimeError, match="pelo menos 32 bytes"):
        create_app(
            {
                "SECRET_KEY": secret_key,
                "JWT_SECRET_KEY": jwt_secret_key,
                "SQLALCHEMY_DATABASE_URI": "sqlite://",
            }
        )


def test_app_rejects_unknown_business_timezone():
    with pytest.raises(RuntimeError, match="APP_TIMEZONE"):
        create_app(
            {
                "SECRET_KEY": "chave-flask-local-de-teste-com-mais-de-32-bytes",
                "JWT_SECRET_KEY": "chave-jwt-local-de-teste-com-mais-de-32-bytes",
                "SQLALCHEMY_DATABASE_URI": "sqlite://",
                "APP_TIMEZONE": "America/Desconhecida",
            }
        )


def test_mysql_urls_use_the_installed_pymysql_driver(monkeypatch):
    monkeypatch.setenv(
        "DATABASE_URL",
        "mysql://app:senha@db.example.com:25060/aplicativo_gastos?ssl-mode=REQUIRED",
    )
    monkeypatch.setenv("DATABASE_SSL_CA", "/etc/ssl/mysql-ca.pem")

    config = load_config()

    assert (
        config["SQLALCHEMY_DATABASE_URI"]
        == "mysql+pymysql://app:senha@db.example.com:25060/aplicativo_gastos"
    )
    assert config["SQLALCHEMY_ENGINE_OPTIONS"]["connect_args"] == {
        "ssl": {"ca": "/etc/ssl/mysql-ca.pem"},
        "ssl_verify_cert": True,
        "ssl_verify_identity": True,
    }


def test_tls_mysql_url_requires_a_ca_certificate(monkeypatch):
    monkeypatch.setenv(
        "DATABASE_URL",
        "mysql://app:senha@db.example.com:25060/aplicativo_gastos?sslmode=REQUIRED",
    )
    monkeypatch.delenv("DATABASE_SSL_CA", raising=False)

    with pytest.raises(RuntimeError, match="DATABASE_SSL_CA"):
        load_config()
