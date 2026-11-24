#!/usr/bin/env python3
"""
Tahrir — Google Play Console Closed Testing (Alpha) & ASO Listing Publisher
Google Play Android Developer API v3 (edits -> bundles.upload -> tracks.update -> listings.put -> edits.commit)

Usage:
  python scripts/play_console_publish.py --dry-run-metadata
  python scripts/play_console_publish.py --track alpha
  python scripts/play_console_publish.py --listings-only
"""

from __future__ import annotations

import argparse
import functools
import json
import os
import re
import sys
import time
from pathlib import Path

import jwt
import requests

print = functools.partial(print, flush=True)

if sys.platform == "win32":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

PACKAGE_NAME = "com.akarworks.tahrir"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
BASE_URL = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}"
UPLOAD_URL = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE_NAME}"

MAX_PLAY_TITLE_CHARS = 30
MAX_PLAY_SHORT_DESC_CHARS = 80
MAX_PLAY_FULL_DESC_CHARS = 4000
MAX_WHATS_NEW_CHARS = 500
STORE_LOCALES = ("tr-TR", "en-US")


def parse_pubspec_version(repo_root: Path) -> tuple[str, int]:
    """Parse X.Y.Z+BUILD version from pubspec.yaml."""
    pubspec = (repo_root / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)", pubspec, re.MULTILINE)
    if not match:
        raise RuntimeError("pubspec.yaml icinde version: X.Y.Z+BUILD bulunamadi.")
    return match.group(1), int(match.group(2))


def load_release_notes(repo_root: Path, version_name: str, version_code: int) -> tuple[str, str]:
    """Load TR/EN release notes (<500 chars) from docs or fastlane changelogs."""
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

    tr_whats_new = repo_root / "docs" / "play_store_whats_new" / "whatsnew-tr-TR"
    en_whats_new = repo_root / "docs" / "play_store_whats_new" / "whatsnew-en-US"
    tr_changelog = repo_root / "android" / "fastlane" / "metadata" / "android" / "tr-TR" / "changelogs" / f"{version_code}.txt"
    en_changelog = repo_root / "android" / "fastlane" / "metadata" / "android" / "en-US" / "changelogs" / f"{version_code}.txt"

    if not tr_text:
        if tr_whats_new.exists():
            tr_text = tr_whats_new.read_text(encoding="utf-8").strip()
        elif tr_changelog.exists():
            tr_text = tr_changelog.read_text(encoding="utf-8").strip()

    if not en_text:
        if en_whats_new.exists():
            en_text = en_whats_new.read_text(encoding="utf-8").strip()
        elif en_changelog.exists():
            en_text = en_changelog.read_text(encoding="utf-8").strip()

    return tr_text[: MAX_WHATS_NEW_CHARS - 5], en_text[: MAX_WHATS_NEW_CHARS - 5]


def load_store_listings(repo_root: Path) -> dict[str, dict[str, str]]:
    """Load and validate android/fastlane/metadata/android/{tr-TR,en-US} ASO texts."""
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
            raise ValueError(f"Play Store title ({lang}) > {MAX_PLAY_TITLE_CHARS}: {len(title)}")
        if len(short_desc) > MAX_PLAY_SHORT_DESC_CHARS:
            raise ValueError(f"Play Store short_description ({lang}) > {MAX_PLAY_SHORT_DESC_CHARS}: {len(short_desc)}")
        if len(full_desc) > MAX_PLAY_FULL_DESC_CHARS:
            raise ValueError(f"Play Store full_description ({lang}) > {MAX_PLAY_FULL_DESC_CHARS}: {len(full_desc)}")

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
    """Update TR/EN store listings inside an open Google Play Edit session."""
    for lang, fields in listings.items():
        payload = {"language": lang, **fields}
        res = requests.put(
            f"{BASE_URL}/edits/{edit_id}/listings/{lang}",
            headers=headers,
            json=payload,
            timeout=30,
        )
        if res.status_code not in (200, 201):
            raise RuntimeError(f"Play Store listing ({lang}) update error ({res.status_code}): {res.text}")
        print(
            f"   Play Store listing ({lang}) updated: "
            f"title={len(fields['title'])}/{MAX_PLAY_TITLE_CHARS}, "
            f"short={len(fields['shortDescription'])}/{MAX_PLAY_SHORT_DESC_CHARS}, "
            f"full={len(fields['fullDescription'])}/{MAX_PLAY_FULL_DESC_CHARS}"
        )


