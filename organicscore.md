# Software Requirements Specification (SRS) for OrganicScore

**Project Name:** OrganicScore (formerly FoodScore)  
**Document Version:** 0.1.0 (Production Baseline, Multi-Profile & Crowdsourced Moat)  
**Date:** July 27, 2026  
**Status:** Approved Architecture & Positioning Baseline  
**Target Platforms:** Android (Primary / Phase 1), iOS (Phase 2)  
**Package Name:** `com.organicscore.app`  
**ASO Title:** `OrganicScore: Barkod & İçindekiler Analizi`  
**Technology Stack:** Flutter (Dart), Cloudflare Workers (Edge Proxy & KV Cache), Google ML Kit (On-Device OCR & Barcode), Gemini 1.5 Flash API, Open Food Facts API, SQLite (`sqflite`/`drift`), RevenueCat (`purchases_flutter`), AdMob (`google_mobile_ads`)

---

## 1. Executive Summary & Strategic Positioning

### 1.1 Purpose
**OrganicScore** is a lightweight, ultra-fast, cross-platform mobile utility designed to empower consumers to make informed, healthy, organic, and ethical purchasing decisions—**100% offline in internet-restricted environments such as supermarket basements**. By scanning product barcodes or ingredient labels via device camera, OrganicScore instantly identifies additives (E-numbers), calculates a scientific OrganicScore (0-100), detects corporate ownership and boycott status, flags dietary profile violations across family members, and delivers AI-driven ingredient explanations.

### 1.2 Competitive Positioning & Differentiating Moat
Unlike competitor applications (e.g., `foodscore.com` / `com.foodscore`) that focus on manual photo logging of prepared plate meals, **OrganicScore** is hyper-focused on **Instant Packaged Grocery Product Verification**.

1. **Market Basement Offline Priority:** 100% functional on-device scanning without hanging, crashing, or requiring live cellular data. Top 1,000 product AI summaries pre-synced in local SQLite.
2. **Family Multi-Profile Engine:** Instant custom dietary alarms (Child vs. Adult profile: Sugar/Colorants, Gluten, Lactose, Halal, Low-Sodium, Palm Oil).
3. **Crowdsourced Ethical Verification:** Community-driven reporting for corporate ownership/boycott status and local healthy alternative product deep-links, verified via Edge Workers.
4. **Zero-Waste Cloud Proxy:** Central KV Caching ensures 0% duplicate AI spending on popular products.

---

## 2. System Architecture & Component Design

### 2.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ORGANICSCORE MOBILE APP                           │
│                                 (Flutter)                                   │
└──────────┬──────────────────────────┬──────────────────────────────┬────────┘
           │                          │                              │
           ▼                          ▼                              ▼
┌──────────────────────┐   ┌──────────────────────┐    ┌──────────────────────┐
│  ON-DEVICE ENGINES   │   │ LOCAL STORAGE LAYER  │    │ REVENUE & ANALYTICS  │
├──────────────────────┤   ├──────────────────────┤    ├──────────────────────┤
│ • ML Kit Barcode Scan│   │ • Bundled JSON Assets│    │ • RevenueCat Paywall │
│ • ML Kit Text OCR    │   │ • SQLite (sqflite)   │    │ • AdMob Rewarded/    │
│ • RAM Compressor     │   │   - Top-1000 AI Cache│    │   Banner Ads         │
│ • OrganicScore Engine│   │   - E-Numbers & GS1  │    │ • Affiliate Deep     │
│ • Offline Network    │   │   - Family Profiles  │    │   Links              │
│   Monitor            │   │   - Offline Snapshots│    │                      │
└──────────────────────┘   └──────────────────────┘    └──────────────────────┘
                                      │
                                      ▼
                   ┌──────────────────────────────────────┐
                   │    CLOUDFLARE EDGE PROXY & CACHE     │
                   ├──────────────────────────────────────┤
                   │ • Central KV Cache (Product/AI)      │
                   │ • Top-1000 AI Snapshot Generator     │
                   │ • Crowdsourced Verification Pipeline │
                   │ • Gemini 1.5 Flash Proxy Relay       │
                   │ • CDN Incremental DB Patch Server    │
                   └──────────────────┬───────────────────┘
                                      │
                                      ▼
                   ┌──────────────────────────────────────┐
                   │          EXTERNAL SERVICES           │
                   ├──────────────────────────────────────┤
                   │ • Gemini 1.5 Flash API (Cloud AI)    │
                   │ • Open Food Facts API (OFF Backup)   │
                   └──────────────────────────────────────┘
