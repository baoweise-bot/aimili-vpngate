# AimiliVPN Multi-Country Fork

Bilingual: [中文](#中文) | [English](#english)

> Forked from [baoweise-bot/aimili-vpngate](https://github.com/baoweise-bot/aimili-vpngate). 本 fork 在上游基础上加入 **多国家固定落地** (JP / US / KR) 并行支持：每个国家一条独立 OpenVPN 隧道、独立 tun 设备、独立策略路由表、独立代理端口和 Web UI 端口。

---

## 中文

### 与上游的区别

| 维度 | 上游 baoweise-bot | 本仓库 CarminBack |
| --- | --- | --- |
| 出口国家 | 随机国家住宅 IP | 同时落地 **日本 / 美国 / 韩国** |
| 隧道数 | 单实例 (tun0) | 每国一条 systemd 模板实例 |
| 候选过滤 | 不过滤 | 按 `ALLOWED_COUNTRIES` 过滤；默认排除 `hosting/datacenter` IP |
| 代理端口 | 7928 | JP=7928 / US=7929 / KR=7930 |
| Web UI 端口 | 8787 | JP=8788 / US=8789 / KR=8790 |
| CLI | `ml <command>` | `ml [cc] <command>`，裸 `ml` 是聚合视图 |

### 🚀 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/CarminBack/vpngate/main/install.sh)
```

安装脚本会：
1. 拉取代码与依赖（OpenVPN、Python、systemd）
2. 引导一次共用的 Web UI 用户名 / 密码
3. 部署 systemd 模板单元 `aimilivpn@.service`，并 enable 三个实例：`aimilivpn@jp`、`aimilivpn@us`、`aimilivpn@kr`
4. 在 `/etc/aimilivpn/<cc>.env` 写入每个实例的 tun 设备、路由表、端口、`ALLOWED_COUNTRIES`、`EXCLUDE_DATACENTER` 等变量

### 🛠️ ml CLI（多实例）

| 命令 | 行为 |
| --- | --- |
| `ml` | 三国聚合状态：每个实例的 VPN 节点、出口 IP、代理端口、UI 地址 |
| `ml jp status` / `ml us status` / `ml kr status` | 单国详细状态 |
| `ml jp restart` / `ml us stop` / `ml kr start` | 控制单国实例 |
| `ml jp logs` | 查看单国 systemd 日志 |
| `ml web` / `ml port` / `ml password` | 共用 Web UI 设置（一次写入所有实例） |
| `ml uninstall` | 卸载模板单元、所有实例与 `/etc/aimilivpn` |

> 仅装一国时，`ml <command>` 会自动透传到那个唯一实例，无需带国家代码。

### ⚙️ 多国并行架构

```
              ┌────────────── Xray / 3x-ui (上游) ──────────────┐
              │                                                  │
              ▼ 7928 (JP)         ▼ 7929 (US)         ▼ 7930 (KR)
   ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
   │ aimilivpn@jp       │  │ aimilivpn@us       │  │ aimilivpn@kr       │
   │ tun10 / table 110  │  │ tun11 / table 111  │  │ tun12 / table 112  │
   │ UI :8788           │  │ UI :8789           │  │ UI :8790           │
   │ ALLOWED=JP         │  │ ALLOWED=US         │  │ ALLOWED=KR         │
   └─────────┬──────────┘  └─────────┬──────────┘  └─────────┬──────────┘
             │                        │                        │
             ▼ OpenVPN                ▼ OpenVPN                ▼ OpenVPN
   [VPNGate JP 住宅节点]  [VPNGate US 住宅节点]  [VPNGate KR 住宅节点]
```

每个实例独立选节点、独立切换、独立健康检查；某一国挂掉不会影响其它国。

### 🔧 关键环境变量（写在 `/etc/aimilivpn/<cc>.env`）

| 变量 | 示例 | 含义 |
| --- | --- | --- |
| `INSTANCE_ID` | `jp` | 实例标识 |
| `TUN_DEV` | `tun10` | OpenVPN 虚拟网卡 |
| `POLICY_TABLE` | `110` | 策略路由表号 |
| `PROXY_PORT` | `7928` | HTTP/SOCKS5 监听端口 |
| `UI_PORT` | `8788` | Web UI 端口 |
| `ALLOWED_COUNTRIES` | `JP` | 候选节点国家白名单（VPNGate `CountryShort`） |
| `EXCLUDE_DATACENTER` | `1` | 1=排除 hosting/datacenter，0=允许（节点稀少时可放宽） |
| `VPNGATE_DATA_DIR` | `/opt/aimilivpn/data/jp` | 每实例独立缓存与状态目录 |

> 韩国 (KR) 候选偏少。如某实例长时间找不到节点，把 `/etc/aimilivpn/kr.env` 的 `EXCLUDE_DATACENTER` 改为 `0`，再 `ml kr restart`。

### 🛡️ 防泄漏（继承上游）

- 所有出站 socket 通过 `SO_BINDTODEVICE` 强制绑定到对应 `TUN_DEV`，VPN 断线即 502，不会回落物理 IP。
- 策略路由仅作用于 tun 接口流量，SSH / Web UI / 系统流量仍走物理网卡。

---

## English

### Differences vs upstream

| Aspect | Upstream baoweise-bot | This fork (CarminBack) |
| --- | --- | --- |
| Exit country | random residential | concurrent **JP / US / KR** |
| Tunnels | single instance (tun0) | one systemd template instance per country |
| Candidate filter | none | filter by `ALLOWED_COUNTRIES`; drop `hosting/datacenter` by default |
| Proxy port | 7928 | JP=7928 / US=7929 / KR=7930 |
| Web UI port | 8787 | JP=8788 / US=8789 / KR=8790 |
| CLI | `ml <command>` | `ml [cc] <command>`; bare `ml` = aggregate view |

### 🚀 Install

```bash
bash <(curl -Ls https://raw.githubusercontent.com/CarminBack/vpngate/main/install.sh)
```

The installer pulls dependencies, prompts once for the shared Web UI credentials, deploys the systemd template `aimilivpn@.service`, and enables three instances (`aimilivpn@jp`, `aimilivpn@us`, `aimilivpn@kr`). Per-instance variables live in `/etc/aimilivpn/<cc>.env`.

### 🛠️ ml CLI (multi-instance)

| Command | Behavior |
| --- | --- |
| `ml` | Aggregate dashboard for all enabled countries |
| `ml jp status` / `ml us status` / `ml kr status` | Per-country detailed status |
| `ml jp restart` / `ml us stop` / `ml kr start` | Control a single instance |
| `ml jp logs` | systemd journal for one instance |
| `ml web` / `ml port` / `ml password` | Shared Web UI settings (applied to every instance) |
| `ml uninstall` | Tear down the template, every instance, and `/etc/aimilivpn` |

> If only one country is installed, `ml <command>` falls through to that single instance — country code optional.

### ⚙️ Concurrent multi-country architecture

```
              ┌────────────── Xray / 3x-ui upstream ─────────────┐
              │                                                  │
              ▼ 7928 (JP)         ▼ 7929 (US)         ▼ 7930 (KR)
   ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
   │ aimilivpn@jp       │  │ aimilivpn@us       │  │ aimilivpn@kr       │
   │ tun10 / table 110  │  │ tun11 / table 111  │  │ tun12 / table 112  │
   │ UI :8788           │  │ UI :8789           │  │ UI :8790           │
   │ ALLOWED=JP         │  │ ALLOWED=US         │  │ ALLOWED=KR         │
   └─────────┬──────────┘  └─────────┬──────────┘  └─────────┬──────────┘
             │                        │                        │
             ▼ OpenVPN                ▼ OpenVPN                ▼ OpenVPN
   [VPNGate JP residential]  [VPNGate US residential]  [VPNGate KR residential]
```

Each instance picks, switches, and health-checks nodes independently; a failure in one country never affects the others.

### 🔧 Per-instance env (`/etc/aimilivpn/<cc>.env`)

| Variable | Example | Meaning |
| --- | --- | --- |
| `INSTANCE_ID` | `jp` | Instance identifier |
| `TUN_DEV` | `tun10` | OpenVPN virtual interface |
| `POLICY_TABLE` | `110` | Policy routing table id |
| `PROXY_PORT` | `7928` | HTTP/SOCKS5 listen port |
| `UI_PORT` | `8788` | Web UI port |
| `ALLOWED_COUNTRIES` | `JP` | Whitelist on VPNGate `CountryShort` |
| `EXCLUDE_DATACENTER` | `1` | 1=drop hosting/datacenter, 0=allow (relax when the pool is small) |
| `VPNGATE_DATA_DIR` | `/opt/aimilivpn/data/jp` | Per-instance cache & state dir |

> The KR pool is usually thin. If an instance can't find nodes for a long time, set `EXCLUDE_DATACENTER=0` in `/etc/aimilivpn/kr.env` and `ml kr restart`.

### 🛡️ Leak protection (inherited from upstream)

- All outbound sockets are `SO_BINDTODEVICE`-bound to their `TUN_DEV`. If the tunnel drops, requests return `502` instead of leaking via the physical NIC.
- Policy routing scopes tunneled traffic only — SSH, Web UI, and system traffic stay on the physical interface.

---

### Credits

Original project by [@baoweise-bot](https://github.com/baoweise-bot). Multi-country refactor maintained at [CarminBack/vpngate](https://github.com/CarminBack/vpngate).
