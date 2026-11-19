# Тоглоомын дэлгүүр — Flutter апп + Node.js backend

**Байршуулах заавар → [DEPLOY.md](DEPLOY.md)**

```
toy_shop/
├── render.yaml                       Render-д нэг товчоор байршуулах тохиргоо
├── .github/workflows/android-apk.yml APK-г GitHub дээр автоматаар build хийнэ
├── backend/
│   ├── server.js                     API, QPay / дансаар шилжүүлэх төлбөр
│   ├── store.js                      PostgreSQL (Neon) эсвэл локал JSON
│   ├── public/admin/index.html       Удирдлагын хуудас (/admin)
│   └── data/products.json            Анхны бараа (өгөгдлийн сан хоосон үед)
└── app/                              Flutter апп (Android, iOS)
    ├── lib/
    └── platform/                     Локал build хийхэд AndroidManifest/Info.plist-д нэмэх
```

## Локал дээр туршиж ажиллуулах
```bash
cd backend && npm install
cp .env.example .env        # PAYMENT_MODE=mock, ADMIN_KEY=дурын үг
npm start                   # http://localhost:3000/admin

# өөр терминалд (Flutter суусан бол)
cd app && flutter create --platforms=android,ios --org mn.toyshop --project-name toy_shop .
flutter run                 # Android эмулятор → http://10.0.2.2:3000
```

## API
| Method | Зам | |
|---|---|---|
| GET | `/api/toys` | Барааны жагсаалт |
| POST | `/api/orders` | Захиалга + төлбөрийн мэдээлэл |
| GET | `/api/orders/:id/status` | PENDING / PAID |
| ALL | `/api/qpay/callback` | QPay мэдэгдэл |
| GET/PUT/PATCH/POST | `/api/admin/...` | `x-admin-key` header-тэй |
