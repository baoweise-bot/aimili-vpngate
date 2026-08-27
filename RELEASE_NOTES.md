# AimiliVPN V2.1.3 正式版

V2.1.3 是一次完整的稳定性、安全性和节点识别修复版本。重点解决节点切换期间状态显示过早、未知网络误判住宅、部分 VPS 节点源回退不合理，以及安装卸载残留等问题。

## IP 类型识别

- IP 类型缓存升级到新的分类版本，旧分类会自动失效并重新检测。
- 明确区分住宅、移动、机房和未知网络，并显示高、中、低置信度及情报来源。
- Sony、KDDI、SoftBank、Korea Telecom 等有明确消费接入运营商信息且未命中机房特征的网络继续识别为住宅。
- `proxy + 数据中心关键词` 冲突节点以及完全缺少运营商信息的节点会调用 `ipapi.is` 进行第二来源复核。
- 第二来源不可用或证据不足时标记为未知/低置信度，不再直接当作住宅。
- 严格住宅路由只接受中、高置信度住宅或移动网络，拒绝未知和低置信度分类。

## 节点获取与连接切换

- 修复官方 HTTPS 超时后直接跳过官方 HTTP 的问题；现在仍会继续尝试 VPNGate 官方真实 HTTP，再进入 GitHub Pages、VPS 最近缓存和内置快照。
- GitHub 镜像状态显示生成时间与陈旧程度，HTTP 地址明确标注为跳转 HTTPS，不再描述成独立明文镜像。
- 连接状态拆分为隧道就绪和代理出口就绪；只有 OpenVPN、策略路由与真实代理出口全部通过后，前端才显示“已连接”。
- 修复批量节点检测失败时用空字段覆盖已有 ISP、物理位置和 IP 类型的问题。
- 固定国家统一保存 ISO 两字母代码，并兼容旧版中文国家名称配置。
- 物理位置国旗使用 IP 情报源国家，节点申报国家与 IP 推测位置分开提示，避免来源冲突造成误解。

## 安装、安全与运维

- 卸载时清理 AimiliVPN 的 sysctl 文件、table 100 路由和全部 table 100 策略规则。
- `ui_auth.json` 创建、迁移和保存时使用私有权限 `0600`，并采用安全写入流程。
- Web 管理端口与代理端口增加双向冲突校验，冲突配置直接拒绝，不再静默改写端口。
- OpenVPN 启用 `remote-cert-tls server`，验证服务器证书用途并移除相关安全警告。
- 新增 `AIMILIVPN_NONINTERACTIVE=1` 无人值守安装模式，首次部署不会停在交互提示。
- 安装完成信息只显示实际默认监听的 IPv4 本地代理地址，不再错误提示未启用的 IPv6 地址。

## 验证与兼容性

- 本地 Python 单元测试 51/51 通过，Python 编译、Dashboard JavaScript 语法、安装脚本语法和补丁格式检查通过。
- Ubuntu 22.04 x86_64 VPS 已完成真实卸载、重新安装、节点源、连接切换、代理出口、Web API、权限和路由残留验证。
- 发布流水线会在 Python 3.9、3.11、3.13 上运行完整测试。
- Docker 会分别构建验证 `linux/amd64`、`linux/386`、`linux/arm64`、`linux/arm/v7`，并发布统一多架构镜像清单。

## 平台限制

- GitHub Actions 定时任务由 GitHub 调度，不保证每 15 分钟准点运行。
- GitHub Pages 会把 HTTP 强制跳转到 HTTPS，不能作为真正的明文 HTTP 镜像。
- 程序保留 VPNGate 官方 HTTP、VPS 最近有效缓存和内置初始快照，以降低上述平台限制的影响。

## 下载与更新

- GitHub Release：`aimilivpn-v2.1.3-linux-source.tar.gz` 和 `sha256sums.txt`。
- GHCR：`2.1.3`、`2.1`、`latest` 多架构镜像标签。

Python 源码安装更新：

```bash
ml update
```

Docker Compose 更新：

```bash
docker compose pull
docker compose up -d
```
