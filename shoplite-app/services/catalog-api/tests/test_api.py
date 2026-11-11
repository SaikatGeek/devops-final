from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.conftest import PRODUCTS


def test_healthz_returns_ok(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_list_products_returns_all(client):
    response = client.get("/products")
    assert response.status_code == 200
    assert response.json() == PRODUCTS


def test_get_product_returns_one(client):
    response = client.get("/products/2")
    assert response.status_code == 200
    assert response.json()["name"] == "Mechanical Keyboard"


def test_get_unknown_product_returns_404(client):
    response = client.get("/products/999")
    assert response.status_code == 404
    assert response.json() == {"detail": "product not found"}


def test_get_product_with_non_integer_id_returns_422(client):
    assert client.get("/products/abc").status_code == 422


def test_readyz_ok_when_database_and_queue_reachable(client):
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["checks"] == {"database": "ok", "queue": "ok"}


def test_readyz_503_when_database_down(client, db):
    db.healthy = False
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.json()["checks"] == {"database": "fail", "queue": "ok"}


def test_readyz_503_when_queue_down(client, queue):
    queue.healthy = False
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.json()["checks"]["queue"] == "fail"


def test_shutdown_closes_connections(db, queue):
    with TestClient(create_app(Settings(postgres_password="unused"), db=db, queue=queue)):
        pass
    assert db.closed and queue.closed
