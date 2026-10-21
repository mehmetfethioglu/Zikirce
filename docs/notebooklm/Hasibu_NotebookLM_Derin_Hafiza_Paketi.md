# Hasibu NotebookLM Plus Derin Hafıza & Mimari Atlası

# Hasibu â€” SÄ±cak Proje HafÄ±zasÄ± (`.agent/PROJECT_MEMORY.md`)
> **Son GÃ¼ncelleme:** 2026-10-21 | **Mimari:** Antigravity 2.0 (6-Sensei v3.0) | **Durum YÃ¶netimi:** Riverpod 2.6 (`StateNotifierProvider`)

## 1. Riverpod Provider & Notifier Ä°ndeksi (Tahmin Etme, Buradan Oku!)
- **`hasibuDatabaseProvider`** (`Provider<HasibuDatabase>`): [pdks_providers.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/presentation/providers/pdks_providers.dart#L13-L17) â€” SQLite (`sqlite3`) veritabanÄ± tekil Ã¶rneÄŸi.
- **`googleDriveSyncServiceProvider`** (`Provider<GoogleDriveSyncService>`): [pdks_providers.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/presentation/providers/pdks_providers.dart#L19-L22) â€” Gmail & Google Drive JSON anlÄ±k gÃ¶rÃ¼ntÃ¼ senkronizasyonu.
- **`pdksDashboardProvider`** (`StateNotifierProvider<PdksDashboardNotifier, PdksDashboardState>`): [pdks_providers.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/presentation/providers/pdks_providers.dart#L1463-L1468) â€” Ana PDKS, Ä°K, Ã–zlÃ¼k, Terminal, Ä°zin ve Talep durumu (`dailyStatuses`, `allLeaveRecords`, `allPersonnelDocuments`, `allHrRequests`, `selectedAnomalyFilter`, `pendingHrRequestsCount`, `statutoryLeaveMismatchCount`).
- **`mobileUiProvider`** (`StateNotifierProvider<MobileUiNotifier, MobileUiState>`): [mobil_arayuz_iyilestirme_provider.dart](file:///c:/Users/theak/source/repos/hasibu/lib/providers/mobil_arayuz_iyilestirme_provider.dart) â€” Mobil gÃ¶rÃ¼nÃ¼m yoÄŸunluÄŸu (`comfortable`/`compact`), hÄ±zlÄ± filtre ve arama durumu.

## 2. SQLite TablolarÄ± (`HasibuDatabase`)
- Dosya: [hasibu_database.dart](file:///c:/Users/theak/source/repos/hasibu/lib/core/database/hasibu_database.dart)
- Tablolar:
  1. `company_settings`: Åirket adÄ±, logo yolu (`logoPath`), otomatik tarama (`autoPollEnabled`, `autoPollMinutes`), yÃ¶netici temasÄ± (`adminThemeMode`).
  2. `branches`: Åubeler (`id`, `name`, `terminalIp`, `terminalPort`, `latitude`, `longitude`, `geofenceRadiusMeters`, `qrSecret`).
  3. `shifts`: Vardiya planlarÄ± (`id`, `name`, `startTime`, `endTime`, `toleranceMinutes`, `plannedDurationMinutes`).
  4. `departments`: 27 Ã¼retim/ÅŸube bÃ¶lÃ¼mÃ¼ (`id`, `name`, `defaultShiftId`).
  5. `employees`: Personel sicil/kart (`id`, `cardNo`, `fullName`, `departmentId`, `branchId`, `shiftId`, `hireDate`, `annualLeaveEntitlement`, `annualLeaveUsed`, `password`, `allowedModules`, `photoPath`, `themeMode`).
  6. `attendance_logs`: GiriÅŸ/Ã§Ä±kÄ±ÅŸ hareketleri (`id`, `cardNo`, `branchId`, `deviceNo`, `timestamp`, `isCheckIn`, `source`, `verifyMethod`, `latitude`, `longitude`, `note`).
  7. `leave_records`: Ä°zin ve rapor kayÄ±tlarÄ± (`id`, `employeeId`, `date`, `leaveType`, `note`).
  8. `personnel_documents`: Dijital Ã¶zlÃ¼k dosyasÄ± evraklarÄ± (`id`, `employeeId`, `category`, `title`, `filePath`, `uploadDate`, `expiryDate`, `notes`).
  9. `hr_requests`: Ã‡ift yÃ¶nlÃ¼ Ä°K talepleri (`id`, `employeeId`, `employeeCardNo`, `employeeName`, `type`, `status`, `targetDate`, `endDate`, `requestedTime`, `isCheckInCorrection`, `leaveType`, `overtimeMinutes`, `advanceAmount`, `reason`, `reviewerNote`, `createdAt`).

## 3. DonanÄ±m & Ä°ÅŸ MantÄ±ÄŸÄ± Sabitleri (`cezeri-piri`)
- **Tenfei D35 YÃ¼z TanÄ±ma Terminali:** [tenfei_zk_client.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/data/tenfei_zk_client.dart) â€” Merkez IP: `192.168.9.150`, Port: `4370` (ZKTeco Binary TCP).
  - `CMD_CONNECT` (`1000`) -> `CMD_ACK_UNAUTH` (`2005`) dÃ¶nerse `makeCommKey(0, sessionId)` ile `CMD_AUTH` (`1102`) gÃ¶nderilir.
  - `CMD_ATTLOG_RRQ` (`13`) yanÄ±tÄ±nda 4-bayt iÃ§ tablo uzunluk baÅŸlÄ±ÄŸÄ± + 40-baytlÄ±k binary kayÄ±tlar gelir; aynÄ± gÃ¼n 2. okuma Ã§Ä±kÄ±ÅŸ (`isCheckIn: false`) olarak sÄ±nÄ±flandÄ±rÄ±lÄ±r.
- **Anti-Passback Debounce:** [`_evaluateDayLogs`](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/presentation/providers/pdks_providers.dart#L789-L896) iÃ§inde ilk giriÅŸten sonraki **15 dakika** iÃ§inde yapÄ±lan mÃ¼kerrer okumalar filtrelenir (`duplicateScansFiltered`).
- **4857 SayÄ±lÄ± Ä°ÅŸ Kanunu Md. 53 KÄ±dem Ä°zin HesabÄ±:** [`Employee.statutoryAnnualLeaveEntitlement`](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/domain/pdks_models.dart#L368-L379) â€” 1â€“5 yÄ±l: `14 gÃ¼n`, 5â€“15 yÄ±l: `20 gÃ¼n`, 15+ yÄ±l: `26 gÃ¼n`.

## 4. Dosya HaritasÄ±
- **Domain Modelleri:** [pdks_models.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/domain/pdks_models.dart)
- **BaÅŸlangÄ±Ã§ Verileri (Seed):** [workplace_seed_data.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/data/workplace_seed_data.dart) (Ã–rnek siciller: `00064` Mehmet Sinan Cenan, `01406` Abdullah YÄ±ldÄ±z, `01110` MÃ¼slÃ¼m Ã–ncel, `00046` Suliman Alhussin, `00058` Serkan AkbaÅŸ)
- **Ana Kabuk & PDKS/Ä°K EkranlarÄ±:** [hasibu_shell_screen.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/presentation/screens/hasibu_shell_screen.dart) (6 PDKS sekmesi; mobil `NavigationBar` `tabs.take(5)` ile sÄ±nÄ±rlÄ±dÄ±r)
- **Ayarlar & Ä°K Talep/Uyum RadarÄ±:** [hasibu_settings_view.dart](file:///c:/Users/theak/source/repos/hasibu/lib/features/pdks/presentation/screens/hasibu_settings_view.dart) (`HrRequestsAndComplianceView`)
- **Mobil Saha EkranÄ±:** [mobil_arayuz_iyilestirme_screen.dart](file:///c:/Users/theak/source/repos/hasibu/lib/screens/mobil_arayuz_iyilestirme_screen.dart)
- **Test Paketi:** [widget_test.dart](file:///c:/Users/theak/source/repos/hasibu/test/widget_test.dart) (10 deterministik test)

---

# ğŸ¦… Hezarfen Ahmed Ã‡elebi â€” Hasibu PDKS & Ä°K Piyasa Analizi ve Mavi Okyanus Stratejisi

> [!IMPORTANT]
> **SÄ±fÄ±r Dalkavukluk & Kesin Objektiflik Doktrini:** Bu rapor, TÃ¼rkiye'deki gerÃ§ek PDKS ve Ä°K rakiplerinin (Perkotek, Meyer, Kolay Ä°K, Ä°denfit, ZKTeco BioTime) saha gerÃ§eklerini, Åikayetvar ve uygulama maÄŸazalarÄ±ndaki 1-yÄ±ldÄ±z kullanÄ±cÄ± acÄ± noktalarÄ±nÄ± ve Hasibu'nun mevcut `PDKS & Ä°K` modÃ¼lÃ¼ndeki eksiklikleri tÃ¼m Ã§Ä±plaklÄ±ÄŸÄ±yla ortaya koymak Ã¼zere hazÄ±rlanmÄ±ÅŸtÄ±r.

---

## 1. TÃ¼rkiye PDKS & Ä°K PazarÄ±: Rakip Analizi ve 1-YÄ±ldÄ±z KullanÄ±cÄ± AcÄ± NoktalarÄ± (`Hezarfen-Radar`)

| Rakip Platform | Pazar Konumu | GÃ¼Ã§lÃ¼ YÃ¶nleri | 1-YÄ±ldÄ±z Åikayetler & Kronik Saha SorunlarÄ± (Åikayetvar / MaÄŸaza YorumlarÄ±) |
| :--- | :--- | :--- | :--- |
| **Perkotek PDKS** | Geleneksel DonanÄ±m + MasaÃ¼stÃ¼ PDKS | ZKTeco/Tenfei cihaz yaygÄ±nlÄ±ÄŸÄ±, fabrika ve turnike entegrasyonu | â€¢ **MÃ¼kerrer Okuma Kaosu:** Personel cihaz Ã¶nÃ¼nde 1-2 dk iÃ§inde 2 kez yÃ¼z okutunca 2. okumayÄ± "Ã‡Ä±kÄ±ÅŸ" sayÄ±p akÅŸamki gerÃ§ek Ã§Ä±kÄ±ÅŸÄ± yutmasÄ±.<br>â€¢ **Destek & Lisans Maliyeti:** Basit puantaj desteÄŸi veya format deÄŸiÅŸikliÄŸi iÃ§in yÃ¼ksek servis Ã¼creti talep edilmesi.<br>â€¢ **Hantal ArayÃ¼z:** 2000'lerden kalma karmaÅŸÄ±k masaÃ¼stÃ¼ tablolarÄ±, tek ekranda eksik Ã§Ä±kÄ±ÅŸ/anomali gÃ¶rÃ¼lememesi. |
| **Meyer (Angel / Web PDKS)** | Kurumsal Holding & Fabrika PDKS | GeliÅŸmiÅŸ vardiya, gece mesaisi ve hakediÅŸ kurallarÄ± | â€¢ **YÃ¼ksek KarmaÅŸÄ±klÄ±k (UX Muda):** Ä°K uzmanÄ±nÄ±n "BugÃ¼n kim erken Ã§Ä±ktÄ±, kim Ã§Ä±kÄ±ÅŸ basmayÄ± unuttu?" sorusuna cevap bulmak iÃ§in 5 farklÄ± rapor ekranÄ± gezmesi.<br>â€¢ **ERP/Excel AktarÄ±m SÃ¼rtÃ¼nmesi:** Standart muhasebe/bordro Ã§Ä±ktÄ±larÄ± iÃ§in ek entegrasyon maliyeti. |
| **Kolay Ä°K** | Bulut (SaaS) Ä°K & Personel Ã–z-Servis | Modern arayÃ¼z, personel izin/fazla mesai/avans talep-onay akÄ±ÅŸÄ±, 4857 kÄ±dem hesabÄ± | â€¢ **ZayÄ±f DonanÄ±m KÃ¶prÃ¼sÃ¼:** Yerel aÄŸdaki yÃ¼z tanÄ±ma terminaliyle (TCP 4370) doÄŸrudan sÄ±fÄ±r-ek-donanÄ±m konuÅŸamamasÄ±.<br>â€¢ **Ä°nternet BaÄŸÄ±mlÄ±lÄ±ÄŸÄ±:** Bulut Ã§Ã¶ktÃ¼ÄŸÃ¼nde veya fabrika interneti kesildiÄŸinde yerel veriye eriÅŸilememesi. |
| **Ä°denfit** | Bulut Ä°K & Mobil GPS/QR PDKS | Saha personeli takibi, gÃ¶rev ve vardiya planlama | â€¢ **Mobil GPS & Batarya SorunlarÄ±:** Telefon gÃ¼Ã§ tasarrufu modlarÄ±nda konum sapmasÄ±.<br>â€¢ **KiÅŸi BaÅŸÄ± AylÄ±k SaaS Maliyeti:** 50+ personelli Ã¼retim iÅŸletmelerinde her ay artan dÃ¶viz/TL abonelik yÃ¼kÃ¼. |
| **ZKTeco BioTime 8.0** | Global Biyometrik Cihaz YazÄ±lÄ±mÄ± | DoÄŸrudan TCP/Push cihaz yÃ¶netimi ve gerÃ§ek zamanlÄ± log Ã§ekimi | â€¢ **TÃ¼rkiye Ä°ÅŸ Hukuku (4857) UyumsuzluÄŸu:** KÄ±deme gÃ¶re yÄ±llÄ±k izin hakediÅŸi, resmi Ã¶zlÃ¼k dosyasÄ± takibi ve TÃ¼rkÃ§e yalÄ±n Ã¶n muhasebe puantajÄ±nÄ±n bulunmamasÄ±. |

---

## 2. AcÄ±masÄ±z Ã–z-EleÅŸtiri: Hasibu PDKS & Ä°K ModÃ¼lÃ¼mÃ¼zÃ¼n Mevcut Eksikleri (`Hezarfen-Sentez`)

YÃ¼z okuma terminalinden (`Tenfei D35 - TCP 4370`) veri Ã§ekme ve Google Drive senkronizasyon altyapÄ±mÄ±z rakiplerden Ã§ok daha Ã§evik olsa da, mevcut `HasibuModule.pdksHr` katmanÄ±mÄ±zda ÅŸu **5 kritik eksiklik** bulunmaktaydÄ±:

1. **Sadece "GiriÅŸ" OdaklÄ± Eksik Mesai Motoru:**
   - Mevcut yapÄ± yalnÄ±zca `firstCheckIn` ve `lateMinutes` (geÃ§ kalma) hesaplÄ±yordu.
   - Personelin **Net Ã‡alÄ±ÅŸma SÃ¼resi (`workedMinutes`)**, **Fazla Mesaisi (`overtimeMinutes`)**, **Erken Ã‡Ä±kÄ±ÅŸÄ± (`earlyLeaveMinutes`)** ve en Ã¶nemlisi **Ã‡Ä±kÄ±ÅŸ BasmayÄ± Unutma (`hasMissingCheckOut` - Eksik Hareket Anomalisi)** durumu hesaplanmÄ±yordu.
2. **MÃ¼kerrer Okuma KalkanÄ± (Anti-Passback / Debounce) YokluÄŸu:**
   - Cihaz Ã¶nÃ¼nde emin olamayÄ±p 2 dakika arayla iki kez yÃ¼z okutan personelin ikinci okumasÄ± doÄŸrudan "Ã‡Ä±kÄ±ÅŸ" sanÄ±lÄ±p personeli 2 dakika Ã§alÄ±ÅŸmÄ±ÅŸ gÃ¶sterme riski taÅŸÄ±yordu.
3. **Personel Ã–z-Servis Ä°le Ä°K ArasÄ±nda Kopukluk (Talep & Onay AkÄ±ÅŸÄ± Yok):**
   - `Personel PortalÄ±` yalnÄ±zca bilgi gÃ¶steriyordu; personel izin, unutulan giriÅŸ/Ã§Ä±kÄ±ÅŸ dÃ¼zeltmesi, fazla mesai onayÄ± veya avans talebi oluÅŸturamÄ±yor, Ä°K tek tÄ±kla onaylayÄ±p puantaja otomatik iÅŸleyemiyordu.
4. **4857 SayÄ±lÄ± Ä°ÅŸ Kanunu KÄ±dem & Ä°zin Otomasyonu EksikliÄŸi:**
   - Personelin iÅŸe giriÅŸ tarihinden (`hireDate`) kÄ±dem yÄ±lÄ± ve 4857 Md. 53 yasal yÄ±llÄ±k izin hakediÅŸi (1â€“5 yÄ±l: 14 gÃ¼n, 5â€“15 yÄ±l: 20 gÃ¼n, 15+ yÄ±l: 26 gÃ¼n) otomatik denetlenmiyordu.
5. **Anomali Filtreleri ve Tek TÄ±kla Resmi Excel/CSV Puantaj Ã‡Ä±ktÄ±sÄ± YokluÄŸu:**
   - CanlÄ± PDKS ekranÄ±nda "Sadece Fazla Mesai Yapanlar", "Sadece Eksik Ã‡Ä±kÄ±ÅŸÄ± Olanlar", "Eksik Ã–zlÃ¼k EvrakÄ± Olanlar" filtreleri ve tek tÄ±kla muhasebeye gÃ¶nderilecek UTF-8 CSV/Excel puantaj dÄ±ÅŸa aktarÄ±mÄ± yoktu.

---

## 3. Mavi Okyanus (Blue Ocean) Mimari DÃ¶nÃ¼ÅŸÃ¼m PlanÄ± (`Kanuni's Edict`)

```mermaid
flowchart LR
    T["Tenfei D35 (TCP 4370)\n& Mobil QR/GPS"] --> D["Anti-Passback KalkanÄ±\n(15 dk MÃ¼kerrer Filtresi)"]
    D --> E["AkÄ±llÄ± Mesai & Anomali Motoru\n(Net SÃ¼re, +Mesai, Erken Ã‡Ä±kÄ±ÅŸ, Eksik Ã‡Ä±kÄ±ÅŸ)"]
    P["Personel PortalÄ±\n(Ä°zin / Mesai / Hareket / Avans Talebi)"] --> H["Ä°K Talep & Uyum RadarÄ±\n(Tek TÄ±kla Onay -> Otomatik Puantaj)"]
    E --> C["CanlÄ± PDKS Kokpiti\n(Anomali Ã‡ipleri & 1-TÄ±k Ã‡Ä±kÄ±ÅŸ Tamamlama)"]
    H --> C
    C --> X["Resmi Excel / CSV\nPuantaj DÄ±ÅŸa AktarÄ±m"]
```

### Devreye AlÄ±nan 5 RekabetÃ§i ÃœstÃ¼nlÃ¼k:
1. **15 Dakika Anti-Passback (MÃ¼kerrer Okuma) KalkanÄ± & Tam Mesai AnalitiÄŸi:** ArdÄ±ÅŸÄ±k mÃ¼kerrer okumalarÄ± sÃ¼zer; gece vardiyalarÄ± dahil net Ã§alÄ±ÅŸma, fazla mesai, erken Ã§Ä±kÄ±ÅŸ ve eksik Ã§Ä±kÄ±ÅŸ anomalisini anlÄ±k hesaplar.
2. **CanlÄ± PDKS Ãœzerinde Anomali Filtreleri & 1-TÄ±kla Eksik Ã‡Ä±kÄ±ÅŸ Tamamlama:** YÃ¶neticinin eksik Ã§Ä±kÄ±ÅŸ basan personeli tek tÄ±kla vardiya bitiÅŸ saatine gÃ¶re tamamlamasÄ±nÄ± saÄŸlar.
3. **Ã‡ift YÃ¶nlÃ¼ Ä°K Talep & Onay Merkezi (`HrRequest`):** Personel PortalÄ±'ndan aÃ§Ä±lan Ä°zin, Fazla Mesai, Unutulan GiriÅŸ/Ã‡Ä±kÄ±ÅŸ ve Avans talepleri SQLite + Google Drive ile senkronize edilir; Ä°K onayladÄ±ÄŸÄ± anda puantaja veya izin tablosuna otomatik iÅŸlenir.
4. **4857 Ä°ÅŸ Kanunu KÄ±dem & Ã–zlÃ¼k Uyum RadarÄ±:** KÄ±dem yÄ±lÄ±na gÃ¶re yasal yÄ±llÄ±k izin hakediÅŸlerini hesaplar, tek tÄ±kla eÅŸitler ve eksik zorunlu Ã¶zlÃ¼k evraklarÄ±nÄ± raporlar.
5. **Tek TÄ±kla Resmi Puantaj Cetveli (CSV / Excel) DÄ±ÅŸa AktarÄ±mÄ±:** Ek lisans Ã¼creti olmadan gÃ¼nlÃ¼k/aylÄ±k puantaj tablosunu panoya veya dosyaya aktarÄ±r.

