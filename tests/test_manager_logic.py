from __future__ import annotations

import base64
import os
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

import proxy_server
import snapshot_utils

_import_data_dir = tempfile.TemporaryDirectory()
_original_data_dir = os.environ.get("VPNGATE_DATA_DIR")
os.environ["VPNGATE_DATA_DIR"] = _import_data_dir.name
try:
    import vpngate_manager as manager
finally:
    if _original_data_dir is None:
        os.environ.pop("VPNGATE_DATA_DIR", None)
    else:
        os.environ["VPNGATE_DATA_DIR"] = _original_data_dir


class FakeProcess:
    def __init__(self) -> None:
        self.running = True
        self.terminated = False

    def poll(self):
        return None if self.running else 0

    def terminate(self) -> None:
        self.terminated = True
        self.running = False

    def wait(self, timeout=None):
        self.running = False
        return 0

    def kill(self) -> None:
        self.running = False


def valid_snapshot(ip: str = "198.51.100.10") -> str:
    config_text = (
        "client\n"
        "dev tun\n"
        "proto udp\n"
        f"remote {ip} 1194 udp\n"
        "resolv-retry infinite\n"
        "nobind\n"
        "<ca>\nCA\n</ca>\n"
        "<cert>\nCERT\n</cert>\n"
        "<key>\nKEY\n</key>\n"
    )
    config = base64.b64encode(config_text.encode("utf-8")).decode("ascii")
    return (
        "#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,OpenVPN_ConfigData_Base64\n"
        f"vpn.example,{ip},100,20,1000,Japan,JP,1,{config}\n"
    )


class ManagerLogicTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        root = Path(self.temp_dir.name)
        self.path_patches = [
            mock.patch.object(manager, "DATA_DIR", root),
            mock.patch.object(manager, "CONFIG_DIR", root / "configs"),
            mock.patch.object(manager, "NODES_FILE", root / "nodes.json"),
            mock.patch.object(manager, "STATE_FILE", root / "state.json"),
            mock.patch.object(manager, "AUTH_FILE", root / "auth.txt"),
            mock.patch.object(manager, "BLACKLIST_FILE", root / "blacklist.json"),
            mock.patch.object(manager, "API_CACHE_FILE", root / "api_snapshot.csv"),
            mock.patch.object(manager, "API_CACHE_META_FILE", root / "api_snapshot.meta.json"),
            mock.patch.object(manager, "BUNDLED_SNAPSHOT_FILE", root / "bundled_snapshot.csv"),
        ]
        for patcher in self.path_patches:
            patcher.start()
        manager.ensure_dirs()
        manager.active_openvpn_process = None
        manager.pending_openvpn_process = None
        manager.active_openvpn_node_id = ""
        manager.active_connection_cancel_event = None
        manager.is_connecting = False
        manager.consecutive_proxy_failures = 0
        manager.last_proxy_failure_node_id = ""
        manager.background_refill_thread = None
        manager.background_refill_cancel_event.clear()

    def tearDown(self) -> None:
        if manager.connection_attempt_lock.locked():
            manager.connection_attempt_lock.release()
        manager.background_refill_cancel_event.set()
        manager.background_refill_thread = None
        for patcher in reversed(self.path_patches):
            patcher.stop()
        self.temp_dir.cleanup()

    def write_nodes(self, count: int) -> list[dict]:
        nodes = []
        for index in range(count):
            node_id = f"node-{index}"
            nodes.append(
                {
                    "id": node_id,
                    "ip": f"192.0.2.{index + 1}",
                    "remote_host": f"192.0.2.{index + 1}",
                    "remote_port": 1194,
                    "ping": index + 1,
                    "score": 1000 - index,
                    "config_text": "client\nremote 192.0.2.1 1194 udp\n",
                    "config_file": str(manager.CONFIG_DIR / f"{node_id}.ovpn"),
                    "probe_status": "not_checked",
                    "probed_at": 0,
                    "active": False,
                }
            )
        manager.write_json(manager.NODES_FILE, nodes)
        return nodes

    def test_node_probe_stops_after_target_batch(self) -> None:
        nodes = self.write_nodes(12)
        calls = []

        def fake_openvpn(config_file, **kwargs):
            calls.append(config_file)
            return True, "ready", None

        with (
            mock.patch.object(manager.vpn_utils, "ping_latency_ms", return_value=10),
            mock.patch.object(manager.vpn_utils, "enrich_ip_info"),
            mock.patch.object(manager, "run_openvpn_until_ready", side_effect=fake_openvpn),
            mock.patch.object(manager, "NODE_PROBE_WORKERS", 5),
        ):
            results = manager.test_multiple_nodes(
                [node["id"] for node in nodes],
                target_available=3,
            )

        self.assertEqual(5, len(calls))
        self.assertEqual(5, len(results))
        stored = manager.read_nodes()
        self.assertEqual(5, sum(node.get("probe_status") == "available" for node in stored))
        self.assertEqual(7, sum(node.get("probe_status") == "not_checked" for node in stored))

    def test_node_probe_stops_after_systemic_openvpn_failure(self) -> None:
        nodes = self.write_nodes(12)

        with (
            mock.patch.object(manager.vpn_utils, "ping_latency_ms", return_value=10),
            mock.patch.object(
                manager,
                "run_openvpn_until_ready",
                return_value=(False, "[ERR_OVPN_TUN_NOT_AVAILABLE] missing TUN", None),
            ) as openvpn_mock,
            mock.patch.object(manager, "NODE_PROBE_WORKERS", 5),
            mock.patch.object(manager, "log_to_json"),
        ):
            results = manager.test_multiple_nodes(
                [node["id"] for node in nodes],
                target_available=3,
            )

        self.assertEqual(5, openvpn_mock.call_count)
        self.assertEqual(5, len(results))
        stored = manager.read_nodes()
        self.assertEqual(5, sum(node.get("probe_status") == "unavailable" for node in stored))
        self.assertEqual(7, sum(node.get("probe_status") == "not_checked" for node in stored))

    def test_maintenance_does_not_start_second_batch_after_systemic_failure(self) -> None:
        candidates = self.write_nodes(12)

        with (
            mock.patch.object(manager, "fetch_candidates", return_value=candidates),
            mock.patch.object(manager.vpn_utils, "ping_latency_ms", return_value=10),
            mock.patch.object(
                manager,
                "run_openvpn_until_ready",
                return_value=(False, "[ERR_OVPN_CMD_NOT_FOUND] openvpn missing", None),
            ) as openvpn_mock,
            mock.patch.object(manager, "NODE_PROBE_WORKERS", 5),
            mock.patch.object(manager, "log_to_json"),
        ):
            result = manager.maintain_valid_nodes()

        self.assertEqual(5, openvpn_mock.call_count)
        self.assertIn("Tested 5", result)

    def test_cancel_pending_connection_stops_handshake_process(self) -> None:
        process = FakeProcess()
        event = threading.Event()
        manager.pending_openvpn_process = process
        manager.active_connection_cancel_event = event
        manager.is_connecting = True
        previous_epoch = manager.connection_epoch

        manager.cancel_pending_connection_attempt()

        self.assertTrue(event.is_set())
        self.assertTrue(process.terminated)
        self.assertIsNone(manager.pending_openvpn_process)
        self.assertFalse(manager.is_connecting)
        self.assertEqual(previous_epoch + 1, manager.connection_epoch)

    def test_proxy_failures_reset_when_node_changes(self) -> None:
        self.assertEqual(1, manager.record_proxy_failure("node-a"))
        self.assertEqual(2, manager.record_proxy_failure("node-a"))
        self.assertEqual(1, manager.record_proxy_failure("node-b"))
        manager.reset_proxy_failure_counter("node-b")
        self.assertEqual(1, manager.record_proxy_failure("node-b"))

    def test_failed_switch_preflight_keeps_current_connection(self) -> None:
        nodes = self.write_nodes(2)
        nodes[0]["active"] = True
        manager.write_json(manager.NODES_FILE, nodes)
        current_process = FakeProcess()
        manager.active_openvpn_process = current_process
        manager.active_openvpn_node_id = nodes[0]["id"]

        with (
            mock.patch.object(
                manager,
                "run_openvpn_until_ready",
                return_value=(False, "preflight failed", None),
            ),
            mock.patch.object(manager, "log_to_json"),
        ):
            with self.assertRaisesRegex(RuntimeError, "已保留当前连接"):
                manager.connect_node(nodes[1]["id"])

        self.assertIs(manager.active_openvpn_process, current_process)
        self.assertEqual(nodes[0]["id"], manager.active_openvpn_node_id)
        self.assertTrue(current_process.running)
        stored = {node["id"]: node for node in manager.read_nodes()}
        self.assertEqual("unavailable", stored[nodes[1]["id"]]["probe_status"])

    def test_proxy_failure_does_not_report_connection_success(self) -> None:
        nodes = self.write_nodes(1)
        process = FakeProcess()

        with (
            mock.patch.object(
                manager,
                "run_openvpn_until_ready",
                return_value=(True, "ready", process),
            ),
            mock.patch.object(manager, "setup_policy_routing", return_value=False),
            mock.patch.object(manager, "cleanup_policy_routing"),
            mock.patch.object(manager.vpn_utils, "ping_latency_ms", return_value=10),
            mock.patch.object(manager, "check_proxy_health", return_value={"ok": False, "error": "no route"}),
            mock.patch.object(manager, "log_to_json"),
        ):
            with self.assertRaisesRegex(RuntimeError, "代理出口不可用"):
                manager.connect_node(nodes[0]["id"])

        self.assertFalse(process.running)
        self.assertIsNone(manager.active_openvpn_process)
        self.assertEqual("", manager.active_openvpn_node_id)
        stored = manager.read_nodes()
        self.assertEqual("unavailable", stored[0]["probe_status"])

    def test_manual_failure_recovery_prefers_previous_node(self) -> None:
        with (
            mock.patch.object(manager, "active_openvpn_running", return_value=False),
            mock.patch.object(manager, "connect_node", return_value="connected") as connect_mock,
            mock.patch.object(manager, "log_to_json"),
            mock.patch.object(manager, "auto_switch_node") as auto_switch_mock,
        ):
            manager.recover_after_manual_connect_failure("old-node")

        connect_mock.assert_called_once_with("old-node")
        auto_switch_mock.assert_not_called()

    def test_physical_interface_detection_is_cached(self) -> None:
        original_cache = manager.vpn_utils.physical_interface_cache
        manager.vpn_utils.physical_interface_cache = (None, 0.0)
        try:
            with mock.patch.object(
                manager.vpn_utils,
                "_detect_physical_interface",
                return_value="eth0",
            ) as detect_mock:
                self.assertEqual("eth0", manager.vpn_utils.get_physical_interface())
                self.assertEqual("eth0", manager.vpn_utils.get_physical_interface())
            detect_mock.assert_called_once_with()
        finally:
            manager.vpn_utils.physical_interface_cache = original_cache

    def test_forced_refresh_keeps_healthy_active_connection(self) -> None:
        process = FakeProcess()
        manager.active_openvpn_process = process
        manager.active_openvpn_node_id = "active-node"

        with (
            mock.patch.object(manager, "fetch_candidates", return_value=[]),
            mock.patch.object(manager, "stop_active_openvpn") as stop_mock,
            mock.patch.object(manager, "log_to_json"),
        ):
            result = manager.maintain_valid_nodes(force=True)

        self.assertEqual("没有拉取到新节点", result)
        self.assertTrue(process.running)
        stop_mock.assert_not_called()

    def test_fetch_timeout_skips_insecure_https_retry(self) -> None:
        csv_text = valid_snapshot()

        def fake_fetch(url, verify_ssl):
            if url.startswith("https://"):
                raise TimeoutError("timed out")
            return csv_text

        with (
            mock.patch.object(manager, "fetch_api_text", side_effect=fake_fetch) as fetch_mock,
            mock.patch.object(manager, "load_blacklist", return_value={}),
            mock.patch.object(manager, "set_state"),
            mock.patch.object(manager, "log_to_json"),
        ):
            nodes = manager.fetch_candidates()

        self.assertEqual(1, len(nodes))
        self.assertEqual(
            [mock.call(manager.API_HTTPS_URL, True), mock.call(manager.API_HTTP_URL, True)],
            fetch_mock.call_args_list,
        )

    def test_fetch_uses_github_mirror_after_official_sources(self) -> None:
        csv_text = valid_snapshot()

        def fake_fetch(url, verify_ssl):
            if url == manager.MIRROR_HTTPS_URL:
                return csv_text
            raise TimeoutError("blocked")

        with (
            mock.patch.object(manager, "fetch_api_text", side_effect=fake_fetch) as fetch_mock,
            mock.patch.object(manager, "load_blacklist", return_value={}),
            mock.patch.object(manager, "log_to_json"),
        ):
            nodes = manager.fetch_candidates()

        self.assertEqual(1, len(nodes))
        self.assertEqual(
            [manager.API_HTTPS_URL, manager.API_HTTP_URL, manager.MIRROR_HTTPS_URL],
            [call.args[0] for call in fetch_mock.call_args_list],
        )
        self.assertEqual(csv_text, manager.API_CACHE_FILE.read_text(encoding="utf-8"))
        self.assertEqual("github_pages_https", manager.get_state()["last_fetch_source"])

    def test_http_source_does_not_replace_trusted_cache(self) -> None:
        cached_text = valid_snapshot("198.51.100.20")
        http_text = valid_snapshot("198.51.100.21")
        manager.API_CACHE_FILE.write_text(cached_text, encoding="utf-8")

        def fake_fetch(url, verify_ssl):
            if url == manager.API_HTTP_URL:
                return http_text
            raise TimeoutError("TLS unavailable")

        with (
            mock.patch.object(manager, "fetch_api_text", side_effect=fake_fetch),
            mock.patch.object(manager, "load_blacklist", return_value={}),
            mock.patch.object(manager, "log_to_json"),
        ):
            nodes = manager.fetch_candidates()

        self.assertEqual("198.51.100.21", nodes[0]["ip"])
        self.assertEqual(cached_text, manager.API_CACHE_FILE.read_text(encoding="utf-8"))

    def test_fetch_falls_back_to_local_cache(self) -> None:
        cached_text = valid_snapshot("198.51.100.30")
        manager.API_CACHE_FILE.write_text(cached_text, encoding="utf-8")

        with (
            mock.patch.object(manager, "fetch_api_text", side_effect=TimeoutError("all blocked")),
            mock.patch.object(manager, "load_blacklist", return_value={}),
            mock.patch.object(manager, "log_to_json"),
        ):
            nodes = manager.fetch_candidates()

        self.assertEqual("198.51.100.30", nodes[0]["ip"])
        self.assertEqual("local_cache", manager.get_state()["last_fetch_source"])

    def test_bundled_snapshot_seeds_local_cache(self) -> None:
        bundled_text = valid_snapshot("198.51.100.40")
        manager.BUNDLED_SNAPSHOT_FILE.write_text(bundled_text, encoding="utf-8")

        with (
            mock.patch.object(manager, "fetch_api_text", side_effect=TimeoutError("all blocked")),
            mock.patch.object(manager, "load_blacklist", return_value={}),
            mock.patch.object(manager, "log_to_json"),
        ):
            nodes = manager.fetch_candidates()

        self.assertEqual("198.51.100.40", nodes[0]["ip"])
        self.assertEqual(bundled_text, manager.API_CACHE_FILE.read_text(encoding="utf-8"))
        self.assertEqual("bundled_initial", manager.get_state()["last_fetch_source"])

    def test_snapshot_rejects_executable_openvpn_directive(self) -> None:
        unsafe_config = (
            "client\ndev tun\nproto udp\nremote 198.51.100.50 1194 udp\n"
            "script-security 2\nup /tmp/payload\n"
            "<ca>\nCA\n</ca>\n<cert>\nCERT\n</cert>\n<key>\nKEY\n</key>\n"
        )
        encoded = base64.b64encode(unsafe_config.encode("utf-8")).decode("ascii")
        csv_text = (
            "#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,OpenVPN_ConfigData_Base64\n"
            f"vpn.example,198.51.100.50,100,20,1000,Japan,JP,1,{encoded}\n"
        )

        with self.assertRaisesRegex(ValueError, "no valid nodes"):
            snapshot_utils.parse_and_validate_snapshot(csv_text)