```

---

## 3. Functional Requirements (FR)

### 3.1 Barcode & Manufacturer Identification (On-Device & Hybrid)
* **FR-1.1:** The system shall use `mobile_scanner` and `google_mlkit_barcode_scanning` to detect EAN-13, EAN-8, and UPC barcodes within <100ms from live camera feed.
* **FR-1.2:** Scanned barcodes shall be resolved locally against bundled GS1 country/brand prefix tables and cached SQLite database before falling back to Open Food Facts API.
* **FR-1.3:** Scanned products shall be cross-referenced instantly against an active Boycott & Ethical Sourcing database to display status flags: `Clear (Yeşil)`, `Caution (Sarı)`, or `Flagged (Kırmızı)`.

### 3.2 Memory-Optimized OCR Ingredient Scanner
* **FR-2.1:** Users can photograph product "İçindekiler" (Ingredients) labels.
* **FR-2.2:** The camera frame shall be compressed in volatile memory (RAM) to a maximum resolution of 1080p grayscale before processing by `google_mlkit_text_recognition`.
* **FR-2.3:** Raw image buffers must be purged from memory immediately after text extraction (<50ms post-OCR). No photos are saved to local storage or transmitted over the network.
* **FR-2.4:** Extracted text shall be matched against `e_numbers.json` to highlight additives (e.g., E102, E211, E621) with risk colors (Green = Safe, Yellow = Caution, Red = Toxic/High Hazard).

### 3.3 OrganicScore 0-100 Calculation Algorithm
* **FR-3.1:** The app shall compute a deterministic, 3-component **OrganicScore (0-100)** on-device:
  $$\text{OrganicScore} = (W_{\text{Additive}} \times S_{\text{Additive}}) + (W_{\text{Nutri}} \times S_{\text{Nutri}}) + (W_{\text{NOVA}} \times S_{\text{NOVA}})$$
  * **Additive Risk Score ($W_{\text{Additive}} = 40\%$):** Starts at 100 points, decremented based on severity weights of detected E-numbers (High Risk: -20 pts, Moderate Risk: -10 pts, Low Risk: -2 pts).
  * **Nutri-Score Balance ($W_{\text{Nutri}} = 40\%$):** Penalizes high sugar, saturated fats, and sodium per 100g; rewards dietary fiber and protein.
  * **NOVA Processing Level ($W_{\text{NOVA}} = 20\%$):** Unprocessed/Organic (NOVA 1 = 100 pts), Processed (NOVA 2-3 = 70 pts), Ultra-Processed (NOVA 4 = 20 pts).
* **FR-3.2:** Calculation executes in <10ms on-device without network latency.

### 3.4 Gemini 1.5 Flash Cloud AI Engine & Offline Snapshot Engine
* **FR-4.1:** When triggered for complex chemical analysis or natural language health queries online, sanitized text is sent to the **Cloudflare Edge Proxy**.
* **FR-4.2 (KV Cache Lookup):** The Edge Proxy checks central KV storage for the exact text hash. If a cached analysis exists, it returns in <200ms with **zero Gemini API billing**.
* **FR-4.3 (Gemini Relay):** On cache miss, the Edge Proxy forwards the request to Gemini 1.5 Flash API with strict JSON schema enforcement, returns the result, and stores it in KV Cache.
* **FR-4.4 (Pre-computed Top-1000 AI Snapshot Sync):** The Edge Proxy generates a periodic compressed JSON bundle (2-3 MB) of the Top 1,000 most scanned products' AI summaries. The mobile app downloads and stores this in local SQLite `offline_ai_snapshots` during background syncs.
* **FR-4.5 (Graceful Fallback on Network Loss):** If offline (e.g., market basement) or request times out (>2.5s):
  * **Step A:** Check `offline_ai_snapshots` in local SQLite. If found, display result with badge: `⚡ Çevrimdışı Mod: Önceden Senkronize AI Analizi`.
  * **Step B:** If not found, seamlessly render deterministic OrganicScore, E-number list, and boycott status with badge: `📶 Çevrimdışı Mod: Temel Cihaz İçi Analiz Gösteriliyor`.
  * **Step C:** The UI shall never crash, hang indefinitely, or display empty/broken state.

### 3.5 Family Multi-Profile Engine (Moat Feature)
* **FR-5.1:** Users can create and switch between multiple family member health profiles (e.g. `Çocuk Profili`, `Kendi Profilim`, `Ebeveyn Profili`).
* **FR-5.2:** Profile restriction rules include: `Gluten Alerjisi`, `Laktoz İntoleransı`, `Diyabet / Düşük Şeker`, `Sentetik Renklendirici İstemiyorum`, `Hipertansiyon / Düşük Sodyum`, `Palmiye Yağı İstemiyorum`, `Vejetaryen / Vegan`, `Helal Hassasiyeti`.
* **FR-5.3:** Scanning a product violating the active family member's profile triggers an instant High-Priority Red Alert Banner over the score result card (works 100% offline).

### 3.6 Crowdsourced Ethical & Brand Verification Engine (Moat Feature)
* **FR-6.1:** Users can submit reports regarding updated brand corporate ownership, boycott status changes, or suggest healthy local alternative products directly in the app.
* **FR-6.2:** Submissions are queued in local SQLite when offline and pushed to Cloudflare Edge Proxy upon reconnection for auto-moderation and validation before dynamic CDN database distribution.

### 3.7 Affiliate Quick-Commerce Deep Links (3rd Revenue Engine)
* **FR-7.1:** If a scanned product receives an OrganicScore < 40 or carries a Boycott flag, the app displays up to 3 healthy, ethical alternative products.
* **FR-7.2:** Alternative product cards include deep-links with affiliate parameters for platforms like Trendyol, Migros Sanal Market, and Getir.

### 3.8 Social Share Cards (Viral Organic Growth)
* **FR-8.1:** Scanned product result screens feature a "Hikayede Paylaş" (Share to Story) button.
* **FR-8.2:** Generates a styled 1080x1920 image preview containing product title, OrganicScore badge, risk summary, and OrganicScore brand watermark for 1-click sharing to Instagram Stories, WhatsApp, or Telegram.

---

## 4. Non-Functional Requirements (NFR)

### 4.1 Performance & Footprint Specifications
* **NFR-1.1:** Barcode scan to result render: $\le 100\text{ ms}$.
* **NFR-1.2:** OCR image capture to text extraction: $\le 1.5\text{ s}$ on mid-tier Android hardware.
* **NFR-1.3:** Download size (APK / IPA): $\le 30\text{ MB}$.
* **NFR-1.4:** Peak RAM consumption: $\le 150\text{ MB}$ during active camera OCR operations.

### 4.2 Incremental Dynamic Sync & Offline Resilience
* **NFR-2.1:** All core dictionary lookups (E-codes, GS1 prefixes, past scan history, family profiles) operate 100% offline using local SQLite (`sqflite`/`drift`).
* **NFR-2.2:** Network loss detection (`connectivity_plus`) triggers instant UI fallback within <50ms without waiting for HTTP timeouts.

### 4.3 Security & API Protection
* **NFR-3.1:** Zero Gemini API keys reside in the client application binary.
* **NFR-3.2:** All network requests between mobile client and Edge Proxy use HMAC request signing / token validation to prevent unauthorized API scraping.

---

## 5. Monetization Strategy & Quotas

### 5.1 Hybrid Revenue Model
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ORGANICSCORE GELİR MODELİ                            │
└───────────────────┬─────────────────────────────────────┬───────────────────┘
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────────┐             ┌───────────────────────┐
        │  FREE TIER (ÜCRETSİZ) │             │  PRO TIER (ABONELİK)  │
        ├───────────────────────┤             ├───────────────────────┤
        │ • Sınırsız Barkod &   │             │ • Sınırsız Gemini AI  │
        │   E-Kodu Taraması     │             │   Analizi             │
        │ • Günlük 1 AI Analizi │             │ • $1.99/ay veya       │
        │ • Ödüllü Reklam (Ad   │             │   49.99 TL/ay         │
        │   Watch = +1 Hak)     │             │ • Reklamsız Deneyim   │
        │ • Banner & Interstitial│            │ • Sınırsız Aile Çoklu │
        │   Reklamlar           │             │   Profili & Badgeler  │
        └───────────────────────┘             └───────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────────────────────────────────┐
        │               AFFİLİATE GELİRİ (HER İKİ TİER)               │
        │ • Alternatif Sağlıklı Ürün Derin Link Satış Komisyonları    │
        └─────────────────────────────────────────────────────────────┘
```

