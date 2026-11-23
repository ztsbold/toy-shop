// QPay Quick QR v2 (https://quickqr.qpay.mn) — хувь хүн/жижиг бизнест зориулсан QR нэхэмжлэх.
// Шаардлагатай Render утгууд:
//   QQ_BASE_URL       Sandbox: https://sandbox-quickqr.qpay.mn   Бодит: https://quickqr.qpay.mn
//   QQ_USERNAME, QQ_PASSWORD, QQ_TERMINAL_ID   — QPay-ээс өгсөн
//   QQ_MERCHANT_ID                             — бүртгэгдсэн мерчантын id
//   QQ_BANK_CODE, QQ_ACCOUNT_NUMBER, QQ_ACCOUNT_NAME — мөнгө орох данс
//   QQ_MCC (анхдагч 5945 — тоглоомын дэлгүүр), QQ_BRANCH_CODE (заавал биш)
const env = process.env;
const BASE = (env.QQ_BASE_URL || 'https://sandbox-quickqr.qpay.mn').replace(/\/$/, '');

// Token-ийг зөвхөн санах ойд хадгална (QPay-ийн зөвлөмж)
let token = null;
let refreshToken = null;
let expiresAt = 0; // expires_in нь Unix timestamp (секунд)

async function fetchToken() {
  const basic = Buffer.from(`${env.QQ_USERNAME || ''}:${env.QQ_PASSWORD || ''}`).toString('base64');
  const res = await fetch(`${BASE}/v2/auth/token`, {
    method: 'POST',
    headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ terminal_id: env.QQ_TERMINAL_ID || '' }),
  });
  if (!res.ok) throw new Error(`QuickQR token: ${res.status} ${(await res.text()).slice(0, 300)}`);
  setToken(await res.json());
}

async function refresh() {
  if (!refreshToken) return fetchToken();
  const res = await fetch(`${BASE}/v2/auth/refresh`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${refreshToken}` },
  });
  if (!res.ok) return fetchToken();
  setToken(await res.json());
}

function setToken(d) {
  token = d.access_token;
  refreshToken = d.refresh_token ?? refreshToken;
  const exp = Number(d.expires_in);
  // Unix секунд гэж тооцно; утга хачин бол 20 минут гэж үзнэ
  expiresAt = exp > 1e9 ? exp * 1000 : Date.now() + 20 * 60_000;
}

async function getToken() {
  if (!token) await fetchToken();
  else if (Date.now() > expiresAt - 60_000) await refresh();
  return token;
}

/** 401/403 үед token-ийг хаяад нэг л удаа дахин оролдоно */
async function call(method, path, body, retried = false) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { Authorization: `Bearer ${await getToken()}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if ((res.status === 401 || res.status === 403) && !retried) {
    token = null;
    refreshToken = null;
    return call(method, path, body, true);
  }
  const text = await res.text();
  if (!res.ok) throw new Error(`QuickQR ${path}: ${res.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : {};
}

export async function createQuickQrInvoice(order, callbackUrl, merchantId) {
  const inv = await call('POST', '/v2/invoice', {
    merchant_id: merchantId || env.QQ_MERCHANT_ID,
    amount: order.total,
    currency: 'MNT',
    description: `F5 Toys захиалга ${order.id}`.slice(0, 255),
    mcc_code: env.QQ_MCC || '5945',
    callback_url: callbackUrl,
    bank_accounts: [{
      account_bank_code: env.QQ_BANK_CODE,
      account_number: env.QQ_ACCOUNT_NUMBER,
      account_name: env.QQ_ACCOUNT_NAME,
      is_default: true,
    }],
  });
  return {
    invoiceId: inv.id,
    qrImage: inv.qr_image ?? '',
    qrText: inv.qr_code ?? '',
    shortUrl: '',
    // QPay-ээс ирсэн банкны холбоосыг өөрчлөлгүй дамжуулна
    banks: (inv.urls ?? []).map((u) => ({ name: u.name, description: u.description, logo: u.logo ?? '', link: u.link })),
  };
}

export async function isQuickQrPaid(invoiceId, total) {
  const d = await call('POST', '/v2/payment/check', { invoice_id: invoiceId });
  if (String(d.invoice_status || '').toUpperCase() === 'PAID') return true;
  const paid = (d.payments ?? [])
    .filter((p) => String(p.payment_status || '').toUpperCase() === 'PAID')
    .reduce((s, p) => s + Number(p.amount || 0), 0);
  return paid >= total;
}

/** Төлөгдөөгүй нэхэмжлэхийг цуцална (захиалга цуцлагдах үед) */
export async function cancelQuickQrInvoice(invoiceId) {
  await call('DELETE', `/v2/invoice/${encodeURIComponent(invoiceId)}`);
}

// ---------- Мерчант бүртгэл (нэг удаа) ----------
export const listCities = () => call('GET', '/v2/aimaghot');
export const listDistricts = (cityCode) => call('GET', `/v2/sumduureg/${encodeURIComponent(cityCode)}`);
export const getMerchant = (id) => call('GET', `/v2/merchant/${encodeURIComponent(id)}`);
export const listMerchants = () => call('POST', '/v2/merchant/list', { offset: { page_number: 1, page_limit: 100 } });

/** type: 'person' | 'company' */
export function createMerchant(type, f) {
  const common = {
    mcc_code: f.mcc_code || env.QQ_MCC || '5945',
    city: f.city, district: f.district, address: f.address, phone: f.phone, email: f.email,
  };
  // Талбарууд QPay-ийн албан ёсны Postman collection (Quick QR v2.0.0)-ий дагуу
  if (type === 'company') {
    return call('POST', '/v2/merchant/company', {
      register_number: f.register_number, company_name: f.company_name, name: f.name, ...common,
    });
  }
  return call('POST', '/v2/merchant/person', {
    register_number: f.register_number, first_name: f.first_name, last_name: f.last_name,
    business_name: f.business_name, ...common,
  });
}
