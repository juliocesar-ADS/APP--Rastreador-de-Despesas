from datetime import date
from decimal import Decimal

import pytest

from backend.app.services.financial import calculate_financial_summary


def authenticated_user(client, email):
    response = client.post(
        "/api/usuarios",
        json={"nome": "Cliente", "email": email, "senha": "senha-segura-1"},
    )
    assert response.status_code == 201
    login = client.post(
        "/api/auth/login",
        json={"email": email, "senha": "senha-segura-1"},
    )
    assert login.status_code == 200
    return login.get_json()["access_token"]


def bearer(token):
    return {"Authorization": f"Bearer {token}"}


def add_sale(client, token, amount, sale_date, sale_time="12:00"):
    response = client.post(
        "/api/vendas",
        headers=bearer(token),
        json={
            "descricao": "Venda de teste",
            "valor": amount,
            "data_venda": sale_date,
            "hora_venda": sale_time,
            "forma_pagamento": "dinheiro",
        },
    )
    assert response.status_code == 201


def add_expense(client, token, amount, expense_date, expense_time="12:00"):
    response = client.post(
        "/api/gastos",
        headers=bearer(token),
        json={
            "descricao": "Gasto de teste",
            "categoria_id": 1,
            "valor": amount,
            "data_gasto": expense_date,
            "hora_gasto": expense_time,
        },
    )
    assert response.status_code == 201


def test_financial_summary_uses_exact_decimal_totals_and_date_boundaries(
    app,
    client,
):
    token = authenticated_user(client, "financeiro@example.com")
    add_sale(client, token, "0.10", "2026-09-01")
    add_sale(client, token, "0.20", "2026-09-30", "23:59")
    add_sale(client, token, "5.00", "2026-08-31")
    add_sale(client, token, "7.00", "2026-10-01")
    add_expense(client, token, "0.10", "2026-09-15")
    add_expense(client, token, "9.00", "2026-10-01")

    with app.app_context():
        summary = calculate_financial_summary(
            1,
            date(2026, 9, 1),
            date(2026, 10, 1),
        )

    assert summary.total_sales == Decimal("0.30")
    assert summary.total_expenses == Decimal("0.10")
    assert summary.net_result == Decimal("0.20")
    assert summary.sales_count == 2
    assert summary.expenses_count == 1
    assert summary.to_dict() == {
        "total_vendas": "0.30",
        "total_gastos": "0.10",
        "faturamento_bruto": "0.30",
        "resultado_liquido": "0.20",
        "quantidade_vendas": 2,
        "quantidade_gastos": 1,
    }


def test_financial_summary_is_scoped_to_the_user(app, client):
    authenticated_user(client, "primeiro@example.com")
    second_token = authenticated_user(client, "segundo@example.com")
    add_sale(client, second_token, "75.00", "2026-09-10")

    with app.app_context():
        summary = calculate_financial_summary(
            1,
            date(2026, 9, 1),
            date(2026, 10, 1),
        )

    assert summary.total_sales == Decimal("0.00")
    assert summary.sales_count == 0


def test_financial_summary_with_no_records_returns_zero_totals(app):
    with app.app_context():
        summary = calculate_financial_summary(
            1,
            date(2026, 9, 1),
            date(2026, 10, 1),
        )

    assert summary.to_dict() == {
        "total_vendas": "0.00",
        "total_gastos": "0.00",
        "faturamento_bruto": "0.00",
        "resultado_liquido": "0.00",
        "quantidade_vendas": 0,
        "quantidade_gastos": 0,
    }


def test_financial_summary_keeps_a_negative_net_result(app, client):
    token = authenticated_user(client, "prejuizo@example.com")
    add_sale(client, token, "10.00", "2026-09-10")
    add_expense(client, token, "12.50", "2026-09-10")

    with app.app_context():
        summary = calculate_financial_summary(
            1,
            date(2026, 9, 1),
            date(2026, 10, 1),
        )

    assert summary.net_result == Decimal("-2.50")


@pytest.mark.parametrize(
    ("user_id", "start_date", "end_date"),
    [
        (0, date(2026, 9, 1), date(2026, 10, 1)),
        (1, date(2026, 10, 1), date(2026, 9, 1)),
        (1, date(2026, 9, 1), date(2026, 9, 1)),
    ],
)
def test_financial_summary_rejects_invalid_periods(
    app,
    user_id,
    start_date,
    end_date,
):
    with app.app_context(), pytest.raises(ValueError):
        calculate_financial_summary(user_id, start_date, end_date)
