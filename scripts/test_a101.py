import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
}

url = 'https://www.a101.com.tr/market/sut-ve-kahvaltilik/'
try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
        html = r.read().decode('utf-8', errors='ignore')
        print(f"A101 HTML length: {len(html)}")
        import re
        ld_json = re.findall(r'<script type="application/ld\+json">([\s\S]*?)</script>', html)
        print(f"A101 LD+JSON scripts found: {len(ld_json)}")
        for j in ld_json[:2]:
            try:
                parsed = json.loads(j)
                print("LD+JSON type:", parsed.get('@type'))
                if 'itemListElement' in parsed:
                    print("Items count in LD+JSON:", len(parsed['itemListElement']))
                    sample = parsed['itemListElement'][0]
                    print("Sample item:", sample)
            except Exception as e:
                pass
except Exception as e:
    print("A101 fetch error:", e)
