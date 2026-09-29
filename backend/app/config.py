import os
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy.engine import make_url


PROJECT_ROOT = Path(__file__).resolve().parents[2]


def load_config() -> dict[str, object]:
    load_dotenv(PROJECT_ROOT / ".env")
    database_url, engine_options = _database_configuration()

    return {
        "SECRET_KEY": os.getenv("FLASK_SECRET_KEY"),
        "JWT_SECRET_KEY": os.getenv("JWT_SECRET_KEY"),
        "JWT_ACCESS_TOKEN_EXPIRES": timedelta(minutes=30),
        "SQLALCHEMY_DATABASE_URI": database_url,
        "SQLALCHEMY_TRACK_MODIFICATIONS": False,
        "SQLALCHEMY_ENGINE_OPTIONS": engine_options,
        "MAX_CONTENT_LENGTH": 1_048_576,
        "APP_TIMEZONE": os.getenv("APP_TIMEZONE", "America/Sao_Paulo"),
        "DEBUG": os.getenv("FLASK_DEBUG", "false").strip().lower() == "true",
    }


def _database_configuration() -> tuple[str | None, dict[str, object]]:
    database_url = os.getenv("DATABASE_URL")
    engine_options: dict[str, object] = {"pool_pre_ping": True}
    if not database_url:
        return None, engine_options

    url = make_url(database_url)
    query = dict(url.query)
    ssl_mode = query.pop("ssl-mode", None) or query.pop("sslmode", None)
    if url.drivername == "mysql":
        url = url.set(drivername="mysql+pymysql")

    ssl_ca = os.getenv("DATABASE_SSL_CA")
    if ssl_mode is not None:
        normalized_mode = str(ssl_mode).upper().replace("-", "_")
        if normalized_mode not in {"REQUIRED", "VERIFY_CA", "VERIFY_IDENTITY"}:
            raise RuntimeError(
                "O modo TLS do MySQL deve ser REQUIRED, VERIFY_CA ou VERIFY_IDENTITY."
            )
    if ssl_mode is not None or ssl_ca:
        if not ssl_ca:
            raise RuntimeError(
                "Configure DATABASE_SSL_CA com o certificado CA do provedor "
                "para validar a conexão TLS do MySQL."
            )
        engine_options["connect_args"] = {
            "ssl": {"ca": ssl_ca},
            "ssl_verify_cert": True,
            "ssl_verify_identity": True,
        }

    return url.set(query=query).render_as_string(hide_password=False), engine_options
