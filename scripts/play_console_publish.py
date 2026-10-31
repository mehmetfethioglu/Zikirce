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
    parser = argparse.ArgumentParser(description="Publish Zikirce AAB to Google Play Console")
    parser.add_argument("--track", default=os.environ.get("PLAY_TRACK", "production"), choices=["internal", "alpha", "beta", "production"])
    parser.add_argument("--status", default=os.environ.get("PLAY_RELEASE_STATUS", "completed"), choices=["completed", "draft", "halted", "inProgress"])
    parser.add_argument("--aab", default=None, help="Path to app-release.aab")
    parser.add_argument("--key-file", default=None, help="Path to service account JSON file")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    version_name, version_code = parse_pubspec_version(repo_root)
    aab_path = Path(args.aab) if args.aab else (repo_root / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab")

    if not aab_path.exists():
        print(f"❌ AAB dosyası bulunamadı: {aab_path}")
        return 1

    tr_notes, en_notes = load_release_notes(repo_root, version_name, version_code)
    print(f"📦 Zikirce v{version_name} (Build {version_code}) -> Google Play '{args.track}' kanalına hazırlanıyor...")
    print(f"   AAB Boyutu: {aab_path.stat().st_size / (1024 * 1024):.2f} MB")
    print(f"   TR Sürüm Notu ({len(tr_notes)} krk) / EN Sürüm Notu ({len(en_notes)} krk)")

    sa_info = load_service_account_info(args.key_file)
    token = get_access_token(sa_info)
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    # 1. Yeni bir Edit oturumu aç
    edit_res = requests.post(f"{BASE_URL}/edits", headers=headers, json={}, timeout=30)
    if edit_res.status_code not in (200, 201):
        print(f"❌ Edit oluşturulamadı ({edit_res.status_code}): {edit_res.text}")
        return 1
    edit_id = edit_res.json()["id"]
    print(f"✅ Play Console Edit oturumu açıldı: {edit_id}")

    # 2. AAB dosyasını yükle
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

    # 4. Edit oturumunu onayla ve yayına (incelemeye) gönder
    commit_res = requests.post(f"{BASE_URL}/edits/{edit_id}:commit", headers=headers, timeout=60)
    if commit_res.status_code not in (200, 201):
        print(f"❌ Edit commit hatası ({commit_res.status_code}): {commit_res.text}")
        return 1

    print(f"🚀 Zikirce v{version_name} (Build {uploaded_version_code}) Google Play Console '{args.track}' kanalına başarıyla gönderildi!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
