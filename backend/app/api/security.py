from flask_jwt_extended import get_jwt_identity

from backend.app.api.errors import ApiError


def current_user_id() -> int:
    identity = get_jwt_identity()
    if not isinstance(identity, str) or not identity.isdecimal():
        raise ApiError(401, "token_invalido", "O token de acesso é inválido.")
    return int(identity)
