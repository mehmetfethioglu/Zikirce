import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
}

data = json.dumps({'keywords': 'dost sut'}).encode('utf-8')
req = urllib.request.Request('https://api.marketfiyati.org.tr/api/v2/search', data=data, headers=headers)
with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
    res = json.loads(r.read().decode('utf-8'))
    print("Found:", res.get('numberOfFound'))
    for item in res.get('content', []):
        print(f"ID: {item.get('id')} | Title: {item.get('title')} | Brand: {item.get('brand')}")
        depots = item.get('productDepotInfoList', [])
        markets = set(d.get('marketAdi') for d in depots if d.get('marketAdi'))
        print(f"   Markets: {markets}")
        print("   Item keys:", list(item.keys()))
        print("   Item sample:", item)
        break
