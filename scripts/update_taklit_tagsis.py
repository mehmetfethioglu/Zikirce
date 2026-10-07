import urllib.request
import urllib.parse
import ssl
import json
import re
import time

def fetch_category_data(category_name, extra_params):
    url = 'https://guvenilirgida.tarimorman.gov.tr/GuvenilirGida/GKD/DataTablesList'
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    data = {
        'draw': '1',
        'start': '0',
        'length': '1000', # Fetch up to 1000 items per category
        'siteYayinDurumu': 'True',
        'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '0',
        'KamuoyuDuyuruAra.DuyuruTarihi': '',
        'KamuoyuDuyuruAra.UrunGrupId': '',
    }
    data.update(extra_params)
    
    for i, col in enumerate(['DuyuruTarihi', 'FirmaAdi', 'Marka', 'UrunAdi', 'Uygunsuzluk', 'PartiSeriNo', 'FirmaIlce', 'FirmaIl', 'UrunGrupAdi']):
        data[f'columns[{i}][data]'] = col
        data[f'columns[{i}][name]'] = col
        data[f'columns[{i}][searchable]'] = 'true'
        data[f'columns[{i}][orderable]'] = 'true'
        data[f'columns[{i}][search][value]'] = ''
        data[f'columns[{i}][search][regex]'] = 'false'
        
    data['order[0][column]'] = '0'
    data['order[0][dir]'] = 'desc'
    data['search[value]'] = ''
    data['search[regex]'] = 'false'

    encoded_data = urllib.parse.urlencode(data).encode('utf-8')

    req = urllib.request.Request(
        url,
        data=encoded_data,
        headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            'X-Requested-With': 'XMLHttpRequest',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        }
    )

    items = []
    try:
        with urllib.request.urlopen(req, context=ctx) as res:
            response_text = res.read().decode('utf-8', errors='ignore')
            parsed = json.loads(response_text)
            raw_items = parsed.get('data', [])
            
            for item in raw_items:
                raw_date = str(item.get('DuyuruTarihi', ''))
                date_match = re.search(r'\d+', raw_date)
                timestamp = int(date_match.group(0)) if date_match else int(time.time() * 1000)

                company = (item.get('FirmaAdi') or '').strip()
                brand = (item.get('Marka') or '').strip()
                product = (item.get('UrunAdi') or '').strip()
                reason = (item.get('Uygunsuzluk') or '').strip()
                category = (item.get('UrunGrupAdi') or 'Gıda').strip()

                if not brand and company:
                    brand = company.split()[0]
                if not brand:
                    brand = 'Bilinmeyen Marka'

                items.append({
                    "company_name": company if company else "Firma Belirtilmemiş",
                    "brand_name": brand,
                    "product_name": product if product else "Ürün",
                    "reason": f"[{category_name}] {reason}",
                    "category": category,
                    "announced_at": timestamp
                })
            
            print(f"[{category_name}] kategorisinden {len(items)} adet resmi kayıt çekildi.")
    except Exception as e:
        print(f"[{category_name}] veri çekme hatası:", e)

    return items

def update_all_tagsis_data():
    print("Tarım ve Orman Bakanlığı Güvenilir Gıda Portalından CANLI veriler çekiliyor...\n")

    all_items = []

    # 1. Sağlığı Tehlikeye Düşürecek Gıdalar
    cat1 = fetch_category_data("Sağlığı Tehlikeye Düşürecek Gıdalar", {
        'KamuoyuDuyuruAra.ListeTurId': '',
        'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakIdler': '',
        'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '',
    })
    all_items.extend(cat1)

    # 2. Taklit veya Tağşiş Yapılan Gıdalar (Madde Eklenmesi / Karıştırılması)
    cat2 = fetch_category_data("Taklit/Tağşiş - Madde Eklenmesi", {
        'KamuoyuDuyuruAra.ListeTurId': '304',
        'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '0',
    })
    all_items.extend(cat2)

    # 3. Temel Özelliği Etkileyen İçerik Eksikliği
    cat3 = fetch_category_data("Taklit/Tağşiş - İçerik Eksikliği", {
        'KamuoyuDuyuruAra.HaricTut': '304',
        'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '0',
    })
    all_items.extend(cat3)

    output_file = "assets/data/taklit_tagsis_list.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(all_items, f, ensure_ascii=False, indent=2)

    print(f"\nTEBRİKLER! Tarım ve Orman Bakanlığı'nın 3 kategorideki toplam {len(all_items)} adet güncel kara liste verisi '{output_file}' dosyasına kaydedildi.")

if __name__ == '__main__':
    update_all_tagsis_data()
