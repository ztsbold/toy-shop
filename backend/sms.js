// SMS илгээх. SMS_PROVIDER=test (анхдагч) үед бодит SMS явахгүй, зөвхөн
// админ хуудасны "Мессеж" хэсэгт бичигдэнэ. Гэрээ хийсний дараа:
//   SMS_PROVIDER=messagepro, MESSAGEPRO_KEY=..., MESSAGEPRO_FROM=<илгээгч дугаар>
// (Үйлчилгээ үзүүлэгчийн баримт бичигтэй тулгаж MESSAGEPRO_URL-ийг шалгана уу.)
import { store } from './store.js';

const env = process.env;
export const SMS_PROVIDER = (env.SMS_PROVIDER || 'test').toLowerCase();

async function sendViaMessagePro(phone, text) {
  const url = new URL(env.MESSAGEPRO_URL || 'https://api.messagepro.mn/send');
  url.searchParams.set('from', env.MESSAGEPRO_FROM || '');
  url.searchParams.set('to', phone);
  url.searchParams.set('text', text);
  const res = await fetch(url, { headers: { 'x-api-key': env.MESSAGEPRO_KEY || '' } });
  const body = await res.text();
  if (!res.ok) throw new Error(`MessagePro ${res.status}: ${body.slice(0, 200)}`);
  return body;
}

/** Алдаа шидэхгүй; үр дүнг лог-д хадгална. Амжилттай бол true. */
export async function sendSms(phone, text, kind = 'info') {
  let status = 'test';
  try {
    if (SMS_PROVIDER === 'messagepro') {
      await sendViaMessagePro(phone, text);
      status = 'sent';
    }
  } catch (e) {
    console.error('SMS алдаа:', e.message);
    status = 'failed';
  }
  try { await store.logSms(phone, text, status, kind); } catch (e) { console.error(e); }
  return status !== 'failed';
}
