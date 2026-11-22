#!/usr/bin/env python3
"""
Barbaros Hayreddin Paşa — Google Play Console Otomatik AAB & Sürüm Notu Yayınlayıcı
Google Play Android Developer API v3 (edits -> bundles.upload -> tracks.update -> edits.commit)

Hem yerel Windows ortamından (hazır derlenmiş app-release.aab ile 15 saniyede)
hem de GitHub Actions (.github/workflows/playstore-release.yml) üzerinden çalışır.

Kullanım (Yerel):
  python scripts/play_console_publish.py --track production
  python scripts/play_console_publish.py --track internal --key-file android/fastlane/play-store-credentials.json
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

import jwt
import requests

PACKAGE_NAME = "com.akarworks.zikirce"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
BASE_URL = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}"
UPLOAD_URL = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE_NAME}"


MAX_PLAY_TITLE_CHARS = 30
MAX_PLAY_SHORT_DESC_CHARS = 80
MAX_PLAY_FULL_DESC_CHARS = 4000
STORE_LOCALES = ("tr-TR", "en-US")


def parse_pubspec_version(repo_root: Path) -> tuple[str, int]:
    pubspec = (repo_root / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)", pubspec, re.MULTILINE)
    if not m:
        raise RuntimeError("pubspec.yaml içinde version: X.Y.Z+BUILD bulunamadı.")
    return m.group(1), int(m.group(2))


def load_release_notes(repo_root: Path, version_name: str, version_code: int) -> tuple[str, str]:
    notes_md = repo_root / "docs" / f"RELEASE_NOTES_v{version_name}_b{version_code}.md"
    tr_text = ""
    en_text = ""

    if notes_md.exists():
        content = notes_md.read_text(encoding="utf-8")
        tr_match = re.search(r"<tr-TR>\s*(.*?)\s*</tr-TR>", content, re.DOTALL)
        en_match = re.search(r"<en-US>\s*(.*?)\s*</en-US>", content, re.DOTALL)
        if tr_match:
            tr_text = tr_match.group(1).strip()
        if en_match:
            en_text = en_match.group(1).strip()

    tr_changelog = repo_root / "android" / "fastlane" / "metadata" / "android" / "tr-TR" / "changelogs" / f"{version_code}.txt"
    en_changelog = repo_root / "android" / "fastlane" / "metadata" / "android" / "en-US" / "changelogs" / f"{version_code}.txt"
    tr_default = repo_root / "android" / "fastlane" / "metadata" / "android" / "tr-TR" / "changelogs" / "default.txt"
    en_default = repo_root / "android" / "fastlane" / "metadata" / "android" / "en-US" / "changelogs" / "default.txt"

    if not tr_text:
        if tr_changelog.exists():
            tr_text = tr_changelog.read_text(encoding="utf-8").strip()
        elif tr_default.exists():
            tr_text = tr_default.read_text(encoding="utf-8").strip()

    if not en_text:
        if en_changelog.exists():
            en_text = en_changelog.read_text(encoding="utf-8").strip()
        elif en_default.exists():
            en_text = en_default.read_text(encoding="utf-8").strip()

    # Google Play Console 500 karakter sınırını garanti altına al
    return tr_text[:495], en_text[:495]


def load_store_listings(repo_root: Path) -> dict[str, dict[str, str]]:
    """android/fastlane/metadata/android/{tr-TR,en-US} ASO metinlerini yükler ve sınırları doğrular."""
    base_dir = repo_root / "android" / "fastlane" / "metadata" / "android"
    listings: dict[str, dict[str, str]] = {}

    for lang in STORE_LOCALES:
        lang_dir = base_dir / lang
        if not lang_dir.is_dir():
            continue

        title_file = lang_dir / "title.txt"
        short_file = lang_dir / "short_description.txt"
        full_file = lang_dir / "full_description.txt"
        if not (title_file.exists() and short_file.exists() and full_file.exists()):
            continue

        title = title_file.read_text(encoding="utf-8").strip()
        short_desc = short_file.read_text(encoding="utf-8").strip()
        full_desc = full_file.read_text(encoding="utf-8").strip()

        if len(title) > MAX_PLAY_TITLE_CHARS:
            raise ValueError(
                f"Play Store title ({lang}) {MAX_PLAY_TITLE_CHARS} karakter sınırını aşıyor: {len(title)}"
            )
        if len(short_desc) > MAX_PLAY_SHORT_DESC_CHARS:
            raise ValueError(
                f"Play Store short_description ({lang}) {MAX_PLAY_SHORT_DESC_CHARS} karakter sınırını aşıyor: {len(short_desc)}"
            )
        if len(full_desc) > MAX_PLAY_FULL_DESC_CHARS:
            raise ValueError(
                f"Play Store full_description ({lang}) {MAX_PLAY_FULL_DESC_CHARS} karakter sınırını aşıyor: {len(full_desc)}"
            )

        listings[lang] = {
            "title": title,
            "shortDescription": short_desc,
            "fullDescription": full_desc,
        }

    return listings


def sync_store_listings(
    edit_id: str,
    headers: dict[str, str],
    listings: dict[str, dict[str, str]],
) -> None:
    """Açık Play Console Edit oturumu içinde TR/EN mağaza vitrin metinlerini günceller."""
    for lang, fields in listings.items():
        payload = {"language": lang, **fields}
        res = requests.put(
            f"{BASE_URL}/edits/{edit_id}/listings/{lang}",
            headers=headers,
            json=payload,
            timeout=30,
        )
        if res.status_code not in (200, 201):
            raise RuntimeError(
                f"Play Store listing ({lang}) güncelleme hatası ({res.status_code}): {res.text}"
            )
        print(
            f"   📝 Play Store vitrin ({lang}) güncellendi: "
            f"title={len(fields['title'])}/{MAX_PLAY_TITLE_CHARS}, "
            f"short={len(fields['shortDescription'])}/{MAX_PLAY_SHORT_DESC_CHARS}, "
            f"full={len(fields['fullDescription'])}/{MAX_PLAY_FULL_DESC_CHARS}"
        )


def load_service_account_info(key_file: str | None) -> dict:
    raw_env = os.environ.get("PLAY_STORE_JSON_KEY", "").strip()
    if raw_env:
        return json.loads(raw_env)

    candidates = []
    if key_file:
        candidates.append(Path(key_file))
    env_file = os.environ.get("PLAY_STORE_JSON_KEY_FILE", "").strip()
    if env_file:
        candidates.append(Path(env_file))

    repo_root = Path(__file__).resolve().parent.parent
    candidates.extend([
        repo_root / "android" / "fastlane" / "play-store-credentials.json",
        repo_root / "play-store-credentials.json",
    ])

    for path in candidates:
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))

    raise FileNotFoundError(
        "Google Play Service Account JSON anahtarı bulunamadı!\n"
        "Lütfen 'PLAY_STORE_JSON_KEY' ortam değişkenini tanımlayın veya anahtar dosyasını "
        "'android/fastlane/play-store-credentials.json' konumuna kaydedin."
    )


def get_access_token(sa_info: dict) -> str:
    now = int(time.time())
    payload = {
        "iss": sa_info["client_email"],
        "scope": ANDROID_PUBLISHER_SCOPE,
        "aud": sa_info.get("token_uri", "https://oauth2.googleapis.com/token"),
        "iat": now - 30,
        "exp": now + 3500,
    }
    assertion = jwt.encode(payload, sa_info["private_key"], algorithm="RS256")
    resp = requests.post(
        sa_info.get("token_uri", "https://oauth2.googleapis.com/token"),
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def main() -> int:
    parser = argparse.ArgumentParser(description="Publish Zikirce AAB & ASO Listings to Google Play Console")
    parser.add_argument("--track", default=os.environ.get("PLAY_TRACK", "production"), choices=["internal", "alpha", "beta", "production"])
    parser.add_argument("--status", default=os.environ.get("PLAY_RELEASE_STATUS", "completed"), choices=["completed", "draft", "halted", "inProgress"])
    parser.add_argument("--aab", default=None, help="Path to app-release.aab")
    parser.add_argument("--key-file", default=None, help="Path to service account JSON file")
    parser.add_argument("--skip-listings", action="store_true", help="Skip syncing store title/descriptions")
    parser.add_argument("--listings-only", action="store_true", help="Sync store listings only without AAB upload")
    parser.add_argument("--dry-run-metadata", action="store_true", help="Validate Android metadata locally without API calls")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    version_name, version_code = parse_pubspec_version(repo_root)
    tr_notes, en_notes = load_release_notes(repo_root, version_name, version_code)
    listings = load_store_listings(repo_root)

    if args.dry_run_metadata:
        print(f"🔎 Zikirce v{version_name} (Build {version_code}) Android ASO & Release Notes Doğrulaması:")
        print(f"   TR Sürüm Notu: {len(tr_notes)}/500 krk | EN Sürüm Notu: {len(en_notes)}/500 krk")
        if not listings:
            print("❌ android/fastlane/metadata/android/{tr-TR,en-US} altında ASO dosyası bulunamadı!")
            return 1
        for lang, fields in listings.items():
            print(
                f"   ✅ {lang}: title='{fields['title']}' ({len(fields['title'])}/{MAX_PLAY_TITLE_CHARS}), "
                f"short={len(fields['shortDescription'])}/{MAX_PLAY_SHORT_DESC_CHARS}, "
                f"full={len(fields['fullDescription'])}/{MAX_PLAY_FULL_DESC_CHARS}"
            )
        return 0

    aab_path = Path(args.aab) if args.aab else (repo_root / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab")

    if not args.listings_only and not aab_path.exists():
        print(f"❌ AAB dosyası bulunamadı: {aab_path}")
        return 1

    if args.listings_only:
        print(f"📝 Zikirce v{version_name} (Build {version_code}) -> Yalnızca Play Store ASO vitrin metinleri güncelleniyor...")
    else:
        print(f"📦 Zikirce v{version_name} (Build {version_code}) -> Google Play '{args.track}' kanalına hazırlanıyor...")
        print(f"   AAB Boyutu: {aab_path.stat().st_size / (1024 * 1024):.2f} MB")
        print(f"   TR Sürüm Notu ({len(tr_notes)} krk) / EN Sürüm Notu ({len(en_notes)} krk)")

    sa_info = load_service_account_info(args.key_file)
    client_email = sa_info.get("client_email", "bilinmiyor")
    project_id = sa_info.get("project_id", "bilinmiyor")
    print(f"🔑 Kullanılan Servis Hesabı: {client_email} (Google Cloud Proje: {project_id})")

    token = get_access_token(sa_info)
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    # 1. Yeni bir Edit oturumu aç
    edit_res = requests.post(f"{BASE_URL}/edits", headers=headers, json={}, timeout=30)
    if edit_res.status_code not in (200, 201):
        print(f"❌ Edit oluşturulamadı ({edit_res.status_code}): {edit_res.text}")
        if edit_res.status_code == 403:
            print(
                "\n💡 ÇÖZÜM (Google Play Console 403 PERMISSION_DENIED):\n"
                f"   1. https://play.google.com/console/users-and-permissions adresine gidin.\n"
                f"   2. '{client_email}' kullanıcısına tıklayın (yoksa 'Yeni kullanıcıları davet et' ile ekleyin).\n"
                f"   3. 'Hesap izinleri (Account permissions)' sekmesinde 'Yönetici (tüm izinler) / Admin (all permissions)' kutusunu işaretleyin.\n"
                f"   4. 'Uygulama izinleri (App permissions)' sekmesinde 'Uygulama ekle' -> 'Zikirce (com.akarworks.zikirce)' seçip 'Uygula' ve 'Değişiklikleri kaydet' butonuna basın."
            )
        return 1
    edit_id = edit_res.json()["id"]
    print(f"✅ Play Console Edit oturumu açıldı: {edit_id}")

    # 2. AAB dosyasını yükle ve Track'e bağla (--listings-only değilse)
    uploaded_version_code = version_code
    if not args.listings_only:
        print("⬆️ app-release.aab Google Play sunucularına yükleniyor...")
        upload_headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/octet-stream",
        }
        with aab_path.open("rb") as f:
            bundle_res = requests.post(
                f"{UPLOAD_URL}/edits/{edit_id}/bundles?uploadType=media",
                headers=upload_headers,
                data=f,
                timeout=600,
            )
        if bundle_res.status_code not in (200, 201):
            err_lower = bundle_res.text.lower()
            if "already been used" in err_lower or ("version code" in err_lower and "already" in err_lower):
                print(f"ℹ️ Build {version_code} zaten Google Play Console'a yüklenmiş ve yayınlanmış; yalnızca ASO vitrini varsa güncelleniyor.")
                if not args.skip_listings and listings:
                    sync_store_listings(edit_id, headers, listings)
                    commit_only = requests.post(f"{BASE_URL}/edits/{edit_id}:commit", headers=headers, timeout=60)
                    if commit_only.status_code not in (200, 201):
                        print(f"❌ ASO Edit commit hatası ({commit_only.status_code}): {commit_only.text}")
                        return 1
                return 0
            print(f"❌ AAB yükleme hatası ({bundle_res.status_code}): {bundle_res.text}")
            return 1

        uploaded_version_code = bundle_res.json().get("versionCode", version_code)
        print(f"✅ AAB yüklendi! versionCode: {uploaded_version_code}")

        # 3. İlgili Track'e (production/beta/internal) sürüm notlarıyla bağla
        release_notes_payload = []
        if tr_notes:
            release_notes_payload.append({"language": "tr-TR", "text": tr_notes})
        if en_notes:
            release_notes_payload.append({"language": "en-US", "text": en_notes})

        def update_track(release_status: str) -> requests.Response:
            track_body = {
                "track": args.track,
                "releases": [
                    {
                        "name": f"{version_name} ({uploaded_version_code})",
                        "versionCodes": [str(uploaded_version_code)],
                        "status": release_status,
                        "releaseNotes": release_notes_payload,
                    }
                ],
            }
            return requests.put(
                f"{BASE_URL}/edits/{edit_id}/tracks/{args.track}",
                headers=headers,
                json=track_body,
                timeout=30,
            )

        track_res = update_track(args.status)
        if track_res.status_code not in (200, 201) and args.status == "completed":
            print(f"⚠️ 'completed' statüsü kabul edilmedi ({track_res.status_code}), 'draft' olarak deneniyor...")
            track_res = update_track("draft")

        if track_res.status_code not in (200, 201):
            print(f"❌ Track güncelleme hatası ({track_res.status_code}): {track_res.text}")
            return 1
        print(f"✅ '{args.track}' kanalı sürüm notlarıyla güncellendi.")

    # 3B. Mağaza vitrini (Title, Short, Full Description) senkronizasyonu
    if not args.skip_listings and listings:
        sync_store_listings(edit_id, headers, listings)

    # 4. Edit oturumunu onayla ve yayına (incelemeye) gönder
    commit_res = requests.post(f"{BASE_URL}/edits/{edit_id}:commit", headers=headers, timeout=60)
    if commit_res.status_code not in (200, 201):
        print(f"❌ Edit commit hatası ({commit_res.status_code}): {commit_res.text}")
        return 1

    if args.listings_only:
        print(f"🚀 Zikirce TR/EN Google Play vitrin metinleri başarıyla güncellendi!")
    else:
        print(f"🚀 Zikirce v{version_name} (Build {uploaded_version_code}) Google Play Console '{args.track}' kanalına başarıyla gönderildi!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
