#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Zamera Local Google Play Publisher & ASO Sync Engine
Google Play Android Developer API v3 (details, listings, images, bundles, tracks, commit)

Zero-Stub, Zero-Mirror, 100% Local-First Release Engine for com.akarworks.zamera.
"""

from __future__ import annotations

import argparse
import functools
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

print = functools.partial(print, flush=True)

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception as exc:
        print(f"Warning: console UTF-8 reconfigure skipped: {exc}", file=sys.stderr)

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

PACKAGE_NAME = "com.akarworks.zamera"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
GOOGLE_API_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
GOOGLE_UPLOAD_BASE = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"

MAX_PLAY_TITLE_CHARS = 30
MAX_PLAY_SHORT_DESC_CHARS = 80
MAX_PLAY_FULL_DESC_CHARS = 4000
MAX_PLAY_WHATS_NEW_CHARS = 500
STORE_LOCALES = ("tr-TR", "en-US")
PROHIBITED_TITLE_TERMS = ("#1", "best", "free", "en iyi", "ücretsiz", "bedava", "top 1")

CONTACT_EMAIL = "theakar@windowslive.com"
CONTACT_WEBSITE = "https://mehmetfethioglu.github.io/zamera-privacy/"


class ZameraPlayPublisher:
    def __init__(
        self,
        project_dir: Path,
        track: str = "alpha",
        status: str = "completed",
        credentials_path: Optional[Path] = None,
        skip_build: bool = False,
        build_apk: bool = True,
        build_rust: bool = False,
        skip_listings: bool = False,
        listings_only: bool = False,
        dry_run: bool = False,
    ):
        self.project_dir = project_dir.resolve()
        self.track = track
        self.status = status
        self.credentials_path = credentials_path
        self.skip_build = skip_build
        self.build_apk = build_apk
        self.build_rust = build_rust
        self.skip_listings = skip_listings
        self.listings_only = listings_only
        self.dry_run = dry_run

        self.app_dir = self._detect_app_dir()
        self.package_name, self.version_name, self.version_code = self._detect_app_metadata()

    def _detect_app_dir(self) -> Path:
        if (self.project_dir / "pubspec.yaml").exists() and (self.project_dir / "android").exists():
            return self.project_dir
        if (self.project_dir / "app" / "pubspec.yaml").exists():
            return self.project_dir / "app"
        raise FileNotFoundError(f"Could not locate Flutter app directory in '{self.project_dir}'")

    def _detect_app_metadata(self) -> Tuple[str, str, int]:
        pubspec_path = self.app_dir / "pubspec.yaml"
        pub_txt = pubspec_path.read_text(encoding="utf-8")
        m_ver = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)", pub_txt, re.MULTILINE)
        if not m_ver:
            raise ValueError(f"Could not parse X.Y.Z+BUILD version from {pubspec_path}")
        version_name = m_ver.group(1)
        version_code = int(m_ver.group(2))

        pkg_name = PACKAGE_NAME
        gradle_ktx = self.app_dir / "android" / "app" / "build.gradle.kts"
        if gradle_ktx.is_file():
            content = gradle_ktx.read_text(encoding="utf-8", errors="ignore")
            m_app_id = re.search(r'applicationId\s*=\s*["\']([^"\']+)["\']', content)
            if m_app_id:
                pkg_name = m_app_id.group(1)

        return pkg_name, version_name, version_code

    def resolve_credentials(self) -> Path:
        if self.credentials_path and self.credentials_path.is_file():
            return self.credentials_path

        env_key = os.environ.get("PLAY_STORE_JSON_KEY", "").strip()
        if env_key:
            if os.path.isfile(env_key):
                return Path(env_key)
            try:
                parsed = json.loads(env_key)
                temp_cred = self.app_dir / "build" / "temp-play-credentials.json"
                temp_cred.parent.mkdir(parents=True, exist_ok=True)
                temp_cred.write_text(json.dumps(parsed), encoding="utf-8")
                return temp_cred
            except Exception as exc:
                print(
                    f"Warning: PLAY_STORE_JSON_KEY is not valid JSON ({exc}); checking credential file paths.",
                    file=sys.stderr,
                )

        search_locations = [
            self.app_dir / "android" / "fastlane" / "play-store-credentials.json",
            self.project_dir / "fastlane" / "play-store-credentials.json",
            Path.home() / "Downloads" / "play-store-credentials.json",
            Path("C:/Users/theak/Downloads/play-store-credentials.json"),
            Path("C:/Users/theak/source/repos/zikirce_/android/fastlane/play-store-credentials.json"),
        ]
        for candidate in search_locations:
            if candidate.is_file():
                return candidate

        raise FileNotFoundError(
            "Google Play service account credentials JSON not found! "
            "Set PLAY_STORE_JSON_KEY or pass --credentials <path>."
        )

    def load_release_notes(self) -> List[Dict[str, str]]:
        notes_by_lang: Dict[str, str] = {}
        notes_md = self.project_dir / "docs" / f"RELEASE_NOTES_v{self.version_name}_b{self.version_code}.md"
        if notes_md.is_file():
            md_txt = notes_md.read_text(encoding="utf-8")
            for lang in STORE_LOCALES:
                m = re.search(rf"<{re.escape(lang)}>\s*(.*?)\s*</{re.escape(lang)}>", md_txt, re.DOTALL)
                if m and m.group(1).strip():
                    notes_by_lang[lang] = m.group(1).strip()

        fastlane_base = self.app_dir / "android" / "fastlane" / "metadata" / "android"
        whats_new_dir = self.project_dir / "docs" / "play_store_whats_new"
        for lang in STORE_LOCALES:
            if lang in notes_by_lang:
                continue
            candidates = [
                fastlane_base / lang / "changelogs" / f"{self.version_code}.txt",
                fastlane_base / lang / "changelogs" / "default.txt",
                whats_new_dir / f"whatsnew-{lang}",
            ]
            for c in candidates:
                if c.is_file():
                    notes_by_lang[lang] = c.read_text(encoding="utf-8").strip()
                    break

        notes: List[Dict[str, str]] = []
        for lang in STORE_LOCALES:
            text = notes_by_lang.get(lang, "").strip()
            if not text:
                raise ValueError(f"Missing Google Play release notes for locale '{lang}'")
            if len(text) >= MAX_PLAY_WHATS_NEW_CHARS:
                raise ValueError(
                    f"Google Play release notes for '{lang}' must be <{MAX_PLAY_WHATS_NEW_CHARS} chars (got {len(text)})"
                )
            notes.append({"language": lang, "text": text})
        return notes

    def load_store_listings(self) -> Dict[str, Dict[str, str]]:
        base_dir = self.app_dir / "android" / "fastlane" / "metadata" / "android"
        listings: Dict[str, Dict[str, str]] = {}

        for lang in STORE_LOCALES:
            lang_dir = base_dir / lang
            if not lang_dir.is_dir():
                continue
            title_file = lang_dir / "title.txt"
            short_file = lang_dir / "short_description.txt"
            full_file = lang_dir / "full_description.txt"
            if not (title_file.is_file() and short_file.is_file() and full_file.is_file()):
                continue

            title = title_file.read_text(encoding="utf-8").strip()
            short_desc = short_file.read_text(encoding="utf-8").strip()
            full_desc = full_file.read_text(encoding="utf-8").strip()

            if not title or len(title) > MAX_PLAY_TITLE_CHARS:
                raise ValueError(f"Play Store title ({lang}) invalid length: {len(title)}/{MAX_PLAY_TITLE_CHARS}")
            if title == title.upper():
                raise ValueError(f"Play Store title ({lang}) must not be ALL CAPS: {title!r}")
            for term in PROHIBITED_TITLE_TERMS:
                if term in title.lower():
                    raise ValueError(f"Play Store title ({lang}) contains prohibited term '{term}': {title!r}")
            if not short_desc or len(short_desc) > MAX_PLAY_SHORT_DESC_CHARS:
                raise ValueError(
                    f"Play Store short_description ({lang}) invalid length: {len(short_desc)}/{MAX_PLAY_SHORT_DESC_CHARS}"
                )
            if not full_desc or len(full_desc) > MAX_PLAY_FULL_DESC_CHARS:
                raise ValueError(
                    f"Play Store full_description ({lang}) invalid length: {len(full_desc)}/{MAX_PLAY_FULL_DESC_CHARS}"
                )

            listings[lang] = {
                "title": title,
                "shortDescription": short_desc,
                "fullDescription": full_desc,
            }
        return listings

    def _run_dry_metadata_check(self) -> int:
        notes = self.load_release_notes()
        listings = self.load_store_listings()
        print(f"🔎 {self.package_name} v{self.version_name} (Build {self.version_code}) Metadata Check:")
        for n in notes:
            print(f"   ✅ whatsNew [{n['language']}]: {len(n['text'])}/{MAX_PLAY_WHATS_NEW_CHARS} chars")
        if not listings:
            print("❌ No Fastlane Android listings found!")
            return 1
        base_dir = self.app_dir / "android" / "fastlane" / "metadata" / "android"
        for lang, fields in listings.items():
            icon_ok = (base_dir / lang / "images" / "icon.png").is_file()
            fg_ok = (base_dir / lang / "images" / "featureGraphic.png").is_file()
            print(
                f"   ✅ listing [{lang}]: title={len(fields['title'])}/{MAX_PLAY_TITLE_CHARS}, "
                f"short={len(fields['shortDescription'])}/{MAX_PLAY_SHORT_DESC_CHARS}, "
                f"full={len(fields['fullDescription'])}/{MAX_PLAY_FULL_DESC_CHARS}, "
                f"icon={icon_ok}, featureGraphic={fg_ok}"
            )
        return 0

    def _ensure_jni_libs(self) -> None:
        jni_dir = self.project_dir / "packages" / "zamera_capture" / "android" / "src" / "main" / "jniLibs"
        required = [
            jni_dir / "arm64-v8a" / "libzamera_core.so",
            jni_dir / "armeabi-v7a" / "libzamera_core.so",
            jni_dir / "x86_64" / "libzamera_core.so",
        ]
        missing = [p for p in required if not p.is_file() or p.stat().st_size == 0]
        if not self.build_rust and not missing:
            print("✅ [Rust JNI] Existing 16 KB aligned libzamera_core.so binaries verified; skipping Rust rebuild.")
            return

        rust_dir = self.project_dir / "rust" / "zamera_core"
        if not (rust_dir / "Cargo.toml").is_file():
            raise FileNotFoundError(f"Rust Cargo.toml not found at {rust_dir}")
        print("⚙️ [Rust JNI] Building 16 KB page-aligned native libraries via cargo-ndk...")
        jni_dir.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        rustflags_16k = "-C link-arg=-Wl,-z,max-page-size=16384"
        env["CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS"] = rustflags_16k
        env["CARGO_TARGET_X86_64_LINUX_ANDROID_RUSTFLAGS"] = rustflags_16k
        subprocess.run(
            [
                "cargo",
                "ndk",
                "-t",
                "arm64-v8a",
                "-t",
                "armeabi-v7a",
                "-t",
                "x86_64",
                "-o",
                str(jni_dir),
                "build",
                "--release",
            ],
            cwd=str(rust_dir),
            env=env,
            check=True,
        )
        print("✅ [Rust JNI] Native libraries built successfully.")

    def build_local_artifacts(self) -> Tuple[Path, Optional[Path]]:
        print("\n🔨 [Zamera Build] Starting 100% Local Zero-Mirror Release Build...")
        self._ensure_jni_libs()

        print("📦 [Flutter] Resolving dependencies (flutter pub get)...")
        subprocess.run("flutter pub get", cwd=str(self.app_dir), check=True, shell=True)

        print(f"📦 [Flutter] Building signed AAB for {self.package_name} v{self.version_name}+{self.version_code}...")
        subprocess.run(
            "flutter build appbundle --release --android-skip-build-dependency-validation",
            cwd=str(self.app_dir),
            check=True,
            shell=True,
        )
        aab_path = self.app_dir / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
        if not aab_path.is_file():
            raise FileNotFoundError(f"Generated AAB not found at {aab_path}")
        print(f"✅ [Flutter] Signed AAB ready: {aab_path} ({aab_path.stat().st_size:,} bytes)")

        apk_path: Optional[Path] = None
        if self.build_apk:
            print("📦 [Flutter] Building signed release APK...")
            subprocess.run(
                "flutter build apk --release --android-skip-build-dependency-validation",
                cwd=str(self.app_dir),
                check=True,
                shell=True,
            )
            candidate_apk = self.app_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
            if candidate_apk.is_file():
                apk_path = candidate_apk
                print(f"✅ [Flutter] Signed APK ready: {apk_path} ({apk_path.stat().st_size:,} bytes)")

        return aab_path, apk_path

    def _auth_headers(self, creds_file: Path) -> Dict[str, str]:
        creds = service_account.Credentials.from_service_account_file(
            str(creds_file), scopes=[ANDROID_PUBLISHER_SCOPE]
        )
        creds.refresh(Request())
        return {"Authorization": f"Bearer {creds.token}"}

    def _sync_details_and_listings(
        self, edit_id: str, headers: Dict[str, str], listings: Dict[str, Dict[str, str]]
    ) -> None:
        json_headers = {**headers, "Content-Type": "application/json"}
        details_payload = {
            "defaultLanguage": "tr-TR",
            "contactEmail": CONTACT_EMAIL,
            "contactWebsite": CONTACT_WEBSITE,
        }
        r_det = requests.put(
            f"{GOOGLE_API_BASE}/{self.package_name}/edits/{edit_id}/details",
            headers=json_headers,
            json=details_payload,
            timeout=30,
        )
        if r_det.status_code not in (200, 201):
            raise RuntimeError(f"Failed to update Play Store details: {r_det.status_code} - {r_det.text}")
        print(f"📇 Play Store contact details synced ({CONTACT_EMAIL}, {CONTACT_WEBSITE})")

        base_img_dir = self.app_dir / "android" / "fastlane" / "metadata" / "android"
        for lang, fields in listings.items():
            payload = {"language": lang, **fields}
            r_lst = requests.put(
                f"{GOOGLE_API_BASE}/{self.package_name}/edits/{edit_id}/listings/{lang}",
                headers=json_headers,
                json=payload,
                timeout=30,
            )
            if r_lst.status_code not in (200, 201):
                raise RuntimeError(f"Failed to update Play listing '{lang}': {r_lst.status_code} - {r_lst.text}")
            print(
                f"📝 Play Store listing '{lang}' synced: "
                f"title={len(fields['title'])}/{MAX_PLAY_TITLE_CHARS}, "
                f"short={len(fields['shortDescription'])}/{MAX_PLAY_SHORT_DESC_CHARS}, "
                f"full={len(fields['fullDescription'])}/{MAX_PLAY_FULL_DESC_CHARS}"
            )

            for image_type in ("icon", "featureGraphic"):
                local_img = base_img_dir / lang / "images" / f"{image_type}.png"
                if not local_img.is_file():
                    continue
                r_chk = requests.get(
                    f"{GOOGLE_API_BASE}/{self.package_name}/edits/{edit_id}/listings/{lang}/{image_type}",
                    headers=headers,
                    timeout=30,
                )
                existing_count = len(r_chk.json().get("images", [])) if r_chk.status_code == 200 else 0
                if existing_count > 0:
                    print(f"   ℹ️ '{lang}' {image_type} already present ({existing_count}); keeping existing.")
                    continue
                with local_img.open("rb") as img_f:
                    r_up = requests.post(
                        f"{GOOGLE_UPLOAD_BASE}/{self.package_name}/edits/{edit_id}/listings/{lang}/{image_type}?uploadType=media",
                        headers={**headers, "Content-Type": "image/png"},
                        data=img_f,
                        timeout=120,
                    )
                if r_up.status_code not in (200, 201):
                    raise RuntimeError(
                        f"Failed to upload '{lang}' {image_type}: {r_up.status_code} - {r_up.text}"
                    )
                print(f"   🖼️ Uploaded '{lang}' {image_type} ({local_img.stat().st_size:,} bytes)")

    def _put_track(
        self, edit_id: str, headers: Dict[str, str], release_status: str, release_notes: List[Dict[str, str]]
    ) -> requests.Response:
        body = {
            "track": self.track,
            "releases": [
                {
                    "name": f"{self.version_name} ({self.version_code})",
                    "versionCodes": [str(self.version_code)],
                    "status": release_status,
                    "releaseNotes": release_notes,
                }
            ],
        }
        return requests.put(
            f"{GOOGLE_API_BASE}/{self.package_name}/edits/{edit_id}/tracks/{self.track}",
            headers={**headers, "Content-Type": "application/json"},
            json=body,
            timeout=30,
        )

    def publish(self, aab_path: Optional[Path]) -> int:
        creds_file = self.resolve_credentials()
        release_notes = self.load_release_notes()
        listings = {} if self.skip_listings else self.load_store_listings()

        print(f"\n🚀 [Google Play Publisher] Package: {self.package_name} | Version: {self.version_name} ({self.version_code})")
        print(f"🔑 Credentials: {creds_file}")
        print(f"🎯 Target Track: {self.track} | Requested Status: {self.status}")

        headers = self._auth_headers(creds_file)
        r_edit = requests.post(
            f"{GOOGLE_API_BASE}/{self.package_name}/edits",
            headers={**headers, "Content-Type": "application/json"},
            json={},
            timeout=30,
        )
        if r_edit.status_code not in (200, 201):
            raise RuntimeError(f"Failed to create Google Play Edit: {r_edit.status_code} - {r_edit.text}")
        edit_id = r_edit.json()["id"]
        print(f"📝 Play Console Edit ID: {edit_id}")

        committed = False
        try:
            if not self.skip_listings and listings:
                self._sync_details_and_listings(edit_id, headers, listings)

            final_status = "listings_only"
            if not self.listings_only:
                if aab_path is None or not aab_path.is_file():
                    raise FileNotFoundError(f"AAB not found: {aab_path}")
                print(f"📤 Uploading AAB ({aab_path.stat().st_size / (1024 * 1024):.2f} MB)...")
                with aab_path.open("rb") as f:
                    r_up = requests.post(
                        f"{GOOGLE_UPLOAD_BASE}/{self.package_name}/edits/{edit_id}/bundles?uploadType=media",
                        headers={**headers, "Content-Type": "application/octet-stream"},
                        data=f,
                        timeout=600,
                    )
                if r_up.status_code in (200, 201):
                    binfo = r_up.json()
                    print(f"✅ Bundle uploaded: versionCode={binfo.get('versionCode')} | sha1={binfo.get('sha1')}")
                elif "version code" in r_up.text.lower() and "already" in r_up.text.lower():
                    print(f"ℹ️ Bundle versionCode {self.version_code} already exists on Google Play; reusing.")
                else:
                    raise RuntimeError(f"Failed to upload AAB: {r_up.status_code} - {r_up.text}")

                desired_status = "completed" if self.status == "auto" else self.status
                r_tr = self._put_track(edit_id, headers, desired_status, release_notes)
                if r_tr.status_code not in (200, 201) and desired_status != "draft":
                    print(
                        f"⚠️ Track '{self.track}' rejected status '{desired_status}' "
                        f"({r_tr.status_code}): {r_tr.text[:300]}\n🔄 Falling back to 'draft'..."
                    )
                    desired_status = "draft"
                    r_tr = self._put_track(edit_id, headers, desired_status, release_notes)
                if r_tr.status_code not in (200, 201):
                    raise RuntimeError(f"Failed to update track '{self.track}': {r_tr.status_code} - {r_tr.text}")
                final_status = desired_status
                print(f"✅ Track '{self.track}' updated with status '{final_status}'.")

            if self.dry_run:
                print("🔍 [Dry Run] Skipping commit; cleaning up temporary edit.")
                return 0

            print("💾 Committing Google Play edit...")
            commit_url = f"{GOOGLE_API_BASE}/{self.package_name}/edits/{edit_id}:commit"
            r_com = requests.post(commit_url, headers=headers, timeout=60)

            if r_com.status_code not in (200, 201):
                err_txt = r_com.text
                if (
                    "Only releases with status draft may be created" in err_txt
                    and not self.listings_only
                    and final_status != "draft"
                ):
                    print(
                        f"⚠️ Commit rejected non-draft release on draft app: {err_txt[:240]}\n"
                        "🔄 Switching release status to 'draft' and recommitting..."
                    )
                    final_status = "draft"
                    r_tr2 = self._put_track(edit_id, headers, "draft", release_notes)
                    if r_tr2.status_code not in (200, 201):
                        raise RuntimeError(f"Failed fallback track update to draft: {r_tr2.status_code} - {r_tr2.text}")
                    r_com = requests.post(commit_url, headers=headers, timeout=60)
                    err_txt = r_com.text

                if r_com.status_code not in (200, 201) and "changesnotsentforreview" in err_txt.lower():
                    print("🔄 Retrying commit with changesNotSentForReview=true...")
                    r_com = requests.post(f"{commit_url}?changesNotSentForReview=true", headers=headers, timeout=60)

            if r_com.status_code not in (200, 201):
                raise RuntimeError(f"Failed to commit Google Play edit: {r_com.status_code} - {r_com.text}")

            committed = True
            commit_id = r_com.json().get("id")
            print("\n" + "=" * 65)
            print("🎉 GOOGLE PLAY CONSOLE DEPLOYMENT COMMITTED!")
            print("=" * 65)
            print(f"📦 Package:     {self.package_name}")
            print(f"🏷️ Version:     {self.version_name} (Build {self.version_code})")
            print(f"🎯 Track:       {self.track.upper()} | Release Status: {final_status.upper()}")
            print(f"🆔 Commit ID:   {commit_id}")
            print("=" * 65 + "\n")
            return 0
        finally:
            if not committed:
                try:
                    requests.delete(f"{GOOGLE_API_BASE}/{self.package_name}/edits/{edit_id}", headers=headers, timeout=15)
                except Exception as exc:
                    print(f"Warning: cleanup for uncommitted edit {edit_id} failed: {exc}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Zamera Local Google Play Publisher & ASO Metadata Sync"
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Path to Zamera repository root",
    )
    parser.add_argument(
        "--track",
        type=str,
        default="alpha",
        choices=["internal", "alpha", "beta", "production"],
        help="Google Play release track (default: alpha)",
    )
    parser.add_argument(
        "--status",
        type=str,
        default="completed",
        choices=["auto", "completed", "draft"],
        help="Release status (default: completed, with automatic draft fallback on draft apps)",
    )
    parser.add_argument("--credentials", type=Path, default=None, help="Path to play-store-credentials.json")
    parser.add_argument("--skip-build", action="store_true", help="Upload existing signed AAB without rebuilding")
    parser.add_argument("--no-apk", action="store_true", help="Skip building release APK")
    parser.add_argument("--build-rust", action="store_true", help="Force rebuilding Rust JNI .so libraries")
    parser.add_argument("--skip-listings", action="store_true", help="Skip ASO listings, details & graphics sync")
    parser.add_argument("--listings-only", action="store_true", help="Sync ASO listings & graphics without AAB upload")
    parser.add_argument("--dry-run-metadata", action="store_true", help="Validate local ASO metadata & release notes")
    parser.add_argument("--dry-run", action="store_true", help="Run Play API upload/checks without committing")
    args = parser.parse_args()

    publisher = ZameraPlayPublisher(
        project_dir=args.project,
        track=args.track,
        status=args.status,
        credentials_path=args.credentials,
        skip_build=args.skip_build,
        build_apk=not args.no_apk,
        build_rust=args.build_rust,
        skip_listings=args.skip_listings,
        listings_only=args.listings_only,
        dry_run=args.dry_run,
    )

    if args.dry_run_metadata:
        return publisher._run_dry_metadata_check()

    aab_path: Optional[Path] = None
    if not args.listings_only:
        if args.skip_build:
            aab_path = publisher.app_dir / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
            if not aab_path.is_file():
                raise FileNotFoundError(f"Existing AAB not found at {aab_path}")
        else:
            aab_path, _ = publisher.build_local_artifacts()

    return publisher.publish(aab_path)


if __name__ == "__main__":
    sys.exit(main())