---

## 6. Local SQLite Database Schema

```sql
-- E-Numbers Reference Table
CREATE TABLE e_numbers (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    risk_level TEXT CHECK(risk_level IN ('LOW', 'MODERATE', 'HIGH', 'TOXIC')),
    category TEXT,
    description TEXT,
    health_hazards TEXT
);

-- Boycott & Ethical Sourcing Brands Table
CREATE TABLE boycott_brands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_name TEXT UNIQUE NOT NULL,
    parent_company TEXT,
    status_flag TEXT CHECK(status_flag IN ('CLEAR', 'CAUTION', 'FLAGGED')),
    reason TEXT,
    updated_at INTEGER
);

-- Family Profiles Table (Moat Feature)
CREATE TABLE family_profiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_name TEXT NOT NULL,
    is_active INTEGER DEFAULT 0,
    restrictions_json TEXT NOT NULL
);

-- Pre-synced Top-1000 AI Snapshots for Offline Use
CREATE TABLE offline_ai_snapshots (
    barcode TEXT PRIMARY KEY,
    product_name TEXT,
    ai_summary_json TEXT NOT NULL,
    synced_at INTEGER
);

-- Cached Product Scan History
CREATE TABLE product_history (
    barcode TEXT PRIMARY KEY,
    product_name TEXT,
    brand TEXT,
    organicscore INTEGER,
    nova_group INTEGER,
    raw_ingredients TEXT,
    scanned_at INTEGER
);

-- Crowdsourced Submissions Queue (Moat Feature)
CREATE TABLE crowdsourced_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT CHECK(type IN ('OWNERSHIP_UPDATE', 'ALTERNATIVE_SUGGESTION')),
    barcode TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    status TEXT DEFAULT 'PENDING'
);
```

