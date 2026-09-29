from datetime import date, timedelta

from sqlalchemy import text

from backend.app.extensions import db
from backend.app.services.financial import calculate_financial_summary
from backend.app.services.serializers import serialize_expense, serialize_sale


def build_financial_report(
    user_id: int,
    start_date: date,
    end_date_exclusive: date,
) -> dict[str, object]:
    summary = calculate_financial_summary(
        user_id,
        start_date,
        end_date_exclusive,
    )
    sales = db.session.execute(
        text(
            "SELECT id, descricao, valor, data_venda, hora_venda, "
            "forma_pagamento, observacao "
            "FROM vendas WHERE usuario_id = :usuario_id "
            "AND data_venda >= :inicio AND data_venda < :fim "
            "ORDER BY data_venda DESC, hora_venda DESC, id DESC"
        ),
        {
            "usuario_id": user_id,
            "inicio": start_date.isoformat(),
            "fim": end_date_exclusive.isoformat(),
        },
    ).mappings().all()
    expenses = db.session.execute(
        text(
            "SELECT g.id, g.descricao, g.categoria_id, c.nome AS categoria_nome, "
            "g.valor, g.data_gasto, g.hora_gasto, g.observacao "
            "FROM gastos AS g "
            "JOIN categorias_gastos AS c "
            "ON c.id = g.categoria_id AND c.usuario_id = g.usuario_id "
            "WHERE g.usuario_id = :usuario_id "
            "AND g.data_gasto >= :inicio AND g.data_gasto < :fim "
            "ORDER BY g.data_gasto DESC, g.hora_gasto DESC, g.id DESC"
        ),
        {
            "usuario_id": user_id,
            "inicio": start_date.isoformat(),
            "fim": end_date_exclusive.isoformat(),
        },
    ).mappings().all()

    return {
        "data_inicio": start_date.isoformat(),
        "data_fim": (end_date_exclusive - timedelta(days=1)).isoformat(),
        "resumo": summary.to_dict(),
        "vendas": [serialize_sale(sale) for sale in sales],
        "gastos": [serialize_expense(expense) for expense in expenses],
    }
