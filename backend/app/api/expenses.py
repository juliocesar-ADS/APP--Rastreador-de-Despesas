from collections.abc import Mapping

from flask import request, url_for
from flask_jwt_extended import jwt_required
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from werkzeug.exceptions import NotFound

from backend.app.api import api_bp
from backend.app.api.errors import ApiError
from backend.app.api.requests import require_json_object
from backend.app.api.security import current_user_id
from backend.app.api.validation import (
    parse_amount,
    parse_business_date,
    parse_business_time,
    parse_description,
    parse_optional_date_range,
)
from backend.app.extensions import db
from backend.app.services.serializers import serialize_expense


REQUIRED_EXPENSE_FIELDS = (
    "descricao",
    "categoria_id",
    "valor",
    "data_gasto",
    "hora_gasto",
)
EXPENSE_FIELDS = {*REQUIRED_EXPENSE_FIELDS, "observacao"}


def _parse_expense(payload: dict[str, object]) -> dict[str, object]:
    unknown_fields = set(payload) - EXPENSE_FIELDS
    if unknown_fields:
        fields = ", ".join(sorted(unknown_fields))
        raise ApiError(422, "campos_desconhecidos", f"Campos não reconhecidos: {fields}.")

    missing_fields = [field for field in REQUIRED_EXPENSE_FIELDS if field not in payload]
    if missing_fields:
        fields = ", ".join(missing_fields)
        raise ApiError(422, "campos_obrigatorios", f"Informe os campos: {fields}.")

    category_id = payload["categoria_id"]
    if isinstance(category_id, bool) or not isinstance(category_id, int) or category_id <= 0:
        raise ApiError(
            422,
            "categoria_invalida",
            "Selecione uma categoria de gasto válida.",
        )

    description = parse_description(payload["descricao"], "do gasto")
    observation = payload.get("observacao")
    if observation is not None and not isinstance(observation, str):
        raise ApiError(422, "observacao_invalida", "A observação deve ser um texto.")

    return {
        "descricao": description,
        "categoria_id": category_id,
        "valor": parse_amount(payload["valor"]),
        "data_gasto": parse_business_date(payload["data_gasto"]),
        "hora_gasto": parse_business_time(payload["hora_gasto"]),
        "observacao": observation.strip() if observation else None,
    }


def _find_expense(expense_id: int, user_id: int) -> Mapping[str, object]:
    expense = db.session.execute(
        text(
            "SELECT g.id, g.descricao, g.categoria_id, c.nome AS categoria_nome, "
            "g.valor, g.data_gasto, g.hora_gasto, g.observacao "
            "FROM gastos AS g "
            "JOIN categorias_gastos AS c "
            "ON c.id = g.categoria_id AND c.usuario_id = g.usuario_id "
            "WHERE g.id = :id AND g.usuario_id = :usuario_id"
        ),
        {"id": expense_id, "usuario_id": user_id},
    ).mappings().first()

    if expense is None:
        raise NotFound()
    return expense


@api_bp.get("/categorias/gastos")
@jwt_required()
def list_expense_categories() -> dict[str, list[dict[str, object]]]:
    categories = db.session.execute(
        text(
            "SELECT id, nome, ativa FROM categorias_gastos "
            "WHERE usuario_id = :usuario_id AND ativa = TRUE "
            "ORDER BY nome, id"
        ),
        {"usuario_id": current_user_id()},
    ).mappings().all()

    return {
        "dados": [
            {"id": category["id"], "nome": category["nome"]}
            for category in categories
        ]
    }


@api_bp.post("/categorias/gastos")
@jwt_required()
def create_expense_category() -> tuple[dict[str, object], int]:
    payload = require_json_object()
    unknown_fields = set(payload) - {"nome"}
    if unknown_fields:
        fields = ", ".join(sorted(unknown_fields))
        raise ApiError(422, "campos_desconhecidos", f"Campos não reconhecidos: {fields}.")

    name = payload.get("nome")
    if not isinstance(name, str) or not name.strip():
        raise ApiError(422, "nome_invalido", "Informe o nome da categoria.")
    name = name.strip()
    if len(name) > 80:
        raise ApiError(
            422,
            "nome_muito_longo",
            "O nome da categoria deve ter no máximo 80 caracteres.",
        )

    try:
        result = db.session.execute(
            text(
                "INSERT INTO categorias_gastos (usuario_id, nome) "
                "VALUES (:usuario_id, :nome)"
            ),
            {"usuario_id": current_user_id(), "nome": name},
        )
    except IntegrityError as error:
        db.session.rollback()
        raise ApiError(
            409,
            "categoria_ja_cadastrada",
            "Já existe uma categoria com esse nome na sua conta.",
        ) from error

    if result.lastrowid is None:
        raise RuntimeError("O banco não retornou o identificador da categoria.")
    db.session.commit()
    return {"id": result.lastrowid, "nome": name}, 201


