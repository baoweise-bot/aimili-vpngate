from __future__ import annotations

import base64
import csv
import io
import re
from typing import Any


MAX_SNAPSHOT_BYTES = 12 * 1024 * 1024
MAX_CONFIG_BYTES = 128 * 1024

REQUIRED_COLUMNS = {
    "HostName",
    "IP",
    "Score",
    "Ping",
    "Speed",
    "CountryLong",
    "CountryShort",
    "NumVpnSessions",
    "OpenVPN_ConfigData_Base64",
}

# VPNGate profiles are data, but OpenVPN profiles can also launch programs.
# Keep the accepted surface limited to connection and TLS settings.
SAFE_DIRECTIVES = {
    "auth",
    "cipher",
    "client",
    "comp-lzo",
    "compress",
    "connect-retry",
    "connect-retry-max",
    "connect-timeout",
    "data-ciphers",
    "data-ciphers-fallback",
    "dev",
    "dev-type",
    "dhcp-option",
    "explicit-exit-notify",
    "keepalive",
    "key-direction",
    "mute",
    "nobind",
    "persist-key",
    "persist-tun",
    "ping",
    "ping-restart",
    "ping-timer-rem",
    "proto",
    "pull",
    "rcvbuf",
    "remote",
    "remote-cert-tls",
    "remote-random",
    "remote-random-hostname",
    "reneg-sec",
    "resolv-retry",
    "route-delay",
    "sndbuf",
    "tls-cipher",
    "tls-ciphersuites",
    "tls-client",
    "tls-version-min",
    "verb",
    "verify-x509-name",
}
SAFE_INLINE_BLOCKS = {"ca", "cert", "key", "tls-auth", "tls-crypt"}


def decode_config(encoded: str) -> str:
    compact = "".join(str(encoded or "").split())
    if not compact:
        raise ValueError("OpenVPN configuration is empty")
    raw = base64.b64decode(compact.encode("ascii"), validate=True)
    if not raw or len(raw) > MAX_CONFIG_BYTES:
        raise ValueError("OpenVPN configuration size is invalid")
    return raw.decode("utf-8", errors="strict")


def validate_openvpn_config(config_text: str) -> None:
    if not config_text or len(config_text.encode("utf-8")) > MAX_CONFIG_BYTES:
        raise ValueError("OpenVPN configuration size is invalid")
    if "\x00" in config_text:
        raise ValueError("OpenVPN configuration contains a NUL byte")

    directives: set[str] = set()
    current_block: str | None = None
    remote_seen = False
    for raw_line in config_text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("<") and line.endswith(">"):
            tag = line[1:-1].strip().lower()
            if tag.startswith("/"):
                if current_block != tag[1:]:
                    raise ValueError(f"Unexpected closing OpenVPN block: {tag}")
                current_block = None
                continue
            if current_block is not None or tag not in SAFE_INLINE_BLOCKS:
                raise ValueError(f"Unsafe OpenVPN inline block: {tag}")
            current_block = tag
            directives.add(f"<{tag}>")
            continue
        if current_block is not None:
            continue

        parts = re.split(r"\s+", line)
        directive = parts[0].lstrip("-").lower()
        if directive not in SAFE_DIRECTIVES:
            raise ValueError(f"Unsafe OpenVPN directive: {directive}")
        directives.add(directive)

        if directive == "remote":
            if len(parts) < 3:
                raise ValueError("OpenVPN remote directive is incomplete")
            try:
                port = int(parts[2])
            except ValueError as exc:
                raise ValueError("OpenVPN remote port is invalid") from exc
            if not (1 <= port <= 65535):
                raise ValueError("OpenVPN remote port is out of range")
            remote_seen = True
        elif directive == "dev" and (len(parts) < 2 or not re.fullmatch(r"tun\d*", parts[1].lower())):
            raise ValueError("Only TUN OpenVPN devices are accepted")

    if current_block is not None:
        raise ValueError(f"Unclosed OpenVPN inline block: {current_block}")
    if "client" not in directives or not remote_seen:
        raise ValueError("OpenVPN client or remote directive is missing")
    if not {"<ca>", "<cert>", "<key>"}.issubset(directives):
        raise ValueError("OpenVPN certificate blocks are incomplete")


def parse_and_validate_snapshot(text: str, max_rows: int | None = None) -> list[dict[str, str]]:
    raw_size = len(text.encode("utf-8"))
    if raw_size <= 0 or raw_size > MAX_SNAPSHOT_BYTES:
        raise ValueError("VPNGate snapshot size is invalid")

    lines = [line for line in text.splitlines() if line and not line.startswith("*")]
    if not lines:
        raise ValueError("VPNGate snapshot is empty")
    if lines[0].startswith("#"):
        lines[0] = lines[0][1:]

    reader = csv.DictReader(io.StringIO("\n".join(lines)))
    fieldnames = set(reader.fieldnames or [])
    if not REQUIRED_COLUMNS.issubset(fieldnames):
        raise ValueError("VPNGate snapshot columns are incomplete")

    rows: list[dict[str, str]] = []
    for row in reader:
        normalized = {str(key): str(value or "") for key, value in row.items() if key is not None}
        if not normalized.get("IP") or not normalized.get("OpenVPN_ConfigData_Base64"):
            continue
        try:
            config_text = decode_config(normalized["OpenVPN_ConfigData_Base64"])
            validate_openvpn_config(config_text)
        except (UnicodeError, ValueError):
            continue
        rows.append(normalized)
        if max_rows is not None and len(rows) >= max_rows:
            break
    if not rows:
        raise ValueError("VPNGate snapshot contains no valid nodes")
    return rows


def snapshot_summary(text: str) -> dict[str, Any]:
    rows = parse_and_validate_snapshot(text)
    return {"row_count": len(rows), "byte_count": len(text.encode("utf-8"))}
