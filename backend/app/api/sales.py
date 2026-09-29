import re
from collections.abc import Mapping
from datetime import date, time
from decimal import Decimal, InvalidOperation

from flask import url_for
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import text
from werkzeug.exceptions import NotFound

from backend.app.api import api_bp
from backend.app.api.errors import ApiError
from backend.app.api.requests import require_json_object
from backend.app.extensions import db


PAYMENT_METHODS = {
    "dinheiro",
    "pix",
    "cartao_debito",
    "cartao_credito",
    "outro",
}
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TIME_PATTERN = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$")
AMOUNT_PATTERN = re.compile(r"^\d{1,11}(?:\.\d{1,2})?$")
MAX_AMOUNT = Decimal("99999999999.99")
REQUIRED_SALE_FIELDS = (
    "descricao",
    "valor",
    "data_venda",
    "hora_venda",
    "forma_pagamento",
)
SALE_FIELDS = {*REQUIRED_SALE_FIELDS, "observacao"}


def _user_id() -> int:
    return int(get_jwt_identity())


def _parse_sale(payload: dict[str, object]) -> dict[str, object]:
    unknown_fields = set(payload) - SALE_FIELDS
    if unknown_fields:
        fields = ", ".join(sorted(unknown_fields))
        raise ApiError(422, "campos_desconhecidos", f"Campos não reconhecidos: {fields}.")

    missing_fields = [field for field in REQUIRED_SALE_FIELDS if field not in payload]
    if missing_fields:
        fields = ", ".join(missing_fields)
        raise ApiError(422, "campos_obrigatorios", f"Informe os campos: {fields}.")

    description = payload["descricao"]
    if not isinstance(description, str) or not description.strip():
        raise ApiError(422, "descricao_invalida", "Informe a descrição da venda.")
    description = description.strip()
    if len(description) > 255:
        raise ApiError(
            422,
            "descricao_muito_longa",
            "A descrição deve ter no máximo 255 caracteres.",
        )

    raw_amount = payload["valor"]
    if isinstance(raw_amount, bool) or not isinstance(raw_amount, (str, int)):
        raise ApiError(
            422,
            "valor_invalido",
            "Informe o valor como texto decimal ou número inteiro.",
        )
    amount_text = str(raw_amount).strip()
    if not AMOUNT_PATTERN.fullmatch(amount_text):
        raise ApiError(
            422,
            "valor_invalido",
            "O valor deve ser positivo e ter no máximo duas casas decimais.",
        )
    try:
        amount = Decimal(amount_text)
    except InvalidOperation as error:
        raise ApiError(422, "valor_invalido", "O valor informado é inválido.") from error
    if amount <= 0 or amount > MAX_AMOUNT:
        raise ApiError(
            422,
            "valor_invalido",
            "O valor deve ser maior que zero e caber no limite financeiro permitido.",
        )

    sale_date = payload["data_venda"]
    if not isinstance(sale_date, str) or not DATE_PATTERN.fullmatch(sale_date):
        raise ApiError(422, "data_invalida", "Use uma data válida no formato AAAA-MM-DD.")
    try:
        parsed_date = date.fromisoformat(sale_date)
    except ValueError as error:
        raise ApiError(422, "data_invalida", "A data informada não existe.") from error

    sale_time = payload["hora_venda"]
    if not isinstance(sale_time, str) or not TIME_PATTERN.fullmatch(sale_time):
        raise ApiError(422, "hora_invalida", "Use um horário válido no formato HH:MM.")
    try:
        parsed_time = time.fromisoformat(sale_time)
    except ValueError as error:
        raise ApiError(422, "hora_invalida", "O horário informado não existe.") from error

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
        "valor": format(amount, ".2f"),
        "data_venda": parsed_date.isoformat(),
        "hora_venda": parsed_time.isoformat(),
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
        "hora_venda": (
            sale_time.isoformat()
            if isinstance(sale_time, time)
            else str(sale_time)
        ),
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
        {"usuario_id": _user_id()},
    ).mappings().all()

    return {"dados": [_serialize_sale(sale) for sale in sales]}


@api_bp.get("/vendas/<int:sale_id>")
@jwt_required()
def get_sale(sale_id: int) -> dict[str, object]:
    return _serialize_sale(_find_sale(sale_id, _user_id()))


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
        {"usuario_id": _user_id(), **sale},
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
