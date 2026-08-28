# AimiliVPN V2.1.5 正式版验收报告

测试日期：2026-08-27 至 2026-08-28（Asia/Shanghai）  
测试版本：`2.1.5`  
Git 提交：`97fc337`  
测试环境：Ubuntu 22.04.1 LTS、Linux 5.15、x86_64、Python 3.10、OpenVPN 2.5.11

> 本报告不记录 VPS SSH 密码、Web 登录凭据、安全路径或完整管理地址。

## 1. 结论

V2.1.5 已通过本地自动化、GitHub Actions 多版本/多架构构建，以及 Ubuntu x86_64 VPS 的完整卸载、公开脚本重装和真实网络验收。

本轮原计划复验 V2.1.3，但正式安装检查发现手动断开后 `proxy_ready` 没有同步清零，因此未改写旧标签，而是发布 V2.1.4。随后 V2.1.4 的失败切换压力测试又发现：原节点和 3 个备用节点均失败后，日志提示会后台补齐，实际却直接返回。该遗漏已修复并按不可变发行原则发布为 V2.1.5。

正式 V2.1.5 最终状态：服务 active/enabled，官方 HTTPS 节点源正常，97 个节点覆盖 9 个国家，六项后台服务全部 running，HTTP/SOCKS5 真实出口一致，连接状态、策略路由和断开清理正常。

## 2. 发布产物

- GitHub Actions：`33123598394`，结论 `success`。
- Python 3.9、3.11、3.13：完整测试通过。
- Docker `linux/amd64`、`linux/386`、`linux/arm64`、`linux/arm/v7`：分别构建并导入验证通过。
- GHCR 多架构索引摘要：`sha256:46b8f73ebb93ef308ef5bd51b649ce5030ab19ea7eff984e7525f9e7cb84044a`。
- GitHub Release：`v2.1.5`，非草稿、非预发布，并为当前 latest。
- 源码包：`aimilivpn-v2.1.5-linux-source.tar.gz`。
- 源码包 SHA-256：`e2cbcbb35558c34fed6083047bbb730fc9d43bd3537eb301538a1b01ff7f9363`，下载后与 `sha256sums.txt` 完全一致。
- Actions 使用 `actions/checkout@v7`、`actions/setup-python@v7` 等当前运行时版本，本次没有 Node.js 20 弃用失败。

## 3. 自动化检查

- `python -m unittest discover -s tests -v`：53/53 通过。
- `python -m py_compile`：核心 Python 模块全部通过。
- Dashboard JavaScript：由单元测试提取脚本并执行 Node.js 语法检查，通过。
- `docker compose -f compose.yaml config`：通过。
- `bash -n install.sh`：在 VPS Bash 环境通过。
- `git diff --check`：通过。
- 发行压缩包本地预构建：文件名、版本号和校验文件正确。

## 4. 完整卸载与公开脚本重装

两次执行项目自带 `ml uninstall` 后分别确认：

- `/opt/aimilivpn`、`ml`、systemd unit 和 `/etc/sysctl.d/99-aimilivpn.conf` 均不存在。
- OpenVPN 进程为 0，`tun0` 不存在。
- table 100 路由为 0，table 100 策略规则为 0。
- systemd 返回 inactive，unit 文件不存在。

随后严格执行 README 的无人值守 GitHub 安装方式：

```bash
AIMILIVPN_NONINTERACTIVE=1 bash <(curl -Ls https://raw.githubusercontent.com/baoweise-bot/aimili-vpngate/main/install.sh)
```

结果：

- 版本 `2.1.5`，提交 `97fc337`。
- 服务 active/enabled，首次连接在安装器等待窗口内完成。
- `ui_auth.json` 权限为 `0600`，所有者为 root。
- 默认 Web 端口 8787、代理端口 7928。
- 更新检查返回当前版本与 latest 均为 `2.1.5`，`update_available=false`。

## 5. 节点源与回退

| 场景 | 实际来源 | 候选数 | 结果 |
| --- | --- | ---: | --- |
| 默认正式服务 | `official_https` | 97 | 通过 |
| 强制官方 HTTPS 失败 | `official_http` | 97 | 通过 |
| 强制两个官方源失败 | `github_pages_https` | 98 | 通过 |
| GitHub Pages HTTP 地址 | 最终跳转 HTTPS | 98 | 通过，但不是真正明文镜像 |
| 四个网络源全部失败 | `local_cache` | 97 | 通过 |
| 网络源失败且无最近缓存 | `bundled_initial` | 99 | 通过 |

四个公开 URL 均从 VPS 返回 HTTP 200 和合法 VPNGate CSV。官方 HTTP/HTTPS 均保留；GitHub Pages HTTP 由平台强制跳转 HTTPS，本地最近有效快照和内置初始快照承担无网络兜底。

国家发现范围实测：选择 `JP` 后得到 58 个节点且全部为日本，配置持久化为 `JP`；清空后恢复 97 个节点、9 个国家。筛选在来源成功判定后执行，没有把“所选国家当前为 0 个节点”误判成来源失败。

## 6. IP 类型识别

正式安装的 97 个节点分类如下：

| 类型 | 数量 | 置信度约束 |
| --- | ---: | --- |
| 住宅 | 81 | 中置信度 |
| 移动 | 1 | 高置信度 |
| 机房 | 15 | 高置信度 |

严格住宅路由可接受节点为 82 个，全部属于住宅/移动且置信度为中或高。主来源冲突节点会使用第二情报源复核，不能复核的项目保持 unknown/低置信度，不会直接放入严格住宅路由。