---

## 7. Development Roadmap

### Phase 1: Core Engine, Edge Proxy & Offline Fallback (Weeks 1-3)
* Setup Flutter architecture with `sqflite`, `mobile_scanner`, and `google_mlkit_text_recognition`.
* Implement deterministic OrganicScore algorithm and Family Multi-Profile engine.
* Deploy Cloudflare Worker Edge Proxy with KV caching and Gemini 1.5 Flash API integration.
* Build `Offline Fallback Manager` and SQLite `offline_ai_snapshots` sync.

### Phase 2: Monetization & Crowdsourced Engine (Weeks 4-5)
* Integrate RevenueCat (`purchases_flutter`) for Pro tier sub management.
* Integrate AdMob (`google_mobile_ads`) for Rewarded Video & Banner ads.
* Build Crowdsourced Ethical Verification submission pipeline and incremental sync manager.

### Phase 3: Growth & Polish (Weeks 6-7)
* Build Instagram Story / Social Share Card generator canvas.
* Implement Affiliate Deep-Link recommendation engine.
* Conduct performance testing (APK size, RAM purge verification, <100ms scan benchmark, offline basement simulation).

---

## 8. Document Approval & Metadata
* **Author:** Lead Mobile & Cloud Systems Architect  
* **Target File:** `foodscore.md` (Project re-branded to **OrganicScore**)  
* **Status:** Approved Baseline v0.1.0  
