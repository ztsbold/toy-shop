# Үнэгүй байршуулах заавар

Бүгд үнэгүй, кредит карт шаардахгүй:

| Хэсэг | Үйлчилгээ | Үнэгүй хязгаар |
|---|---|---|
| Код хадгалах, APK build | GitHub + GitHub Actions | хувийн репо ч болно |
| Backend сервер | Render (Free web service) | 15 мин хандалтгүй бол унтана, сэрэхэд ~1 мин |
| Өгөгдлийн сан | Neon Postgres (Free) | 1 GB, хугацаагүй |
| Сервер унтуулахгүй байх | cron-job.org | үнэгүй |

> Render-ийн өөрийн үнэгүй Postgres 30 хоногийн дараа устдаг тул Neon ашиглана.
> Render сервер дээр файлд бичсэн өгөгдөл restart бүрт арилдаг тул захиалгыг заавал өгөгдлийн санд хадгална (код үүнийг хийдэг).

---

## 1. GitHub-д код байршуулах (10 мин)
1. github.com дээр бүртгүүлж **New repository** → нэр: `toy-shop` → Private → Create.
2. **Add file → Upload files** → zip-ээс задалсан `toy_shop` хавтасны **доторх** бүх зүйлийг чирж оруулна → Commit.
3. `.github` хавтас нуугдмал тул орохгүй байж магадгүй. Тэгвэл **Add file → Create new file** → нэр хэсэгт
   `.github/workflows/android-apk.yml` гэж бичээд тухайн файлын агуулгыг хуулж буулгана.

## 2. Neon өгөгдлийн сан (5 мин)
1. neon.com → Sign up (GitHub-аар нэвтэрч болно).
2. **Create project** → Region: **AWS Asia Pacific (Singapore)**.
3. **Connect** товч → `postgresql://...` гэж эхэлсэн холболтын мөрийг хуулж авна.
   Хүснэгтүүд болон жишээ бараа сервер анх асахад автоматаар үүснэ.

## 3. Render сервер (10 мин)
1. render.com → GitHub-аар нэвтэрнэ.
2. **New + → Blueprint** → `toy-shop` репог сонгоно (`render.yaml`-ийг автоматаар уншина).
3. Асуух утгуудыг бөглөнө:
   - `DATABASE_URL` — Neon-оос хуулсан мөр
   - `BANK_NAME`, `BANK_ACCOUNT`, `BANK_ACCOUNT_HOLDER` — төлбөр хүлээн авах данс
4. **Apply** → 3–5 минутын дараа `https://toy-shop-api.onrender.com` маягийн хаяг гарна.
5. Шалгах: `https://<таны-хаяг>/health` → `{"ok":true,"paymentMode":"manual","storage":"postgres"}`
6. Админ түлхүүр: Render → toy-shop-api → **Environment** → `ADMIN_KEY` утгыг харна.
7. Удирдлага: `https://<таны-хаяг>/admin` → түлхүүрээ оруулна. Эндээс бараа нэмэх, үнэ/үлдэгдэл засах, захиалга харах, төлбөр батлах, хүргэлтийн төлөв солих боломжтой.

## 4. Серверийг унтуулахгүй байлгах (3 мин)
cron-job.org → бүртгүүлэх → **Create cronjob** → URL: `https://<таны-хаяг>/health` → **Every 10 minutes** → Save.
(Нэг сервер 24/7 ажиллахад ~720 цаг, Render-ийн сарын 750 цагийн хязгаарт багтана.)

## 5. Android апп (APK) гаргах (15 мин)
1. GitHub репо → **Settings → Secrets and variables → Actions → Variables** таб → **New repository variable**
   - Name: `API_URL`  Value: `https://<таны-хаяг>` (төгсгөлд `/` бүү тавь)
2. **Actions** таб → **Build Android APK** → **Run workflow**. ~8 минут.
3. Дууссаны дараа доор **Artifacts** хэсэгт:
   - `toy-shop-apk` → татаж задлаад `app-release.apk`
   - `keystore` (зөвхөн анх удаа) → доторх текстийг бүтнээр нь хуулж
     **Settings → Secrets → Actions → New repository secret**, нэр: `ANDROID_DEBUG_KEYSTORE_B64`.
     Ингэснээр дараагийн хувилбарууд одоогийн суулгасан апп дээр шууд шинэчлэгдэнэ.
4. APK-г Google Drive-д хийж холбоосоор хэрэглэгчдэд тараана. Утсан дээр
   "Тодорхойгүй эх сурвалжаас суулгах"-ыг зөвшөөрч суулгана.

Аппын кодыг GitHub дээр өөрчлөх бүрт APK автоматаар дахин build хийгдэнэ.

---

## Төлбөрийн горим
| `PAYMENT_MODE` | Ажиллах байдал |
|---|---|
| `manual` (анхдагч) | Апп дансны дугаар, дүн, гүйлгээний утга (захиалгын дугаар) харуулна. Та данс руу мөнгө орсныг шалгаад `/admin`-аас **Төлбөр орсон гэж батлах** дарна. Гэрээгүйгээр шууд ажиллана. |
| `qpay` | QPay гэрээ байгуулсны дараа. Render → Environment-д `PAYMENT_MODE=qpay`, `QPAY_BASE_URL=https://merchant.qpay.mn`, `QPAY_USERNAME`, `QPAY_PASSWORD`, `QPAY_INVOICE_CODE` нэмнэ. Төлбөр автоматаар баталгаажна. |
| `mock` | Зөвхөн туршилт — мөнгө авахгүйгээр "төлөгдсөн" болно. Бодит хэрэглэгчид бүү ашигла. |

## Үнэгүй хувилбарын сул тал
- Сервер унтсан үед апп анх нээхэд ~1 минут ачаална (cron-job.org үүнийг ихэнхдээ шийднэ).
- Play Store-д гаргахад Google Play Developer бүртгэл (нэг удаа $25) хэрэгтэй.
- **iOS үнэгүй гаргах боломжгүй**: Apple Developer Program жилд $99, мөн Mac эсвэл Codemagic зэрэг cloud build хэрэгтэй. Код нь iOS-д бэлэн.
- Захиалга ихсээд Render-ийн хязгаарт хүрвэл Starter ($7/сар) руу шилжихэд код өөрчлөх шаардлагагүй.
