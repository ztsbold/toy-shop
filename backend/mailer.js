// Имэйл илгээх (HTTPS API — Render-ийн үнэгүй сервер SMTP портыг хаадаг тул).
//   EMAIL_PROVIDER=test (анхдагч): бодит имэйл явахгүй, админ хуудасны "Имэйл" табд харагдана
//   EMAIL_PROVIDER=brevo  + BREVO_API_KEY  + EMAIL_FROM (Brevo-д баталгаажуулсан илгээгч)
//   EMAIL_PROVIDER=resend + RESEND_API_KEY + EMAIL_FROM (Resend-д баталгаажуулсан домэйн дээрх хаяг)
//   EMAIL_PROVIDER=gmail  + GMAIL_SCRIPT_URL + GMAIL_SCRIPT_SECRET (өөрийн Gmail дээрх Google Apps Script)
import { store } from './store.js';

const env = process.env;
export const EMAIL_PROVIDER = (env.EMAIL_PROVIDER || 'test').toLowerCase();
const FROM = env.EMAIL_FROM || '';
const FROM_NAME = env.EMAIL_FROM_NAME || 'F5 Toys';

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/** Бүх имэйл програм дээр зөв харагдах энгийн загвар */
export function emailHtml({ shopName, heading, lines = [], code }) {
  return `<!doctype html><html><body style="margin:0;background:#f3f6fb;font-family:Arial,Helvetica,sans-serif;color:#111827">
<table width="100%" cellpadding="0" cellspacing="0" style="padding:24px 12px"><tr><td align="center">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:14px;padding:28px">
<tr><td style="font-size:26px;font-weight:900;font-style:italic;color:#1558E0">F5 <span style="font-size:14px;font-style:normal;color:#111827;font-weight:700">${esc(shopName)}</span></td></tr>
<tr><td style="padding-top:18px;font-size:19px;font-weight:700">${esc(heading)}</td></tr>
${code ? `<tr><td style="padding:18px 0"><div style="font-size:34px;letter-spacing:10px;font-weight:700;color:#1847B8;background:#EEF4FE;border-radius:10px;padding:14px;text-align:center">${esc(code)}</div></td></tr>` : ''}
${lines.map((l) => `<tr><td style="padding-top:8px;font-size:15px;line-height:1.5;color:#374151">${esc(l)}</td></tr>`).join('')}
</table></td></tr></table></body></html>`;
}

async function viaBrevo(to, subject, html, text) {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'api-key': env.BREVO_API_KEY || '', 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ sender: { name: FROM_NAME, email: FROM }, to: [{ email: to }], subject, htmlContent: html, textContent: text }),
  });
  if (!res.ok) throw new Error(`Brevo ${res.status}: ${(await res.text()).slice(0, 300)}`);
}

async function viaResend(to, subject, html, text) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { authorization: `Bearer ${env.RESEND_API_KEY || ''}`, 'content-type': 'application/json' },
    body: JSON.stringify({ from: `${FROM_NAME} <${FROM}>`, to: [to], subject, html, text }),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${(await res.text()).slice(0, 300)}`);
}

// Өөрийн Gmail-ээр Google Apps Script вэб апп дамжуулж илгээнэ (утас, домэйн шаардахгүй)
async function viaGmailScript(to, subject, html, text) {
  const res = await fetch(env.GMAIL_SCRIPT_URL || '', {
    method: 'POST',
    headers: { 'content-type': 'text/plain;charset=utf-8' },
    body: JSON.stringify({ secret: env.GMAIL_SCRIPT_SECRET || '', to, subject, html, text, name: FROM_NAME }),
    redirect: 'follow',
  });
  const body = (await res.text()).trim();
  if (!res.ok || body !== 'OK') throw new Error(`Gmail script ${res.status}: ${body.slice(0, 300)}`);
}

/**
 * Имэйл илгээнэ. Алдаа шидэхгүй; үр дүнг лог-д хадгална. Амжилттай бол true.
 * kind: 'otp' (нэвтрэх код — хязгаарлалтад тооцогдоно) эсвэл 'info'
 */
export async function sendEmail(to, subject, { html, text }, kind = 'info') {
  let status = 'test';
  try {
    if (EMAIL_PROVIDER === 'brevo') { await viaBrevo(to, subject, html, text); status = 'sent'; }
    else if (EMAIL_PROVIDER === 'resend') { await viaResend(to, subject, html, text); status = 'sent'; }
    else if (EMAIL_PROVIDER === 'gmail') { await viaGmailScript(to, subject, html, text); status = 'sent'; }
  } catch (e) {
    console.error('Имэйл алдаа:', e.message);
    status = 'failed';
  }
  try { await store.logEmail(to, subject, text, status, kind); } catch (e) { console.error(e); }
  return status !== 'failed';
}