def load_service_account_info(key_file: str | None) -> dict:
    """Resolve Google Play Service Account JSON credentials without hardcoding secrets."""
    raw_env = os.environ.get("PLAY_STORE_JSON_KEY", "").strip()
    if raw_env:
        return json.loads(raw_env)

    candidates: list[Path] = []
    if key_file:
        candidates.append(Path(key_file))
    env_file = os.environ.get("PLAY_STORE_JSON_KEY_FILE", "").strip()
    if env_file:
        candidates.append(Path(env_file))

    repo_root = Path(__file__).resolve().parent.parent
    candidates.extend([
        repo_root / "android" / "fastlane" / "play-store-credentials.json",
        repo_root / "play-store-credentials.json",
        Path("C:/Users/theak/Downloads/play-store-credentials.json"),
    ])

    for path in candidates:
        if path.is_file():
            return json.loads(path.read_text(encoding="utf-8"))

    raise FileNotFoundError(
        "Google Play Service Account JSON anahtari bulunamadi!\n"
        "PLAY_STORE_JSON_KEY tanimlayin veya --key-file <yol> verin."
    )


def get_access_token(sa_info: dict) -> str:
    """Mint a short-lived OAuth2 access token from service account RS256 JWT."""
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


def print_missing_app_checklist(client_email: str) -> None:
    """Print one-time Google Play Console manual app creation steps on 404."""
    print(
        "\nGoogle Play Console'da 'com.akarworks.tahrir' uygulama kaydi henuz acilmamis (404 NOT_FOUND).\n"
        "Ilk uygulama olusturma adimi Play API uzerinden yapilamaz; bir kez asagidaki 4 adimi tamamlayin:\n"
        "  1. https://play.google.com/console -> 'Uygulama olustur' (Ad: Tahrir: Akilli PDF & E-Kitap, Dil: Turkce).\n"
        "  2. Test ve yayinla -> Test etme -> Kapali test (Alpha) -> Yeni surum olustur.\n"
        "  3. Yerel imzali AAB dosyasini yukleyin: build/app/outputs/bundle/release/app-release.aab\n"
        f"  4. Kullanicilar ve izinler -> '{client_email}' hesabina 'com.akarworks.tahrir' uygulama izni verin.\n"
        "Sonraki tum guncellemeler ve TR/EN ASO senkronizasyonu icin:\n"
        "  python scripts/play_console_publish.py --track alpha\n"
    )


def commit_edit(edit_id: str, headers: dict[str, str]) -> requests.Response:
    """Commit Play Console edit, retrying with changesNotSentForReview=true if demanded."""
    commit_url = f"{BASE_URL}/edits/{edit_id}:commit"
    res = requests.post(commit_url, headers=headers, timeout=60)
    if res.status_code != 200 and "changesnotsentforreview" in res.text.lower():
        print("Account requires changesNotSentForReview=true. Retrying commit...")
        res = requests.post(f"{commit_url}?changesNotSentForReview=true", headers=headers, timeout=60)
    return res