@api_bp.get("/gastos")
@jwt_required()
def list_expenses() -> dict[str, list[dict[str, object]]]:
    user_id = current_user_id()
    start_date, end_date = parse_optional_date_range(request.args)
    conditions = ["g.usuario_id = :usuario_id"]
    params: dict[str, object] = {"usuario_id": user_id}
    if start_date is not None:
        conditions.append("g.data_gasto >= :inicio")
        params["inicio"] = start_date
    if end_date is not None:
        conditions.append("g.data_gasto <= :fim")
        params["fim"] = end_date

    category_id = request.args.get("categoria_id")
    if category_id is not None:
        if (
            not category_id.isascii()
            or not category_id.isdecimal()
            or int(category_id) <= 0
        ):
            raise ApiError(
                422,
                "categoria_invalida",
                "Selecione uma categoria de gasto válida.",
            )
        conditions.append("g.categoria_id = :categoria_id")
        params["categoria_id"] = int(category_id)

    expenses = db.session.execute(
        text(
            "SELECT g.id, g.descricao, g.categoria_id, c.nome AS categoria_nome, "
            "g.valor, g.data_gasto, g.hora_gasto, g.observacao "
            "FROM gastos AS g "
            "JOIN categorias_gastos AS c "
            "ON c.id = g.categoria_id AND c.usuario_id = g.usuario_id "
            "WHERE "
            + " AND ".join(conditions)
            + " ORDER BY g.data_gasto DESC, g.hora_gasto DESC, g.id DESC"
        ),
        params,
    ).mappings().all()

    return {"dados": [serialize_expense(expense) for expense in expenses]}


@api_bp.get("/gastos/<int:expense_id>")
@jwt_required()
def get_expense(expense_id: int) -> dict[str, object]:
    return serialize_expense(_find_expense(expense_id, current_user_id()))


@api_bp.post("/gastos")
@jwt_required()
def create_expense() -> tuple[dict[str, object], int, dict[str, str]]:
    expense = _parse_expense(require_json_object())
    user_id = current_user_id()
    category = db.session.execute(
        text(
            "SELECT id, nome FROM categorias_gastos "
            "WHERE id = :categoria_id AND usuario_id = :usuario_id AND ativa = TRUE"
        ),
        {"categoria_id": expense["categoria_id"], "usuario_id": user_id},
    ).mappings().first()
    if category is None:
        raise ApiError(
            422,
            "categoria_indisponivel",
            "A categoria não existe ou não está disponível na sua conta.",
        )

    result = db.session.execute(
        text(
            "INSERT INTO gastos "
            "(usuario_id, categoria_id, descricao, valor, data_gasto, "
            "hora_gasto, observacao) "
            "VALUES (:usuario_id, :categoria_id, :descricao, :valor, "
            ":data_gasto, :hora_gasto, :observacao)"
        ),
        {"usuario_id": user_id, **expense},
    )
    if result.lastrowid is None:
        raise RuntimeError("O banco não retornou o identificador do gasto.")

    expense_id = result.lastrowid
    db.session.commit()
    created_expense = {
        "id": expense_id,
        "categoria_nome": category["nome"],
        **expense,
    }
    return (
        serialize_expense(created_expense),
        201,
        {"Location": url_for("api.get_expense", expense_id=expense_id)},
    )


@api_bp.put("/gastos/<int:expense_id>")
@jwt_required()
def update_expense(expense_id: int) -> dict[str, object]:
    user_id = current_user_id()
    _find_expense(expense_id, user_id)
    expense = _parse_expense(require_json_object())
    category = db.session.execute(
        text(
            "SELECT id FROM categorias_gastos "
            "WHERE id = :categoria_id AND usuario_id = :usuario_id AND ativa = TRUE"
        ),
        {"categoria_id": expense["categoria_id"], "usuario_id": user_id},
    ).mappings().first()
    if category is None:
        raise ApiError(
            422,
            "categoria_indisponivel",
            "A categoria não existe ou não está disponível na sua conta.",
        )

    db.session.execute(
        text(
            "UPDATE gastos SET categoria_id = :categoria_id, descricao = :descricao, "
            "valor = :valor, data_gasto = :data_gasto, hora_gasto = :hora_gasto, "
            "observacao = :observacao "
            "WHERE id = :id AND usuario_id = :usuario_id"
        ),
        {"id": expense_id, "usuario_id": user_id, **expense},
    )
    db.session.commit()
    return serialize_expense(_find_expense(expense_id, user_id))


@api_bp.delete("/gastos/<int:expense_id>")
@jwt_required()
def delete_expense(expense_id: int) -> tuple[str, int]:
    result = db.session.execute(
        text("DELETE FROM gastos WHERE id = :id AND usuario_id = :usuario_id"),
        {"id": expense_id, "usuario_id": current_user_id()},
    )
    if result.rowcount != 1:
        db.session.rollback()
        raise NotFound()
    db.session.commit()
    return "", 204
