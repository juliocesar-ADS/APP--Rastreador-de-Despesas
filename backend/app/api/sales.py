from collections.abc import Mapping
from datetime import date
from decimal import Decimal

from flask import url_for
from flask_jwt_extended import jwt_required
from sqlalchemy import text
from werkzeug.exceptions import NotFound

from backend.app.api import api_bp
from backend.app.api.errors import ApiError
from backend.app.api.requests import require_json_object
from backend.app.api.security import current_user_id
from backend.app.api.validation import (
    format_time_value,
    parse_amount,
    parse_business_date,
    parse_business_time,
    parse_description,
)
from backend.app.extensions import db


PAYMENT_METHODS = {
    "dinheiro",
    "pix",
    "cartao_debito",
    "cartao_credito",
    "outro",
}
REQUIRED_SALE_FIELDS = (
    "descricao",
    "valor",
    "data_venda",
    "hora_venda",
    "forma_pagamento",
)
SALE_FIELDS = {*REQUIRED_SALE_FIELDS, "observacao"}


def _parse_sale(payload: dict[str, object]) -> dict[str, object]:
    unknown_fields = set(payload) - SALE_FIELDS
    if unknown_fields:
        fields = ", ".join(sorted(unknown_fields))
        raise ApiError(422, "campos_desconhecidos", f"Campos não reconhecidos: {fields}.")

    missing_fields = [field for field in REQUIRED_SALE_FIELDS if field not in payload]
    if missing_fields:
        fields = ", ".join(missing_fields)
        raise ApiError(422, "campos_obrigatorios", f"Informe os campos: {fields}.")

    description = parse_description(payload["descricao"], "da venda")
    payment_method = payload["forma_pagamento"]
    if not isinstance(payment_method, str) or payment_method not in PAYMENT_METHODS:
        raise ApiError(
            422,
            "forma_pagamento_invalida",
            "Selecione uma forma de pagamento válida.",
        )

    observation = payload.get("observacao")
    if observation is not None and not isinstance(observation, str):
        raise ApiError(422, "observacao_invalida", "A observação deve ser um texto.")

    return {
        "descricao": description,
        "valor": parse_amount(payload["valor"]),
        "data_venda": parse_business_date(payload["data_venda"]),
        "hora_venda": parse_business_time(payload["hora_venda"]),
        "forma_pagamento": payment_method,
        "observacao": observation.strip() if observation else None,
    }


def _serialize_sale(row: Mapping[str, object]) -> dict[str, object]:
    amount = Decimal(str(row["valor"])).quantize(Decimal("0.01"))
    sale_date = row["data_venda"]
    sale_time = row["hora_venda"]

    return {
        "id": row["id"],
        "descricao": row["descricao"],
        "valor": format(amount, ".2f"),
        "data_venda": (
            sale_date.isoformat()
            if isinstance(sale_date, date)
            else str(sale_date)
        ),
        "hora_venda": format_time_value(sale_time),
        "forma_pagamento": row["forma_pagamento"],
        "observacao": row["observacao"],
    }


def _find_sale(sale_id: int, user_id: int) -> Mapping[str, object]:
    sale = db.session.execute(
        text(
            "SELECT id, descricao, valor, data_venda, hora_venda, "
            "forma_pagamento, observacao "
            "FROM vendas WHERE id = :id AND usuario_id = :usuario_id"
        ),
        {"id": sale_id, "usuario_id": user_id},
    ).mappings().first()

    if sale is None:
        raise NotFound()
    return sale


@api_bp.get("/vendas")
@jwt_required()
def list_sales() -> dict[str, list[dict[str, object]]]:
    sales = db.session.execute(
        text(
            "SELECT id, descricao, valor, data_venda, hora_venda, "
            "forma_pagamento, observacao "
            "FROM vendas WHERE usuario_id = :usuario_id "
            "ORDER BY data_venda DESC, hora_venda DESC, id DESC"
        ),
        {"usuario_id": current_user_id()},
    ).mappings().all()

    return {"dados": [_serialize_sale(sale) for sale in sales]}


@api_bp.get("/vendas/<int:sale_id>")
@jwt_required()
def get_sale(sale_id: int) -> dict[str, object]:
    return _serialize_sale(_find_sale(sale_id, current_user_id()))


@api_bp.post("/vendas")
@jwt_required()
def create_sale() -> tuple[dict[str, object], int, dict[str, str]]:
    sale = _parse_sale(require_json_object())
    result = db.session.execute(
        text(
            "INSERT INTO vendas "
            "(usuario_id, descricao, valor, data_venda, hora_venda, "
            "forma_pagamento, observacao) "
            "VALUES (:usuario_id, :descricao, :valor, :data_venda, "
            ":hora_venda, :forma_pagamento, :observacao)"
        ),
        {"usuario_id": current_user_id(), **sale},
    )
    if result.lastrowid is None:
        raise RuntimeError("O banco não retornou o identificador da venda.")

    sale_id = result.lastrowid
    db.session.commit()
    created_sale = {"id": sale_id, **sale}
    return (
        _serialize_sale(created_sale),
        201,
        {"Location": url_for("api.get_sale", sale_id=sale_id)},
    )