class ProxyServerConcurrencyTests(unittest.TestCase):
    def test_each_proxy_worker_keeps_its_accepted_socket(self) -> None:
        class Client:
            def __init__(self, name):
                self.name = name

            def close(self):
                pass

        class FakeServer:
            def __init__(self):
                self.items = [(Client("first"), ("first", 1)), (Client("second"), ("second", 2))]

            def setsockopt(self, *args):
                pass

            def bind(self, *args):
                pass

            def listen(self, *args):
                pass

            def accept(self):
                if self.items:
                    return self.items.pop(0)
                raise KeyboardInterrupt()

        class DeferredThread:
            targets = []

            def __init__(self, target, daemon=True):
                self.target = target
                self.targets.append(target)

            def start(self):
                pass

        seen = []
        semaphore = mock.Mock()
        semaphore.acquire.return_value = True
        with (
            mock.patch.object(proxy_server.socket, "socket", return_value=FakeServer()),
            mock.patch.object(proxy_server.threading, "Thread", DeferredThread),
            mock.patch.object(
                proxy_server,
                "proxy_client",
                side_effect=lambda client, address: seen.append((client.name, address[0])),
            ),
            mock.patch.object(proxy_server, "proxy_connection_sem", semaphore),
        ):
            with self.assertRaises(KeyboardInterrupt):
                proxy_server.start_proxy_server("127.0.0.1", 7928)
            for target in DeferredThread.targets:
                target()

        self.assertEqual([("first", "first"), ("second", "second")], seen)


if __name__ == "__main__":
    unittest.main()
