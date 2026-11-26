#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
App Store Connect & TestFlight Synchronization Script for Zamera (com.akarworks.zamera).
Extracted from .github/workflows/ios-release.yml for testability and maintainability.
"""

from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

import jwt
import requests


def main() -> int:
    key_id = os.environ["APP_STORE_KEY_ID"].strip()
    issuer_id = os.environ["APP_STORE_ISSUER_ID"].strip()
    private_key = os.environ["APP_STORE_PRIVATE_KEY"].strip()

    def make_headers() -> dict[str, str]:
        now = int(time.time())
        payload = {
            "iss": issuer_id,
            "iat": now - 30,
            "exp": now + 1100,
            "aud": "appstoreconnect-v1",
        }
        token = jwt.encode(
            payload,
            private_key,
            algorithm="ES256",
            headers={"kid": key_id, "typ": "JWT"},
        )
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    base_url = "https://api.appstoreconnect.apple.com/v1"
    support_url = "https://mehmetfethioglu.github.io/zamera-privacy/support.html"
    marketing_url = "https://mehmetfethioglu.github.io/zamera-privacy/indir.html"
    privacy_url = "https://mehmetfethioglu.github.io/zamera-privacy/"
    contact_email = "theakar@windowslive.com"

    repo_root = Path(".")
    pubspec_txt = (repo_root / "app" / "pubspec.yaml").read_text(encoding="utf-8")
    m_ver = re.search(
        r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)",
        pubspec_txt,
        re.MULTILINE,
    )
    if not m_ver:
        print("ERROR: version X.Y.Z+BUILD not found in app/pubspec.yaml")
        return 1
    version_str = m_ver.group(1)
    build_num = m_ver.group(2)
    print(f"Detected Zamera version: {version_str} (Build {build_num})")

    whats_new_tr = (
        f"Zamera v{version_str} Yenilikleri:\n"
        "• Zamera Pro (1 Ay Ücretsiz Deneme) & StoreKit 2: Yıllık Pro, Lansman Ömür Boyu ve Aylık planlar sıfır izleyiciyle eklendi.\n"
        "• Birleşik 4 Mod Stüdyosu: Sanat (ΔE00 ≤ 1.0), Pro DSLR, Portre ve 10-bit Pro Sinema Video tek uygulamada."
    )
    whats_new_en = (
        f"What's New in Zamera v{version_str}:\n"
        "• Zamera Pro (1-Month Free Trial) & StoreKit 2: Added Annual Pro, Launch Lifetime, and Monthly plans with zero third-party telemetry.\n"
        "• Unified 4-Mode Studio: Art Mode (ΔE00 ≤ 1.0), Pro DSLR, Portrait, and 10-bit Pro Cinema Video unified in one app."
    )
    notes_path = repo_root / "docs" / f"RELEASE_NOTES_v{version_str}_b{build_num}.md"
    if notes_path.is_file():
        notes_md = notes_path.read_text(encoding="utf-8")
        m_tr = re.search(r"### Türkçe \(tr\)\s*(.*?)(?=\n### |\Z)", notes_md, re.DOTALL)
        m_en = re.search(r"### English \(en-US\)\s*(.*?)(?=\n### |\Z)", notes_md, re.DOTALL)
        if m_tr and m_tr.group(1).strip():
            whats_new_tr = m_tr.group(1).strip()
        if m_en and m_en.group(1).strip():
            whats_new_en = m_en.group(1).strip()

    meta_root = repo_root / "app" / "ios" / "fastlane" / "metadata"
    ios_meta: dict[str, dict[str, str]] = {}
    for folder in ("tr", "en-US"):
        fdir = meta_root / folder
        if not fdir.is_dir():
            continue
        data: dict[str, str] = {}
        for fname in (
            "name.txt",
            "subtitle.txt",
            "keywords.txt",
            "promotional_text.txt",
            "description.txt",
        ):
            fpath = fdir / fname
            if fpath.is_file():
                data[fname.replace(".txt", "")] = fpath.read_text(encoding="utf-8").strip()
        if "name" in data and len(data["name"]) > 30:
            raise ValueError(f"iOS name ({folder}) exceeds 30 chars: {len(data['name'])}")
        if "subtitle" in data and len(data["subtitle"]) > 30:
            raise ValueError(f"iOS subtitle ({folder}) exceeds 30 chars: {len(data['subtitle'])}")
        if "keywords" in data and len(data["keywords"].encode("utf-8")) > 100:
            raise ValueError(f"iOS keywords ({folder}) exceed 100 UTF-8 bytes")
        if "promotional_text" in data and len(data["promotional_text"]) > 170:
            raise ValueError(f"iOS promotional_text ({folder}) exceeds 170 chars")
        if "description" in data and len(data["description"]) > 4000:
            raise ValueError(f"iOS description ({folder}) exceeds 4000 chars")
        ios_meta[folder] = data

    # 1. Lookup Zamera App ID
    r = requests.get(
        f"{base_url}/apps?filter[bundleId]=com.akarworks.zamera",
        headers=make_headers(),
        timeout=30,
    )
    r.raise_for_status()
    apps = r.json().get("data", [])
    if not apps:
        print("App com.akarworks.zamera not yet found via apps endpoint.")
        return 0
    app_id = apps[0]["id"]
    print(f"Found Zamera App ID: {app_id}")

    # 2. Ensure App Store Version matches version_str
    r = requests.get(
        f"{base_url}/apps/{app_id}/appStoreVersions?filter[platform]=IOS",
        headers=make_headers(),
        timeout=30,
    )
    r.raise_for_status()
    versions = r.json().get("data", [])
    target_version_id = None
    editable_version = None

    for v in versions:
        v_str = v["attributes"]["versionString"]
        v_state = v["attributes"]["appStoreState"]
        print(f"  Existing version: {v_str} (state: {v_state}, id: {v['id']})")
        if v_str == version_str:
            target_version_id = v["id"]
            break
        if v_state in (
            "PREPARE_FOR_SUBMISSION",
            "DEVELOPER_REJECTED",
            "REJECTED",
            "METADATA_REJECTED",
            "WAITING_FOR_REVIEW",
            "INVALID_BINARY",
        ):
            editable_version = v

    if not target_version_id and editable_version:
        target_version_id = editable_version["id"]
        if editable_version["attributes"]["appStoreState"] == "WAITING_FOR_REVIEW":
            sub_r = requests.get(
                f"{base_url}/apps/{app_id}/reviewSubmissions?filter[platform]=IOS&filter[state]=WAITING_FOR_REVIEW",
                headers=make_headers(),
                timeout=30,
            )
            if sub_r.status_code == 200:
                for sub in sub_r.json().get("data", []):
                    sub_id = sub["id"]
                    cancel_r = requests.patch(
                        f"{base_url}/reviewSubmissions/{sub_id}",
                        headers=make_headers(),
                        json={
                            "data": {
                                "type": "reviewSubmissions",
                                "id": sub_id,
                                "attributes": {"canceled": True},
                            }
                        },
                        timeout=30,
                    )
                    print(f"Canceled pending reviewSubmission {sub_id}: status {cancel_r.status_code}")
                if sub_r.json().get("data"):
                    time.sleep(3)
        up = requests.patch(
            f"{base_url}/appStoreVersions/{target_version_id}",
            headers=make_headers(),
            json={
                "data": {
                    "type": "appStoreVersions",
                    "id": target_version_id,
                    "attributes": {"versionString": version_str},
                }
            },
            timeout=30,
        )
        print("Update versionString status:", up.status_code)

    if not target_version_id:
        cr = requests.post(
            f"{base_url}/appStoreVersions",
            headers=make_headers(),
            json={
                "data": {
                    "type": "appStoreVersions",
                    "attributes": {
                        "platform": "IOS",
                        "versionString": version_str,
                        "releaseType": "AFTER_APPROVAL",
                    },
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
            timeout=30,
        )
        if cr.status_code in (200, 201):
            target_version_id = cr.json()["data"]["id"]
            print("Created App Store Version:", version_str)
        else:
            print("Could not create new App Store Version:", cr.status_code, cr.text[:300])

    # 2B. Sync App-level Name & Subtitle via editable appInfoLocalizations
    if ios_meta:
        ai_res = requests.get(f"{base_url}/apps/{app_id}/appInfos", headers=make_headers(), timeout=30)
        if ai_res.status_code == 200:
            app_infos = ai_res.json().get("data", [])
            editable_states = {
                "PREPARE_FOR_SUBMISSION",
                "WAITING_FOR_REVIEW",
                "DEVELOPER_REJECTED",
                "REJECTED",
                "METADATA_REJECTED",
            }
            chosen_info = next(
                (a for a in app_infos if a.get("attributes", {}).get("appStoreState") in editable_states),
                app_infos[0] if app_infos else None,
            )
            if chosen_info:
                ai_id = chosen_info["id"]
                ail_res = requests.get(
                    f"{base_url}/appInfos/{ai_id}/appInfoLocalizations",
                    headers=make_headers(),
                    timeout=30,
                )
                existing_ai_locs: dict[str, str] = {}
                if ail_res.status_code == 200:
                    for loc in ail_res.json().get("data", []):
                        existing_ai_locs[loc["attributes"]["locale"]] = loc["id"]
                for folder, target_locale in (("tr", "tr"), ("en-US", "en-US")):
                    if folder not in ios_meta:
                        continue
                    mf = ios_meta[folder]
                    attrs: dict[str, str] = {}
                    if mf.get("name"):
                        attrs["name"] = mf["name"]
                    if mf.get("subtitle"):
                        attrs["subtitle"] = mf["subtitle"]
                    if not attrs:
                        continue
                    loc_id = existing_ai_locs.get(target_locale)
                    if not loc_id and target_locale == "en-US":
                        loc_id = existing_ai_locs.get("en-GB")
                    if loc_id:
                        pr_info = requests.patch(
                            f"{base_url}/appInfoLocalizations/{loc_id}",
                            headers=make_headers(),
                            json={"data": {"type": "appInfoLocalizations", "id": loc_id, "attributes": attrs}},
                            timeout=30,
                        )
                        print(f"Patched appInfoLocalization '{target_locale}': status {pr_info.status_code}")
                    else:
                        cr_info = requests.post(
                            f"{base_url}/appInfoLocalizations",
                            headers=make_headers(),
                            json={
                                "data": {
                                    "type": "appInfoLocalizations",
                                    "attributes": {"locale": target_locale, **attrs},
                                    "relationships": {"appInfo": {"data": {"type": "appInfos", "id": ai_id}}},
                                }
                            },
                            timeout=30,
                        )
                        print(f"Created appInfoLocalization '{target_locale}': status {cr_info.status_code}")

    # 3. Sync Version Localizations (whatsNew + ASO fields + URLs)
    if target_version_id:
        loc_r = requests.get(
            f"{base_url}/appStoreVersions/{target_version_id}/appStoreVersionLocalizations",
            headers=make_headers(),
            timeout=30,
        )
        existing_vlocs: dict[str, str] = {}
        if loc_r.status_code == 200:
            for loc in loc_r.json().get("data", []):
                existing_vlocs[loc["attributes"]["locale"]] = loc["id"]

        for folder, target_locale in (("tr", "tr"), ("en-US", "en-US")):
            mf = ios_meta.get(folder, {})
            attrs = {
                "whatsNew": whats_new_tr if folder == "tr" else whats_new_en,
                "supportUrl": support_url,
                "marketingUrl": marketing_url,
            }
            if mf.get("keywords"):
                attrs["keywords"] = mf["keywords"]
            if mf.get("promotional_text"):
                attrs["promotionalText"] = mf["promotional_text"]
            if mf.get("description"):
                attrs["description"] = mf["description"]

            loc_id = existing_vlocs.get(target_locale)
            if loc_id:
                pr = requests.patch(
                    f"{base_url}/appStoreVersionLocalizations/{loc_id}",
                    headers=make_headers(),
                    json={"data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": attrs}},
                    timeout=30,
                )
                print(f"Patched version localization '{target_locale}': status {pr.status_code}")
                if pr.status_code == 409:
                    attrs_no_wn = {k: v for k, v in attrs.items() if k != "whatsNew"}
                    pr2 = requests.patch(
                        f"{base_url}/appStoreVersionLocalizations/{loc_id}",
                        headers=make_headers(),
                        json={"data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": attrs_no_wn}},
                        timeout=30,
                    )
                    print(f"Retried '{target_locale}' without whatsNew: status {pr2.status_code}")
            else:
                cr_loc = requests.post(
                    f"{base_url}/appStoreVersionLocalizations",
                    headers=make_headers(),
                    json={
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "attributes": {"locale": target_locale, **attrs},
                            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": target_version_id}}},
                        }
                    },
                    timeout=30,
                )
                if cr_loc.status_code == 409:
                    attrs_no_wn = {k: v for k, v in attrs.items() if k != "whatsNew"}
                    cr_loc = requests.post(
                        f"{base_url}/appStoreVersionLocalizations",
                        headers=make_headers(),
                        json={
                            "data": {
                                "type": "appStoreVersionLocalizations",
                                "attributes": {"locale": target_locale, **attrs_no_wn},
                                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": target_version_id}}},
                            }
                        },
                        timeout=30,
                    )
                print(f"Created version localization '{target_locale}': status {cr_loc.status_code}")

    # 4. Sync Beta TestFlight Testers -> Zamera External Beta Group
    zamera_beta_group_id = None
    try:
        zr = requests.get(
            f"{base_url}/apps?filter[bundleId]=com.akarworks.zikirce",
            headers=make_headers(),
            timeout=30,
        )
        source_apps = zr.json().get("data", []) if zr.status_code == 200 else []
        tester_ids: set[str] = set()
        if source_apps:
            source_app_id = source_apps[0]["id"]
            next_url: str | None = f"{base_url}/betaTesters?filter[apps]={source_app_id}&limit=200"
            while next_url:
                tr_resp = requests.get(next_url, headers=make_headers(), timeout=30)
                if tr_resp.status_code != 200:
                    print(f"betaTesters query status {tr_resp.status_code}: {tr_resp.text[:200]}")
                    break
                tr_json = tr_resp.json()
                for t in tr_json.get("data", []):
                    tester_ids.add(t["id"])
                next_url = tr_json.get("links", {}).get("next")

            bg_resp = requests.get(f"{base_url}/apps/{source_app_id}/betaGroups?limit=50", headers=make_headers(), timeout=30)
            if bg_resp.status_code == 200:
                for grp in bg_resp.json().get("data", []):
                    g_next: str | None = f"{base_url}/betaGroups/{grp['id']}/betaTesters?limit=200"
                    while g_next:
                        gt = requests.get(g_next, headers=make_headers(), timeout=30)
                        if gt.status_code != 200:
                            break
                        gt_json = gt.json()
                        for t in gt_json.get("data", []):
                            tester_ids.add(t["id"])
                        g_next = gt_json.get("links", {}).get("next")
            print(f"Collected {len(tester_ids)} unique TestFlight tester(s).")

        z_groups_r = requests.get(f"{base_url}/apps/{app_id}/betaGroups?limit=50", headers=make_headers(), timeout=30)
        if z_groups_r.status_code == 200:
            for grp in z_groups_r.json().get("data", []):
                if grp["attributes"].get("name") == "Zikirce Testers":
                    zamera_beta_group_id = grp["id"]
                    break
        if not zamera_beta_group_id:
            cr_grp = requests.post(
                f"{base_url}/betaGroups",
                headers=make_headers(),
                json={
                    "data": {
                        "type": "betaGroups",
                        "attributes": {
                            "name": "Zikirce Testers",
                            "isInternalGroup": False,
                            "publicLinkEnabled": True,
                            "feedbackEnabled": True,
                        },
                        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                    }
                },
                timeout=30,
            )
            if cr_grp.status_code in (200, 201):
                zamera_beta_group_id = cr_grp.json()["data"]["id"]
                print(f"Created external TestFlight group ({zamera_beta_group_id})")
            else:
                print(f"Could not create external betaGroup: {cr_grp.status_code} {cr_grp.text[:240]}")

        if zamera_beta_group_id and tester_ids:
            tid_list = sorted(tester_ids)
            synced_count = 0
            for i in range(0, len(tid_list), 50):
                chunk = tid_list[i:i + 50]
                add_r = requests.post(
                    f"{base_url}/betaGroups/{zamera_beta_group_id}/relationships/betaTesters",
                    headers=make_headers(),
                    json={"data": [{"type": "betaTesters", "id": tid} for tid in chunk]},
                    timeout=30,
                )
                if add_r.status_code in (200, 201, 204):
                    synced_count += len(chunk)
                else:
                    for tid in chunk:
                        one_r = requests.post(
                            f"{base_url}/betaGroups/{zamera_beta_group_id}/relationships/betaTesters",
                            headers=make_headers(),
                            json={"data": [{"type": "betaTesters", "id": tid}]},
                            timeout=30,
                        )
                        if one_r.status_code in (200, 201, 204):
                            synced_count += 1
            print(f"Synced {synced_count}/{len(tid_list)} TestFlight testers into beta group.")

        bal_r = requests.get(f"{base_url}/apps/{app_id}/betaAppLocalizations", headers=make_headers(), timeout=30)
        existing_bal = {loc["attributes"]["locale"]: loc["id"] for loc in bal_r.json().get("data", [])} if bal_r.status_code == 200 else {}
        for folder, b_loc in (("tr", "tr"), ("en-US", "en-US")):
            desc_txt = ios_meta.get(folder, {}).get("description", whats_new_en)
            bal_attrs = {
                "feedbackEmail": contact_email,
                "privacyPolicyUrl": privacy_url,
                "description": desc_txt[:4000],
            }
            if b_loc in existing_bal:
                requests.patch(
                    f"{base_url}/betaAppLocalizations/{existing_bal[b_loc]}",
                    headers=make_headers(),
                    json={"data": {"type": "betaAppLocalizations", "id": existing_bal[b_loc], "attributes": bal_attrs}},
                    timeout=30,
                )
            else:
                requests.post(
                    f"{base_url}/betaAppLocalizations",
                    headers=make_headers(),
                    json={
                        "data": {
                            "type": "betaAppLocalizations",
                            "attributes": {"locale": b_loc, **bal_attrs},
                            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                        }
                    },
                    timeout=30,
                )

        bard_r = requests.get(f"{base_url}/apps/{app_id}/betaAppReviewDetail", headers=make_headers(), timeout=30)
        if bard_r.status_code == 200 and bard_r.json().get("data"):
            bard_id = bard_r.json()["data"]["id"]
            requests.patch(
                f"{base_url}/betaAppReviewDetails/{bard_id}",
                headers=make_headers(),
                json={
                    "data": {
                        "type": "betaAppReviewDetails",
                        "id": bard_id,
                        "attributes": {
                            "contactEmail": contact_email,
                            "contactFirstName": "Mehmet",
                            "contactLastName": "Fethioglu",
                            "demoAccountRequired": False,
                        },
                    }
                },
                timeout=30,
            )
    except Exception as exc:
        print(f"TestFlight tester/metadata sync warning: {exc}")

    # 5. Wait for target Build to finish Apple processing
    build_id = None
    for attempt in range(28):
        br = requests.get(
            f"{base_url}/builds?filter[app]={app_id}&filter[version]={build_num}&sort=-uploadedDate&limit=5",
            headers=make_headers(),
            timeout=30,
        )
        if br.status_code == 200 and br.json().get("data"):
            b = br.json()["data"][0]
            state = b["attributes"].get("processingState")
            print(f"Build {build_num} found (id: {b['id']}, state: {state})")
            if state == "VALID":
                build_id = b["id"]
                break
            if state in ("FAILED", "INVALID"):
                print(f"Build {build_num} state is {state}")
                break
        else:
            print(f"Attempt {attempt + 1}/28: Build {build_num} processing on Apple TestFlight, waiting 25s...")
        time.sleep(25)

    if build_id:
        requests.patch(
            f"{base_url}/builds/{build_id}",
            headers=make_headers(),
            json={"data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}},
            timeout=30,
        )
        print(f"Export compliance set (usesNonExemptEncryption=False) for Build {build_num} ({build_id})")

        try:
            bloc_r = requests.get(f"{base_url}/builds/{build_id}/betaBuildLocalizations", headers=make_headers(), timeout=30)
            existing_locs = {loc["attributes"]["locale"]: loc["id"] for loc in bloc_r.json().get("data", [])} if bloc_r.status_code == 200 else {}
            for loc_code, loc_text in [("tr", whats_new_tr), ("en-US", whats_new_en)]:
                if loc_code in existing_locs:
                    requests.patch(
                        f"{base_url}/betaBuildLocalizations/{existing_locs[loc_code]}",
                        headers=make_headers(),
                        json={"data": {"type": "betaBuildLocalizations", "id": existing_locs[loc_code], "attributes": {"whatsNew": loc_text}}},
                        timeout=30,
                    )
                else:
                    requests.post(
                        f"{base_url}/betaBuildLocalizations",
                        headers=make_headers(),
                        json={"data": {"type": "betaBuildLocalizations", "attributes": {"locale": loc_code, "whatsNew": loc_text}, "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}},
                        timeout=30,
                    )
            print(f"TestFlight betaBuildLocalizations synced for Build {build_num}")
        except Exception as exc:
            print("Beta build localization note:", exc)

        if zamera_beta_group_id:
            grp_build_r = requests.post(
                f"{base_url}/betaGroups/{zamera_beta_group_id}/relationships/builds",
                headers=make_headers(),
                json={"data": [{"type": "builds", "id": build_id}]},
                timeout=30,
            )
            print(f"Assigned Build {build_num} to external beta group: status {grp_build_r.status_code}")
            beta_sub_r = requests.post(
                f"{base_url}/betaAppReviewSubmissions",
                headers=make_headers(),
                json={"data": {"type": "betaAppReviewSubmissions", "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}},
                timeout=30,
            )
            print(f"TestFlight Beta App Review submission status: {beta_sub_r.status_code} {beta_sub_r.text[:200]}")

        if target_version_id:
            att = requests.patch(
                f"{base_url}/appStoreVersions/{target_version_id}/relationships/build",
                headers=make_headers(),
                json={"data": {"type": "builds", "id": build_id}},
                timeout=30,
            )
            print(f"Attached Build {build_num} to Version {version_str}: status {att.status_code}")
            sub_create = requests.post(
                f"{base_url}/reviewSubmissions",
                headers=make_headers(),
                json={
                    "data": {
                        "type": "reviewSubmissions",
                        "attributes": {"platform": "IOS"},
                        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                    }
                },
                timeout=30,
            )
            if sub_create.status_code in (200, 201):
                sub_id = sub_create.json()["data"]["id"]
                requests.post(
                    f"{base_url}/reviewSubmissionItems",
                    headers=make_headers(),
                    json={
                        "data": {
                            "type": "reviewSubmissionItems",
                            "relationships": {
                                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": target_version_id}},
                            },
                        }
                    },
                    timeout=30,
                )
                confirm = requests.patch(
                    f"{base_url}/reviewSubmissions/{sub_id}",
                    headers=make_headers(),
                    json={"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}},
                    timeout=30,
                )
                print("App Store Review submission status:", confirm.status_code, confirm.text[:300])
            else:
                print("App Store reviewSubmissions note:", sub_create.status_code, sub_create.text[:300])
    else:
        print(f"Build {build_num} is uploaded and continuing Apple TestFlight background processing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
