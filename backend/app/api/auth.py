import re

from flask import current_app
from flask_jwt_extended import create_access_token
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from werkzeug.security import check_password_hash, generate_password_hash

from backend.app.api import api_bp
from backend.app.api.errors import ApiError
from backend.app.api.requests import require_json_object
from backend.app.extensions import db


DEFAULT_EXPENSE_CATEGORIES = (
    "Compras",
    "Funcionários",
    "Transporte",
    "Manutenção",
    "Contas",
    "Aluguel",
    "Materiais",
    "Outros",
)
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _required_text(
    payload: dict[str, object],
    field: str,
    label: str,
    max_length: int,
) -> str:
    value = payload.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ApiError(422, "campo_obrigatorio", f"Informe {label}.")

    normalized = value.strip()
    if len(normalized) > max_length:
        raise ApiError(
            422,
            "campo_muito_longo",
            f"{label.capitalize()} deve ter no máximo {max_length} caracteres.",
        )
    return normalized


@api_bp.post("/usuarios")
def register_user() -> tuple[dict[str, object], int]:
    payload = require_json_object()
    name = _required_text(payload, "nome", "o nome", 120)
    email = _required_text(payload, "email", "o e-mail", 254).lower()
    password = payload.get("senha")

    if not EMAIL_PATTERN.fullmatch(email):
        raise ApiError(422, "email_invalido", "Informe um endereço de e-mail válido.")
    if (
        not isinstance(password, str)
        or not password.strip()
        or len(password) < 8
        or len(password) > 128
    ):
        raise ApiError(
            422,
            "senha_invalida",
            "A senha deve ter entre 8 e 128 caracteres.",
        )

    try:
        result = db.session.execute(
            text(
                "INSERT INTO usuarios (nome, email, senha_hash) "
                "VALUES (:nome, :email, :senha_hash)"
            ),
            {
                "nome": name,
                "email": email,
                "senha_hash": generate_password_hash(password),
            },
        )
        user_id = result.lastrowid
        if user_id is None:
            raise RuntimeError("O banco não retornou o identificador da conta.")

        db.session.execute(
            text(
                "INSERT INTO categorias_gastos (usuario_id, nome) "
                "VALUES (:usuario_id, :nome)"
            ),
            [
                {"usuario_id": user_id, "nome": category}
                for category in DEFAULT_EXPENSE_CATEGORIES
            ],
        )
        db.session.commit()
    except IntegrityError as error:
        db.session.rollback()
        raise ApiError(
            409,
            "email_ja_cadastrado",
            "Não foi possível criar a conta. Verifique se o e-mail já está cadastrado.",
        ) from error

    current_app.logger.info("Conta criada: usuario_id=%s", user_id)
    return {
        "id": user_id,
        "nome": name,
        "email": email,
    }, 201


@api_bp.post("/auth/login")
def login() -> tuple[dict[str, str], int]:
    payload = require_json_object()
    email = _required_text(payload, "email", "o e-mail", 254).lower()
    password = payload.get("senha")

    if (
        not EMAIL_PATTERN.fullmatch(email)
        or not isinstance(password, str)
        or not password
        or len(password) > 128
    ):
        raise ApiError(422, "credenciais_invalidas", "Informe e-mail e senha válidos.")

    user = db.session.execute(
        text(
            "SELECT id, senha_hash FROM usuarios "
            "WHERE email = :email"
        ),
        {"email": email},
    ).mappings().first()

    if user is None or not check_password_hash(user["senha_hash"], password):
        raise ApiError(401, "credenciais_invalidas", "E-mail ou senha incorretos.")

    access_token = create_access_token(identity=str(user["id"]))
    return {"access_token": access_token, "token_type": "Bearer"}, 200
