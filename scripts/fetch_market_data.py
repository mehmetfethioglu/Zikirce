import requests
import json
import os
import time

def calculate_organic_score_and_nova(ingredients_text, nova_group_input):
    """Calculates OrganicScore (0-100) and NOVA group based on ingredients and NOVA input."""
    score = 85
    nova = nova_group_input or 3
    warnings = []
    
    if not ingredients_text:
        return score, nova, "Orta Seviye İşlenmiş (NOVA 3)", warnings

    text_lower = ingredients_text.lower()
    
    # Ultra-processed indicators
    ultra_processed_terms = [
        "glikoz şurubu", "fruktoz şurubu", "palm yağı", "emülgatör", "mısır şurubu", 
        "aroma verici", "koruyucu", "renklendirici", "hidrojenize", "monosodyum glutamat",
        "e621", "e250", "e251", "e951", "tatlandırıcı", "aspartam"
    ]

    found_terms = [term for term in ultra_processed_terms if term in text_lower]
    
    if len(found_terms) >= 3 or "glikoz şurubu" in text_lower or "palm yağı" in text_lower:
        nova = 4
        score -= (len(found_terms) * 8 + 15)
        for term in found_terms:
            warnings.append(f"İçeriğinde '{term.title()}' bulundu.")
    elif len(found_terms) >= 1:
        nova = 3
        score -= (len(found_terms) * 6)
        for term in found_terms:
            warnings.append(f"Katkı maddesi: '{term.title()}' içermektedir.")
    else:
        if nova_group_input == 1 or "doğal" in text_lower or "organik" in text_lower or len(ingredients_text) < 40:
            nova = 1
            score = min(100, score + 12)

    score = max(15, min(100, score))
    
    verdict_labels = {
        1: "İşlenmemiş / Organik (NOVA 1)",
        2: "Mutfak Malzemesi (NOVA 2)",
        3: "İşlenmiş Gıda (NOVA 3)",
        4: "Aşırı İşlenmiş Gıda (NOVA 4)"
    }
    verdict = verdict_labels.get(nova, "İşlenmiş Gıda (NOVA 3)")
    
    return score, nova, verdict, warnings

def fetch_real_turkish_products():
    print("Fetching real Turkish market product data...")
    
    url = "https://tr.openfoodfacts.org/cgi/search.pl"
    params = {
        "action": "process",
        "tagtype_0": "countries",
        "tag_contains_0": "contains",
        "tag_0": "turkey",
        "page_size": 50,
        "json": 1
    }
    
    headers = {
        "User-Agent": "OrganicScoreApp - Android/iOS - Version 1.0"
    }

    try:
        response = requests.get(url, params=params, headers=headers, timeout=15)
        if response.status_code == 200:
            data = response.json()
            products = data.get("products", [])
            print(f"Found {len(products)} products from OpenFoodFacts Turkey.")
            return products
    except Exception as e:
        print(f"Error fetching from OpenFoodFacts: {e}")
    
    return []

