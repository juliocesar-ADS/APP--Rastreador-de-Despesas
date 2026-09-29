import pytest


SALE = {
    "descricao": "Venda balcão",
    "valor": "850.00",
    "data_venda": "2026-09-29",
    "hora_venda": "12:30",
    "forma_pagamento": "pix",
}


def authenticated_user(client, email="cliente@example.com"):
    registered = client.post(
        "/api/usuarios",
        json={"nome": "Cliente", "email": email, "senha": "senha-segura-1"},
    )
    assert registered.status_code == 201
    response = client.post(
        "/api/auth/login",
        json={"email": email, "senha": "senha-segura-1"},
    )
    assert response.status_code == 200
    return response.get_json()["access_token"]


def bearer(token):
    return {"Authorization": f"Bearer {token}"}


def test_create_and_read_sale(client):
    token = authenticated_user(client)
    response = client.post("/api/vendas", json=SALE, headers=bearer(token))

    assert response.status_code == 201
    sale = response.get_json()
    assert sale["descricao"] == "Venda balcão"
    assert sale["valor"] == "850.00"
    assert sale["data_venda"] == "2026-09-29"
    assert sale["hora_venda"] == "12:30:00"
    assert sale["forma_pagamento"] == "pix"
    assert sale["observacao"] is None
    assert response.headers["Location"].endswith(f"/api/vendas/{sale['id']}")

    response = client.get("/api/vendas", headers=bearer(token))

    assert response.status_code == 200
    assert response.get_json()["dados"] == [sale]

    response = client.get(f"/api/vendas/{sale['id']}", headers=bearer(token))

    assert response.status_code == 200
    assert response.get_json() == sale


def test_sales_are_isolated_between_users(client):
    first_token = authenticated_user(client, "primeiro@example.com")
    second_token = authenticated_user(client, "segundo@example.com")
    created = client.post(
        "/api/vendas",
        json=SALE,
        headers=bearer(first_token),
    ).get_json()

    response = client.get("/api/vendas", headers=bearer(second_token))

    assert response.status_code == 200
    assert response.get_json()["dados"] == []

    response = client.get(
        f"/api/vendas/{created['id']}",
        headers=bearer(second_token),
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("descricao", ""),
        ("valor", "0"),
        ("valor", "-1.00"),
        ("valor", "1.001"),
        ("valor", "123456789012.00"),
        ("valor", 1.25),
        ("data_venda", "2026-02-30"),
        ("hora_venda", "25:00"),
        ("forma_pagamento", "criptomoeda"),
        ("observacao", ["não é texto"]),
    ],
)
def test_create_sale_rejects_invalid_fields(client, field, value):
    token = authenticated_user(client)
    payload = {**SALE, field: value}

    response = client.post(
        "/api/vendas",
        json=payload,
        headers=bearer(token),
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"]


def test_create_sale_rejects_missing_and_unknown_fields(client):
    token = authenticated_user(client)
    response = client.post(
        "/api/vendas",
        json={"descricao": "Venda"},
        headers=bearer(token),
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "campos_obrigatorios"

    response = client.post(
        "/api/vendas",
        json={**SALE, "usuario_id": 999},
        headers=bearer(token),
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "campos_desconhecidos"


def test_sales_are_returned_in_reverse_chronological_order(client):
    token = authenticated_user(client)
    client.post(
        "/api/vendas",
        json={**SALE, "hora_venda": "12:00"},
        headers=bearer(token),
    )
    client.post(
        "/api/vendas",
        json={**SALE, "hora_venda": "15:00"},
        headers=bearer(token),
    )

    response = client.get("/api/vendas", headers=bearer(token))

    assert response.status_code == 200
    assert [sale["hora_venda"] for sale in response.get_json()["dados"]] == [
        "15:00:00",
        "12:00:00",
    ]


def test_sales_can_be_filtered_by_date_and_payment_method(client):
    token = authenticated_user(client)
    client.post("/api/vendas", json=SALE, headers=bearer(token))
    client.post(
        "/api/vendas",
        json={
            **SALE,
            "data_venda": "2026-09-30",
            "forma_pagamento": "dinheiro",
        },
        headers=bearer(token),
    )

    response = client.get(
        "/api/vendas?inicio=2026-09-30&fim=2026-09-30&forma_pagamento=dinheiro",
        headers=bearer(token),
    )

    assert response.status_code == 200
    assert len(response.get_json()["dados"]) == 1
    assert response.get_json()["dados"][0]["forma_pagamento"] == "dinheiro"


def test_update_and_delete_sale(client):
    token = authenticated_user(client)
    created = client.post("/api/vendas", json=SALE, headers=bearer(token)).get_json()
    updated_payload = {
        **SALE,
        "descricao": "Venda atualizada",
        "valor": "999.99",
        "forma_pagamento": "dinheiro",
        "observacao": "Corrigida",
    }

    response = client.put(
        f"/api/vendas/{created['id']}",
        json=updated_payload,
        headers=bearer(token),
    )

    assert response.status_code == 200
    assert response.get_json()["descricao"] == "Venda atualizada"
    assert response.get_json()["valor"] == "999.99"
    assert response.get_json()["forma_pagamento"] == "dinheiro"
    assert response.get_json()["observacao"] == "Corrigida"

    response = client.delete(
        f"/api/vendas/{created['id']}",
        headers=bearer(token),
    )

    assert response.status_code == 204
    assert client.get(
        f"/api/vendas/{created['id']}",
        headers=bearer(token),
    ).status_code == 404


def test_user_cannot_update_or_delete_another_users_sale(client):
    first_token = authenticated_user(client, "primeiro@example.com")
    second_token = authenticated_user(client, "segundo@example.com")
    created = client.post(
        "/api/vendas",
        json=SALE,
        headers=bearer(first_token),
    ).get_json()

    update = client.put(
        f"/api/vendas/{created['id']}",
        json=SALE,
        headers=bearer(second_token),
    )
    delete = client.delete(
        f"/api/vendas/{created['id']}",
        headers=bearer(second_token),
    )

    assert update.status_code == 404
    assert delete.status_code == 404
    assert client.get(
        f"/api/vendas/{created['id']}",
        headers=bearer(first_token),
    ).status_code == 200
