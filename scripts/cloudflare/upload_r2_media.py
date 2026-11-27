"""Parallel uploader for Kilerce 23,933 WebP recipe images to Cloudflare R2."""
import argparse
import os
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

DEFAULT_MEDIA_DIR = Path(r"G:\Drive'ım\Kilerce_Recipe_Covers\photo_webp_v2")
DEFAULT_CHECKPOINT = Path(r"c:\Users\theak\Downloads\ym\r2_uploaded_keys.txt")


def build_key(media_dir: Path, file_path: Path) -> str:
    rel = file_path.relative_to(media_dir).as_posix()
    return f"photo_webp_v2/{rel}"


def collect_media_files(media_dir: Path) -> list[tuple[Path, str]]:
    if not media_dir.exists():
        raise FileNotFoundError(f"Media directory not found: {media_dir}")
    pairs = [(p, build_key(media_dir, p)) for p in sorted(media_dir.rglob("*.webp"))]
    if not pairs:
        raise RuntimeError(f"No .webp files found under {media_dir}")
    return pairs


def load_checkpoint(cp_path: Path) -> set[str]:
    if not cp_path.exists():
        return set()
    return {line.strip() for line in cp_path.read_text(encoding="utf-8").splitlines() if line.strip()}


def upload_to_r2(
    pairs: list[tuple[Path, str]],
    checkpoint_path: Path,
    bucket: str,
    account_id: str,
    access_key: str,
    secret_key: str,
    workers: int,
) -> None:
    try:
        import boto3
        from botocore.config import Config
    except ImportError as exc:
        raise RuntimeError("boto3 kurulu degil. Yuklemek icin: pip install boto3") from exc

    done_keys = load_checkpoint(checkpoint_path)
    pending = [(p, k) for p, k in pairs if k not in done_keys]
    print(f"Toplam: {len(pairs):,} | Onceden yuklenen: {len(done_keys):,} | Kalan: {len(pending):,}")
    if not pending:
        print("R2_UPLOAD_COMPLETE (tum dosyalar zaten yuklu)")
        return

    endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"
    client_cfg = Config(max_pool_connections=max(16, workers * 2), retries={"max_attempts": 5, "mode": "standard"})
    thread_local = threading.local()
    lock = threading.Lock()
    uploaded = 0
    failed = 0

    def get_client():
        if not hasattr(thread_local, "s3"):
            thread_local.s3 = boto3.client(
                "s3",
                endpoint_url=endpoint_url,
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key,
                region_name="auto",
                config=client_cfg,
            )
        return thread_local.s3

    def upload_one(item: tuple[Path, str]) -> str:
        local_path, object_key = item
        s3 = get_client()
        s3.upload_file(
            str(local_path),
            bucket,
            object_key,
            ExtraArgs={
                "ContentType": "image/webp",
                "CacheControl": "public, max-age=31536000, immutable",
            },
        )
        return object_key

    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    with checkpoint_path.open("a", encoding="utf-8") as cp_f, ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(upload_one, item): item[1] for item in pending}
        for fut in as_completed(futures):
            obj_key = futures[fut]
            try:
                done_key = fut.result()
                with lock:
                    cp_f.write(done_key + "\n")
                    uploaded += 1
                    if uploaded % 250 == 0 or uploaded == len(pending):
                        cp_f.flush()
                        print(f"Yuklenen: {uploaded:,}/{len(pending):,} | Hata: {failed}", flush=True)
            except Exception as exc:
                with lock:
                    failed += 1
                    print(f"UPLOAD_ERR {obj_key}: {exc}", flush=True)

    if failed > 0:
        raise RuntimeError(f"R2 upload finished with {failed} failures. Re-run to resume remaining keys.")
    print(f"R2_UPLOAD_COMPLETE uploaded={uploaded}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload Kilerce WebP images to Cloudflare R2.")
    parser.add_argument("--media-dir", type=Path, default=DEFAULT_MEDIA_DIR)
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--bucket", default=os.environ.get("R2_BUCKET", "kilerce-recipe-media"))
    parser.add_argument("--workers", type=int, default=24)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    pairs = collect_media_files(args.media_dir)
    if args.dry_run:
        total_mb = sum(p.stat().st_size for p, _ in pairs) / (1024 ** 2)
        print(f"R2_DRY_RUN_OK files={len(pairs)} total_mb={total_mb:.2f} sample_keys={[k for _, k in pairs[:3]]}")
        return

    account_id = os.environ.get("CF_ACCOUNT_ID", "").strip()
    access_key = os.environ.get("R2_ACCESS_KEY_ID", "").strip()
    secret_key = os.environ.get("R2_SECRET_ACCESS_KEY", "").strip()
    if not account_id or not access_key or not secret_key:
        raise RuntimeError(
            "Eksik R2 kimlik bilgileri. Env tanimlayin: CF_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY"
        )

    upload_to_r2(pairs, args.checkpoint, args.bucket, account_id, access_key, secret_key, args.workers)


if __name__ == "__main__":
    main()