def main():
    off_products = fetch_real_turkish_products()
    
    output_dataset = []
    seen_barcodes = set()

    for p in off_products:
        barcode = p.get("code") or p.get("_id")
        name = p.get("product_name_tr") or p.get("product_name") or p.get("product_name_en")
        brand = p.get("brands") or "Bilinmeyen Marka"
        ingredients = p.get("ingredients_text_tr") or p.get("ingredients_text") or ""
        nova_input = p.get("nova_group")

        if not barcode or not name or len(barcode) < 8 or barcode in seen_barcodes:
            continue
            
        seen_barcodes.add(barcode)
        brand = brand.split(",")[0].strip()
        
        score, nova, verdict, warnings = calculate_organic_score_and_nova(ingredients, nova_input)
        
        summary = f"{brand} üreticisine ait {name}."
        if ingredients:
            summary += f" İçindekiler: {ingredients[:150]}..."

        item = {
            "barcode": str(barcode),
            "product_name": name.strip(),
            "brand": brand,
            "ai_summary_json": {
                "organic_score": score,
                "nova_group": nova,
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
                        "name": "Torku / Yerli Temiz Seçenek",
                        "brand": "Torku",
                        "reason": "Glikoz şurupsuz yerli üretici tercihi"
                    }
                ]
            }
        }
        output_dataset.append(item)

    curated_items = [
        {
            "barcode": "8690504008782",
            "product_name": "Ülker Çikolatalı Gofret 36g",
            "brand": "Ülker",
            "ai_summary_json": {
                "organic_score": 38,
                "nova_group": 4,
                "verdict": "Aşırı İşlenmiş Gıda (NOVA 4)",
                "summary": "Ülker üreticisine ait Ülker Çikolatalı Gofret. İçindekiler: Şeker, buğday unu, bitkisel yağ (palm), fındık ezmesi (%9,5), tam yağlı süt tozu, kakao yağı, kakao kitlesi, emülgatör (soya lesitini), kabartıcılar.",
                "warnings": [
                    "İçeriğinde 'Palm Yağı' bulundu.",
                    "Katkı maddesi: 'Emülgatör (Soya Lesitini)' içermektedir.",
                    "Yüksek oranda rafine şeker içerir."
                ],
                "alternatives": [
                    {
                        "name": "Züber Fındıklı Meyve Barı",
                        "brand": "Züber",
                        "reason": "Şekersiz, %100 doğal meyve ve kuruyemiş içeriği"
                    },
                    {
                        "name": "Torku Banada Fındık Kremalı Gofret",
                        "brand": "Torku",
                        "reason": "Pancardan üretilen doğal şeker kullanımı"
                    }
                ]
            }
        },
        {
            "barcode": "8690526069500",
            "product_name": "Eti Lifalif Yulaf Ezmesi 500g",
            "brand": "Eti",
            "ai_summary_json": {
                "organic_score": 96,
                "nova_group": 1,
                "verdict": "İşlenmemiş / Organik (NOVA 1)",
                "summary": "Eti üreticisine ait Lifalif Yulaf Ezmesi. İçindekiler: %100 Yulaf ezmesi. Tam tahıl kaynağı ve yüksek lif içerir.",
                "warnings": [],
                "alternatives": [
                    {
                        "name": "Organik Yulaf Ezmesi",
                        "brand": "Raya Organik",
                        "reason": "Sertifikalı organik tarım ürünü"
                    }
                ]
            }
        },
        {
            "barcode": "8691381000486",
            "product_name": "Beypazarı Doğal Maden Suyu 200ml",
            "brand": "Beypazarı",
            "ai_summary_json": {
                "organic_score": 92,
                "nova_group": 1,
                "verdict": "İşlenmemiş / Organik (NOVA 1)",
                "summary": "Beypazarı üreticisine ait Doğal Maden Suyu. İçindekiler: Yeraltı kaynaklı doğal mineralli maden suyu, karbondioksit.",
                "warnings": [],
                "alternatives": [
                    {
                        "name": "Kızılay Doğal Maden Suyu",
                        "brand": "Kızılay",
                        "reason": "Zengin mineral içerikli yerli maden suyu"
                    }
                ]
            }
        },
        {
            "barcode": "8690504017301",
            "product_name": "Ülker Çubuk Kraker 40g",
            "brand": "Ülker",
            "ai_summary_json": {
                "organic_score": 62,
                "nova_group": 3,
                "verdict": "İşlenmiş Gıda (NOVA 3)",
                "summary": "Ülker üreticisine ait Çubuk Kraker. İçindekiler: Buğday unu, bitkisel yağ (palm), tuz (%3,5), emülgatör (soya lesitini), asitlik düzenleyici (sodyum hidroksit).",
                "warnings": [
                    "İçeriğinde 'Palm Yağı' bulundu.",
                    "Yüksek sodyum (tuz) oranı içerir."
                ],
                "alternatives": [
                    {
                        "name": "Torku Çubuk Kraker",
                        "brand": "Torku",
                        "reason": "Katkısız fırınlanmış kraker tercihi"
                    }
                ]
            }
        },
        {
            "barcode": "8690533000015",
            "product_name": "Sütaş Doğal Yoğurt 1000g",
            "brand": "Sütaş",
            "ai_summary_json": {
                "organic_score": 90,
                "nova_group": 1,
                "verdict": "İşlenmemiş / Organik (NOVA 1)",
                "summary": "Sütaş üreticisine ait Doğal Yoğurt. İçindekiler: Pastörize inek sütü, yoğurt mayası.",
                "warnings": [],
                "alternatives": [
                    {
                        "name": "Torku Doğal Süzme Yoğurt",
                        "brand": "Torku",
                        "reason": "Katkısız %100 doğal maya içerir"
                    }
                ]
            }
        },
        {
            "barcode": "8690504031505",
            "product_name": "Eti Negro Kakaolu Bisküvi 110g",
            "brand": "Eti",
            "ai_summary_json": {
                "organic_score": 35,
                "nova_group": 4,
                "verdict": "Aşırı İşlenmiş Gıda (NOVA 4)",
                "summary": "Eti üreticisine ait Negro Kakaolu Bisküvi. İçindekiler: Buğday unu, şeker, bitkisel yağ (palm), kakao tozu (%6,5), kabartıcılar, emülgatör, aroma vericiler.",
                "warnings": [
                    "İçeriğinde 'Palm Yağı' bulundu.",
                    "Katkı maddesi: 'Aroma Verici' içermektedir."
                ],
                "alternatives": [
                    {
                        "name": "Züber Kakaolu Fındık Barı",
                        "brand": "Züber",
                        "reason": "Hurma özlü katkısız atıştırmalık"
                    }
                ]
            }
        },
        {
            "barcode": "8690504190100",
            "product_name": "Torku Banada Fındık Kreması 400g",
            "brand": "Torku",
            "ai_summary_json": {
                "organic_score": 58,
                "nova_group": 3,
                "verdict": "İşlenmiş Gıda (NOVA 3)",
                "summary": "Torku üreticisine ait Banada Fındık Kreması. İçindekiler: Şeker (pancar şekeri), fındık (%13), bitkisel yağ, yağsız süt tozu, kakao tozu.",
                "warnings": [
                    "Şeker içeriği yüksektir."
                ],
                "alternatives": [
                    {
                        "name": "Züber %100 Fındık Ezmesi",
                        "brand": "Züber",
                        "reason": "%100 fındıktan oluşan şekersiz doğal ezme"
                    }
                ]
            }
        },
        {
            "barcode": "8690637000102",
            "product_name": "Dimes %100 Sıkma Portakal Suyu 1L",
            "brand": "Dimes",
            "ai_summary_json": {
                "organic_score": 88,
                "nova_group": 1,
                "verdict": "İşlenmemiş / Organik (NOVA 1)",
                "summary": "Dimes üreticisine ait %100 Sıkma Portakal Suyu. İçindekiler: %100 Portakal suyu. İlave şeker, su ve koruyucu içermez.",
                "warnings": [],
                "alternatives": [
                    {
                        "name": "Taze Sıkılmış Ev Yapımı Portakal Suyu",
                        "brand": "Temiz Tarif",
                        "reason": "Dalından taze meyve sıkımı"
                    }
                ]
            }
        }
    ]

    for item in curated_items:
        if item["barcode"] not in seen_barcodes:
            output_dataset.append(item)
            seen_barcodes.add(item["barcode"])

    output_path = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "jojapi_market_products.json")
    output_path = os.path.abspath(output_path)
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output_dataset, f, ensure_ascii=False, indent=2)

    print(f"Successfully generated OrganicScore JSON dataset with {len(output_dataset)} real market products at:")
    print(output_path)

if __name__ == "__main__":
    main()
