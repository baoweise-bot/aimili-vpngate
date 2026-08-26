#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tarfile
import tempfile
from pathlib import Path


TARGETS = {
    "amd64": {"cpu": "x86_64 / x64", "docker_platform": "linux/amd64"},
    "386": {"cpu": "x86 / i386 32-bit", "docker_platform": "linux/386"},
    "arm64": {"cpu": "ARM64 / AArch64", "docker_platform": "linux/arm64"},
    "armv7": {"cpu": "ARMv7 32-bit", "docker_platform": "linux/arm/v7"},
}

RELEASE_FILES = [
    "VERSION",
    "README.md",
    "RELEASE_NOTES.md",
    "LICENSE",
    "install.sh",
    "vpngate_manager.py",
    "vpn_utils.py",
    "proxy_server.py",
    "snapshot_utils.py",
    "Dockerfile",
    "compose.yaml",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_archives(root: Path, output_dir: Path) -> list[Path]:
    version = (root / "VERSION").read_text(encoding="utf-8").strip()
    version_parts = version.split(".")
    if len(version_parts) not in (2, 3) or any(not part.isdigit() for part in version_parts):
        raise ValueError("VERSION 必须是点分隔的数字版本号")

    missing = [name for name in RELEASE_FILES if not (root / name).is_file()]
    if missing:
        raise FileNotFoundError(f"发行文件缺失: {', '.join(missing)}")
    if not (root / "mirror").is_dir():
        raise FileNotFoundError("发行文件缺失: mirror")

    output_dir.mkdir(parents=True, exist_ok=True)
    archives: list[Path] = []
    with tempfile.TemporaryDirectory(prefix="aimilivpn-release-") as temp_name:
        temp_root = Path(temp_name)
        for architecture, metadata in TARGETS.items():
            package_name = f"aimilivpn-v{version}-linux-{architecture}"
            package_root = temp_root / package_name
            package_root.mkdir()

            for name in RELEASE_FILES:
                shutil.copy2(root / name, package_root / name)
            shutil.copytree(root / "mirror", package_root / "mirror")
            build_info = {
                "product": "AimiliVPN",
                "version": version,
                "release": f"V{'.'.join(version.split('.')[:2])} 正式版",
                "branch": "main",
                "operating_system": "Linux",
                "architecture": architecture,
                **metadata,
                "supported_distributions": [
                    "Debian",
                    "Ubuntu",
                    "CentOS",
                    "RHEL",
                    "Rocky Linux",
                    "AlmaLinux",
                    "Fedora",
                    "Oracle Linux",
                    "Amazon Linux",
                    "Alpine Linux",
                ],
            }
            (package_root / "BUILD_INFO.json").write_text(
                json.dumps(build_info, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

            archive_path = output_dir / f"{package_name}.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                archive.add(package_root, arcname=package_name)
            archives.append(archive_path)

    checksum_lines = [f"{sha256(path)}  {path.name}" for path in archives]
    checksum_path = output_dir / "sha256sums.txt"
    checksum_path.write_text("\n".join(checksum_lines) + "\n", encoding="ascii")
    return archives


def main() -> int:
    parser = argparse.ArgumentParser(description="构建 AimiliVPN Linux 多架构发行包")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output-dir", type=Path, default=Path("dist"))
    args = parser.parse_args()

    archives = build_archives(args.root.resolve(), args.output_dir.resolve())
    for archive in archives:
        print(archive)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
