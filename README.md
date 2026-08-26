# AimiliVPN 🌐

[![正式版](https://img.shields.io/badge/正式版-V2.1-16a34a?style=flat-square)](https://github.com/baoweise-bot/aimili-vpngate/releases/latest)
[![主分支](https://img.shields.io/badge/更新通道-main-2563eb?style=flat-square)](https://github.com/baoweise-bot/aimili-vpngate/tree/main)
[![Docker](https://img.shields.io/badge/GHCR-amd64%20%7C%20386%20%7C%20arm64%20%7C%20armv7-0ea5e9?style=flat-square)](https://github.com/baoweise-bot/aimili-vpngate/pkgs/container/aimili-vpngate)

Bilingual: [中文](#中文) | [English](#english)

---

<a name="中文"></a>
## 中文 (Chinese)

AimiliVPN 是一款基于官方 VPNGate 开放协议的高性能、零依赖 VPN 代理网关。它以纯 Python 标准库编写，内置美观响应式的管理网页，提供智能并发测速、多路由模式、出站代理网关、实时日志等强大功能。

---

### 📌 当前正式版本：V2.1

V2.1 是项目启用正式版本标志后的首个稳定版本。仓库、安装器、命令行更新和 Web 更新检测现在全部统一使用 **`main` 主分支正式通道**。

#### V2.1 更新进展

- **节点来源容灾**：依次尝试 VPNGate 官方 HTTPS、官方 HTTP、GitHub Pages HTTPS、GitHub Pages HTTP、VPS 本地最近有效快照和仓库内置初始快照。
- **获取与切换修复**：缩短被 VPNGate 域名封锁的 VPS 等待时间；切换新节点前先完成预检，目标失败时保留当前可用连接。
- **节点可视化**：恢复延迟列，优先显示本机实测延迟；没有实测值时显示 VPNGate 官方预估值并明确标注“仅供参考”。
- **国家筛选**：支持带国旗和节点数量的实时多选筛选，选择范围保存到本机，并作用于手动更新和后台周期同步。
- **节点操作**：恢复单节点“检测”按钮，补齐收藏、检测、连接和断开状态逻辑。
- **镜像同步**：GitHub Pages 每 15 分钟同步并校验官方节点快照，官方 API 被屏蔽时自动回退。
- **Web 更新检测**：页面顶部显示 `V2.1 正式版`，可直接检查 GitHub 最新稳定 Release；只展示 `main` 和正式版下载入口。
- **正式发布链路**：GitHub 标签自动运行 Python 兼容测试、构建四类 Linux 发行包、生成 SHA-256 校验文件并发布多架构 Docker 镜像。

#### 系统与架构兼容性

| 类型 | 正式支持范围 | GitHub 发行标识 |
| --- | --- | --- |
| Linux x64 | Intel/AMD 64 位 VPS | `linux-amd64` |
| Linux x86 | Intel/AMD 32 位系统 | `linux-386` |
| Linux ARM64 | AArch64、ARMv8 VPS/开发板 | `linux-arm64` |
| Linux ARM32 | ARMv7 设备 | `linux-armv7` |
| Linux 发行版 | Debian、Ubuntu、CentOS、RHEL、Rocky、AlmaLinux、Fedora、Oracle Linux、Amazon Linux、Alpine | 使用同一正式核心 |
| Docker | Linux 主机上的 amd64、386、arm64、arm/v7 | GHCR 多架构镜像 |

> AimiliVPN 依赖 Linux 的 TUN、OpenVPN、iptables 和策略路由，因此不发布虚假的 Windows/macOS 原生兼容包。Windows 或 macOS 只能作为代理客户端使用，不能直接运行完整网关；Docker Desktop 同样不等同于具备宿主机 TUN 能力的 Linux 服务器。

项目由纯 Python 标准库组成，不需要为 CPU 编译不同的 Python 二进制。GitHub Actions 会为每种架构生成经过相同测试的正式发行包，并实际构建对应架构的 Docker 镜像。

---

### 🌟 VPS 优选推荐：跑 AimiliVPN 更稳更省心
[![BandwagonHost 顶级三网优化](https://img.shields.io/badge/BandwagonHost-%E9%A1%B6%E7%BA%A7%E4%B8%89%E7%BD%91%E4%BC%98%E5%8C%96-red?style=for-the-badge)](https://bandwagonhost.com/aff.php?aff=81790)
[![RackNerd 6000GB 流量](https://img.shields.io/badge/RackNerd-6000GB%2F%E6%9C%88%20%E5%A4%A7%E6%B5%81%E9%87%8F-blue?style=for-the-badge)](https://my.racknerd.com/aff.php?aff=18708)

| 推荐 | 适合谁 | 亮点 | 入口 |
| --- | --- | --- | --- |
| **BandwagonHost 搬瓦工** | 更看重国内访问质量、延迟和线路上限的用户 | **顶级三网优化线路**，适合对网络体验、跨境访问质量和长期稳定性要求更高的场景 | [立即查看](https://bandwagonhost.com/aff.php?aff=81790) |
| **RackNerd** | 想低成本部署、测试、长期挂机的用户 | **每月 6000GB 流量**，价格实惠、配置给得足，适合入门部署和性价比优先的 VPS 需求 | [立即查看](https://my.racknerd.com/aff.php?aff=18708) |

---

### 📢 官方交流与反馈
[![Telegram](https://img.shields.io/badge/TG交流群-arestemple-2CA5E0?style=flat-square&logo=telegram&logoColor=white)](https://t.me/arestemple)
[![Forum](https://img.shields.io/badge/交流论坛-339936.xyz-orange?style=flat-square&logo=discourse&logoColor=white)](https://339936.xyz)
[![YouTube](https://img.shields.io/badge/视频教程-YouTube-red?style=flat-square&logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=s-ATfXR8BpI)
[![Email](https://img.shields.io/badge/Bug反馈-yaohunse7@gmail.com-red?style=flat-square&logo=gmail&logoColor=white)](mailto:yaohunse7@gmail.com)

---

### 🚀 安装与正式版更新

#### 方法一：从 main 主分支一键安装（推荐）

在 Linux VPS 上以 root 用户执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/baoweise-bot/aimili-vpngate/main/install.sh)
```

部署完成后，终端会输出管理网页专属链接。输入 `ml update` 时只会获取并切换到 `origin/main`，不会检测或切换任何测试分支。

#### 方法二：GitHub 正式发行包

[Releases 页面](https://github.com/baoweise-bot/aimili-vpngate/releases/latest)提供以下文件：

- `aimilivpn-v2.1.0-linux-amd64.tar.gz`：x64 / x86_64。
- `aimilivpn-v2.1.0-linux-386.tar.gz`：x86 32 位。
- `aimilivpn-v2.1.0-linux-arm64.tar.gz`：ARM64 / AArch64。
- `aimilivpn-v2.1.0-linux-armv7.tar.gz`：ARMv7 32 位。
- `sha256sums.txt`：所有发行包的 SHA-256 校验值。

#### 方法三：Docker / Docker Compose

Docker 镜像地址：`ghcr.io/baoweise-bot/aimili-vpngate:2.1`。仓库中的 [`compose.yaml`](./compose.yaml) 已配置主机网络、`NET_ADMIN` 和 TUN 设备：

```bash
docker compose up -d
docker logs -f aimilivpn
```

也可以直接运行：

```bash
docker run -d \
  --name aimilivpn \
  --restart unless-stopped \
  --network host \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  -v aimilivpn-data:/data \
  ghcr.io/baoweise-bot/aimili-vpngate:2.1
```

> Docker 方式只支持具备 `/dev/net/tun` 的 Linux 主机。管理页面默认端口为 `8787`，本机 HTTP/SOCKS5 代理默认端口为 `7928`。

---

### 💡 快速使用指南 (小白必看)

部署成功后，如何使用它进行科学上网？

#### 第一步：登录 Web 管理后台
打开浏览器，访问部署完成时提示的专属后台地址（含安全后缀），即可进入精美的暗黑玻璃拟物风管理界面。

#### 第二步：获取并连接节点
1. 首次进入后台，节点列表可能正在进行首次自动测速与拉取。
2. 点击 **“更新节点”** 按钮（或通过网页下方的网关/日志进行状态检查），程序会在后台通过多线程并发测速，自动筛选出延迟最低、可连接的 VPNGate 节点。
3. 选择您喜欢的出站路由模式：
   - **智能自动配置**（推荐）：如果当前连接的节点失效，系统会在数秒内自动漂移连接至其他备用健康节点，无需手动干预。
   - **固定国家地区**：只选择指定国家（如日本 JP、韩国 KR、美国 US）的最佳节点。
   - **固定 IP 节点**：始终锁定连接到这一个特定节点。

#### 第三步：使用本机代理 (核心步骤)
为了防止代理端口暴露至公网被恶意扫描和滥用，AimiliVPN 的双效代理服务（默认端口 **`7928`**，自适应支持 SOCKS5 和 HTTP 协议）**默认仅绑定在本地回环地址（`127.0.0.1`）**，只接收 VPS 本机上的流量，不对外机提供代理。

* **🐍 Python 脚本中使用代理**:
  ```python
  import requests
  proxies = {
      "http": "http://127.0.0.1:7928",
      "https": "http://127.0.0.1:7928",
  }
  response = requests.get("https://www.google.com", proxies=proxies)
  ```
* **🐚 Shell 终端环境中使用代理**:
  在命令行执行以下命令，可以让当前终端的后续命令（如 `curl`、`wget` 等）走代理出口：
  ```bash
  export http_proxy="http://127.0.0.1:7928"
  export https_proxy="http://127.0.0.1:7928"
  ```
* **⚙️ 本地其他服务配置**:
  将本机的其他代理工具、爬虫框架或服务的出战代理设置为 `127.0.0.1:7928`。

> 💡 **小贴士**：如果您确实需要对公网其他设备开放此代理端口，可以通过设置环境变量 `export LOCAL_PROXY_HOST="::"` 重新启动服务以允许公网接入。

---

### 🛠️ 核心功能与操作说明

* **合并操作面板**：将“更新节点”与“立即检测补齐”合并，一键触发多线程拉取与测速。
* **正式版更新检测**：Web 顶部版本菜单可以检查 GitHub 最新稳定 Release，并提供 `main` 主分支和正式版下载入口。
* **多国家发现范围**：节点表可实时勾选多个国家；点击“更新节点”后保存范围并影响后台周期拉取。
* **延迟来源区分**：实测延迟正常显示，官方 Ping 回退值使用弱化样式并标注为预估。
* **网关状态面板**：
  - **系统诊断**：检测网关心跳及后台各个子守护线程（网页服务、VPN连接管理、出站网关服务）是否正常运行。若有脚本未运行，会提示具体的异常原因。
  - **本地代理出口检测**：在网页端直接一键检测 VPS 后台对海外的实际连通状况，并回显真实的代理出站 IP 和所在地理位置。
* **日志追踪面板**：
  - **分类过滤**：可精准筛选查看特定功能的日志（如 VPN 连接日志、API 请求日志、系统异常等）。
  - **实时滚动与管理**：日志实时滚动加载，支持一键复制代码、一键导出 `.log` 日志文件到本地。

---

### ⚠️ 小白安装与运行常见问题 (FAQ)

#### 1. 提示 `Cannot allocate tun` 或 `Cannot open tun/tap dev`
* **原因**：VPS 宿主机未启用虚拟网卡（TUN/TAP 设备）。这种情况常见于 LXC 或 OpenVZ 架构的轻量 VPS。
* **解决办法**：请登录您的 VPS 服务商控制面板（如 SolusVM/Proxmox），找到 **Enable TUN/TAP** / **开启 TUN** 选项并启用，然后重启 VPS。如无此选项，请工单联系客服开启。

#### 2. 网页管理后台无法打开（链接超时或拒绝连接）
* **原因 1**：VPS 本身自带防火墙（如 UFW、firewalld 或 iptables）阻断了管理端口（默认 `8787`）或代理端口（默认 `7928`）。
* **解决办法 1**：请在终端放行对应端口：
  * **UFW (Ubuntu/Debian)**: `ufw allow 8787/tcp && ufw allow 7928/tcp`
  * **Firewalld (CentOS/RHEL)**: `firewall-cmd --zone=public --add-port=8787/tcp --permanent && firewall-cmd --zone=public --add-port=7928/tcp --permanent && firewall-cmd --reload`
* **原因 2**：云服务商的“安全组”或“网络访问控制列表 (ACL)”未放行端口。
* **解决办法 2**：**非常重要！** 登录云服务商控制台（如阿里云、腾讯云、AWS、Oracle Cloud等），找到您 VPS 实例的 **安全组规则 (Security Group)**，在入站规则中添加：
  - **协议类型**: `TCP`
  - **端口范围**: `8787` (管理网页) 和 `7928` (代理端口)
  - **授权对象/源IP**: `0.0.0.0/0` (允许所有人，或指定您自己的家庭公网 IP 提高安全性)

#### 3. 页面提示 `API Domain Blocked` 且备选节点显示为 0
* **原因**：您的 VPS DNS 解析异常，或者官方 VPNGate 域名遭防火墙拦截污染，导致无法下载节点列表。
* **解决办法**：
  * **设置上游代理**：如果您有其他可用的代理服务，可在网页管理面板中打开“管理员 -> 代理及网络设置”，配置有效的 HTTP/SOCKS5 上游代理，后台会自动通过该代理拉取更新。
  * **修改 DNS 解析器**：在终端修改 `/etc/resolv.conf`，将域名服务器替换为公共 DNS（如 `nameserver 8.8.8.8` 和 `nameserver 1.1.1.1`）。

程序会按以下顺序自动回退，不需要用户手动切换：

1. VPNGate 官方 HTTPS
2. VPNGate 官方 HTTP（兼容旧系统，结果不会覆盖 HTTPS 获得的可信缓存）
3. GitHub Pages 镜像 HTTPS
4. GitHub Pages 镜像 HTTP
5. VPS 本地最近有效快照；首次安装时使用仓库附带的初始快照

默认镜像为 `https://baoweise-bot.github.io/aimili-vpngate/vpngate.csv`。仓库管理员需要在 GitHub 的 **Settings -> Pages** 中将 Source 设置为 **GitHub Actions**，定时工作流会每 15 分钟校验并发布一次快照。可通过 `VPNGATE_API_HTTPS_URL`、`VPNGATE_API_HTTP_URL`、`VPNGATE_MIRROR_HTTPS_URL` 和 `VPNGATE_MIRROR_HTTP_URL` 覆盖各节点源。

#### 4. VPN 已成功连接，但客户端设置代理后无法上网 (无流量)
* **原因**：部分系统启用了严格的反向路径过滤（`rp_filter`），导致策略路由的入站/出站数据包被系统误判丢弃。
* **解决办法**：在终端输入 `ml` 命令打开交互菜单，工具会自动检测并提示您将 `rp_filter` 修复为宽松模式（值为 `2`）。

---

### 🎁 捐赠支持项目开发

如果您觉得这个项目对您有所帮助，欢迎捐赠支持我们的后续开发与维护：

* **BNB (BSC / BEP20)**: `0xB6d78c42CEB0687A31B8cfEBE4b51b6eB8953C17`
* **TRX (TRC20)**: `TSdzCW6JvsrqcppodYjhSrku4mYmDJ9pxf`

感谢您的慷慨与支持！❤️

---

<a name="english"></a>
## English

AimiliVPN is a high-performance, zero-dependency VPN proxy gateway built entirely using Python's standard library. It parses official VPNGate servers, benchmarks latency, and routes traffic through a built-in dual-protocol (HTTP/SOCKS5) proxy server.

### 🌟 Recommended VPS Deals
[![BandwagonHost Premium Optimized Routes](https://img.shields.io/badge/BandwagonHost-Premium%20Optimized%20Routes-red?style=for-the-badge)](https://bandwagonhost.com/aff.php?aff=81790)
[![RackNerd 6000GB Bandwidth](https://img.shields.io/badge/RackNerd-6000GB%2Fmonth%20Bandwidth-blue?style=for-the-badge)](https://my.racknerd.com/aff.php?aff=18708)

| Pick | Best for | Highlights | Link |
| --- | --- | --- | --- |
| **BandwagonHost** | Users who care most about China connectivity, latency, and route quality | **Premium China Telecom/Unicom/Mobile optimized routes**, ideal for demanding cross-border networking and long-term use | [View deals](https://bandwagonhost.com/aff.php?aff=81790) |
| **RackNerd** | Budget deployments, testing, and long-running lightweight services | **6000GB monthly bandwidth**, affordable pricing, and generous specs for value-focused VPS use | [View deals](https://my.racknerd.com/aff.php?aff=18708) |


### 📢 Community & Feedback
- **Telegram Group**: [arestemple](https://t.me/arestemple)
- **Discussion Forum**: [339936.xyz](https://339936.xyz)
- **Video Tutorial**: [YouTube Guide](https://www.youtube.com/watch?v=s-ATfXR8BpI)
- **Email Contact**: yaohunse7@gmail.com

---

### 🚀 One-Click Installation

Run the corresponding command on your Linux VPS as root:

#### 🌟 V2.1 Formal Release (main branch only)
```bash
bash <(curl -Ls https://raw.githubusercontent.com/baoweise-bot/aimili-vpngate/main/install.sh)
```

> 💡 **Quick Note**: Once installed, copy the printed URL from the terminal to access the Web UI. Type the `ml` command in the terminal to summon the interactive CLI management console.

---

### 💡 Quick Start Guide

#### Step 1: Access the Web UI
Open your browser and navigate to the printed URL (e.g. `http://your_vps_ip:8787/u71e9IXp4TPx`).

#### Step 2: Select Node and Mode
1. Wait for the program to complete its first automatic node speed benchmarks.
2. Under "Admin", you can trigger node fetching. The backend concurrently tests official VPNGate nodes and ranks them by latency.
3. Switch routes mode (Smart Auto, Specific Region, or Specific Server Node) according to your needs.

#### Step 3: Use Localhost Proxy (Core Step)
To prevent unauthorized scanning and abuse of the proxy port on the public internet, the built-in HTTP/SOCKS5 proxy server (default port **`7928`**) **binds to localhost (`127.0.0.1`) by default**. It is designed to route traffic generated locally on the VPS, rather than acting as a public proxy server.

* **🐍 Proxy in Python**:
  ```python
  import requests
  proxies = {
      "http": "http://127.0.0.1:7928",
      "https": "http://127.0.0.1:7928",
  }
  response = requests.get("https://www.google.com", proxies=proxies)
  ```
* **🐚 Proxy in Shell terminal**:
  ```bash
  export http_proxy="http://127.0.0.1:7928"
  export https_proxy="http://127.0.0.1:7928"
  ```
* **⚙️ Other local services**:
  Configure your scrapers, frameworks, or utility tools on this VPS to send traffic via `127.0.0.1:7928`.

> 💡 **Quick Note**: If you really need to open this proxy port to the public internet, you can set the environment variable `export LOCAL_PROXY_HOST="::"` before running the manager.

---

### ⚠️ Common Troubleshooting (FAQ)

#### 1. Error: `Cannot allocate tun` or `Cannot open tun/tap dev`
* **Reason**: Virtual network adapter (TUN/TAP device) is disabled. This is common in OpenVZ/LXC VPS instances.
* **Solution**: Enable **TUN/TAP** in your VPS SolusVM/KiwiVM control panel, or submit a support ticket to your hosting provider.

#### 2. Cannot open the Web UI in the browser
* **Reason 1**: The built-in firewall (UFW or firewalld) is blocking ports `8787` (Web UI) and `7928` (Proxy).
* **Solution 1**: Allow the ports in your OS firewall:
  * **UFW**: `ufw allow 8787/tcp && ufw allow 7928/tcp`
  * **Firewalld**: `firewall-cmd --add-port=8787/tcp --permanent && firewall-cmd --add-port=7928/tcp --permanent && firewall-cmd --reload`
* **Reason 2**: Service provider security group blocking ports.
* **Solution 2**: **Crucial!** Log in to your cloud provider console (AWS, Aliyun, Oracle Cloud, etc.), locate the **Security Group** for your instance, and add an inbound TCP rule to allow ports `8787` and `7928` from `0.0.0.0/0`.

#### 3. "API Domain Blocked" / Candidate nodes pool is empty (0 nodes)
* **Reason**: The official VPNGate domain is blocked or DNS resolution failed on your VPS.
* **Solution**: Add an HTTP/SOCKS5 upstream proxy in the settings panel (Admin -> Proxy Settings), or configure public DNS in `/etc/resolv.conf` (e.g., `nameserver 8.8.8.8`).

The application automatically tries the official HTTPS endpoint, official HTTP endpoint, GitHub Pages HTTPS mirror, GitHub Pages HTTP mirror, and finally the last valid local snapshot. A validated initial snapshot is bundled for first startup. HTTP results remain supported for older systems but do not replace the cache obtained through HTTPS.

The default mirror is `https://baoweise-bot.github.io/aimili-vpngate/vpngate.csv`. Repository administrators must select **GitHub Actions** as the Pages source under **Settings -> Pages**. The scheduled workflow validates and publishes a fresh snapshot every 15 minutes. Source URLs can be overridden with `VPNGATE_API_HTTPS_URL`, `VPNGATE_API_HTTP_URL`, `VPNGATE_MIRROR_HTTPS_URL`, and `VPNGATE_MIRROR_HTTP_URL`.

---

### 🎁 Donation Support

If you find this project helpful, you can support its development and maintenance via donation:

* **BNB (BSC / BEP20)**: `0xB6d78c42CEB0687A31B8cfEBE4b51b6eB8953C17`
* **TRX (TRC20)**: `TSdzCW6JvsrqcppodYjhSrku4mYmDJ9pxf`

Thank you for your generosity and support! ❤️
