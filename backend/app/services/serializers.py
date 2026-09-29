from collections.abc import Mapping
from datetime import date
from decimal import Decimal

from backend.app.api.validation import format_time_value


def serialize_sale(row: Mapping[str, object]) -> dict[str, object]:
    amount = Decimal(str(row["valor"])).quantize(Decimal("0.01"))
    sale_date = row["data_venda"]

    return {
        "id": row["id"],
        "descricao": row["descricao"],
        "valor": format(amount, ".2f"),
        "data_venda": (
            sale_date.isoformat()
            if isinstance(sale_date, date)
            else str(sale_date)
        ),
        "hora_venda": format_time_value(row["hora_venda"]),
        "forma_pagamento": row["forma_pagamento"],
        "observacao": row["observacao"],
    }


def serialize_expense(row: Mapping[str, object]) -> dict[str, object]:
    amount = Decimal(str(row["valor"])).quantize(Decimal("0.01"))
    expense_date = row["data_gasto"]

    return {
        "id": row["id"],
        "descricao": row["descricao"],
        "categoria_id": row["categoria_id"],
        "categoria_nome": row["categoria_nome"],
        "valor": format(amount, ".2f"),
        "data_gasto": (
            expense_date.isoformat()
            if isinstance(expense_date, date)
            else str(expense_date)
        ),
        "hora_gasto": format_time_value(row["hora_gasto"]),
        "observacao": row["observacao"],
    }
