from flask import current_app
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from backend.app.api import api_bp
from backend.app.api.errors import ApiError
from backend.app.extensions import db


def check_database() -> None:
    db.session.execute(text("SELECT 1"))


@api_bp.get("/health")
def health() -> tuple[dict[str, str], int]:
    try:
        check_database()
    except SQLAlchemyError as error:
        current_app.logger.exception("Falha ao verificar a conexão com o banco.")
        raise ApiError(
            503,
            "banco_indisponivel",
            "Não foi possível conectar ao banco de dados.",
        ) from error

    return {
        "status": "ok",
        "mensagem": "API e banco de dados disponíveis.",
    }, 200
