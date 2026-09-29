import pytest

from backend.app import create_app


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
