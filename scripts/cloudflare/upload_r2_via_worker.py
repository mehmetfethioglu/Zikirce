"""Parallel R2 image uploader using the temporary authenticated Worker batch endpoint."""
import argparse
import base64
import json
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

DEFAULT_MEDIA_DIR = Path(r"G:\Drive'ım\Kilerce_Recipe_Covers\photo_webp_v2")
DEFAULT_CHECKPOINT = Path(r"c:\Users\theak\Downloads\ym\r2_uploaded_keys.txt")
DEFAULT_SECRETS_FILE = Path(__file__).resolve().parents[2] / "edge_worker" / ".secrets.local.env"
DEFAULT_ENDPOINT = "https://kilerce-edge-api.kilerce.workers.dev/api/internal/r2-batch"


def read_upload_secret(secrets_file: Path) -> str:
    if not secrets_file.exists():
        raise FileNotFoundError(f"Secrets file not found: {secrets_file}")
    for line in secrets_file.read_text(encoding="utf-8").splitlines():
        if line.startswith("MEDIA_SIGNING_SECRET="):
            val = line.split("=", 1)[1].strip()
            if val:
                return val
    raise RuntimeError("MEDIA_SIGNING_SECRET not found in .secrets.local.env")


def collect_pairs(media_dir: Path) -> list[tuple[Path, str]]:
    if not media_dir.exists():
        raise FileNotFoundError(f"Media directory not found: {media_dir}")
    return [
        (p, f"photo_webp_v2/{p.relative_to(media_dir).as_posix()}")
        for p in sorted(media_dir.rglob("*.webp"))
    ]


def load_checkpoint(cp_path: Path) -> set[str]:
    if not cp_path.exists():
        return set()
    return {line.strip() for line in cp_path.read_text(encoding="utf-8").splitlines() if line.strip()}


def post_batch(endpoint: str, secret: str, batch: list[tuple[Path, str]]) -> list[str]:
    items = [
        {
            "key": key,
            "b64": base64.b64encode(path.read_bytes()).decode("ascii"),
        }
        for path, key in batch
    ]
    payload = json.dumps({"items": items}).encode("utf-8")
    req = urllib.request.Request(
        endpoint,
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Kilerce-R2-Uploader/1.0",
            "X-Internal-Upload-Secret": secret,
        },
    )
    last_err: Exception | None = None
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                if resp.status == 200:
                    return [key for _, key in batch]
                raise RuntimeError(f"Unexpected HTTP {resp.status}")
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, RuntimeError) as exc:
            last_err = exc
            if attempt < 3:
                time.sleep(2 * attempt)
    raise RuntimeError(f"Batch upload failed after 3 attempts: {last_err}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload 23,933 Kilerce WebP images to R2 via Worker batch endpoint.")
    parser.add_argument("--media-dir", type=Path, default=DEFAULT_MEDIA_DIR)
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--secrets-file", type=Path, default=DEFAULT_SECRETS_FILE)
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--batch-size", type=int, default=20)
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args()

    secret = read_upload_secret(args.secrets_file)
    pairs = collect_pairs(args.media_dir)
    done_keys = load_checkpoint(args.checkpoint)
    pending = [(p, k) for p, k in pairs if k not in done_keys]

    print(f"Toplam: {len(pairs):,} | Onceden yuklenen: {len(done_keys):,} | Kalan: {len(pending):,}", flush=True)
    if not pending:
        print("R2_WORKER_UPLOAD_COMPLETE total=0")
        return

    batches = [pending[i : i + args.batch_size] for i in range(0, len(pending), args.batch_size)]
    lock = threading.Lock()
    uploaded = 0
    failed = 0
    t_start = time.time()

    args.checkpoint.parent.mkdir(parents=True, exist_ok=True)
    with args.checkpoint.open("a", encoding="utf-8") as cp_f, ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(post_batch, args.endpoint, secret, b): len(b) for b in batches}
        for idx, fut in enumerate(as_completed(futures), start=1):
            try:
                keys = fut.result()
                with lock:
                    for k in keys:
                        cp_f.write(k + "\n")
                    cp_f.flush()
                    uploaded += len(keys)
                    if idx % 25 == 0 or idx == len(batches):
                        elapsed = max(0.1, time.time() - t_start)
                        rate = uploaded / elapsed
                        eta_min = (len(pending) - uploaded) / max(0.1, rate) / 60
                        print(
                            f"[{uploaded:,}/{len(pending):,}] Hiz: {rate:.1f} gorsel/sn | ETA: {eta_min:.1f} dk | Hata: {failed}",
                            flush=True,
                        )
            except Exception as exc:
                with lock:
                    failed += futures[fut]
                    print(f"BATCH_ERR: {exc}", flush=True)

    if failed > 0:
        raise RuntimeError(f"R2 upload finished with {failed} failed items. Re-run to resume.")
    print(f"R2_WORKER_UPLOAD_COMPLETE uploaded={uploaded:,}")


if __name__ == "__main__":
    main()
