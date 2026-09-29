from flask import request
from werkzeug.exceptions import BadRequest

from backend.app.api.errors import ApiError


def require_json_object() -> dict[str, object]:
    if not request.is_json:
        raise ApiError(
            415,
            "tipo_de_conteudo_invalido",
            "Envie os dados no formato JSON.",
        )

    try:
        payload = request.get_json()
    except BadRequest as error:
        raise ApiError(
            400,
            "json_invalido",
            "O conteúdo enviado não contém um JSON válido.",
        ) from error

    if not isinstance(payload, dict):
        raise ApiError(
            400,
            "objeto_json_esperado",
            "O conteúdo JSON deve ser um objeto.",
        )

    return payload
