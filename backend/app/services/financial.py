from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import text

from backend.app.extensions import db


CENT = Decimal("0.01")


@dataclass(frozen=True)
class FinancialSummary:
    total_sales: Decimal
    total_expenses: Decimal
    net_result: Decimal
    sales_count: int
    expenses_count: int

    def to_dict(self) -> dict[str, object]:
        return {
            "total_vendas": format(self.total_sales, ".2f"),
            "total_gastos": format(self.total_expenses, ".2f"),
            "faturamento_bruto": format(self.total_sales, ".2f"),
            "resultado_liquido": format(self.net_result, ".2f"),
            "quantidade_vendas": self.sales_count,
            "quantidade_gastos": self.expenses_count,
        }


def end_of_day_exclusive(day: date) -> date:
    try:
        return day + timedelta(days=1)
    except OverflowError as error:
        raise ValueError("A data final está fora do intervalo permitido.") from error


def calculate_financial_summary(
    user_id: int,
    start_date: date,
    end_date_exclusive: date,
) -> FinancialSummary:
    if user_id <= 0:
        raise ValueError("O identificador do usuário deve ser positivo.")
    if start_date >= end_date_exclusive:
        raise ValueError("O início do período deve ser anterior ao fim.")

    sales = db.session.execute(
        text(
            "SELECT COALESCE(SUM(valor), 0.00) AS total, COUNT(*) AS quantidade "
            "FROM vendas "
            "WHERE usuario_id = :usuario_id "
            "AND data_venda >= :inicio AND data_venda < :fim"
        ),
        {
            "usuario_id": user_id,
            "inicio": start_date.isoformat(),
            "fim": end_date_exclusive.isoformat(),
        },
    ).mappings().one()
    expenses = db.session.execute(
        text(
            "SELECT COALESCE(SUM(valor), 0.00) AS total, COUNT(*) AS quantidade "
            "FROM gastos "
            "WHERE usuario_id = :usuario_id "
            "AND data_gasto >= :inicio AND data_gasto < :fim"
        ),
        {
            "usuario_id": user_id,
            "inicio": start_date.isoformat(),
            "fim": end_date_exclusive.isoformat(),
        },
    ).mappings().one()

    total_sales = Decimal(str(sales["total"])).quantize(CENT)
    total_expenses = Decimal(str(expenses["total"])).quantize(CENT)
    return FinancialSummary(
        total_sales=total_sales,
        total_expenses=total_expenses,
        net_result=(total_sales - total_expenses).quantize(CENT),
        sales_count=int(sales["quantidade"]),
        expenses_count=int(expenses["quantidade"]),
    )
