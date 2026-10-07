import urllib.request
import ssl
import re
import json
import time

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

base_url = 'https://www.boykot.co'

def get_html(url):
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
    })
    try:
        with urllib.request.urlopen(req, context=ctx) as res:
            return res.read().decode('utf-8', errors='ignore')
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return ""

def main():
    print("boykot.co ana sayfası taranıyor...")
    homepage_html = get_html(base_url)
    
    # Extract category URLs
    category_links = re.findall(r'href=["\'](https://www\.boykot\.co/c/[^"\']+)["\']', homepage_html)
    category_links = sorted(list(set(category_links)))
    print(f"Toplam {len(category_links)} adet kategori linki bulundu.\n")

    all_boycotted_items = {}

    for cat_url in category_links:
        cat_name_match = re.search(r'/c/([^/]+)', cat_url)
        cat_slug = cat_name_match.group(1) if cat_name_match else "genel"
        cat_display_name = cat_slug.split('-')[0].capitalize()
        
        print(f"Kategori taranıyor: {cat_slug} ({cat_url})")
        
        # Check pagination for category
        page = 1
        while True:
            page_url = cat_url if page == 1 else f"{cat_url}?page={page}"
            cat_html = get_html(page_url)
            if not cat_html:
                break

            # Find all brand links like <a href="https://www.boykot.co/d/slug">Brand Name</a>
            brand_matches = re.findall(r'<a\s+href=["\'](https://www\.boykot\.co/d/[^"\']+)["\'][^>]*>\s*([^<]+)\s*</a>', cat_html)
            
            found_count = 0
            for b_url, b_name in brand_matches:
                b_name_clean = b_name.strip()
                if not b_name_clean or len(b_name_clean) < 2:
                    continue
                
                # Exclude menu items, questions, and boilerplate
                b_lower = b_name_clean.lower()
                if b_lower in ['boykot listesi', 'iletişim', 'hakkımızda', 'ana sayfa', 'neden?', 'neden', 'ta', 'ves', 'vsh'] or '?' in b_name_clean:
                    continue
                if len(b_name_clean) < 3 and b_lower not in ['hp', 'bp', 'fa', 'ge', 'lg']:
                    continue

                if b_lower not in all_boycotted_items:
                    all_boycotted_items[b_lower] = {
                        "brand_name": b_name_clean,
                        "parent_company": b_name_clean,
                        "url": b_url,
                        "category": cat_display_name,
                        "boycott_status": "FLAGGED",
                        "reason": f"Gazze işgali ve İsrail bağlantısı / desteği nedeniyle boykot listesinde ({cat_display_name}).",
                        "evidence_url": b_url,
                        "source": "boykot.co"
                    }
                    found_count += 1

            if found_count == 0 or page >= 10:
                break
            page += 1

    print(f"\n========================================================")
    print(f"BAŞARILI! Toplam {len(all_boycotted_items)} adet özgün boykotlu marka/ürün boykot.co sitesinden çekildi.")
    print(f"========================================================\n")
    
    output_list = list(all_boycotted_items.values())
    output_file = "assets/data/boycott_list.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(output_list, f, ensure_ascii=False, indent=2)

    print(f"Veriler '{output_file}' dosyasına kaydedildi.")

if __name__ == '__main__':
    main()
