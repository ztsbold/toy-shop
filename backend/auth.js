// Хэрэглэгчийн нэвтрэлт: SMS код (OTP) ба гарын үсэгтэй токен
import crypto from 'node:crypto';

const SECRET = process.env.AUTH_SECRET || process.env.ADMIN_KEY || 'dev-secret-change-me';
const TOKEN_DAYS = 180;

const b64 = (s) => Buffer.from(s).toString('base64url');
const sign = (data) => crypto.createHmac('sha256', SECRET).update(data).digest('base64url');

export function issueToken(customerId) {
  const payload = b64(JSON.stringify({ c: customerId, e: Date.now() + TOKEN_DAYS * 864e5 }));
  return `${payload}.${sign(payload)}`;
}

/** Хүчинтэй бол customerId, үгүй бол null */
export function verifyToken(token) {
  const [payload, sig] = String(token || '').split('.');
  if (!payload || !sig) return null;
  const expected = sign(payload);
  if (sig.length !== expected.length ||
      !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
  try {
    const { c, e } = JSON.parse(Buffer.from(payload, 'base64url').toString());
    return e > Date.now() ? c : null;
  } catch { return null; }
}

export const newOtpCode = () => String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
export const hashOtp = (phone, code) =>
  crypto.createHmac('sha256', SECRET).update(`${phone}:${code}`).digest('hex');
export const sameHash = (a, b) =>
  a.length === b.length && crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
