import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { store } from './store.js';
import { sendEmail, emailHtml, EMAIL_PROVIDER } from './mailer.js';
import { issueToken, verifyToken, newOtpCode, hashOtp, sameHash } from './auth.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const env = process.env;
const PORT = Number(env.PORT || 3000);
const PUBLIC_URL = env.PUBLIC_URL || env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`;
const PAYMENT_MODE = (env.PAYMENT_MODE || 'mock').toLowerCase(); // qpay | manual | mock
const ADMIN_KEY = env.ADMIN_KEY || '';
const QPAY_BASE_URL = env.QPAY_BASE_URL || 'https://merchant-sandbox.qpay.mn';
const rid = (p) => `${p}${Date.now().toString(36)}${crypto.randomBytes(3).toString('hex')}`;

// ---------------- Дэлгүүрийн тохиргоо (/admin → Тохиргоо) ----------------
const DEFAULT_SETTINGS = {
  deliveryOptions: [
    { id: 'standard', name: 'Стандарт хүргэлт', eta: '1-2 өдөр', fee: Number(env.DELIVERY_FEE ?? 5000), active: true },
    { id: 'fast', name: 'Хурдан хүргэлт', eta: '24 цаг', fee: 10000, active: true },
    { id: 'urgent', name: 'Яаралтай хүргэлт', eta: '2-4 цаг', fee: 20000, active: true },
  ],
  freeDeliveryFrom: Number(env.FREE_DELIVERY_FROM ?? 0),
  shopPhone: '', shopAddress: '', workHours: '',
  shopName: 'F5 Toys',
  pointsPerAmount: 1000, // хэдэн ₮ тутамд 1 оноо
  pointValue: 1, // 1 оноо = хэдэн ₮
  pointsMaxPercent: 100, // оноогоор төлж болох барааны дүнгийн дээд хувь
  emailOnStatus: true, // захиалгын төлөв солигдоход имэйл илгээх
};
const getSettings = async () => ({ ...DEFAULT_SETTINGS, ...(await store.getSettings()) });

function deliveryFeeFor(st, option, subtotal) {
  if (option.id === 'standard' && st.freeDeliveryFrom > 0 && subtotal >= st.freeDeliveryFrom) return 0;
  return option.fee;
}

const STATUS_TEXT = {
  CREATED: 'Захиалга хүлээн авлаа',
  PAID: 'Төлбөр баталгаажлаа',
  PREPARING: 'Захиалгыг бэлтгэж байна',
  SHIPPING: 'Захиалга хүргэлтэнд гарлаа',
  DELIVERED: 'Захиалга хүргэгдлээ',
  CANCELLED: 'Захиалга цуцлагдлаа',
};

/** Апп доторх мэдэгдэл + (тохиргооноос хамааран) имэйл */
async function notifyCustomer(order, status, extra = '') {
  if (!order.customerId) return;
  const st = await getSettings();
  const title = STATUS_TEXT[status] ?? status;
  const body = `${order.id} дугаартай захиалга. ${extra}`.trim();
  try { await store.addNotification(order.customerId, title, body, order.id); } catch (e) { console.error(e); }
  if (st.emailOnStatus !== false && ['PAID', 'SHIPPING', 'DELIVERED', 'CANCELLED'].includes(status)) {
    const c = await store.getCustomer(order.customerId);
    if (c?.email) {
      const lines = [`Захиалгын дугаар: ${order.id}`, `Нийт дүн: ${order.total.toLocaleString('en-US')}₮`, extra].filter(Boolean);
      await sendEmail(c.email, `${st.shopName}: ${title}`, {
        html: emailHtml({ shopName: st.shopName, heading: title, lines }),
        text: `${title}\n${lines.join('\n')}`,
      });
    }
  }
}

// ---------------- QPay v2 ----------------
let qpayToken = null;
let qpayTokenAt = 0;
async function getToken(force = false) {
  if (!force && qpayToken && Date.now() - qpayTokenAt < 30 * 60 * 1000) return qpayToken;
  const basic = Buffer.from(`${env.QPAY_USERNAME}:${env.QPAY_PASSWORD}`).toString('base64');
  const res = await fetch(`${QPAY_BASE_URL}/v2/auth/token`, { method: 'POST', headers: { Authorization: `Basic ${basic}` } });
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

async function createPayment(order) {
  const base = { invoiceId: order.id, qrImage: '', qrText: '', shortUrl: '', banks: [], manual: null };
  if (order.paymentMode === 'points') return base;
  if (order.paymentMode === 'qpay') {
    const inv = await qpayPost('/v2/invoice', {
      invoice_code: env.QPAY_INVOICE_CODE,
      sender_invoice_no: order.id,
      invoice_receiver_code: order.delivery.phone,
      invoice_description: `Тоглоомын захиалга ${order.id}`,
      amount: order.total,
      callback_url: `${PUBLIC_URL}/api/qpay/callback?order_id=${encodeURIComponent(order.id)}`,
    });
    return {
      ...base, invoiceId: inv.invoice_id, qrImage: inv.qr_image ?? '', qrText: inv.qr_text ?? '',
      shortUrl: inv.qPay_shortUrl ?? '',
      banks: (inv.urls ?? []).map((u) => ({ name: u.name, description: u.description, logo: u.logo, link: u.link })),
    };
  }
  if (order.paymentMode === 'manual') {
    return {
      ...base,
      manual: {
        bankName: env.BANK_NAME || '', accountNumber: env.BANK_ACCOUNT || '',
        accountHolder: env.BANK_ACCOUNT_HOLDER || '', reference: order.id,
        note: env.BANK_NOTE || 'Гүйлгээний утга дээр захиалгын дугаараа заавал бичнэ үү.',
      },
    };
  }
  return { ...base, qrText: `ТУРШИЛТ: ${order.id} — 15 секундын дараа төлөгдсөнд тооцогдоно` };
}

async function isPaidAtProvider(order) {
  if (order.paymentMode === 'mock') return Date.now() - order.createdAt > 15000;
  if (order.paymentMode !== 'qpay') return false;
  const data = await qpayPost('/v2/payment/check', {
    object_type: 'INVOICE', object_id: order.invoiceId, offset: { page_number: 1, page_limit: 100 },
  });
  const paid = (data.rows ?? []).filter((r) => r.payment_status === 'PAID')
    .reduce((s, r) => s + Number(r.payment_amount || 0), 0);
  return paid >= order.total || Number(data.paid_amount || 0) >= order.total;
}

/** Төлөгдсөн болгох: үлдэгдэл хасах, оноо олгох, мэдэгдэх (нэг л удаа) */
async function markPaid(order) {
  if (!(await store.markPaidOnce(order.id))) return;
  order.status = 'PAID';
  for (const it of order.items) await store.decrementStock(it.toyId, it.qty);
  let extra = '';
  if (order.customerId) {
    const st = await getSettings();
    const discount = order.pointsUsed * st.pointValue;
    const earned = Math.floor(Math.max(0, order.subtotal - discount) / st.pointsPerAmount);
    if (earned > 0) {
      await store.addPoints(order.customerId, earned, `Захиалга ${order.id}`, order.id);
      await store.setPointsEarned(order.id, earned);
      order.pointsEarned = earned;
      extra = `${earned} оноо нэмэгдлээ.`;
    }
  }
  await notifyCustomer(order, 'PAID', extra);
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

// ---------------- Апп ----------------
const app = express();
app.set('trust proxy', 1);
app.use(cors());
const jsonSmall = express.json({ limit: '100kb' });
const jsonLarge = express.json({ limit: '6mb' });
app.use((req, res, next) => (req.path === '/api/admin/images' ? jsonLarge : jsonSmall)(req, res, next));
app.use('/admin', express.static(path.join(__dirname, 'public', 'admin')));

const wrap = (fn) => (req, res) => fn(req, res).catch((e) => {
  console.error(e);
  res.status(500).json({ error: 'Серверийн алдаа' });
});

function customerIdFrom(req) {
  const h = req.get('authorization') || '';
  return h.startsWith('Bearer ') ? verifyToken(h.slice(7)) : null;
}
function requireCustomer(req, res, next) {
  req.customerId = customerIdFrom(req);
  if (!req.customerId) return res.status(401).json({ error: 'Нэвтэрнэ үү' });
  next();
}

app.get('/', (_req, res) => res.redirect('/admin/'));
app.get('/health', (_req, res) => res.json({ ok: true, paymentMode: PAYMENT_MODE, email: EMAIL_PROVIDER }));

app.get('/api/config', wrap(async (_req, res) => {
  const st = await getSettings();
  res.json({
    deliveryOptions: st.deliveryOptions.filter((o) => o.active !== false).map(({ id, name, eta, fee }) => ({ id, name, eta, fee })),
    freeDeliveryFrom: st.freeDeliveryFrom,
    shopPhone: st.shopPhone, shopAddress: st.shopAddress, workHours: st.workHours,
    loyalty: { pointsPerAmount: st.pointsPerAmount, pointValue: st.pointValue, maxPercent: st.pointsMaxPercent },
    paymentMode: PAYMENT_MODE,
  });
}));

app.get('/images/:id', wrap(async (req, res) => {
  const img = await store.getImage(req.params.id);
  if (!img) return res.status(404).end();
  res.set('Content-Type', img.mime);
  res.set('Cache-Control', 'public, max-age=31536000, immutable');
  res.send(img.data);
}));

app.get('/api/toys', wrap(async (_req, res) => {
  res.json((await store.listProducts()).map(({ active, ...p }) => p));
}));

// ---------- Нэвтрэлт (имэйл код) ----------
const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]+\.[^\s@]{2,}$/;
const normEmail = (v) => String(v ?? '').trim().toLowerCase().slice(0, 254);

app.post('/api/auth/request-otp', wrap(async (req, res) => {
  const email = normEmail(req.body?.email);
  if (!EMAIL_RE.test(email)) return res.status(400).json({ error: 'И-мэйл хаяг буруу байна' });
  const last = await store.lastOtpEmailAt(email);
  const wait = Math.ceil((last + 60_000 - Date.now()) / 1000);
  if (wait > 0) return res.status(429).json({ error: `${wait} секундын дараа дахин оролдоно уу`, retryAfter: wait });
  if ((await store.countOtpEmailsSince(email, Date.now() - 3600_000)) >= 5)
    return res.status(429).json({ error: 'Хэт олон оролдлого. 1 цагийн дараа дахин оролдоно уу.' });
  const st = await getSettings();
  const code = newOtpCode();
  await store.saveOtp(email, hashOtp(email, code), Date.now() + 10 * 60_000);
  const ok = await sendEmail(email, `${st.shopName}: нэвтрэх код ${code}`, {
    html: emailHtml({
      shopName: st.shopName, heading: 'Таны нэвтрэх код', code,
      lines: ['Энэ кодыг апп-д оруулна уу. Код 10 минутын дотор хүчинтэй.', 'Хэрэв та хүсэлт гаргаагүй бол энэ имэйлийг үл тоомсорлоно уу.'],
    }),
    text: `Таны нэвтрэх код: ${code}\nКод 10 минутын дотор хүчинтэй.`,
  }, 'otp');
  if (!ok) return res.status(502).json({ error: 'Имэйл илгээж чадсангүй. Дахин оролдоно уу.' });
  res.json({ ok: true, retryAfter: 60, testMode: EMAIL_PROVIDER === 'test' });
}));

app.post('/api/auth/verify', wrap(async (req, res) => {
  const email = normEmail(req.body?.email);
  const code = String(req.body?.code ?? '').trim();
  const otp = await store.getOtp(email);
  if (!otp || otp.expiresAt < Date.now()) return res.status(400).json({ error: 'Кодын хугацаа дууссан. Шинэ код авна уу.' });
  if (otp.attempts >= 5) {
    await store.deleteOtp(email);
    return res.status(429).json({ error: 'Хэт олон буруу оролдлого. Шинэ код авна уу.' });
  }
  if (!/^\d{6}$/.test(code) || !sameHash(hashOtp(email, code), otp.codeHash)) {
    await store.bumpOtpAttempts(email);
    return res.status(400).json({ error: 'Код буруу байна' });
  }
  await store.deleteOtp(email);
  let c = await store.getCustomerByEmail(email);
  const isNew = !c;
  if (!c) c = await store.createCustomer(rid('c_'), email);
  // Нэр, утас бөглөөгүй бол апп профайл бөглөх алхам руу шилжинэ
  res.json({ token: issueToken(c.id), customer: c, isNew, needsProfile: !c.name || !c.phone });
}));

app.get('/api/me', requireCustomer, wrap(async (req, res) => {
  const c = await store.getCustomer(req.customerId);
  if (!c) return res.status(401).json({ error: 'Нэвтэрнэ үү' });
  const notes = await store.listNotifications(c.id, 50);
  res.json({ ...c, unread: notes.filter((n) => !n.read).length });
}));

// Профайл: нэр ба утас заавал
app.patch('/api/me', requireCustomer, wrap(async (req, res) => {
  const cur = await store.getCustomer(req.customerId);
  if (!cur) return res.status(401).json({ error: 'Нэвтэрнэ үү' });
  const name = clip(req.body?.name ?? cur.name, 80).trim();
  const phone = String(req.body?.phone ?? cur.phone ?? '').replace(/\D/g, '');
  if (!name) return res.status(400).json({ error: 'Нэр оруулна уу' });
  if (!PHONE_RE.test(phone)) return res.status(400).json({ error: '8 оронтой утасны дугаар оруулна уу' });
  await store.updateCustomerProfile(req.customerId, name, phone);
  res.json(await store.getCustomer(req.customerId));
}));

const orderView = (o) => ({
  orderId: o.id, status: o.status, fulfillment: o.fulfillment, total: o.total,
  subtotal: o.subtotal, deliveryFee: o.deliveryFee, createdAt: o.createdAt,
  itemCount: o.items.reduce((n, i) => n + i.qty, 0), firstItem: o.items[0]?.name ?? '',
  items: o.items.map(({ name, qty, price }) => ({ name, qty, price })),
  deliveryOption: o.delivery?.deliveryOption?.name ?? '',
  pointsUsed: o.pointsUsed, pointsEarned: o.pointsEarned,
  history: [{ status: 'CREATED', at: o.createdAt }, ...(o.history ?? []).filter((h) => h.status !== 'CREATED')],
});

app.get('/api/me/orders', requireCustomer, wrap(async (req, res) => {
  res.json((await store.listOrdersByCustomer(req.customerId)).map(orderView));
}));
app.get('/api/me/points', requireCustomer, wrap(async (req, res) => {
  res.json(await store.listLedger(req.customerId));
}));
app.get('/api/me/notifications', requireCustomer, wrap(async (req, res) => {
  res.json(await store.listNotifications(req.customerId));
}));
app.post('/api/me/notifications/read', requireCustomer, wrap(async (req, res) => {
  await store.markNotificationsRead(req.customerId);
  res.json({ ok: true });
}));

// ---------- Захиалга ----------
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
    lines.push({ toyId: p.id, name: p.name, price: p.price, qty: n, pointsEligible: p.pointsEligible });
  }
  const subtotal = lines.reduce((s, l) => s + l.price * l.qty, 0);
  const st = await getSettings();
  const options = st.deliveryOptions.filter((o) => o.active !== false);
  const option = options.find((o) => o.id === (req.body.deliveryOptionId || 'standard')) ?? options[0];
  if (!option) return res.status(400).json({ error: 'Хүргэлтийн сонголт олдсонгүй' });
  const deliveryFee = deliveryFeeFor(st, option, subtotal);

  // Оноо ашиглах (зөвхөн нэвтэрсэн, "оноогоор авч болно" бараанд)
  const customerId = customerIdFrom(req);
  let pointsUsed = 0;
  const wanted = Math.max(0, Math.floor(Number(req.body.pointsToUse) || 0));
  if (customerId && wanted > 0) {
    const c = await store.getCustomer(customerId);
    const eligible = lines.filter((l) => l.pointsEligible).reduce((s, l) => s + l.price * l.qty, 0);
    const cap = Math.floor((eligible * st.pointsMaxPercent) / 100 / st.pointValue);
    pointsUsed = Math.min(wanted, cap, c?.points ?? 0);
  }
  const discount = pointsUsed * st.pointValue;
  const total = Math.max(0, subtotal + deliveryFee - discount);

  const cleanDelivery = Object.fromEntries(
    ['fullName', 'phone', 'district', 'khoroo', 'building', 'apartment', 'address', 'note',
     'receiptType', 'companyRegister'].map((k) => [k, clip(delivery[k])]));
  cleanDelivery.deliveryOption = { id: option.id, name: option.name, eta: option.eta, fee: deliveryFee };

  const now = Date.now();
  const order = {
    id: `TOY-${now.toString(36).toUpperCase()}${crypto.randomInt(10, 99)}`,
    items: lines, delivery: cleanDelivery, subtotal, deliveryFee, total,
    status: 'PENDING', fulfillment: 'NEW', paymentMode: total === 0 ? 'points' : PAYMENT_MODE,
    createdAt: now, customerId, pointsUsed, history: [],
  };

  if (pointsUsed > 0 &&
      (await store.addPoints(customerId, -pointsUsed, `Захиалга ${order.id}-д ашигласан`, order.id)) === null) {
    return res.status(409).json({ error: 'Оноо хүрэлцэхгүй байна' });
  }
  let payment;
  try {
    payment = await createPayment(order);
  } catch (e) {
    console.error(e);
    if (pointsUsed > 0) await store.addPoints(customerId, pointsUsed, `Захиалга ${order.id} амжилтгүй, буцаалт`, order.id);
    return res.status(502).json({ error: 'Төлбөрийн нэхэмжлэх үүсгэж чадсангүй. Дахин оролдоно уу.' });
  }
  order.invoiceId = payment.invoiceId;
  await store.insertOrder(order);
  await notifyCustomer(order, 'CREATED', pointsUsed ? `${pointsUsed} оноо ашиглалаа.` : '');
  if (total === 0) await markPaid(order);

  res.status(201).json({
    orderId: order.id, subtotal, deliveryFee, total, pointsUsed, discount,
    paymentMode: order.paymentMode, invoice: payment,
  });
}));

app.get('/api/orders/:id/status', wrap(async (req, res) => {
  const order = await store.getOrder(req.params.id);
  if (!order) return res.status(404).json({ error: 'Захиалга олдсонгүй' });
  try { await refreshStatus(order); } catch (e) { console.error(e); }
  const fresh = await store.getOrder(order.id);
  const v = orderView(fresh);
  delete v.items; // нэвтрээгүй хүнд барааны жагсаалтыг харуулахгүй
  res.json(v);
}));

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
  res.json({ paymentMode: PAYMENT_MODE, email: EMAIL_PROVIDER }));

app.get('/api/admin/orders', requireAdmin, wrap(async (_req, res) => {
  const orders = await store.listOrders();
  const customers = new Map((await store.listCustomers()).map((c) => [c.id, c]));
  res.json(orders.map((o) => ({ ...o, customer: o.customerId ? customers.get(o.customerId) ?? null : null })));
}));

app.post('/api/admin/orders/:id/mark-paid', requireAdmin, wrap(async (req, res) => {
  const order = await store.getOrder(req.params.id);
  if (!order) return res.status(404).json({ error: 'Захиалга олдсонгүй' });
  if (order.fulfillment === 'CANCELLED') return res.status(400).json({ error: 'Цуцлагдсан захиалга' });
  await markPaid(order);
  res.json({ ok: true });
}));

const FULFILLMENT = ['NEW', 'PREPARING', 'SHIPPING', 'DELIVERED', 'CANCELLED'];
app.patch('/api/admin/orders/:id', requireAdmin, wrap(async (req, res) => {
  const f = String(req.body?.fulfillment ?? '');
  if (!FULFILLMENT.includes(f)) return res.status(400).json({ error: 'Төлөв буруу' });
  const order = await store.getOrder(req.params.id);
  if (!order) return res.status(404).json({ error: 'Захиалга олдсонгүй' });
  if (order.fulfillment === 'CANCELLED') return res.status(400).json({ error: 'Цуцлагдсан захиалгыг өөрчлөх боломжгүй' });
  if (!(await store.setFulfillment(order.id, f))) return res.json({ ok: true });

  let extra = '';
  if (f === 'CANCELLED') {
    // Ашигласан оноог буцааж, олгосон оноог хасна; төлөгдсөн бол үлдэгдлийг сэргээнэ
    if (order.customerId && order.pointsUsed > 0) {
      await store.addPoints(order.customerId, order.pointsUsed, `Захиалга ${order.id} цуцлагдсан, буцаалт`, order.id);
      extra = `${order.pointsUsed} оноо буцаагдлаа.`;
    }
    if (order.customerId && order.pointsEarned > 0) {
      await store.addPoints(order.customerId, -order.pointsEarned, `Захиалга ${order.id} цуцлагдсан`, order.id, { allowPartial: true });
    }
    if (order.status === 'PAID') for (const it of order.items) await store.incrementStock(it.toyId, it.qty);
  }
  await notifyCustomer(order, f, extra);
  res.json({ ok: true });
}));

app.get('/api/admin/customers', requireAdmin, wrap(async (_req, res) => res.json(await store.listCustomers())));

app.post('/api/admin/customers/:id/points', requireAdmin, wrap(async (req, res) => {
  const delta = Math.trunc(Number(req.body?.delta) || 0);
  const reason = clip(req.body?.reason || 'Админ засвар', 120);
  if (!delta) return res.status(400).json({ error: 'Оноо оруулна уу' });
  const bal = await store.addPoints(req.params.id, delta, reason, null);
  if (bal === null) return res.status(400).json({ error: 'Үлдэгдэл хүрэлцэхгүй' });
  const c = await store.getCustomer(req.params.id);
  await store.addNotification(c.id, delta > 0 ? `${delta} оноо нэмэгдлээ` : `${-delta} оноо хасагдлаа`, reason);
  res.json({ ok: true, points: bal });
}));

app.get('/api/admin/emails', requireAdmin, wrap(async (_req, res) => res.json(await store.listEmails())));

app.get('/api/admin/products', requireAdmin, wrap(async (_req, res) =>
  res.json(await store.listProducts({ includeInactive: true }))));

app.put('/api/admin/products/:id', requireAdmin, wrap(async (req, res) => {
  const b = req.body ?? {};
  const price = Number(b.price), stock = Number(b.stock);
  if (!String(b.name ?? '').trim()) return res.status(400).json({ error: 'Нэр оруулна уу' });
  if (!Number.isInteger(price) || price < 0) return res.status(400).json({ error: 'Үнэ буруу' });
  if (!Number.isInteger(stock) || stock < 0) return res.status(400).json({ error: 'Үлдэгдэл буруу' });
  const id = req.params.id === 'new' ? rid('t') : req.params.id;
  const features = (Array.isArray(b.features) ? b.features : []).slice(0, 4)
    .map((f) => ({ value: clip(f?.value, 20), label: clip(f?.label, 30) }))
    .filter((f) => f.value || f.label);
  await store.upsertProduct({
    id, name: clip(b.name, 120), subtitle: clip(b.subtitle, 120), sku: clip(b.sku, 40),
    category: clip(b.category, 60), ageRange: clip(b.ageRange, 20),
    price, stock, emoji: clip(b.emoji || '🎁', 8), imageUrl: clip(b.imageUrl, 500),
    description: clip(b.description, 3000), isNew: !!b.isNew, pointsEligible: !!b.pointsEligible,
    features, active: b.active !== false,
  });
  res.json({ ok: true, id });
}));

const IMAGE_TYPES = { 'image/jpeg': 1, 'image/png': 1, 'image/webp': 1 };
app.post('/api/admin/images', requireAdmin, wrap(async (req, res) => {
  const m = /^data:(image\/[a-z]+);base64,(.+)$/.exec(String(req.body?.dataUrl ?? ''));
  if (!m || !IMAGE_TYPES[m[1]]) return res.status(400).json({ error: 'Зөвхөн JPG, PNG, WEBP зураг' });
  const buf = Buffer.from(m[2], 'base64');
  if (buf.length > 3 * 1024 * 1024) return res.status(413).json({ error: 'Зураг 3MB-аас их байна' });
  const id = crypto.randomBytes(12).toString('hex');
  await store.saveImage(id, m[1], buf);
  res.json({ url: `/images/${id}` });
}));

app.get('/api/admin/settings', requireAdmin, wrap(async (_req, res) => res.json(await getSettings())));

app.put('/api/admin/settings', requireAdmin, wrap(async (req, res) => {
  const b = req.body ?? {};
  const int = (v, min, max, d) => {
    const n = Math.round(Number(v));
    return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : d;
  };
  const opts = (Array.isArray(b.deliveryOptions) ? b.deliveryOptions : []).slice(0, 6).map((o, i) => ({
    id: clip(o?.id || `opt${i}`, 30), name: clip(o?.name, 60), eta: clip(o?.eta, 40),
    fee: int(o?.fee, 0, 10_000_000, 0), active: o?.active !== false,
  })).filter((o) => o.name);
  if (!opts.some((o) => o.active)) return res.status(400).json({ error: 'Дор хаяж нэг хүргэлтийн сонголт идэвхтэй байх ёстой' });
  await store.saveSettings({
    deliveryOptions: opts,
    freeDeliveryFrom: int(b.freeDeliveryFrom, 0, 100_000_000, 0),
    shopPhone: clip(b.shopPhone, 30), shopAddress: clip(b.shopAddress, 200), workHours: clip(b.workHours, 80),
    shopName: clip(b.shopName || 'F5 Toys', 30),
    pointsPerAmount: int(b.pointsPerAmount, 1, 10_000_000, 1000),
    pointValue: int(b.pointValue, 1, 1_000_000, 1),
    pointsMaxPercent: int(b.pointsMaxPercent, 0, 100, 100),
    emailOnStatus: b.emailOnStatus !== false,
  });
  res.json({ ok: true });
}));

await store.init();
app.listen(PORT, () => {
  console.log(`Backend ${PUBLIC_URL} | төлбөр: ${PAYMENT_MODE} | имэйл: ${EMAIL_PROVIDER}`);
  if (!ADMIN_KEY) console.warn('ADMIN_KEY тохируулаагүй — админ хэсэг хаалттай.');
});
