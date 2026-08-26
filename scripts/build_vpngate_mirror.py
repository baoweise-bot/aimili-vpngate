#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR))

import snapshot_utils


DEFAULT_SOURCE = "https://www.vpngate.net/api/iphone/"


def fetch_snapshot(url: str, timeout: int) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "AimiliVPN-Mirror/1.0",
            "Accept": "text/plain,*/*",
        },
    )
    chunks: list[bytes] = []
    total = 0
    with urllib.request.urlopen(request, timeout=timeout) as response:
        if getattr(response, "status", 200) != 200:
            raise RuntimeError(f"VPNGate returned HTTP {response.status}")
        while True:
            chunk = response.read(65536)
            if not chunk:
                break
            total += len(chunk)
            if total > snapshot_utils.MAX_SNAPSHOT_BYTES:
                raise RuntimeError("VPNGate response exceeds the size limit")
            chunks.append(chunk)
    return b"".join(chunks).decode("utf-8", errors="strict")


def atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_bytes(content)
    temp_path.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build a validated VPNGate mirror snapshot")
    parser.add_argument("--output-dir", default="mirror")
    parser.add_argument("--source", default=os.environ.get("VPNGATE_API_HTTPS_URL", DEFAULT_SOURCE))
    parser.add_argument("--timeout", type=int, default=20)
    args = parser.parse_args()

    text = fetch_snapshot(args.source, args.timeout)
    summary = snapshot_utils.snapshot_summary(text)
    encoded = text.encode("utf-8")
    now = time.time()
    metadata = {
        "schema_version": 1,
        "source": args.source,
        "generated_at": now,
        "generated_at_iso": datetime.fromtimestamp(now, timezone.utc).isoformat(),
        "row_count": summary["row_count"],
        "byte_count": summary["byte_count"],
        "sha256": hashlib.sha256(encoded).hexdigest(),
    }

    output_dir = Path(args.output_dir).resolve()
    atomic_write(output_dir / "vpngate.csv", encoded)
    atomic_write(
        output_dir / "vpngate.meta.json",
        (json.dumps(metadata, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
    )
    print(json.dumps(metadata, ensure_ascii=False))


if __name__ == "__main__":
    main()
