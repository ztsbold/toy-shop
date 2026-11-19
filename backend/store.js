// Өгөгдлийн давхарга: DATABASE_URL байвал PostgreSQL (Neon), үгүй бол локал JSON файл.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SEED_FILE = path.join(__dirname, 'data', 'products.json');
const seedProducts = () => JSON.parse(fs.readFileSync(SEED_FILE, 'utf8'));

// ---------------- PostgreSQL ----------------
function pgStore(url) {
  const pool = new pg.Pool({ connectionString: url, max: 5, ssl: { rejectUnauthorized: false } });
  const q = (sql, params) => pool.query(sql, params);

  const toProduct = (r) => ({
    id: r.id, name: r.name, category: r.category, ageRange: r.age_range,
    price: r.price, stock: r.stock, emoji: r.emoji, imageUrl: r.image_url,
    description: r.description, active: r.active,
  });
  const toOrder = (r) => r && ({
    id: r.id, items: r.items, delivery: r.delivery, subtotal: r.subtotal,
    deliveryFee: r.delivery_fee, total: r.total, status: r.status,
    fulfillment: r.fulfillment, invoiceId: r.invoice_id, paymentMode: r.payment_mode,
    createdAt: Number(r.created_at), paidAt: r.paid_at ? Number(r.paid_at) : null,
  });

  return {
    kind: 'postgres',
    async init() {
      await q(`CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT DEFAULT '',
        age_range TEXT DEFAULT '', price INTEGER NOT NULL, stock INTEGER NOT NULL DEFAULT 0,
        emoji TEXT DEFAULT '🎁', image_url TEXT DEFAULT '', description TEXT DEFAULT '',
        active BOOLEAN NOT NULL DEFAULT TRUE)`);
      await q(`CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY, items JSONB NOT NULL, delivery JSONB NOT NULL,
        subtotal INTEGER NOT NULL, delivery_fee INTEGER NOT NULL, total INTEGER NOT NULL,
        status TEXT NOT NULL, fulfillment TEXT NOT NULL DEFAULT 'NEW',
        invoice_id TEXT, payment_mode TEXT, created_at BIGINT NOT NULL, paid_at BIGINT)`);
      const { rows } = await q('SELECT COUNT(*)::int AS n FROM products');
      if (rows[0].n === 0) for (const p of seedProducts()) await this.upsertProduct(p);
    },
    async listProducts({ includeInactive = false } = {}) {
      const { rows } = await q(
        `SELECT * FROM products ${includeInactive ? '' : 'WHERE active'} ORDER BY name`);
      return rows.map(toProduct);
    },
    async getProduct(id) {
      const { rows } = await q('SELECT * FROM products WHERE id=$1', [id]);
      return rows[0] ? toProduct(rows[0]) : null;
    },
    async upsertProduct(p) {
      await q(`INSERT INTO products (id,name,category,age_range,price,stock,emoji,image_url,description,active)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
        ON CONFLICT (id) DO UPDATE SET name=$2,category=$3,age_range=$4,price=$5,stock=$6,
        emoji=$7,image_url=$8,description=$9,active=$10`,
        [p.id, p.name, p.category ?? '', p.ageRange ?? '', p.price, p.stock ?? 0,
         p.emoji ?? '🎁', p.imageUrl ?? '', p.description ?? '', p.active ?? true]);
    },
    async decrementStock(id, qty) {
      await q('UPDATE products SET stock = GREATEST(stock - $2::int, 0) WHERE id=$1', [id, qty]);
    },
    async insertOrder(o) {
      await q(`INSERT INTO orders (id,items,delivery,subtotal,delivery_fee,total,status,fulfillment,invoice_id,payment_mode,created_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
        [o.id, JSON.stringify(o.items), JSON.stringify(o.delivery), o.subtotal, o.deliveryFee,
         o.total, o.status, o.fulfillment, o.invoiceId, o.paymentMode, o.createdAt]);
    },
    async getOrder(id) {
      const { rows } = await q('SELECT * FROM orders WHERE id=$1', [id]);
      return toOrder(rows[0]);
    },
    // PENDING -> PAID шилжилтийг зөвхөн нэг удаа хийнэ (давхар callback-аас хамгаална)
    async markPaidOnce(id) {
      const { rowCount } = await q(
        `UPDATE orders SET status='PAID', paid_at=$2 WHERE id=$1 AND status='PENDING'`, [id, Date.now()]);
      return rowCount === 1;
    },
    async setFulfillment(id, f) {
      await q('UPDATE orders SET fulfillment=$2 WHERE id=$1', [id, f]);
    },
    async listOrders(limit = 200) {
      const { rows } = await q('SELECT * FROM orders ORDER BY created_at DESC LIMIT $1', [limit]);
      return rows.map(toOrder);
    },
  };
}

// ---------------- JSON файл (локал туршилт) ----------------
function fileStore() {
  const PRODUCTS = path.join(__dirname, 'data', 'products.local.json');
  const ORDERS = path.join(__dirname, 'data', 'orders.local.json');
  const read = (f, d) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return d; } };
  const write = (f, d) => fs.writeFileSync(f, JSON.stringify(d, null, 2));
  let products = read(PRODUCTS, null) ?? seedProducts().map((p) => ({ active: true, ...p }));
  let orders = read(ORDERS, {});
  const saveP = () => write(PRODUCTS, products);
  const saveO = () => write(ORDERS, orders);

  return {
    kind: 'file',
    async init() { saveP(); },
    async listProducts({ includeInactive = false } = {}) {
      return products.filter((p) => includeInactive || p.active !== false)
        .sort((a, b) => a.name.localeCompare(b.name));
    },
    async getProduct(id) { return products.find((p) => p.id === id) ?? null; },
    async upsertProduct(p) {
      const i = products.findIndex((x) => x.id === p.id);
      const v = { active: true, ...p };
      if (i >= 0) products[i] = v; else products.push(v);
      saveP();
    },
    async decrementStock(id, qty) {
      const p = products.find((x) => x.id === id);
      if (p) { p.stock = Math.max(0, p.stock - qty); saveP(); }
    },
    async insertOrder(o) { orders[o.id] = o; saveO(); },
    async getOrder(id) { return orders[id] ?? null; },
    async markPaidOnce(id) {
      const o = orders[id];
      if (!o || o.status !== 'PENDING') return false;
      o.status = 'PAID'; o.paidAt = Date.now(); saveO();
      return true;
    },
    async setFulfillment(id, f) { if (orders[id]) { orders[id].fulfillment = f; saveO(); } },
    async listOrders(limit = 200) {
      return Object.values(orders).sort((a, b) => b.createdAt - a.createdAt).slice(0, limit);
    },
  };
}

export const store = process.env.DATABASE_URL ? pgStore(process.env.DATABASE_URL) : fileStore();
