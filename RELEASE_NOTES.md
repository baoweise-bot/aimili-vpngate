# AimiliVPN V2.1 正式版

V2.1 是仅从 `main` 主分支发布的首个正式版本标志。

## 本次更新

- 节点来源按“VPNGate 官方 HTTPS -> 官方 HTTP -> GitHub Pages HTTPS -> GitHub Pages HTTP -> VPS 本地快照 -> 内置初始快照”自动回退。
- 修复节点获取缓慢、连接断开和切换失败时误伤现有连接的问题。
- 恢复节点延迟列，区分本机实测值与 VPNGate 官方预估值。
- 加入国旗、实时多选国家筛选、国家范围持久化和单节点测试。
- Web 管理端加入正式版更新检测，只检查 GitHub 最新稳定 Release，并只保留 `main` 主分支入口。
- `install.sh` 和 `ml update` 统一只更新 `origin/main`。
- GitHub Release 提供 Linux `amd64`、`386`、`arm64`、`armv7` 发行包与 SHA-256 校验文件。
- GHCR 提供相同四种架构的 Docker 镜像。

## 兼容范围

应用依赖 Linux TUN、OpenVPN、iptables 和策略路由，因此正式支持 Linux 主机。Docker 也必须运行在具备 `/dev/net/tun` 的 Linux 主机上，并授予 `NET_ADMIN` 能力。
