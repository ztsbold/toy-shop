import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { store } from './store.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const env = process.env;
const PORT = Number(env.PORT || 3000);
// Render өөрөө RENDER_EXTERNAL_URL-г тохируулдаг
const PUBLIC_URL = env.PUBLIC_URL || env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`;
// qpay | manual | mock
const PAYMENT_MODE = (env.PAYMENT_MODE || 'mock').toLowerCase();
const DELIVERY_FEE = Number(env.DELIVERY_FEE ?? 5000);
const FREE_DELIVERY_FROM = Number(env.FREE_DELIVERY_FROM ?? 100000);
const ADMIN_KEY = env.ADMIN_KEY || '';
const QPAY_BASE_URL = env.QPAY_BASE_URL || 'https://merchant-sandbox.qpay.mn';

// ---------------- QPay v2 ----------------
let qpayToken = null;
let qpayTokenAt = 0;

async function getToken(force = false) {
  if (!force && qpayToken && Date.now() - qpayTokenAt < 30 * 60 * 1000) return qpayToken;
  const basic = Buffer.from(`${env.QPAY_USERNAME}:${env.QPAY_PASSWORD}`).toString('base64');
  const res = await fetch(`${QPAY_BASE_URL}/v2/auth/token`, {
    method: 'POST', headers: { Authorization: `Basic ${basic}` },
  });
  if (!res.ok) throw new Error(`QPay token: ${res.status} ${await res.text()}`);
  qpayToken = (await res.json()).access_token;
  qpayTokenAt = Date.now();
  return qpayToken;
}

async function qpayPost(p, body, retried = false) {
  const res = await fetch(`${QPAY_BASE_URL}${p}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${await getToken(retried)}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (res.status === 401 && !retried) return qpayPost(p, body, true);
  if (!res.ok) throw new Error(`QPay ${p}: ${res.status} ${await res.text()}`);
  return res.json();
}

// Төлбөрийн мэдээллийг апп руу нэг хэлбэрээр буцаана
async function createPayment(order) {
  const base = { invoiceId: order.id, qrImage: '', qrText: '', shortUrl: '', banks: [], manual: null };
  if (PAYMENT_MODE === 'qpay') {
    const inv = await qpayPost('/v2/invoice', {
      invoice_code: env.QPAY_INVOICE_CODE,
      sender_invoice_no: order.id,
      invoice_receiver_code: order.delivery.phone,
      invoice_description: `Тоглоомын захиалга ${order.id}`,
      amount: order.total,
      callback_url: `${PUBLIC_URL}/api/qpay/callback?order_id=${encodeURIComponent(order.id)}`,
    });
    return {
      ...base,
      invoiceId: inv.invoice_id,
      qrImage: inv.qr_image ?? '',
      qrText: inv.qr_text ?? '',
      shortUrl: inv.qPay_shortUrl ?? '',
      banks: (inv.urls ?? []).map((u) => ({ name: u.name, description: u.description, logo: u.logo, link: u.link })),
    };
  }
  if (PAYMENT_MODE === 'manual') {
    return {
      ...base,
      manual: {
        bankName: env.BANK_NAME || '',
        accountNumber: env.BANK_ACCOUNT || '',
        accountHolder: env.BANK_ACCOUNT_HOLDER || '',
        reference: order.id, // гүйлгээний утга
        note: env.BANK_NOTE || 'Гүйлгээний утга дээр захиалгын дугаараа заавал бичнэ үү.',
      },
    };
  }
  return { ...base, qrText: `ТУРШИЛТ: ${order.id} — 15 секундын дараа төлөгдсөнд тооцогдоно` };
}

async function isPaidAtProvider(order) {
  if (order.paymentMode === 'mock') return Date.now() - order.createdAt > 15000;
  if (order.paymentMode !== 'qpay') return false; // manual: админ баталгаажуулна
  const data = await qpayPost('/v2/payment/check', {
    object_type: 'INVOICE', object_id: order.invoiceId,
    offset: { page_number: 1, page_limit: 100 },
  });
  const paid = (data.rows ?? []).filter((r) => r.payment_status === 'PAID')
    .reduce((s, r) => s + Number(r.payment_amount || 0), 0);
  return paid >= order.total || Number(data.paid_amount || 0) >= order.total;
}

