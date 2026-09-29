from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import text

from backend.app.extensions import db
from backend.app.services.financial import calculate_financial_summary


CENT = Decimal("0.01")


def _date_value(value: object) -> date:
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value))


def _money(value: Decimal) -> str:
    return format(value.quantize(CENT), ".2f")


def _daily_totals(
    user_id: int,
    start_date: date,
    end_date_exclusive: date,
) -> tuple[dict[date, Decimal], dict[date, Decimal]]:
    sales_rows = db.session.execute(
        text(
            "SELECT data_venda AS dia, SUM(valor) AS total "
            "FROM vendas WHERE usuario_id = :usuario_id "
            "AND data_venda >= :inicio AND data_venda < :fim "
            "GROUP BY data_venda"
        ),
        {
            "usuario_id": user_id,
            "inicio": start_date.isoformat(),
            "fim": end_date_exclusive.isoformat(),
        },
    ).mappings().all()
    expense_rows = db.session.execute(
        text(
            "SELECT data_gasto AS dia, SUM(valor) AS total "
            "FROM gastos WHERE usuario_id = :usuario_id "
            "AND data_gasto >= :inicio AND data_gasto < :fim "
            "GROUP BY data_gasto"
        ),
        {
            "usuario_id": user_id,
            "inicio": start_date.isoformat(),
            "fim": end_date_exclusive.isoformat(),
        },
    ).mappings().all()

    sales_by_day = {
        _date_value(row["dia"]): Decimal(str(row["total"])).quantize(CENT)
        for row in sales_rows
    }
    expenses_by_day = {
        _date_value(row["dia"]): Decimal(str(row["total"])).quantize(CENT)
        for row in expense_rows
    }
    return sales_by_day, expenses_by_day


def _month_start(year: int, month: int, offset: int = 0) -> date:
    month_index = year * 12 + month - 1 + offset
    target_year, target_month = divmod(month_index, 12)
    target_month += 1
    if target_year < 1 or target_year > 9999:
        raise ValueError("O intervalo do gráfico mensal está fora do limite.")
    return date(target_year, target_month, 1)


def build_dashboard(user_id: int, today: date) -> dict[str, object]:
    current_month_start = date(today.year, today.month, 1)
    current_month_end = _month_start(today.year, today.month, 1)
    today_end = today + timedelta(days=1)
    first_chart_month = _month_start(today.year, today.month, -5)
    sales_by_day, expenses_by_day = _daily_totals(
        user_id,
        first_chart_month,
        current_month_end,
    )

    daily_chart = []
    day = current_month_start
    while day < current_month_end:
        daily_chart.append(
            {
                "data": day.isoformat(),
                "vendas": _money(sales_by_day.get(day, Decimal("0.00"))),
                "gastos": _money(expenses_by_day.get(day, Decimal("0.00"))),
            }
        )
        day += timedelta(days=1)

    monthly_chart = []
    for offset in range(-5, 1):
        month_start = _month_start(today.year, today.month, offset)
        month_end = _month_start(today.year, today.month, offset + 1)
        sales_total = sum(
            (
                amount
                for day, amount in sales_by_day.items()
                if month_start <= day < month_end
            ),
            Decimal("0.00"),
        )
        expenses_total = sum(
            (
                amount
                for day, amount in expenses_by_day.items()
                if month_start <= day < month_end
            ),
            Decimal("0.00"),
        )
        monthly_chart.append(
            {
                "mes": f"{month_start.year:04d}-{month_start.month:02d}",
                "vendas": _money(sales_total),
                "gastos": _money(expenses_total),
            }
        )

    return {
        "data": today.isoformat(),
        "hoje": calculate_financial_summary(
            user_id,
            today,
            today_end,
        ).to_dict(),
        "mes": calculate_financial_summary(
            user_id,
            current_month_start,
            current_month_end,
        ).to_dict(),
        "graficos": {
            "vendas_gastos_por_dia": daily_chart,
            "evolucao_mensal": monthly_chart,
        },
    }
