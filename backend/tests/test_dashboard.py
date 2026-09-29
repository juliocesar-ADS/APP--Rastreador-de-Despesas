from datetime import date

from backend.app.api import dashboard


def authenticated_user(client, email="dashboard@example.com"):
    client.post(
        "/api/usuarios",
        json={"nome": "Cliente", "email": email, "senha": "senha-segura-1"},
    )
    login = client.post(
        "/api/auth/login",
        json={"email": email, "senha": "senha-segura-1"},
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.get_json()['access_token']}"}


def create_sale(client, headers, amount, sale_date):
    response = client.post(
        "/api/vendas",
        headers=headers,
        json={
            "descricao": "Venda do dashboard",
            "valor": amount,
            "data_venda": sale_date,
            "hora_venda": "12:00",
            "forma_pagamento": "pix",
        },
    )
    assert response.status_code == 201


def create_expense(client, headers, amount, expense_date):
    response = client.post(
        "/api/gastos",
        headers=headers,
        json={
            "descricao": "Gasto do dashboard",
            "categoria_id": 1,
            "valor": amount,
            "data_gasto": expense_date,
            "hora_gasto": "13:00",
        },
    )
    assert response.status_code == 201


def test_dashboard_returns_daily_monthly_cards_and_chart_data(
    client,
    monkeypatch,
):
    headers = authenticated_user(client)
    monkeypatch.setattr(dashboard, "business_today", lambda: date(2026, 9, 29))
    create_sale(client, headers, "50.00", "2026-09-29")
    create_sale(client, headers, "20.00", "2026-09-01")
    create_sale(client, headers, "10.00", "2026-08-31")
    create_expense(client, headers, "15.00", "2026-09-29")
    create_expense(client, headers, "5.00", "2026-08-31")

    response = client.get("/api/dashboard", headers=headers)

    assert response.status_code == 200
    body = response.get_json()
    assert body["data"] == "2026-09-29"
    assert body["hoje"]["total_vendas"] == "50.00"
    assert body["hoje"]["total_gastos"] == "15.00"
    assert body["hoje"]["resultado_liquido"] == "35.00"
    assert body["mes"]["total_vendas"] == "70.00"
    assert body["mes"]["total_gastos"] == "15.00"
    assert body["mes"]["resultado_liquido"] == "55.00"

    daily_points = body["graficos"]["vendas_gastos_por_dia"]
    assert len(daily_points) == 30
    today = next(point for point in daily_points if point["data"] == "2026-09-29")
    assert today == {
        "data": "2026-09-29",
        "vendas": "50.00",
        "gastos": "15.00",
    }

    monthly_points = body["graficos"]["evolucao_mensal"]
    assert [point["mes"] for point in monthly_points] == [
        "2026-04",
        "2026-05",
        "2026-06",
        "2026-07",
        "2026-08",
        "2026-09",
    ]
    august = next(point for point in monthly_points if point["mes"] == "2026-08")
    assert august == {"mes": "2026-08", "vendas": "10.00", "gastos": "5.00"}
    september = monthly_points[-1]
    assert september == {"mes": "2026-09", "vendas": "70.00", "gastos": "15.00"}


def test_dashboard_is_scoped_to_the_authenticated_user(client, monkeypatch):
    first_headers = authenticated_user(client, "primeiro@example.com")
    second_headers = authenticated_user(client, "segundo@example.com")
    monkeypatch.setattr(dashboard, "business_today", lambda: date(2026, 9, 29))
    create_sale(client, first_headers, "40.00", "2026-09-29")

    response = client.get("/api/dashboard", headers=second_headers)

    assert response.status_code == 200
    assert response.get_json()["hoje"]["total_vendas"] == "0.00"
    assert response.get_json()["mes"]["total_vendas"] == "0.00"


def test_dashboard_requires_authentication(client):
    response = client.get("/api/dashboard")

    assert response.status_code == 401
    assert response.get_json()["erro"]["codigo"] == "token_ausente"