async function markPaid(order) {
  if (await store.markPaidOnce(order.id)) {
    for (const it of order.items) await store.decrementStock(it.toyId, it.qty);
    order.status = 'PAID';
  }
}

async function refreshStatus(order) {
  if (order.status === 'PENDING' && (await isPaidAtProvider(order))) await markPaid(order);
  return order.status;
}

// ---------------- Шалгалт ----------------
const PHONE_RE = /^[6-9]\d{7}$/;
function validateDelivery(d) {
  if (!d || typeof d !== 'object') return ['Хүргэлтийн мэдээлэл дутуу'];
  const e = [];
  if (!String(d.fullName ?? '').trim()) e.push('Нэр оруулна уу');
  if (!PHONE_RE.test(String(d.phone ?? ''))) e.push('Утасны дугаар буруу');
  if (!String(d.district ?? '').trim()) e.push('Дүүрэг сонгоно уу');
  if (!String(d.address ?? '').trim()) e.push('Дэлгэрэнгүй хаяг оруулна уу');
  if (d.receiptType === 'company' && !/^\d{7}$/.test(String(d.companyRegister ?? '')))
    e.push('Байгууллагын регистр 7 оронтой байна');
  return e;
}
const clip = (v, n = 300) => String(v ?? '').slice(0, n);

// ---------------- API ----------------
const app = express();
app.set('trust proxy', 1);
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use('/admin', express.static(path.join(__dirname, 'public', 'admin')));

const wrap = (fn) => (req, res) => fn(req, res).catch((e) => {
  console.error(e);
  res.status(500).json({ error: 'Серверийн алдаа' });
});

app.get('/', (_req, res) => res.redirect('/admin/'));
app.get('/health', (_req, res) => res.json({ ok: true, paymentMode: PAYMENT_MODE, storage: store.kind }));

app.get('/api/toys', wrap(async (_req, res) => {
  res.json((await store.listProducts()).map(({ active, ...p }) => p));
}));

app.post('/api/orders', wrap(async (req, res) => {
  const { items, delivery } = req.body ?? {};
  if (!Array.isArray(items) || items.length === 0 || items.length > 50)
    return res.status(400).json({ error: 'Сагс хоосон байна' });
  const errors = validateDelivery(delivery);
  if (errors.length) return res.status(400).json({ error: errors.join(', ') });

  const lines = [];
  for (const { toyId, qty } of items) {
    const p = await store.getProduct(String(toyId));
    const n = Number(qty);
    if (!p || p.active === false) return res.status(400).json({ error: 'Бараа олдсонгүй' });
    if (!Number.isInteger(n) || n < 1) return res.status(400).json({ error: 'Тоо ширхэг буруу' });
    if (n > p.stock) return res.status(409).json({ error: `"${p.name}" үлдэгдэл ${p.stock} ширхэг байна` });
    lines.push({ toyId: p.id, name: p.name, price: p.price, qty: n });
  }
  const subtotal = lines.reduce((s, l) => s + l.price * l.qty, 0);
  const deliveryFee = subtotal >= FREE_DELIVERY_FROM ? 0 : DELIVERY_FEE;

  const cleanDelivery = Object.fromEntries(
    ['fullName', 'phone', 'extraPhone', 'district', 'khoroo', 'address', 'note',
     'receiptType', 'companyRegister', 'email'].map((k) => [k, clip(delivery[k])]));

  const order = {
    id: `TOY-${Date.now().toString(36).toUpperCase()}${Math.floor(Math.random() * 90 + 10)}`,
    items: lines, delivery: cleanDelivery, subtotal, deliveryFee,
    total: subtotal + deliveryFee, status: 'PENDING', fulfillment: 'NEW',
    paymentMode: PAYMENT_MODE, createdAt: Date.now(),
  };

  let payment;
  try {
    payment = await createPayment(order);
  } catch (e) {
    console.error(e);
    return res.status(502).json({ error: 'Төлбөрийн нэхэмжлэх үүсгэж чадсангүй. Дахин оролдоно уу.' });
  }
  order.invoiceId = payment.invoiceId;
  await store.insertOrder(order);

  res.status(201).json({
    orderId: order.id, subtotal, deliveryFee, total: order.total,
    paymentMode: PAYMENT_MODE, invoice: payment,
  });
}));

