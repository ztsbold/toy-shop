// Өгөгдлийн давхарга — PostgreSQL (Neon).
// Локал туршилтад DATABASE_URL-гүйгээр PG_MEM=1 тавибал санах ойн Postgres ашиглана.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const seedProducts = () =>
  JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'products.json'), 'utf8'));

async function makePool() {
  if (process.env.DATABASE_URL) {
    return new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 5, ssl: { rejectUnauthorized: false } });
  }
  if (process.env.PG_MEM) {
    const { newDb } = await import('pg-mem');
    const { Pool } = newDb().adapters.createPg();
    return new Pool();
  }
  throw new Error('DATABASE_URL тохируулаагүй байна (локал туршилтад PG_MEM=1)');
}

const toProduct = (r) => ({
  id: r.id, name: r.name, subtitle: r.subtitle ?? '', sku: r.sku ?? '',
  category: r.category, ageRange: r.age_range, price: r.price, stock: r.stock,
  emoji: r.emoji, imageUrl: r.image_url, description: r.description,
  isNew: !!r.is_new, pointsEligible: !!r.points_eligible, features: r.features ?? [], active: r.active,
});
const toOrder = (r) => r && ({
  id: r.id, items: r.items, delivery: r.delivery, subtotal: r.subtotal,
  deliveryFee: r.delivery_fee, total: r.total, status: r.status,
  fulfillment: r.fulfillment, invoiceId: r.invoice_id, paymentMode: r.payment_mode,
  createdAt: Number(r.created_at), paidAt: r.paid_at ? Number(r.paid_at) : null,
  customerId: r.customer_id ?? null, pointsUsed: r.points_used ?? 0,
  pointsEarned: r.points_earned ?? 0, history: r.history ?? [],
});
const toCustomer = (r) => r && ({
  id: r.id, phone: r.phone, name: r.name ?? '', points: r.points, createdAt: Number(r.created_at),
});

let pool;
const q = (sql, params) => pool.query(sql, params);

