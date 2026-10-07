import urllib.request
import ssl
import re

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

url = 'https://www.boykot.co/c/yiyecek-11'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})

try:
    with urllib.request.urlopen(req, context=ctx) as res:
        html = res.read().decode('utf-8', errors='ignore')
        print("HTML length:", len(html))
        
        # Look for all links
        links = re.findall(r'href=["\'](https://www\.boykot\.co/d/[^"\']+)["\']', html)
        print("Found /d/ links:", set(links))
        
        # Look for headings or card titles
        cards = re.findall(r'class=["\']card-title[^"\']*["\'][^>]*>(.*?)</div>', html, re.DOTALL)
        print("Card titles:", cards[:10])

        # Print a snippet of HTML around brand cards
        if '/d/' in html:
            idx = html.find('/d/')
            print("Snippet around /d/:", html[idx-100:idx+300])

except Exception as e:
    print("Error:", e)