## 7. 连接、切换与断开

### 7.1 状态门控

真实切换轮询中，连接建立前持续返回：

- `is_connecting=true`
- 活动节点 0
- `tunnel_ready=false`
- `proxy_ready=false`
- `proxy_ok=false`

只有 OpenVPN、策略路由和真实代理出口全部验证通过后，才变为活动节点 1 且三个 readiness 状态为 true。失败节点不会提前显示成已连接。

### 7.2 手动断开

调用 `/api/disconnect` 后实测：

- 活动节点 0，`is_connecting=false`。
- `tunnel_ready/proxy_ready/proxy_ok` 全部为 false。
- OpenVPN 进程 0，`tun0` 不存在。
- table 100 路由和策略规则均为 0。
- `/api/test_proxy` 返回 `ERR_ROUTE_DEV_NOT_FOUND`，没有保留旧出口假状态。
- `connection_enabled=false` 已持久化。

### 7.3 失败恢复与后台补位

V2.1.4 压力测试复现：目标节点失败，原节点恢复失败，随后 3 个备用节点也失败；旧代码只打印“后台重新加载节点”并直接返回，最长可能等到下一轮 21 分钟采集。

V2.1.5 修复后：

- 连续失败分支调用 `schedule_background_refill()`。
- 同一时间只允许一个补位线程，退避间隔为 60、120、300 秒。
- 单元测试确认耗尽分支必定调度补位。
- VPS 隔离运行确认补位线程已创建、存活且未被取消。
- 正式安装中，原节点重新拨号失败后系统保持全部 readiness 为 false，后台重新同步节点，最终自动连接到新的日本节点并恢复 HTTP/SOCKS5 出口。

## 8. 代理、路由与服务

- VPS 直连出口与 VPN 代理出口不同。
- HTTP 与 SOCKS5 返回相同 VPN 出口。
- `/api/test_proxy` 返回成功、出口 IP 和实测延迟。
- 成功连接时 table 100 有 1 条默认路由和 1 条策略规则，不重复叠加。
- Web、代理、OpenVPN、节点同步、出口检测、延迟测速共 6 项服务全部 running。
- OpenVPN 日志包含 `VERIFY KU OK` 与 `VERIFY EKU OK`，没有旧的服务器证书用途警告。
- 代理端口提交为 Web 端口时返回 HTTP 400；配置仍为 8787/7928，没有静默改写。

## 9. Web 前端

静态、自动化和真实 Chromium 交互检查已通过：

- 延迟列、官方预估延迟提示、国旗、国家多选、测试/收藏/切换按钮存在。
- 国家面板层级、复选框自绘、分页、请求去重、页面隐藏时暂停轮询和日志行数上限均有回归覆盖。
- 登录页和 Dashboard 不再使用 `backdrop-filter` 或固定背景，降低 Edge/Chromium GPU 卡死风险。
- Dashboard 内联 JavaScript 语法通过 Node.js 检查。
- Web API 登录、节点、网关、日志、更新、刷新、断开、连接和代理检测已从 VPS 真实调用通过。
- 使用项目真实 `Handler` 和隔离临时数据启动本地实例，以 97 个模拟节点完成 Chromium 桌面和移动视口登录交互；测试账号仅在本地临时实例中存在，退出后已销毁。
- 节点表实际呈现 7 列，实测延迟与“仅供参考、非本机实测”的官方预估延迟同时正确显示；日本、韩国、美国国旗和中文国家名正常，检测/收藏/切换三个按钮完整。
- 国家多选面板显示国旗、中文国名和节点数量；选择日本后即时缩减为 33 个日本节点，清空后恢复 97 个节点，分页分别显示 50/47 行。
- 层叠上下文实测为 `.toolbar z-index: 50`、国家面板 `z-index: 1000`；面板与表格相交区域的顶层命中元素属于国家面板，未再被表格遮挡。
- Web 更新检测返回“当前 V2.1.5 正式版 已是最新正式版”；网关与日志面板均能打开并渲染后端结果。
- 移动视口下工具栏控件没有越界，国家面板完整位于视口内；经过一次自动轮询周期后页面仍可在约 0.6 秒内完成连续交互，浏览器控制台错误/警告为 0。

安全边界：本轮没有在浏览器中提交正式 VPS 新生成的安全路径、账号或密码，因为该动作需要用户在提交前即时确认。正式 VPS 的同一组 Web API 已通过服务端本机登录会话完成真实调用验收；浏览器交互部分使用上述隔离实例验证，不把未执行的线上凭据提交描述为已完成。

## 10. 当前状态与边界

报告写入时：

- VPS 运行 GitHub 公开脚本安装的 V2.1.5，而不是本地临时目录。
- 服务 active/enabled，活动 VPN、HTTP/SOCKS5 出口正常。
- 节点来源为官方 HTTPS，配置恢复为全部国家、自动路由、全部 IP 类型。
- 临时防火墙规则为 0；没有修改宿主机 Docker 服务或其他项目。

未覆盖边界：

- 实体 VPS 为 Ubuntu x86_64；ARM、386 和其他发行版由 CI 构建/导入验证，不等同于对应实体机长期运行。
- VPS 无可用公网 IPv6，未验证公网 IPv6 入站或 IPv6 VPN 出口。
- 未进行数天级持续运行和 GitHub Actions 定时任务准点率统计。
- Edge 实机需要连接 Edge 浏览器扩展；本轮使用可用的 Chromium 浏览器内核进行 Web 交互。
