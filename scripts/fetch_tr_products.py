import json
import urllib.request
import urllib.parse
import sys
import time
import os

def calculate_organic_score(sugar, sat_fat, sodium, fiber, protein, nova_group, has_e_numbers=False):
    raw_additive = 100.0
    if has_e_numbers:
        raw_additive -= 10.0
    s_additive = max(0.0, min(100.0, raw_additive))

    raw_nutri = 80.0
    if sugar > 15.0:
        raw_nutri -= 25.0
    elif sugar > 8.0:
        raw_nutri -= 12.0

    if sat_fat > 5.0:
        raw_nutri -= 20.0
    elif sat_fat > 2.0:
        raw_nutri -= 10.0

    if sodium > 0.6:
        raw_nutri -= 20.0
    elif sodium > 0.3:
        raw_nutri -= 10.0

    if fiber >= 3.0:
        raw_nutri += 15.0
    if protein >= 5.0:
        raw_nutri += 15.0

    s_nutri = max(0.0, min(100.0, raw_nutri))

    if nova_group == 1:
        s_nova = 100.0
        verdict = "İşlenmemiş / Organik (NOVA 1)"
    elif nova_group == 2:
        s_nova = 80.0
        verdict = "İşlenmiş Mutfak Malzemesi (NOVA 2)"
    elif nova_group == 3:
        s_nova = 70.0
        verdict = "İşlenmiş Gıda (NOVA 3)"
    else:
        s_nova = 20.0
        verdict = "Ultra İşlenmiş Gıda (NOVA 4)"

    final_score = int(round(0.4 * s_additive + 0.4 * s_nutri + 0.2 * s_nova))
    final_score = max(0, min(100, final_score))

    return final_score, verdict

def generate_warnings(sugar, sat_fat, sodium, nova_group):
    warnings = []
    if sugar > 15.0:
        warnings.append("Yüksek Şeker İçeriği (100g içinde >15g)")
    if sat_fat > 5.0:
        warnings.append("Yüksek Doymuş Yağ Miktarı")
    if sodium > 0.6:
        warnings.append("Yüksek Sodyum / Tuz Oranı")
    if nova_group == 4:
        warnings.append("Ultra İşlenmiş Gıda kategorisindedir")
    return warnings

def fetch_page_with_retry(url, retries=4, delay=1.5):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) OrganicScoreBot/1.0'
    }
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as res:
                return json.loads(res.read().decode('utf-8'))
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(delay * (attempt + 1))
            else:
                return None

def fetch_all_turkish_products(max_pages=200):
    products_result = []
    page = 1
    page_size = 100
    seen_barcodes = set()

    output_path = 'assets/data/top_turkiye_ai_snapshots.json'
    print(f"Open Food Facts API üzerinden TÜM Türkiye ürünleri çekiliyor...")

    while page <= max_pages:
        url = (
            f"https://world.openfoodfacts.org/api/v2/search?"
            f"countries_tags_en=turkey&"
            f"fields=code,product_name,product_name_tr,brands,ingredients_text,ingredients_text_tr,nutriments,nova_group&"
            f"page_size={page_size}&page={page}"
        )

        data = fetch_page_with_retry(url)
        if not data:
            print(f"Sayfa {page} atlandı (Sunucu yanıt vermedi).")
            page += 1
            time.sleep(1.0)
            continue

        items = data.get('products', [])
        if not items:
            print(f"Sayfa {page}'de ürün kalmadı. İndirme tamamlandı!")
            break

        added_in_page = 0
        for item in items:
            code = str(item.get('code', '')).strip()
            if not code or len(code) < 8 or code in seen_barcodes:
                continue

            name = (item.get('product_name_tr') or item.get('product_name') or '').strip()
            if not name or len(name) < 2:
                continue

            brand = (item.get('brands') or 'Yerli Üretici').split(',')[0].strip()
            if not brand:
                brand = 'Yerli Üretici'

            seen_barcodes.add(code)

            nutriments = item.get('nutriments', {}) or {}
            sugar = float(nutriments.get('sugars_100g', 0.0) or 0.0)
            sat_fat = float(nutriments.get('saturated-fat_100g', 0.0) or 0.0)
            sodium = float(nutriments.get('sodium_100g', 0.0) or 0.0)
            fiber = float(nutriments.get('fiber_100g', 0.0) or 0.0)
            protein = float(nutriments.get('proteins_100g', 0.0) or 0.0)

            raw_nova = nutriments.get('nova-group') or item.get('nova_group')
            nova_group = int(raw_nova) if raw_nova and str(raw_nova).isdigit() else 3

            ingredients = (item.get('ingredients_text_tr') or item.get('ingredients_text') or '').strip()
            has_e_numbers = 'e' in ingredients.lower()

            score, verdict = calculate_organic_score(sugar, sat_fat, sodium, fiber, protein, nova_group, has_e_numbers)
            warnings = generate_warnings(sugar, sat_fat, sodium, nova_group)

            summary = f"{brand} üreticisine ait {name}. "
            if ingredients:
                summary += f"İçindekiler: {ingredients}"
            else:
                summary += "Besin değerleri açık veritabanı ile eşleşti."

            products_result.append({
                "barcode": code,
                "product_name": name,
                "brand": brand,
                "ai_summary_json": {
                    "organic_score": score,
                    "nova_group": nova_group,
                    "verdict": verdict,
                    "summary": summary,
                    "warnings": warnings,
                    "alternatives": [
                        {
                            "name": "Doğal & Ev Yapımı Seçenek",
                            "brand": "Temiz Tarif",
                            "reason": "Katkısız ve rafine şekersiz hazırlama önerisi"
                        },
                        {
                            "name": "Torku Yerli Üretim Seçenek",
                            "brand": "Torku",
                            "reason": "Glikoz şurupsuz, katı palm yağı içermeyen yerli üretici"
                        }
                    ]
                }
            })
            added_in_page += 1

        print(f"Sayfa {page}/{max_pages} tamamlandı. Yeni: {added_in_page}, Toplam Ürün: {len(products_result)}")
        page += 1
        time.sleep(0.5)

        # Periodically flush progress every 5 pages
        if page % 5 == 0:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(products_result, f, ensure_ascii=False, indent=2)

    return products_result

if __name__ == '__main__':
    products = fetch_all_turkish_products(200)
    output_path = 'assets/data/top_turkiye_ai_snapshots.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(products, f, ensure_ascii=False, indent=2)
    print(f"TEBRİKLER! Toplam {len(products)} adet Türkiye ürün verisi '{output_path}' dosyasına kaydedildi.")
