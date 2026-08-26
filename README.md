# AimiliVPN

[![GitHub Release](https://img.shields.io/github/v/release/baoweise-bot/aimili-vpngate?style=flat-square&label=正式版)](https://github.com/baoweise-bot/aimili-vpngate/releases/latest)
[![Docker](https://img.shields.io/badge/GHCR-amd64%20%7C%20386%20%7C%20arm64%20%7C%20armv7-0ea5e9?style=flat-square)](https://github.com/baoweise-bot/aimili-vpngate/pkgs/container/aimili-vpngate)

AimiliVPN 是运行在 Linux VPS 上的 VPNGate 节点管理与代理网关，提供 Web 管理后台以及同端口的 HTTP、HTTPS 和 SOCKS5 代理接入。

> 本项目需要 Linux、root 权限、OpenVPN、iptables、策略路由和可用的 TUN/TAP 设备。Windows 与 macOS 可以作为代理客户端使用，但不能直接运行完整网关。

## VPS 推荐

以下链接含推广参数，通过链接购买不会增加您的费用。

| 推荐 | 适用场景 | 主要特点 | 购买入口 |
| --- | --- | --- | --- |
| **BandwagonHost 搬瓦工** | 重视国内访问质量、延迟和线路稳定性 | 三网优化线路，适合对跨境网络质量要求较高的长期使用场景 | [查看 BandwagonHost](https://bandwagonhost.com/aff.php?aff=81790) |
| **RackNerd** | 低成本部署、测试和长期挂机 | 流量充足、价格较低，适合入门部署和性价比优先的 VPS | [查看 RackNerd](https://my.racknerd.com/aff.php?aff=18708) |

## 安装方式

### 安装前确认

- 使用 Ubuntu、Debian、Alpine、CentOS、RHEL、Rocky Linux、AlmaLinux、Fedora、Oracle Linux 或 Amazon Linux。
- 使用 `root` 用户运行安装命令。
- 在 VPS 控制面板中启用 TUN/TAP，并确认 `/dev/net/tun` 存在。
- 放行 Web 管理端口，默认是 TCP `8787`。建议只允许自己的 IP 访问。
- Python 源码适用于 x64、x86、ARM64 和 ARM32；预构建 Docker 镜像支持 `linux/amd64`、`linux/386`、`linux/arm64` 和 `linux/arm/v7`。

### 一键源码安装（推荐）

在 VPS 上执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/baoweise-bot/aimili-vpngate/main/install.sh)
```

安装器会自动安装依赖、部署到 `/opt/aimilivpn`、注册系统服务，并生成 Web 安全路径、登录账号和密码。请保存安装完成时终端输出的登录信息。

常用管理命令：

```bash
ml                 # 打开管理菜单
ml status          # 查看运行状态和连接信息
ml logs            # 查看实时日志
ml restart         # 重启服务
ml update          # 从 main 正式分支更新
ml uninstall       # 卸载
```

不希望直接通过 `curl` 执行脚本时，也可以克隆仓库后检查并运行安装器：

```bash
git clone --branch main --single-branch https://github.com/baoweise-bot/aimili-vpngate.git
cd aimili-vpngate
sudo bash install.sh
```

通用 Linux 源码包和 SHA-256 校验文件可从 [GitHub Releases](https://github.com/baoweise-bot/aimili-vpngate/releases/latest) 下载。版本变更记录也统一发布在 Releases 页面。

### Docker Compose

Docker 主机必须能够使用 `/dev/net/tun`、host 网络以及 `NET_ADMIN`、`NET_RAW` 权限。

```bash
git clone --branch main --single-branch https://github.com/baoweise-bot/aimili-vpngate.git
cd aimili-vpngate
docker compose pull
docker compose up -d
docker logs -f aimilivpn
```

正式镜像地址：

```text
ghcr.io/baoweise-bot/aimili-vpngate:2.1
```

更新容器：

```bash
docker compose pull
docker compose up -d
```

### Docker 直接运行

```bash
docker run -d \
  --name aimilivpn \
  --restart unless-stopped \
  --network host \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --device /dev/net/tun:/dev/net/tun \
  -e UI_HOST=0.0.0.0 \
  -e UI_PORT=8787 \
  -e LOCAL_PROXY_HOST=127.0.0.1 \
  -e LOCAL_PROXY_PORT=7928 \
  -v aimilivpn-data:/data \
  ghcr.io/baoweise-bot/aimili-vpngate:2.1
```

### 在 VPS 本地构建 Docker 镜像

无法拉取 GHCR 镜像或希望自行审查构建过程时，可在仓库目录构建：

```bash
git clone --branch main --single-branch https://github.com/baoweise-bot/aimili-vpngate.git
cd aimili-vpngate
docker compose build
docker compose up -d
```

## 连接与使用

### 登录 Web 管理后台

源码安装完成后，终端会显示完整地址、账号和密码，地址格式如下：

```text
http://VPS_IP:8787/随机安全路径/
```

忘记地址时可执行 `ml status` 查看；需要重新设置账号或密码时执行 `ml password`。

Docker 首次启动会把 Web 安全路径以及自动生成的账号和密码保存到数据卷，可执行以下命令查看：

```bash
docker exec aimilivpn cat /data/ui_auth.json
```

读取其中的 `secret_path`、`username` 和 `password`，再访问：

```text
http://VPS_IP:8787/secret_path/
```

首次登录后，建议在管理后台修改 Web 安全路径和登录凭据。

### 获取并连接节点

1. 登录 Web 后台，等待首次节点列表加载完成，或点击“更新节点”。
2. 按国家筛选节点，需要时先使用“测试”检查实际延迟和可用性。
3. 点击目标节点的“切换”进行连接；切换前会先预检目标节点，目标不可用时会尽量保留当前连接。
4. 根据需要选择智能自动、固定国家或固定 IP 路由模式。
5. 在状态区域确认 VPN 已连接，并检查当前出口 IP。

### 在 VPS 本机使用代理

HTTP、HTTPS 和 SOCKS5 共用默认端口 `127.0.0.1:7928`。HTTPS 网站通过 HTTP 代理的 `CONNECT` 方法访问，因此代理地址仍填写 `http://127.0.0.1:7928`。

Shell 环境：

```bash
export http_proxy="http://127.0.0.1:7928"
export https_proxy="http://127.0.0.1:7928"
curl https://api.ipify.org
```

单次使用 HTTP 代理：

```bash
curl -x http://127.0.0.1:7928 https://api.ipify.org
```

单次使用 SOCKS5 代理，并让域名解析也经过代理：

```bash
curl --proxy socks5h://127.0.0.1:7928 https://api.ipify.org
```

Python `requests` 示例：

```python
import requests

proxies = {
    "http": "http://127.0.0.1:7928",
    "https": "http://127.0.0.1:7928",
}

response = requests.get("https://api.ipify.org", proxies=proxies, timeout=20)
print(response.text)
```

### 从电脑或其他设备连接

代理默认只监听 VPS 回环地址，不直接暴露到公网。推荐使用 SSH 隧道连接，在本地电脑执行：

```bash
ssh -N \
  -L 8787:127.0.0.1:8787 \
  -L 7928:127.0.0.1:7928 \
  root@VPS_IP
```

隧道建立后：

- Web 后台访问 `http://127.0.0.1:8787/随机安全路径/`。
- HTTP/HTTPS 代理填写 `127.0.0.1:7928`。
- SOCKS5 代理同样填写 `127.0.0.1:7928`，支持时优先选择远程 DNS 或 `socks5h`。

请勿在没有访问控制和身份认证的情况下把 `7928` 代理端口直接开放到公网。
