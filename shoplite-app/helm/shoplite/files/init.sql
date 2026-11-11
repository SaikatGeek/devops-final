-- ShopLite schema and seed data.
--
-- PostgreSQL runs every file in /docker-entrypoint-initdb.d/ once, on the first
-- start with an empty data directory. Docker Compose mounts this file there, and
-- the Helm chart mounts the same file from a ConfigMap, so both environments
-- share one source of truth.
--
-- Every statement is idempotent, so running the script again is harmless.

CREATE TABLE IF NOT EXISTS products (
    id     SERIAL PRIMARY KEY,
    name   TEXT           NOT NULL UNIQUE,
    price  NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    stock  INTEGER        NOT NULL DEFAULT 0 CHECK (stock >= 0)
);

CREATE TABLE IF NOT EXISTS orders (
    id            SERIAL PRIMARY KEY,
    product_id    INTEGER     NOT NULL REFERENCES products (id),
    quantity      INTEGER     NOT NULL CHECK (quantity > 0),
    status        TEXT        NOT NULL DEFAULT 'PENDING'
                  CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS orders_status_idx ON orders (status);

-- At least 10 products are required; ON CONFLICT keeps the seed idempotent.
INSERT INTO products (name, price, stock) VALUES
    ('Wireless Mouse',          19.99, 120),
    ('Mechanical Keyboard',     79.50,  60),
    ('USB-C Hub',               34.00,  85),
    ('27-inch Monitor',        229.00,  25),
    ('Laptop Stand',            45.25,  70),
    ('Noise-Cancelling Headphones', 149.00, 40),
    ('Webcam 1080p',            59.90,  55),
    ('External SSD 1TB',        99.00,  45),
    ('Desk Lamp',               27.75,  90),
    ('Ergonomic Chair',        310.00,  15),
    ('Bluetooth Speaker',       49.99,  65),
    ('Smartphone Charger',      15.50, 200)
ON CONFLICT (name) DO NOTHING;
