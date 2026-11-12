// ShopLite page: lists products, places orders and follows each order until it is done.
// Every call goes to /api/..., which nginx (Docker Compose) or the ingress (Kubernetes)
// forwards to catalog-api with the /api prefix removed.
"use strict";

const API = "/api";
const POLL_INTERVAL_MS = 1000;
const POLL_LIMIT = 300; // stop following an order after about 5 minutes
const FINAL_STATUSES = new Set(["COMPLETED", "FAILED"]);
const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });

const productNames = new Map(); // product id -> name, for orders looked up by ID
const followed = new Set(); // order ids already on the list

const byId = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// fetch() wrapper: JSON both ways; a non-2xx answer becomes an Error carrying the API's detail.
async function api(path, options = {}) {
  const response = await fetch(API + path, {
    ...options,
    headers: { Accept: "application/json", "Content-Type": "application/json" },
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    const detail = typeof body?.detail === "string" ? body.detail : response.statusText;
    throw new Error(`HTTP ${response.status}${detail ? `: ${detail}` : ""}`);
  }
  return body;
}

function showMessage(text, kind = "info") {
  const box = byId("message");
  box.textContent = text;
  box.className = kind;
}

// Builds an element; text always goes in as text, never as HTML.
function make(tag, { className, text, ...props } = {}, children = []) {
  const node = Object.assign(document.createElement(tag), props);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  node.append(...children);
  return node;
}

// ---- products ----

async function loadProducts() {
  const status = byId("products-status");
  status.replaceChildren("Loading products…");
  status.hidden = false;
  try {
    const products = await api("/products");
    for (const product of products) productNames.set(product.id, product.name);
    byId("products").tBodies[0].replaceChildren(...products.map(productRow));
    byId("products").hidden = false;
    status.hidden = true;
  } catch (error) {
    const retry = make("button", { type: "button", text: "Try again" });
    retry.addEventListener("click", loadProducts);
    status.replaceChildren(`Could not load products (${error.message}). `, retry);
  }
}

function productRow(product) {
  const quantity = make("input", { type: "number", min: 1, max: 1000, value: 1, required: true });
  quantity.setAttribute("aria-label", `Quantity of ${product.name}`);
  const button = make("button", { type: "button", text: "Order" });
  button.addEventListener("click", () => placeOrder(product, quantity, button));

  return make("tr", {}, [
    make("td", { text: product.name }),
    make("td", { className: "num", text: money.format(product.price) }),
    make("td", { className: "num stock", text: String(product.stock) }),
    make("td", {}, [quantity]),
    make("td", {}, [button]),
  ]);
}

// ---- orders ----

async function placeOrder(product, quantityInput, button) {
  if (!quantityInput.reportValidity()) return;
  const quantity = Number(quantityInput.value);
  button.disabled = true;
  try {
    const order = await api("/orders", {
      method: "POST",
      body: JSON.stringify({ product_id: product.id, quantity }),
    });
    showMessage(`Order #${order.id} placed: ${quantity} × ${product.name}.`);
    follow(order);
  } catch (error) {
    showMessage(`Could not place the order (${error.message}).`, "error");
  } finally {
    button.disabled = false;
  }
}

// Shows the order at the top of the list and polls its status until COMPLETED or FAILED.
async function follow(order) {
  if (followed.has(order.id)) return;
  followed.add(order.id);
  const item = make("li");
  byId("orders").prepend(item);
  byId("no-orders").hidden = true;
  renderOrder(item, order);

  for (let i = 0; i < POLL_LIMIT && !FINAL_STATUSES.has(order.status); i++) {
    await sleep(POLL_INTERVAL_MS);
    try {
      order = await api(`/orders/${order.id}`);
      renderOrder(item, order);
    } catch (error) {
      renderOrder(item, order, `last check failed: ${error.message}; retrying`);
    }
  }
  if (!FINAL_STATUSES.has(order.status)) {
    renderOrder(item, order, "stopped checking; look it up again later");
  }
}

function renderOrder(item, order, note = "") {
  const name = productNames.get(order.product_id) ?? `product ${order.product_id}`;
  const parts = [
    `#${order.id} · ${order.quantity} × ${name}`,
    make("span", { className: `badge ${order.status.toLowerCase()}`, text: order.status }),
  ];
  if (order.completed_at) {
    const seconds = (Date.parse(order.completed_at) - Date.parse(order.created_at)) / 1000;
    parts.push(`in ${seconds.toFixed(1)} s`);
  }
  if (note) parts.push(make("span", { className: "muted", text: ` (${note})` }));
  item.replaceChildren(...parts);
}

byId("lookup").addEventListener("submit", async (event) => {
  event.preventDefault();
  const id = Number(byId("lookup-id").value);
  try {
    const order = await api(`/orders/${id}`);
    showMessage(`Order #${order.id} is ${order.status}.`);
    follow(order);
  } catch (error) {
    showMessage(`Could not get order #${id} (${error.message}).`, "error");
  }
});

// ---- start ----

byId("page-title").textContent = document.title; // so the Q7 title change is visible on the page too
loadProducts();
