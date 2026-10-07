import urllib.request
import urllib.parse
import ssl
import json

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

url = 'https://guvenilirgida.tarimorman.gov.tr/GuvenilirGida/GKD/DataTablesList'

def fetch_params(name, extra_params):
    data = {
        'draw': '1',
        'start': '0',
        'length': '10',
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

    try:
        with urllib.request.urlopen(req, context=ctx) as res:
            response_text = res.read().decode('utf-8', errors='ignore')
            parsed = json.loads(response_text)
            print(f"=== {name} ===")
            print("Total Records:", parsed.get('recordsTotal'))
            print("Filtered Records:", parsed.get('recordsFiltered'))
            print("Data count:", len(parsed.get('data', [])))
            if parsed.get('data'):
                print("Sample item:", parsed['data'][0])
            print()
    except Exception as e:
        print(f"Error on {name}:", e)

# Category 1: Sagligi Tehlikeye Dusurecek (Health Danger)
fetch_params("Sağlığı Tehlikeye Düşürecek Gıdalar", {
    'KamuoyuDuyuruAra.ListeTurId': '',
    'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakIdler': '',
    'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '',
})

# Category 2: Taklit veya Tağşiş Liste 1 (Madde Eklenmesi / Karıştırılması)
fetch_params("Taklit/Tağşiş Liste 1 (Madde Eklenmesi)", {
    'KamuoyuDuyuruAra.ListeTurId': '304',
    'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '0',
})

# Category 3: Taklit veya Tağşiş Liste 2 (İçerik Eksikliği)
fetch_params("Taklit/Tağşiş Liste 2 (İçerik Eksikliği)", {
    'KamuoyuDuyuruAra.HaricTut': '304',
    'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '0',
})
