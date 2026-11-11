import pytest


def test_create_order_returns_201_pending_and_enqueues(client, queue):
    response = client.post("/orders", json={"product_id": 1, "quantity": 2})
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "PENDING"
    assert body["product_id"] == 1 and body["quantity"] == 2
    assert queue.messages == [body["id"]]


def test_create_order_for_unknown_product_returns_404_and_enqueues_nothing(client, queue):
    response = client.post("/orders", json={"product_id": 999, "quantity": 1})
    assert response.status_code == 404
    assert response.json() == {"detail": "product not found"}
    assert queue.messages == []


@pytest.mark.parametrize(
    "payload",
    [
        {"product_id": 1, "quantity": 0},
        {"product_id": 1, "quantity": -3},
        {"product_id": 1, "quantity": 1001},
        {"product_id": 1},
        {"quantity": 2},
        {"product_id": "abc", "quantity": 2},
    ],
)
def test_create_order_with_invalid_body_returns_422(client, queue, payload):
    assert client.post("/orders", json=payload).status_code == 422
    assert queue.messages == []


def test_create_order_when_queue_down_returns_503_and_marks_failed(client, db, queue):
    queue.healthy = False
    response = client.post("/orders", json={"product_id": 2, "quantity": 1})
    assert response.status_code == 503
    assert [o["status"] for o in db.orders.values()] == ["FAILED"]


def test_get_order_returns_status(client):
    order_id = client.post("/orders", json={"product_id": 1, "quantity": 1}).json()["id"]
    response = client.get(f"/orders/{order_id}")
    assert response.status_code == 200
    assert response.json()["status"] == "PENDING"


def test_get_unknown_order_returns_404(client):
    response = client.get("/orders/12345")
    assert response.status_code == 404
    assert response.json() == {"detail": "order not found"}
