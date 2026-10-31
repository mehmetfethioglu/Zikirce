# Zikirce (`com.akarworks.zikirce`) — Google Play Console Otomatik Üretim & Yayınlama Rehberi

Bu yapı sayesinde tıpkı iOS (App Store Connect) tarafında olduğu gibi, Android güncellemeleri de hem **yerel bilgisayardan 15 saniyede** hem de **GitHub Actions üzerinden otomatik olarak** Google Play Console **Üretim (`production`)**, **Kapalı Test (`beta`)** veya **Dahili Test (`internal`)** kanalına Türkçe (`<tr-TR>`) ve İngilizce (`<en-US>`) sürüm notlarıyla birlikte doğrudan gönderilir.

---

## 1. Tek Seferlik Google Play API (`PLAY_STORE_JSON_KEY`) Kurulumu (2 Dakika)

Google Play Console API erişimi için yalnızca 1 kez Service Account JSON anahtarı oluşturulup yetkilendirilir:

1. **Google Cloud Console > IAM & Admin > Service Accounts** ([console.cloud.google.com/iam-admin/serviceaccounts](https://console.cloud.google.com/iam-admin/serviceaccounts)) sayfasına gidin:
   - **+ CREATE SERVICE ACCOUNT** butonuna tıklayın, isim olarak `play-console-publisher` yazıp **Create and Continue** -> **Done** deyin.
   - Oluşan servis hesabının sağındaki üç noktadan **Manage keys > Add Key > Create new key > JSON** seçip `.json` dosyasını indirin.
   - Aynı Google Cloud projesinde **Google Play Android Developer API** ([console.cloud.google.com/apis/library/androidpublisher.googleapis.com](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com)) sayfasına gidip **ENABLE (Etkinleştir)** butonuna basın.
2. **Google Play Console > Kullanıcılar ve İzinler (Users and permissions)** ([play.google.com/console/users-and-permissions](https://play.google.com/console/users-and-permissions)) sayfasına gidin:
   - **Yeni kullanıcıları davet et (Invite new users)** butonuna tıklayın ve az önce oluşturduğunuz servis hesabının e-posta adresini (`play-console-publisher@....iam.gserviceaccount.com`) yapıştırın.
   - **Uygulama İzinleri (App permissions)** sekmesinden **Zikirce (`com.akarworks.zikirce`)** uygulamasını seçin ve **Sürümler (Releases)** izinlerini (*Üretim sürümü yayınlama, test kanallarını yönetme*) işaretleyip **Kullanıcıyı davet et** butonuna basın.

---

## 2. Yerel Bilgisayardan 15 Saniyede Doğrudan Play Console Üretime Gönderme

İndirdiğiniz `.json` dosyasını şu konuma kaydedin (Git tarafından otomatik gizlenir, depoya yüklenmez):
```text
c:\Users\theak\source\repos\zikirce_\android\fastlane\play-store-credentials.json
```

Artık yerel bilgisayarda derlenen `build/app/outputs/bundle/release/app-release.aab` paketini ve `docs/RELEASE_NOTES_vX.Y.Z_bBUILD.md` içindeki `<tr-TR>` / `<en-US>` sürüm notlarını tek komutla doğrudan Google Play Console **Üretim (Production)** kanalına gönderebilirsiniz:

```powershell
python scripts/play_console_publish.py --track production
```
*(İsterseniz `--track internal` veya `--track beta` parametresiyle test kanallarına da gönderebilirsiniz).*

---

## 3. GitHub Actions Üzerinden Tam Otomatik Bulut Gönderimi ([`.github/workflows/playstore-release.yml`](file:///c:/Users/theak/source/repos/zikirce_/.github/workflows/playstore-release.yml))

`pubspec.yaml` sürümü yükseltilip `main` dalına push yapıldığında GitHub Actions'ın da otomatik olarak imzalı `.aab` üretip Play Console Üretime göndermesi için GitHub deponuzun **Settings > Secrets and variables > Actions > New repository secret** bölümüne şu 3 Secret'ı ekleyin:

1. **`ANDROID_KEYSTORE_BASE64`** (PowerShell'de çalıştırıp panoya kopyalayın):
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("c:\Users\theak\source\repos\zikirce_\android\app\zikirapp.keystore")) | Set-Clipboard
   ```
2. **`ANDROID_KEY_PROPERTIES`** (PowerShell'de çalıştırıp panoya kopyalayın):
   ```powershell
   Get-Content -Raw "c:\Users\theak\source\repos\zikirce_\android\key.properties" | Set-Clipboard
   ```
3. **`PLAY_STORE_JSON_KEY`**:
   - İndirdiğiniz `play-store-credentials.json` dosyasının tam metin içeriği.