export const store = {
  kind: 'postgres',

  async init() {
    pool = await makePool();
    await q(`CREATE TABLE IF NOT EXISTS products (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT DEFAULT '',
      age_range TEXT DEFAULT '', price INTEGER NOT NULL, stock INTEGER NOT NULL DEFAULT 0,
      emoji TEXT DEFAULT '🎁', image_url TEXT DEFAULT '', description TEXT DEFAULT '',
      active BOOLEAN NOT NULL DEFAULT TRUE)`);
    await q(`ALTER TABLE products
      ADD COLUMN IF NOT EXISTS subtitle TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS sku TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS is_new BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '[]'::jsonb,
      ADD COLUMN IF NOT EXISTS points_eligible BOOLEAN DEFAULT FALSE`);
    await q(`CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY, items JSONB NOT NULL, delivery JSONB NOT NULL,
      subtotal INTEGER NOT NULL, delivery_fee INTEGER NOT NULL, total INTEGER NOT NULL,
      status TEXT NOT NULL, fulfillment TEXT NOT NULL DEFAULT 'NEW',
      invoice_id TEXT, payment_mode TEXT, created_at BIGINT NOT NULL, paid_at BIGINT)`);
    await q(`ALTER TABLE orders
      ADD COLUMN IF NOT EXISTS customer_id TEXT,
      ADD COLUMN IF NOT EXISTS points_used INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS points_earned INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS history JSONB DEFAULT '[]'::jsonb`);
    await q(`CREATE TABLE IF NOT EXISTS images (
      id TEXT PRIMARY KEY, mime TEXT NOT NULL, data BYTEA NOT NULL, created_at BIGINT NOT NULL)`);
    await q(`CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value JSONB NOT NULL)`);
    await q(`CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY, phone TEXT UNIQUE NOT NULL, name TEXT DEFAULT '',
      points INTEGER NOT NULL DEFAULT 0, created_at BIGINT NOT NULL)`);
    await q(`CREATE TABLE IF NOT EXISTS points_ledger (
      id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, order_id TEXT, delta INTEGER NOT NULL,
      reason TEXT NOT NULL, created_at BIGINT NOT NULL)`);
    await q(`CREATE TABLE IF NOT EXISTS otp_codes (
      phone TEXT PRIMARY KEY, code_hash TEXT NOT NULL, expires_at BIGINT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0)`);
    await q(`CREATE TABLE IF NOT EXISTS sms_log (
      id TEXT PRIMARY KEY, phone TEXT NOT NULL, text TEXT NOT NULL, status TEXT NOT NULL,
      created_at BIGINT NOT NULL)`);
    await q(`ALTER TABLE sms_log ADD COLUMN IF NOT EXISTS kind TEXT DEFAULT 'info'`);
    await q(`CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
      order_id TEXT, is_read BOOLEAN NOT NULL DEFAULT FALSE, created_at BIGINT NOT NULL)`);
    const { rows } = await q('SELECT COUNT(*)::int AS n FROM products');
    if (rows[0].n === 0) for (const p of seedProducts()) await this.upsertProduct(p);
  },

  // ---------- Бараа ----------
  async listProducts({ includeInactive = false } = {}) {
    const { rows } = await q(
      `SELECT * FROM products ${includeInactive ? '' : 'WHERE active'} ORDER BY is_new DESC, name`);
    return rows.map(toProduct);
  },
  async getProduct(id) {
    const { rows } = await q('SELECT * FROM products WHERE id=$1', [id]);
    return rows[0] ? toProduct(rows[0]) : null;
  },
  async upsertProduct(p) {
    await q(`INSERT INTO products (id,name,category,age_range,price,stock,emoji,image_url,description,active,subtitle,sku,is_new,features,points_eligible)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
      ON CONFLICT (id) DO UPDATE SET name=$2,category=$3,age_range=$4,price=$5,stock=$6,
      emoji=$7,image_url=$8,description=$9,active=$10,subtitle=$11,sku=$12,is_new=$13,features=$14,points_eligible=$15`,
      [p.id, p.name, p.category ?? '', p.ageRange ?? '', p.price, p.stock ?? 0, p.emoji ?? '🎁',
       p.imageUrl ?? '', p.description ?? '', p.active !== false, p.subtitle ?? '', p.sku ?? '',
       !!p.isNew, JSON.stringify(p.features ?? []), !!p.pointsEligible]);
  },
  async decrementStock(id, qty) {
    await q('UPDATE products SET stock = GREATEST(stock - $2::int, 0) WHERE id=$1', [id, qty]);
  },
  async incrementStock(id, qty) {
    await q('UPDATE products SET stock = stock + $2::int WHERE id=$1', [id, qty]);
  },

  // ---------- Захиалга ----------
  async insertOrder(o) {
    await q(`INSERT INTO orders (id,items,delivery,subtotal,delivery_fee,total,status,fulfillment,invoice_id,payment_mode,created_at,customer_id,points_used,history)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
      [o.id, JSON.stringify(o.items), JSON.stringify(o.delivery), o.subtotal, o.deliveryFee,
       o.total, o.status, o.fulfillment, o.invoiceId, o.paymentMode, o.createdAt,
       o.customerId ?? null, o.pointsUsed ?? 0, JSON.stringify(o.history ?? [])]);
  },
  async getOrder(id) {
    const { rows } = await q('SELECT * FROM orders WHERE id=$1', [id]);
    return toOrder(rows[0]);
  },
  /** PENDING → PAID зөвхөн нэг удаа (давхар callback-аас хамгаална) */
  async markPaidOnce(id) {
    const now = Date.now();
    const { rowCount } = await q(
      `UPDATE orders SET status='PAID', paid_at=$2 WHERE id=$1 AND status='PENDING'`, [id, now]);
    if (rowCount !== 1) return false;
    await this._appendHistory(id, { status: 'PAID', at: now });
    return true;
  },
  async _appendHistory(id, entry) {
    const o = await this.getOrder(id);
    if (!o) return;
    await q('UPDATE orders SET history=$2 WHERE id=$1', [id, JSON.stringify([...(o.history ?? []), entry])]);
  },
  async setOrderInvoice(id, invoiceId) {
    await q('UPDATE orders SET invoice_id=$2 WHERE id=$1', [id, invoiceId]);
  },
  async setPointsEarned(id, n) {
    await q('UPDATE orders SET points_earned=$2 WHERE id=$1', [id, n]);
  },
  /** Хүргэлтийн төлөв солих ба түүхэнд нэмэх. Өөрчлөгдсөн бол true. */
  async setFulfillment(id, f) {
    const o = await this.getOrder(id);
    if (!o || o.fulfillment === f) return false;
    const history = [...(o.history ?? []), { status: f, at: Date.now() }];
    const { rowCount } = await q(
      'UPDATE orders SET fulfillment=$2, history=$3 WHERE id=$1 AND fulfillment=$4',
      [id, f, JSON.stringify(history), o.fulfillment]);
    return rowCount === 1;
  },
  async listOrders(limit = 200) {
    const { rows } = await q('SELECT * FROM orders ORDER BY created_at DESC LIMIT $1', [limit]);
    return rows.map(toOrder);
  },
  async listOrdersByCustomer(customerId, limit = 50) {
    const { rows } = await q(
      'SELECT * FROM orders WHERE customer_id=$1 ORDER BY created_at DESC LIMIT $2', [customerId, limit]);
    return rows.map(toOrder);
  },

  // ---------- Хэрэглэгч ба оноо ----------
  async getCustomer(id) {
    const { rows } = await q('SELECT * FROM customers WHERE id=$1', [id]);
    return toCustomer(rows[0]);
  },
  async getCustomerByPhone(phone) {
    const { rows } = await q('SELECT * FROM customers WHERE phone=$1', [phone]);
    return toCustomer(rows[0]);
  },
  async createCustomer(id, phone, name) {
    await q(`INSERT INTO customers (id,phone,name,points,created_at) VALUES ($1,$2,$3,0,$4)
      ON CONFLICT (phone) DO NOTHING`, [id, phone, name ?? '', Date.now()]);
    return this.getCustomerByPhone(phone);
  },
  async updateCustomerName(id, name) {
    await q('UPDATE customers SET name=$2 WHERE id=$1', [id, name]);
  },
  async listCustomers(limit = 500) {
    const { rows } = await q(`SELECT c.id, c.phone, c.name, c.points, c.created_at, COUNT(o.id)::int AS order_count
      FROM customers c LEFT JOIN orders o ON o.customer_id = c.id
      GROUP BY c.id, c.phone, c.name, c.points, c.created_at
      ORDER BY c.created_at DESC LIMIT $1`, [limit]);
    return rows.map((r) => ({ ...toCustomer(r), orderCount: r.order_count }));
  },
  /**
   * Оноо нэмэх/хасах. Үлдэгдэл хасах руу орохгүй.
   * allowPartial=true үед боломжтой хэмжээгээр хасна. Шинэ үлдэгдэл эсвэл null буцаана.
   */
  async addPoints(customerId, delta, reason, orderId = null, { allowPartial = false } = {}) {
    if (!delta) return (await this.getCustomer(customerId))?.points ?? null;
    let applied = delta;
    if (delta < 0 && allowPartial) {
      const c = await this.getCustomer(customerId);
      if (!c) return null;
      applied = -Math.min(c.points, -delta);
      if (!applied) return c.points;
    }
    const { rows } = await q(
      `UPDATE customers SET points = points + $2::int WHERE id=$1 AND points + $2::int >= 0 RETURNING points`,
      [customerId, applied]);
    if (!rows[0]) return null;
    await q(`INSERT INTO points_ledger (id,customer_id,order_id,delta,reason,created_at) VALUES ($1,$2,$3,$4,$5,$6)`,
      [`pl_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`, customerId, orderId, applied, reason, Date.now()]);
    return rows[0].points;
  },
  async listLedger(customerId, limit = 100) {
    const { rows } = await q(
      'SELECT * FROM points_ledger WHERE customer_id=$1 ORDER BY created_at DESC LIMIT $2', [customerId, limit]);
    return rows.map((r) => ({ delta: r.delta, reason: r.reason, orderId: r.order_id, createdAt: Number(r.created_at) }));
  },

  // ---------- OTP ----------
  async saveOtp(phone, codeHash, expiresAt) {
    await q(`INSERT INTO otp_codes (phone,code_hash,expires_at,attempts) VALUES ($1,$2,$3,0)
      ON CONFLICT (phone) DO UPDATE SET code_hash=$2, expires_at=$3, attempts=0`, [phone, codeHash, expiresAt]);
  },
  async getOtp(phone) {
    const { rows } = await q('SELECT * FROM otp_codes WHERE phone=$1', [phone]);
    return rows[0] ? { codeHash: rows[0].code_hash, expiresAt: Number(rows[0].expires_at), attempts: rows[0].attempts } : null;
  },
  async bumpOtpAttempts(phone) {
    await q('UPDATE otp_codes SET attempts = attempts + 1 WHERE phone=$1', [phone]);
  },
  async deleteOtp(phone) {
    await q('DELETE FROM otp_codes WHERE phone=$1', [phone]);
  },

  // ---------- SMS лог ----------
  async logSms(phone, text, status, kind = 'info') {
    await q('INSERT INTO sms_log (id,phone,text,status,created_at,kind) VALUES ($1,$2,$3,$4,$5,$6)',
      [`sms_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`, phone, text, status, Date.now(), kind]);
  },
  // Хязгаарлалт зөвхөн нэвтрэх кодод (kind='otp') үйлчилнэ
  async countSmsSince(phone, since) {
    const { rows } = await q(`SELECT COUNT(*)::int AS n FROM sms_log WHERE phone=$1 AND created_at >= $2 AND kind='otp'`, [phone, since]);
    return rows[0].n;
  },
  async lastSmsAt(phone) {
    const { rows } = await q(`SELECT MAX(created_at) AS t FROM sms_log WHERE phone=$1 AND kind='otp'`, [phone]);
    return rows[0]?.t ? Number(rows[0].t) : 0;
  },
  async listSms(limit = 100) {
    const { rows } = await q('SELECT * FROM sms_log ORDER BY created_at DESC LIMIT $1', [limit]);
    return rows.map((r) => ({ phone: r.phone, text: r.text, status: r.status, kind: r.kind, createdAt: Number(r.created_at) }));
  },

  // ---------- Мэдэгдэл ----------
  async addNotification(customerId, title, body, orderId = null) {
    await q(`INSERT INTO notifications (id,customer_id,title,body,order_id,is_read,created_at) VALUES ($1,$2,$3,$4,$5,FALSE,$6)`,
      [`nt_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`, customerId, title, body, orderId, Date.now()]);
  },
  async listNotifications(customerId, limit = 50) {
    const { rows } = await q(
      'SELECT * FROM notifications WHERE customer_id=$1 ORDER BY created_at DESC LIMIT $2', [customerId, limit]);
    return rows.map((r) => ({ id: r.id, title: r.title, body: r.body, orderId: r.order_id, read: r.is_read, createdAt: Number(r.created_at) }));
  },
  async markNotificationsRead(customerId) {
    await q('UPDATE notifications SET is_read=TRUE WHERE customer_id=$1 AND NOT is_read', [customerId]);
  },

  // ---------- Зураг, тохиргоо ----------
  async saveImage(id, mime, buf) {
    await q('INSERT INTO images (id,mime,data,created_at) VALUES ($1,$2,$3,$4)', [id, mime, buf, Date.now()]);
  },
  async getImage(id) {
    const { rows } = await q('SELECT mime, data FROM images WHERE id=$1', [id]);
    return rows[0] ?? null;
  },
  async getSettings() {
    const { rows } = await q(`SELECT value FROM settings WHERE key='shop'`);
    return rows[0]?.value ?? {};
  },
  async saveSettings(v) {
    await q(`INSERT INTO settings (key,value) VALUES ('shop',$1)
      ON CONFLICT (key) DO UPDATE SET value=$1`, [JSON.stringify(v)]);
  },
};
