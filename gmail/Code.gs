// F5 Toys — имэйл илгээх Google Apps Script
// 1) Доорх SECRET-ийг өөрийн урт нууц үгээр солино (Render дээрх GMAIL_SCRIPT_SECRET-тэй ижил)
// 2) Deploy → New deployment → Web app → Execute as: Me, Who has access: Anyone
const SECRET = 'ЭНД-УРТ-НУУЦ-ҮГ';

function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);
    if (d.secret !== SECRET) return out('FORBIDDEN');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(d.to || '')) return out('BAD_EMAIL');
    MailApp.sendEmail({
      to: d.to,
      subject: String(d.subject || '').slice(0, 200),
      body: String(d.text || ''),
      htmlBody: String(d.html || ''),
      name: String(d.name || 'F5 Toys'),
    });
    return out('OK');
  } catch (err) {
    return out('ERROR: ' + err);
  }
}

// Үлдсэн өдрийн хязгаарыг шалгах: Run → testQuota
function testQuota() {
  Logger.log('Өнөөдөр илгээж болох үлдэгдэл: ' + MailApp.getRemainingDailyQuota());
}

function out(t) {
  return ContentService.createTextOutput(t).setMimeType(ContentService.MimeType.TEXT);
}
