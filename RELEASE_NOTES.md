# AimiliVPN V2.1.2 正式版

V2.1.2 重点修复 IP 类型误判和部分 VPS 获取节点列表等待过久的问题，并增强 GitHub Pages、VPS 最近缓存和程序内置快照的回退体验。

## Bug 修复

- 修复把 `proxy=true` 直接等同于机房 IP 的分类错误。住宅宽带用户运行 VPNGate 后可能被风险库标记为代理，但其网络归属仍然是住宅；现在代理属性与住宅/移动/机房类型分开保存。
- 修复 Sony、Korea Telecom、JCOM、SK Broadband、KDDI、Cable TV 等消费宽带节点容易被误标为机房 IP 的问题。
- 保留对真实机房网络的识别：`hosting=true` 仍直接判为机房；SoftEther、hosting、cloud、server、data center、VPS 等明确数据中心供应商特征也仍判为机房。
- 修复升级后旧版错误 IP 分类缓存继续生效最多 7 天的问题。分类缓存加入版本号，V2.1.2 会自动重新检测旧缓存，不需要用户手动删除运行数据。
- 修复只给少量连通性检测成功节点补充 IP 类型、节点表中大部分节点长期显示未知的问题。后台任务现在会批量补全整个节点列表，同时只合并运营商和分类字段，不覆盖连接、延迟或检测状态。
- 修复 VPNGate 官方接口持续缓慢传输时可能突破原有 socket 超时、拖慢备用源切换的问题。每个网络节点源现在增加 6 秒总时限。
- 修复官方 HTTPS 已超过总时限后仍继续等待同一主机 HTTP 的重复慢请求；超时后会直接尝试 GitHub Pages HTTPS。证书或 TLS 不兼容等非超时错误仍保留 HTTP 回退，兼容旧系统和不同 VPS 环境。

## 节点源与镜像优化

- 节点顺序保持为：VPNGate 官方 HTTPS、官方 HTTP、GitHub Pages HTTPS、GitHub Pages HTTP、VPS 最近有效缓存、程序内置初始快照。
- GitHub Pages 定时同步从整刻 15 分钟调整为每小时第 7、22、37、52 分钟，降低 GitHub Actions 高峰期调度延迟概率。
- GitHub Pages 与官方 HTTPS 获取到的快照继续执行相同的 CSV 字段、大小、Base64 和 OpenVPN 危险指令校验。
- HTTP 节点源继续只作为兼容回退，不覆盖最后一次通过 HTTPS 获得的可信本地快照。

## 验证结果

- 40 项单元测试通过，覆盖住宅/代理分离、真实机房识别、旧缓存迁移、后台全量富化、连接状态保护和慢速官方源回退。
- Python 编译、前端 JavaScript 语法、`install.sh` 语法和 Docker Compose 配置检查通过。
- 测试 VPS 上 VPNGate 官方 HTTPS/HTTP、GitHub Pages HTTPS/HTTP、VPS 最近缓存和内置快照均能下载、解析并生成候选节点。
- 发布流水线对 Python 3.9、3.11、3.13 运行完整测试，并分别构建验证 `linux/amd64`、`linux/386`、`linux/arm64`、`linux/arm/v7`。

## 下载与更新

- GitHub Release 提供 `aimilivpn-v2.1.2-linux-source.tar.gz` 和 `sha256sums.txt`。
- GHCR 发布 `2.1.2`、`2.1`、`latest` 三组镜像标签。

Python 源码安装更新：

```bash
ml update
```

Docker Compose 更新：

```bash
docker compose pull
docker compose up -d
```
