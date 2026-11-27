# Kilerce: Tam Cloudflare (Workers + D1 + R2) + RevenueCat + AdMob SSV Kurulum Rehberi

Bu rehber, 23.933 tarif veritabanını **Cloudflare D1**'e, 755,8 MB WebP görseli **Cloudflare R2**'ye ve **3 Reklam = 24 Saat Pro + Abonelik (Haftalık/Aylık/Yıllık/Ömür Boyu)** kontrolünü **Cloudflare Worker**'a ücretsiz/düşük maliyetle canlıya almak içindir.

---

## 1. Cloudflare Hesabı ve İlk Giriş (Ücretsiz Plan)
1. [dash.cloudflare.com](https://dash.cloudflare.com) adresinden ücretsiz hesap açın (**R2** için kart doğrulaması ister; 10 GB depolama + ayda 10 milyon okuma + egress tamamen **\$0**'dır).
2. Proje kökünde `edge_worker` klasörüne girip oturum açın:
   ```powershell
   cd edge_worker
   npx wrangler login
   ```

## 2. D1, R2 ve KV Kaynaklarını Oluşturma
```powershell
npx wrangler d1 create kilerce-recipes-db
npx wrangler r2 bucket create kilerce-recipe-media
npx wrangler kv namespace create ORGANIC_SCORE_KV
```
Çıktıdaki `database_id` ve KV `id` değerlerini `edge_worker/wrangler.toml` içindeki `REPLACE_WITH_...` alanlarına yazın.

## 3. Gizli Anahtarları (Secrets) Tanımlama
Worker koduna gizli anahtar yazılmaz; sadece Cloudflare'e yüklenir:
```powershell
npx wrangler secret put HMAC_SECRET
npx wrangler secret put MEDIA_SIGNING_SECRET
npx wrangler secret put REVENUECAT_WEBHOOK_AUTH
npx wrangler secret put GEMINI_API_KEY
```

## 4. 23.933 Tarifi D1'e Aktarma
1. Yerel doğrulamalı SQL parçalarını üretin:
   ```powershell
   python scripts/cloudflare/export_d1_chunks.py --verify-local
   ```
2. Uzak D1'e şemayı ve parçaları yükleyip Worker'ı yayınlayın:
   ```powershell
   .\scripts\cloudflare\deploy_cloudflare.ps1
   ```

## 5. 23.933 Görseli (755,8 MB) R2'ye Yükleme
Cloudflare Dashboard -> **R2 -> Manage R2 API Tokens** üzerinden `Object Read & Write` yetkili bir S3 API token'ı oluşturun ve yüklemeyi başlatın:
```powershell
pip install boto3
$env:CF_ACCOUNT_ID = "<CLOUDFLARE_ACCOUNT_ID>"
$env:R2_ACCESS_KEY_ID = "<R2_ACCESS_KEY_ID>"
$env:R2_SECRET_ACCESS_KEY = "<R2_SECRET_ACCESS_KEY>"
python scripts/cloudflare/upload_r2_media.py
```
*(Kesilirse aynı komutu tekrar çalıştırmak yeterlidir; `r2_uploaded_keys.txt` üzerinden kaldığı yerden devam eder.)*

## 6. RevenueCat & AdMob SSV Bağlantısı
- **RevenueCat (Aylık \$2.500 gelire kadar \$0):**
  - App'i (`Kilerce`) Google Play ve App Store ile bağlayın.
  - Offerings/Packages oluşturun: `kilerce_pro_weekly`, `kilerce_pro_monthly`, `kilerce_pro_yearly`, `kilerce_pro_lifetime`.
  - **Project Settings -> Integrations -> Webhooks** bölümüne:
    - **Webhook URL:** `https://kilerce-edge-api.<alt-alan-adiniz>.workers.dev/api/webhooks/revenuecat`
    - **Authorization header:** `Bearer <REVENUECAT_WEBHOOK_AUTH>`
- **AdMob SSV (3 Ödüllü Reklam = 24 Saat Pro):**
  - AdMob Console -> **Ad Units -> Rewarded Ad -> Server-side verification (SSV)**:
    - **Callback URL:** `https://kilerce-edge-api.<alt-alan-adiniz>.workers.dev/api/webhooks/admob-ssv`
    - Mobil uygulama reklamı gösterirken `ServerSideVerificationOptions(userId: appUserId)` göndermelidir.
    - Worker, Google'ın ECDSA P-256 imzasını doğrular; her doğrulanmış reklamda `ad_progress` `1/3 -> 2/3 -> 3/3` olur ve 3. reklamda `+24 saat Pro` açılır (`REWARD_COOLDOWN_HOURS = 4` ile suistimal engellenir).
