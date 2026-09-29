import pytest


EXPENSE = {
    "descricao": "Compra de materiais",
    "categoria_id": 1,
    "valor": "120.50",
    "data_gasto": "2026-09-29",
    "hora_gasto": "09:15",
    "observacao": "Compra semanal",
}


def authenticated_user(client, email="cliente@example.com"):
    registered = client.post(
        "/api/usuarios",
        json={"nome": "Cliente", "email": email, "senha": "senha-segura-1"},
    )
    assert registered.status_code == 201
    login = client.post(
        "/api/auth/login",
        json={"email": email, "senha": "senha-segura-1"},
    )
    assert login.status_code == 200
    return login.get_json()["access_token"]


def bearer(token):
    return {"Authorization": f"Bearer {token}"}


def test_list_and_create_expense_categories(client):
    token = authenticated_user(client)
    response = client.get("/api/categorias/gastos", headers=bearer(token))

    assert response.status_code == 200
    assert len(response.get_json()["dados"]) == 8
    default_category = response.get_json()["dados"][0]
    assert {"id", "nome"} == set(default_category)

    response = client.post(
        "/api/categorias/gastos",
        headers=bearer(token),
        json={"nome": "Assinaturas"},
    )

    assert response.status_code == 201
    assert response.get_json()["nome"] == "Assinaturas"


def test_duplicate_expense_category_is_rejected(client):
    token = authenticated_user(client)
    first = client.post(
        "/api/categorias/gastos",
        headers=bearer(token),
        json={"nome": "Assinaturas"},
    )
    assert first.status_code == 201

    response = client.post(
        "/api/categorias/gastos",
        headers=bearer(token),
        json={"nome": "Assinaturas"},
    )

    assert response.status_code == 409
    assert response.get_json()["erro"]["codigo"] == "categoria_ja_cadastrada"


def test_create_and_read_expense(client):
    token = authenticated_user(client)
    response = client.post("/api/gastos", json=EXPENSE, headers=bearer(token))

    assert response.status_code == 201
    expense = response.get_json()
    assert expense["descricao"] == "Compra de materiais"
    assert expense["categoria_id"] == 1
    assert expense["categoria_nome"] == "Compras"
    assert expense["valor"] == "120.50"
    assert expense["data_gasto"] == "2026-09-29"
    assert expense["hora_gasto"] == "09:15:00"
    assert expense["observacao"] == "Compra semanal"
    assert response.headers["Location"].endswith(f"/api/gastos/{expense['id']}")

    response = client.get("/api/gastos", headers=bearer(token))

    assert response.status_code == 200
    assert response.get_json()["dados"] == [expense]

    response = client.get(f"/api/gastos/{expense['id']}", headers=bearer(token))

    assert response.status_code == 200
    assert response.get_json() == expense


def test_expenses_and_categories_are_isolated_between_users(client):
    first_token = authenticated_user(client, "primeiro@example.com")
    second_token = authenticated_user(client, "segundo@example.com")
    first_categories = client.get(
        "/api/categorias/gastos",
        headers=bearer(first_token),
    ).get_json()["dados"]
    foreign_category_id = first_categories[0]["id"]

    response = client.post(
        "/api/gastos",
        json={**EXPENSE, "categoria_id": foreign_category_id},
        headers=bearer(second_token),
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"] == "categoria_indisponivel"

    created = client.post(
        "/api/gastos",
        json=EXPENSE,
        headers=bearer(first_token),
    ).get_json()

    response = client.get(
        f"/api/gastos/{created['id']}",
        headers=bearer(second_token),
    )

    assert response.status_code == 404


def test_expenses_can_be_filtered_by_date_and_category(client):
    token = authenticated_user(client)
    client.post("/api/gastos", json=EXPENSE, headers=bearer(token))
    second_category = {**EXPENSE, "categoria_id": 5, "data_gasto": "2026-09-30"}
    client.post("/api/gastos", json=second_category, headers=bearer(token))

    response = client.get(
        "/api/gastos?inicio=2026-09-30&fim=2026-09-30&categoria_id=5",
        headers=bearer(token),
    )

    assert response.status_code == 200
    assert len(response.get_json()["dados"]) == 1
    assert response.get_json()["dados"][0]["categoria_id"] == 5


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("descricao", ""),
        ("categoria_id", 0),
        ("categoria_id", True),
        ("valor", "-1.00"),
        ("valor", 0),
        ("data_gasto", "2026-02-30"),
        ("hora_gasto", "25:00"),
        ("observacao", ["inválida"]),
    ],
)
def test_create_expense_rejects_invalid_fields(client, field, value):
    token = authenticated_user(client)
    response = client.post(
        "/api/gastos",
        json={**EXPENSE, field: value},
        headers=bearer(token),
    )

    assert response.status_code == 422
    assert response.get_json()["erro"]["codigo"]


def test_update_and_delete_expense(client):
    token = authenticated_user(client)
    created = client.post(
        "/api/gastos",
        json=EXPENSE,
        headers=bearer(token),
    ).get_json()
    updated_payload = {
        **EXPENSE,
        "descricao": "Gasto atualizado",
        "categoria_id": 5,
        "valor": "200.00",
        "observacao": None,
    }

    response = client.put(
        f"/api/gastos/{created['id']}",
        json=updated_payload,
        headers=bearer(token),
    )

    assert response.status_code == 200
    assert response.get_json()["descricao"] == "Gasto atualizado"
    assert response.get_json()["categoria_id"] == 5
    assert response.get_json()["categoria_nome"] == "Contas"
    assert response.get_json()["valor"] == "200.00"
    assert response.get_json()["observacao"] is None

    response = client.delete(
        f"/api/gastos/{created['id']}",
        headers=bearer(token),
    )

    assert response.status_code == 204
    assert client.get(
        f"/api/gastos/{created['id']}",
        headers=bearer(token),
    ).status_code == 404


def test_user_cannot_update_or_delete_another_users_expense(client):
    first_token = authenticated_user(client, "primeiro@example.com")
    second_token = authenticated_user(client, "segundo@example.com")
    created = client.post(
        "/api/gastos",
        json=EXPENSE,
        headers=bearer(first_token),
    ).get_json()

    update = client.put(
        f"/api/gastos/{created['id']}",
        json=EXPENSE,
        headers=bearer(second_token),
    )
    delete = client.delete(
        f"/api/gastos/{created['id']}",
        headers=bearer(second_token),
    )

    assert update.status_code == 404
    assert delete.status_code == 404
    assert client.get(
        f"/api/gastos/{created['id']}",
        headers=bearer(first_token),
    ).status_code == 200
