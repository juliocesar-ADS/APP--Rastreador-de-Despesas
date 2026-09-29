from collections.abc import Mapping

from flask import Flask

from backend.app.config import load_config
from backend.app.extensions import db


def create_app(test_config: Mapping[str, object] | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_mapping(load_config())

    if test_config is not None:
        app.config.update(test_config)

    _validate_config(app.config)
    db.init_app(app)
    return app


def _validate_config(config: Mapping[str, object]) -> None:
    missing = []
    if not config.get("SECRET_KEY"):
        missing.append("FLASK_SECRET_KEY")
    if not config.get("SQLALCHEMY_DATABASE_URI"):
        missing.append("DATABASE_URL")

    if missing:
        names = ", ".join(missing)
        raise RuntimeError(
            f"Configuração obrigatória ausente: {names}. "
            "Copie .env.example para .env e ajuste os valores."
        )
