// k6 load test of ShopLite through the ALB (questions 6 and 8): customers browse the catalog
// and place orders at a fixed rate. k6's constant-arrival-rate keeps that rate even when
// ShopLite slows down, so a fault shows on the dashboard instead of slowing the test.
//
//   BASE_URL    the environment's address, e.g. http://<ALB DNS name> (prod) or
//               http://<ALB DNS name>:8080 (dev); required
//   DURATION    how long, default 15m (question 8: 15 minutes at 20 or more requests per second)
//   BROWSE_RPS  catalog requests per second, default 16
//   ORDER_RPS   orders per second, default 6: about 60% of what four order-worker pods
//               process (4 pods x 4 orders at a time / 1.5 s each), so a healthy queue
//               stays short
//
//   k6 run -e BASE_URL="$ALB" scripts/loadtest.js
import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL;
if (!BASE_URL) {
  throw new Error('set BASE_URL, e.g. k6 run -e BASE_URL=http://<ALB DNS name> scripts/loadtest.js');
}
const DURATION = __ENV.DURATION || '15m';
const BROWSE_RPS = Number(__ENV.BROWSE_RPS || 16);
const ORDER_RPS = Number(__ENV.ORDER_RPS || 6);
// The seed (helm/shoplite/files/init.sql) has products 1 to 12.
const PRODUCTS = 12;

export const options = {
  scenarios: {
    browse: {
      executor: 'constant-arrival-rate',
      exec: 'browse',
      rate: BROWSE_RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: 20,
      maxVUs: 200,
    },
    orders: {
      executor: 'constant-arrival-rate',
      exec: 'order',
      rate: ORDER_RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: 10,
      maxVUs: 100,
    },
  },
};

function product() {
  return 1 + Math.floor(Math.random() * PRODUCTS);
}

// Half the catalog requests list the products, half open one.
export function browse() {
  const list = Math.random() < 0.5;
  const res = list
    ? http.get(`${BASE_URL}/api/products`, { tags: { name: 'GET /api/products' } })
    : http.get(`${BASE_URL}/api/products/${product()}`, { tags: { name: 'GET /api/products/{id}' } });
  check(res, { 'catalog: 200': (r) => r.status === 200 });
}

export function order() {
  const res = http.post(
    `${BASE_URL}/api/orders`,
    JSON.stringify({ product_id: product(), quantity: 1 + Math.floor(Math.random() * 3) }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'POST /api/orders' } },
  );
  check(res, { 'order: 201': (r) => r.status === 201 });
}