def main() -> int:
    parser = argparse.ArgumentParser(description="Publish Tahrir AAB & ASO Listings to Google Play Console")
    parser.add_argument(
        "--track",
        default=os.environ.get("PLAY_TRACK", "alpha"),
        choices=["internal", "alpha", "beta", "production"],
        help="Google Play release track (default: alpha [Kapali Test])",
    )
    parser.add_argument(
        "--status",
        default=os.environ.get("PLAY_RELEASE_STATUS", "auto"),
        choices=["auto", "completed", "draft", "halted", "inProgress"],
        help="Release status (default: auto)",
    )
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
        print(f"Tahrir v{version_name} (Build {version_code}) Android ASO & Release Notes Check:")
        print(f"   Package: {PACKAGE_NAME} | Default Track: {args.track}")
        print(f"   TR Release Notes: {len(tr_notes)}/{MAX_WHATS_NEW_CHARS} chars | EN Release Notes: {len(en_notes)}/{MAX_WHATS_NEW_CHARS} chars")
        if not listings:
            print("ERROR: No ASO listings found under android/fastlane/metadata/android/{tr-TR,en-US}")
            return 1
        for lang, fields in listings.items():
            print(
                f"   OK {lang}: title='{fields['title']}' ({len(fields['title'])}/{MAX_PLAY_TITLE_CHARS}), "
                f"short={len(fields['shortDescription'])}/{MAX_PLAY_SHORT_DESC_CHARS}, "
                f"full={len(fields['fullDescription'])}/{MAX_PLAY_FULL_DESC_CHARS}"
            )
        return 0

    aab_path = Path(args.aab) if args.aab else (repo_root / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab")
    if not args.listings_only and not aab_path.exists():
        print(f"ERROR: AAB file not found: {aab_path}")
        return 1

    try:
        sa_info = load_service_account_info(args.key_file)
        client_email = sa_info.get("client_email", "unknown")
        print(f"Service Account: {client_email} | Package: {PACKAGE_NAME} | Track: {args.track}")
        token = get_access_token(sa_info)
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

        edit_res = requests.post(f"{BASE_URL}/edits", headers=headers, json={}, timeout=30)
        if edit_res.status_code == 404:
            print_missing_app_checklist(client_email)
            return 1
        if edit_res.status_code == 403:
            print(
                f"PERMISSION_DENIED (403) for {client_email}.\n"
                f"Grant app permission for '{PACKAGE_NAME}' in Play Console -> Users and permissions."
            )
            return 1
        if edit_res.status_code not in (200, 201):
            print(f"Edit creation failed ({edit_res.status_code}): {edit_res.text}")
            return 1

        edit_id = edit_res.json()["id"]
        print(f"Opened Play Console Edit session: {edit_id}")

        uploaded_version_code = version_code
        if not args.listings_only:
            print(f"Uploading AAB ({aab_path.stat().st_size / (1024 * 1024):.2f} MB)...")
            upload_headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/octet-stream"}
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
                    print(f"Build {version_code} already uploaded; syncing ASO listings only.")
                    if not args.skip_listings and listings:
                        sync_store_listings(edit_id, headers, listings)
                        commit_only = commit_edit(edit_id, headers)
                        if commit_only.status_code not in (200, 201):
                            print(f"Commit failed ({commit_only.status_code}): {commit_only.text}")
                            return 1
                    return 0
                print(f"AAB upload failed ({bundle_res.status_code}): {bundle_res.text}")
                return 1

            uploaded_version_code = bundle_res.json().get("versionCode", version_code)
            print(f"AAB uploaded! versionCode={uploaded_version_code}")

            release_notes_payload = []
            if tr_notes:
                release_notes_payload.append({"language": "tr-TR", "text": tr_notes})
            if en_notes:
                release_notes_payload.append({"language": "en-US", "text": en_notes})

            initial_status = "completed" if args.status == "auto" else args.status

            def put_track(release_status: str) -> requests.Response:
                body = {
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
                    json=body,
                    timeout=30,
                )

            track_res = put_track(initial_status)
            if track_res.status_code not in (200, 201) and args.status == "auto":
                print(f"Track '{args.track}' rejected '{initial_status}' ({track_res.status_code}); retrying as 'draft'...")
                track_res = put_track("draft")

            if track_res.status_code not in (200, 201):
                print(f"Track update failed ({track_res.status_code}): {track_res.text}")
                return 1
            print(f"Track '{args.track}' updated.")

        if not args.skip_listings and listings:
            sync_store_listings(edit_id, headers, listings)

        commit_res = commit_edit(edit_id, headers)
        if commit_res.status_code not in (200, 201) and not args.listings_only and args.status == "auto":
            if "only releases with status draft may be created" in commit_res.text.lower():
                print("App is in draft state on Play Console. Switching release status to 'draft' and retrying...")
                body = {
                    "track": args.track,
                    "releases": [
                        {
                            "name": f"{version_name} ({uploaded_version_code})",
                            "versionCodes": [str(uploaded_version_code)],
                            "status": "draft",
                            "releaseNotes": [
                                item
                                for item in (
                                    {"language": "tr-TR", "text": tr_notes} if tr_notes else None,
                                    {"language": "en-US", "text": en_notes} if en_notes else None,
                                )
                                if item is not None
                            ],
                        }
                    ],
                }
                requests.put(f"{BASE_URL}/edits/{edit_id}/tracks/{args.track}", headers=headers, json=body, timeout=30)
                commit_res = commit_edit(edit_id, headers)

        if commit_res.status_code not in (200, 201):
            print(f"Edit commit failed ({commit_res.status_code}): {commit_res.text}")
            return 1

        print(f"SUCCESS: Tahrir v{version_name} (Build {uploaded_version_code}) committed to Google Play '{args.track}'!")
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