app.get('/api/orders/:id/status', wrap(async (req, res) => {
  const order = await store.getOrder(req.params.id);
  if (!order) return res.status(404).json({ error: 'Захиалга олдсонгүй' });
  let status = order.status;
  try { status = await refreshStatus(order); } catch (e) { console.error(e); }
  res.json({ orderId: order.id, status, fulfillment: order.fulfillment });
}));

// QPay төлбөр орсны дараа дуудна → заавал payment/check-ээр баталгаажуулна
app.all('/api/qpay/callback', async (req, res) => {
  try {
    const order = await store.getOrder(String(req.query.order_id ?? ''));
    if (order) await refreshStatus(order);
  } catch (e) { console.error(e); }
  res.status(200).send('SUCCESS');
});

// ---------------- Админ ----------------
function requireAdmin(req, res, next) {
  if (!ADMIN_KEY || req.get('x-admin-key') !== ADMIN_KEY)
    return res.status(401).json({ error: 'Админ түлхүүр буруу' });
  next();
}
app.get('/api/admin/info', requireAdmin, (_req, res) =>
  res.json({ paymentMode: PAYMENT_MODE, storage: store.kind }));

app.get('/api/admin/orders', requireAdmin, wrap(async (_req, res) => res.json(await store.listOrders())));

app.post('/api/admin/orders/:id/mark-paid', requireAdmin, wrap(async (req, res) => {
  const order = await store.getOrder(req.params.id);
  if (!order) return res.status(404).json({ error: 'Захиалга олдсонгүй' });
  await markPaid(order);
  res.json({ ok: true });
}));

const FULFILLMENT = ['NEW', 'SHIPPING', 'DELIVERED', 'CANCELLED'];
app.patch('/api/admin/orders/:id', requireAdmin, wrap(async (req, res) => {
  const f = String(req.body?.fulfillment ?? '');
  if (!FULFILLMENT.includes(f)) return res.status(400).json({ error: 'Төлөв буруу' });
  await store.setFulfillment(req.params.id, f);
  res.json({ ok: true });
}));

app.get('/api/admin/products', requireAdmin, wrap(async (_req, res) =>
  res.json(await store.listProducts({ includeInactive: true }))));

app.put('/api/admin/products/:id', requireAdmin, wrap(async (req, res) => {
  const b = req.body ?? {};
  const price = Number(b.price), stock = Number(b.stock);
  if (!String(b.name ?? '').trim()) return res.status(400).json({ error: 'Нэр оруулна уу' });
  if (!Number.isInteger(price) || price < 0) return res.status(400).json({ error: 'Үнэ буруу' });
  if (!Number.isInteger(stock) || stock < 0) return res.status(400).json({ error: 'Үлдэгдэл буруу' });
  const id = req.params.id === 'new' ? `t${Date.now().toString(36)}` : req.params.id;
  await store.upsertProduct({
    id, name: clip(b.name, 120), category: clip(b.category, 60), ageRange: clip(b.ageRange, 20),
    price, stock, emoji: clip(b.emoji || '🎁', 8), imageUrl: clip(b.imageUrl, 500),
    description: clip(b.description, 2000), active: b.active !== false,
  });
  res.json({ ok: true, id });
}));

await store.init();
app.listen(PORT, () => {
  console.log(`Backend ${PUBLIC_URL} | төлбөр: ${PAYMENT_MODE} | өгөгдөл: ${store.kind}`);
  if (!ADMIN_KEY) console.warn('ADMIN_KEY тохируулаагүй — админ хэсэг хаалттай.');
});
