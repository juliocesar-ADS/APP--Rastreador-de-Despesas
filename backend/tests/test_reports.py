from datetime import date

from backend.app.api import reports


def authenticated_user(client):
    client.post(
        "/api/usuarios",
        json={
            "nome": "Cliente",
            "email": "relatorios@example.com",
            "senha": "senha-segura-1",
        },
    )
    login = client.post(
        "/api/auth/login",
        json={
            "email": "relatorios@example.com",
            "senha": "senha-segura-1",
        },
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.get_json()['access_token']}"}


def create_sale(client, headers, amount, sale_date, sale_time="12:00"):
    response = client.post(
        "/api/vendas",
        headers=headers,
        json={
            "descricao": f"Venda {sale_date}",
            "valor": amount,
            "data_venda": sale_date,
            "hora_venda": sale_time,
            "forma_pagamento": "pix",
        },
    )
    assert response.status_code == 201


def create_expense(client, headers, amount, expense_date):
    response = client.post(
        "/api/gastos",
        headers=headers,
        json={
            "descricao": f"Gasto {expense_date}",
            "categoria_id": 1,
            "valor": amount,
            "data_gasto": expense_date,
            "hora_gasto": "09:00",
        },
    )
    assert response.status_code == 201


def test_today_yesterday_and_specific_day_reports(app, client, monkeypatch):
    headers = authenticated_user(client)
    monkeypatch.setattr(reports, "business_today", lambda: date(2026, 9, 29))
    create_sale(client, headers, "1.00", "2026-09-28")
    create_sale(client, headers, "10.00", "2026-09-29", "15:00")
    create_sale(client, headers, "2.00", "2026-09-30")
    create_expense(client, headers, "3.00", "2026-09-29")
    create_expense(client, headers, "4.00", "2026-09-30")

    today = client.get("/api/relatorios/hoje", headers=headers)

    assert today.status_code == 200
    assert today.get_json()["data"] == "2026-09-29"
    assert today.get_json()["resumo"]["total_vendas"] == "10.00"
    assert today.get_json()["resumo"]["total_gastos"] == "3.00"
    assert today.get_json()["resumo"]["resultado_liquido"] == "7.00"
    assert len(today.get_json()["vendas"]) == 1
    assert len(today.get_json()["gastos"]) == 1

    yesterday = client.get("/api/relatorios/ontem", headers=headers)

    assert yesterday.status_code == 200
    assert yesterday.get_json()["data"] == "2026-09-28"
    assert yesterday.get_json()["resumo"]["total_vendas"] == "1.00"
    assert yesterday.get_json()["gastos"] == []

    specific_day = client.get(
        "/api/relatorios/dia?data=2026-09-30",
        headers=headers,
    )

    assert specific_day.status_code == 200
    assert specific_day.get_json()["resumo"]["total_vendas"] == "2.00"
    assert specific_day.get_json()["resumo"]["total_gastos"] == "4.00"


def test_period_report_uses_inclusive_end_date(client):
    headers = authenticated_user(client)
    create_sale(client, headers, "1.00", "2026-09-28")
    create_sale(client, headers, "10.00", "2026-09-29", "23:59")
    create_sale(client, headers, "2.00", "2026-09-30")

    response = client.get(
        "/api/relatorios/periodo?inicio=2026-09-28&fim=2026-09-29",
        headers=headers,
    )

    assert response.status_code == 200
    report = response.get_json()
    assert report["data_inicio"] == "2026-09-28"
    assert report["data_fim"] == "2026-09-29"
    assert report["resumo"]["total_vendas"] == "11.00"
    assert [sale["data_venda"] for sale in report["vendas"]] == [
        "2026-09-29",
        "2026-09-28",
    ]


def test_report_routes_validate_dates_and_require_authentication(client):
    response = client.get("/api/relatorios/hoje")

    assert response.status_code == 401
    assert response.get_json()["erro"]["codigo"] == "token_ausente"

    headers = authenticated_user(client)
    response = client.get("/api/relatorios/dia", headers=headers)

    assert response.status_code == 400
    assert response.get_json()["erro"]["codigo"] == "data_obrigatoria"

    response = client.get(
        "/api/relatorios/dia?data=2026-02-30",
        headers=headers,
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "data_invalida"

    response = client.get(
        "/api/relatorios/periodo?inicio=2026-10-01&fim=2026-09-01",
        headers=headers,
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "periodo_invalido"
