#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'

# 1. Check root permissions
if [[ "$(id -u)" != "0" ]]; then
    echo -e "${RED}错误: 必须以 root 权限运行此脚本。请使用: sudo bash $0${PLAIN}"
    exit 1
fi

# 2. Check OS distribution (Ubuntu only)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
        echo -e "${RED}错误: 本系统不是 Ubuntu！目前 AimiliVPN 仅支持 Ubuntu 系统。${PLAIN}"
        exit 1
    fi
else
    echo -e "${RED}错误: 无法确定操作系统版本，缺少 /etc/os-release 文件。${PLAIN}"
    exit 1
fi

echo -e "${BLUE}==========================================================${PLAIN}"
echo -e "${BLUE}        欢迎使用 AimiliVPN 一键源码部署与管理脚本${PLAIN}"
echo -e "${BLUE}==========================================================${PLAIN}"

# 3. Configure GitHub Repository URL
# Default to the official repository (baoweise-bot/aimili-vpngate)
DEFAULT_USER="baoweise-bot"
DEFAULT_REPO="aimili-vpngate"

# Allow custom repository override via command line arguments
GITHUB_USER="${1:-${DEFAULT_USER}}"
GITHUB_REPO="${2:-${DEFAULT_REPO}}"

GITHUB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"

echo -e "\n${YELLOW}[1/4] 正在安装系统基础依赖...${PLAIN}"
echo -e "  -> 正在运行 apt-get update 更新软件源清单..."
apt-get update -q || true
echo -e "  -> 正在运行 apt-get install 安装基础依赖包 (openvpn, curl, git, iptables, iproute2, psmisc, python3)..."
apt-get install -y openvpn curl git ca-certificates iptables iproute2 psmisc python3

# 4. Clone or pull the repository
INSTALL_DIR="/opt/aimilivpn"
echo -e "\n${YELLOW}[2/4] 正在从 GitHub 部署源代码到 ${INSTALL_DIR}...${PLAIN}"
if [ -f "${INSTALL_DIR}/.local_dev" ]; then
    echo -e "${GREEN}检测到本地开发模式 (.local_dev)，跳过 git pull/reset 保持本地修改。${PLAIN}"
else
    if [ -d "${INSTALL_DIR}" ]; then
        echo -e "  -> 目录 ${INSTALL_DIR} 已存在，正在更新并强制覆盖本地源码..."
        cd "${INSTALL_DIR}"
        git fetch --all || true
        BRANCH="main"
        if git rev-parse --verify origin/main >/dev/null 2>&1; then
            BRANCH="main"
        elif git rev-parse --verify origin/master >/dev/null 2>&1; then
            BRANCH="master"
        fi
        echo -e "  -> 正在强制重置本地源码至 origin/${BRANCH} ..."
        if git reset --hard "origin/${BRANCH}"; then
            echo -e "${GREEN}  -> 源码更新成功！${PLAIN}"
        else
            if git pull; then
                echo -e "${GREEN}  -> 源码更新成功！${PLAIN}"
            else
                echo -e "${YELLOW}  -> 警告: git pull/reset 失败，将保留当前本地源码并继续安装。${PLAIN}"
            fi
        fi
    else
        echo -e "  -> 正在克隆 GitHub 仓库 ${GITHUB_URL} ..."
        if git clone "${GITHUB_URL}" "${INSTALL_DIR}"; then
            echo -e "${GREEN}  -> 克隆成功！${PLAIN}"
        else
            echo -e "${RED}  -> 错误: 无法克隆仓库 ${GITHUB_URL}，请检查网络！${PLAIN}"
            exit 1
        fi
    fi
fi

# 5. Configure Systemd Service (multi-instance template)
echo -e "\n${YELLOW}[3/4] 正在配置 systemd 系统服务（多实例模板）...${PLAIN}"

# Disable & remove legacy single-instance unit if present (port 7928 / tun0 conflict)
if [ -f /lib/systemd/system/aimilivpn.service ] && [ ! -L /lib/systemd/system/aimilivpn.service ]; then
    if grep -q "^ExecStart=/usr/bin/python3 vpngate_manager.py$" /lib/systemd/system/aimilivpn.service 2>/dev/null; then
        echo -e "  -> 检测到旧版单实例 aimilivpn.service，正在停用并清理..."
        systemctl disable --now aimilivpn.service 2>/dev/null || true
        rm -f /lib/systemd/system/aimilivpn.service
    fi
fi

# Country -> tun device, policy table, proxy port, UI port mapping (deterministic)
# JP: tun10/table110/proxy 7928/UI 8788
# US: tun11/table111/proxy 7929/UI 8789
# KR: tun12/table112/proxy 7930/UI 8790
declare -A TUN_DEV_MAP=(  [JP]=tun10 [US]=tun11 [KR]=tun12 )
declare -A POLICY_MAP=(   [JP]=110   [US]=111   [KR]=112   )
declare -A PROXY_PORT_MAP=( [JP]=7928 [US]=7929 [KR]=7930 )
declare -A UI_PORT_MAP=(  [JP]=8788  [US]=8789  [KR]=8790 )

# Allow override via COUNTRIES=JP,US env var; default JP,US,KR
COUNTRIES="${COUNTRIES:-JP,US,KR}"

mkdir -p /etc/aimilivpn

echo -e "  -> 正在创建 systemd 模板单元 /lib/systemd/system/aimilivpn@.service ..."
cat > /lib/systemd/system/aimilivpn@.service <<EOF
[Unit]
Description=AimiliVPN OpenVPN Manager (instance %i)
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 vpngate_manager.py
Restart=always
RestartSec=5
EnvironmentFile=/etc/aimilivpn/%i.env

[Install]
WantedBy=multi-user.target
EOF

# Generate per-country env files
IFS=',' read -ra CC_LIST <<< "$COUNTRIES"
for CC in "${CC_LIST[@]}"; do
    CC="${CC^^}"
    if [ -z "${TUN_DEV_MAP[$CC]:-}" ]; then
        echo -e "${YELLOW}  -> 跳过未定义的国家代码: ${CC}（仅支持 JP/US/KR）${PLAIN}"
        continue
    fi
    ENV_FILE="/etc/aimilivpn/${CC,,}.env"
    DATA_DIR="${INSTALL_DIR}/data/${CC,,}"
    mkdir -p "$DATA_DIR"
    cat > "$ENV_FILE" <<EOF
INSTANCE_ID=${CC,,}
TUN_DEV=${TUN_DEV_MAP[$CC]}
POLICY_TABLE=${POLICY_MAP[$CC]}
LOCAL_PROXY_HOST=127.0.0.1
LOCAL_PROXY_PORT=${PROXY_PORT_MAP[$CC]}
UI_HOST=0.0.0.0
UI_PORT=${UI_PORT_MAP[$CC]}
ALLOWED_COUNTRIES=${CC}
EXCLUDE_DATACENTER=1
VPNGATE_DATA_DIR=${DATA_DIR}
EOF
    chmod 600 "$ENV_FILE"
    echo -e "  -> ${GREEN}[${CC}]${PLAIN} 已生成 ${ENV_FILE} (tun ${TUN_DEV_MAP[$CC]}, proxy ${PROXY_PORT_MAP[$CC]}, UI ${UI_PORT_MAP[$CC]})"
done

echo -e "  -> 正在重新加载 systemd 系统服务列表并启用各实例开机自启..."
systemctl daemon-reload
for CC in "${CC_LIST[@]}"; do
    CC="${CC,,}"
    [ -f "/etc/aimilivpn/${CC}.env" ] && systemctl enable "aimilivpn@${CC}.service" >/dev/null 2>&1 || true
done

# 6. Configure global command shortcut "ml"
echo -e "\n${YELLOW}[4/4] 正在创建全局命令快捷接口 'ml'...${PLAIN}"
echo -e "  -> 正在写入管理脚本 /usr/bin/ml ..."
cat > /usr/bin/ml <<'EOF'
#!/usr/bin/env python3
import sys
import os
import socket
import subprocess
import time
import tty
import termios

INSTALL_DIR = "/opt/aimilivpn"
ENV_DIR = "/etc/aimilivpn"
INSTANCE = ""  # set by main() once argv is parsed

def discover_instances():
    try:
        return sorted(
            f.removesuffix(".env")
            for f in os.listdir(ENV_DIR)
            if f.endswith(".env") and os.path.isfile(os.path.join(ENV_DIR, f))
        )
    except FileNotFoundError:
        return []

def load_instance_env(cc):
    env_file = os.path.join(ENV_DIR, f"{cc}.env")
    env = {}
    try:
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    except OSError:
        return None
    return env

def instance_data_dir(cc):
    env = load_instance_env(cc) or {}
    return env.get("VPNGATE_DATA_DIR") or os.path.join(INSTALL_DIR, "data", cc)

def instance_log_file(cc):
    return os.path.join(instance_data_dir(cc), "vpngate.log")

def instance_service(cc):
    return f"aimilivpn@{cc}.service"

def instance_proxy_port(cc):
    env = load_instance_env(cc) or {}
    try:
        return int(env.get("LOCAL_PROXY_PORT") or 7928)
    except ValueError:
        return 7928

def instance_ui_port(cc):
    env = load_instance_env(cc) or {}
    try:
        return int(env.get("UI_PORT") or 8787)
    except ValueError:
        return 8787

def generate_random_password():
    import random
    import string
    chars = string.ascii_letters + string.digits
    while True:
        pwd = "".join(random.choices(chars, k=12))
        if any(c.islower() for c in pwd) and any(c.isupper() for c in pwd) and any(c.isdigit() for c in pwd):
            return pwd

def generate_random_suffix():
    import random
    import string
    return "".join(random.choices(string.ascii_letters + string.digits, k=12))

def load_ui_cfg():
    import json
    path = os.path.join(instance_data_dir(INSTANCE), "ui_auth.json")
    cfg = {"host": "0.0.0.0", "port": instance_ui_port(INSTANCE), "secret_path": "EJsW2EeBo9lY", "password": ""}
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                for k, v in data.items():
                    cfg[k] = v
        except Exception:
            pass
    return cfg

def save_ui_cfg(cfg):
    import json
    path = os.path.join(instance_data_dir(INSTANCE), "ui_auth.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)
        return True
    except Exception:
        return False

def load_state():
    import json
    path = os.path.join(instance_data_dir(INSTANCE), "state.json")
    state = {"active_openvpn_node_id": "", "last_check_message": "", "is_connecting": False}
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                for k, v in data.items():
                    state[k] = v
        except Exception:
            pass
    return state

def get_active_node_info():
    import json
    path = os.path.join(instance_data_dir(INSTANCE), "nodes.json")
    state = load_state()
    active_id = state.get("active_openvpn_node_id")
    if not active_id:
        return None, None
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                nodes = json.load(f)
                for n in nodes:
                    if n.get("id") == active_id:
                        ip = n.get("ip") or n.get("remote_host")
                        loc = n.get("location") or n.get("country") or "未知"
                        return ip, loc
        except Exception:
            pass
    return None, None

def ping_ip(ip):
    if not ip:
        return None
    try:
        # Run standard linux ping command with 1 packet and 2 seconds timeout
        res = subprocess.run(["ping", "-c", "1", "-W", "2", ip], capture_output=True, text=True, timeout=3)
        if res.returncode == 0:
            out = res.stdout
            lines = out.splitlines()
            for line in lines:
                if "rtt" in line or "min/avg" in line:
                    parts = line.split("=")[1].strip().split("/")
                    if len(parts) >= 2:
                        avg_rtt = float(parts[1])
                        return f"{int(avg_rtt)} ms"
            return "已响应"
        else:
            return "检测超时"
    except Exception:
        return "无法连接"

def get_public_ip():
    path = os.path.join(instance_data_dir(INSTANCE), "public_ip.txt")
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                ip = f.read().strip()
                if ip:
                    return ip
        except Exception:
            pass
    import urllib.request
    try:
        req = urllib.request.Request("https://api.ipify.org", headers={"User-Agent": "curl/7.68.0"})
        with urllib.request.urlopen(req, timeout=1.5) as r:
            ip = r.read().decode().strip()
            if ip:
                try:
                    os.makedirs(os.path.dirname(path), exist_ok=True)
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(ip)
                except Exception:
                    pass
                return ip
    except Exception:
        pass
    return "您的服务器公网IP"

def check_port_listening(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.2)
    try:
        s.connect(("127.0.0.1", port))
        s.close()
        return True
    except Exception:
        return False

def get_service_pid(cc=None):
    cc = cc or INSTANCE
    if not cc:
        return None
    expect = f"VPNGATE_DATA_DIR={instance_data_dir(cc)}"
    try:
        for pid_dir in os.listdir('/proc'):
            if not pid_dir.isdigit():
                continue
            try:
                with open(os.path.join('/proc', pid_dir, 'cmdline'), 'r') as f:
                    cmd = f.read()
                if 'vpngate_manager.py' not in cmd:
                    continue
                with open(os.path.join('/proc', pid_dir, 'environ'), 'r') as f:
                    env = f.read()
                if expect in env:
                    return pid_dir
            except Exception:
                continue
    except Exception:
        pass
    return None

def check_service_active(cc=None):
    return get_service_pid(cc) is not None

def check_openvpn_process(cc=None):
    cc = cc or INSTANCE
    env = load_instance_env(cc) or {}
    tun = env.get("TUN_DEV", "")
    try:
        for pid_dir in os.listdir('/proc'):
            if not pid_dir.isdigit():
                continue
            try:
                with open(os.path.join('/proc', pid_dir, 'cmdline'), 'r') as f:
                    cmd = f.read()
                if 'openvpn' not in cmd:
                    continue
                if tun and tun in cmd:
                    return True
                if not tun:
                    return True
            except Exception:
                continue
    except Exception:
        pass
    return False

def get_display_width(s):
    import re
    ansi_escape = re.compile(r'\x1b\[[0-9;]*[mGKH]')
    s_clean = ansi_escape.sub('', s)
    width = 0
    for char in s_clean:
        if ord(char) > 127:
            width += 2
        else:
            width += 1
    return width

def format_line(label, value, target_width=26):
    prefix = "  ● "
    w = get_display_width(label)
    padding = " " * max(0, target_width - w)
    return f"{prefix}{label}{padding}:  {value}"

def print_line(text=""):
    print(f"{text}\033[K")

def print_status():
    cfg = load_ui_cfg()
    ui_port = instance_ui_port(INSTANCE)
    proxy_port = instance_proxy_port(INSTANCE)
    secret_path = cfg.get("secret_path", "EJsW2EeBo9lY")
    state = load_state()
    is_connecting = state.get("is_connecting", False)

    gateway_ok = check_port_listening(proxy_port)
    service_ok = check_service_active(INSTANCE)
    openvpn_ok = check_openvpn_process(INSTANCE)
    pid = get_service_pid(INSTANCE)

    active_ip, active_loc = get_active_node_info()
    latency = state.get("active_node_latency", "测试中...") if active_ip else "无活动连接"

    green = "\033[1;32m"
    red = "\033[1;31m"
    reset = "\033[0m"
    bold = "\033[1m"
    yellow = "\033[1;33m"

    backend_status = f"{green}[已激活] (PID: {pid}){reset}" if (service_ok and pid) else f"{red}[未启动]{reset}"

    if is_connecting:
        gateway_status = f"{yellow}[切换中...]{reset}"
        openvpn_status = f"{yellow}[{state.get('active_node_latency') or '连接中'}...]{reset}"
    else:
        gateway_status = f"{green}[已激活]{reset}" if gateway_ok else f"{red}[未启动]{reset}"
        openvpn_status = f"{green}[已连接]{reset}" if openvpn_ok else f"{red}[未连接]{reset}"

    print_line("=======================================================")
    print_line(f"        {bold}AimiliVPN 管理终端 [实例: {INSTANCE.upper()}]{reset}")
    print_line("=======================================================")
    print_line("【核心服务状态】")
    print_line(format_line(f"代理网关 (Port {proxy_port})", gateway_status))
    print_line(format_line(f"管理后台 (Port {ui_port})", backend_status))
    print_line(format_line("连接核心 (OpenVPN)", openvpn_status))

    login_ip = "127.0.0.1" if cfg.get("host") == "127.0.0.1" else get_public_ip()
    print_line(format_line("网页登录地址", f"{yellow}http://{login_ip}:{ui_port}/{secret_path}/{reset}"))
    print_line(format_line("网页管理账号", cfg.get("username", "未配置")))
    curr_pwd = cfg.get("password", "")
    masked_pwd = curr_pwd if len(curr_pwd) <= 4 else curr_pwd[:3] + "********" + curr_pwd[-2:]
    print_line(format_line("网页管理密码", masked_pwd))
    print_line()
    print_line("【活动节点状态】")
    if is_connecting:
        connecting_msg = state.get('last_check_message') or '正在建立加密隧道并验证路由规则...'
        print_line(format_line("节点状态", f"{yellow}{connecting_msg}{reset}"))
    elif active_ip:
        proxy_ip = state.get("proxy_ip", "-")
        proxy_latency = state.get("proxy_latency_ms", 0)
        proxy_ok = state.get("proxy_ok", False)

        print_line(format_line("节点 IP (入口)", active_ip))
        print_line(format_line("节点地区", active_loc))
        print_line(format_line("节点延迟 (直连测试)", latency))
        if proxy_ok and proxy_ip and proxy_ip != "-":
            print_line(format_line("出口 IP (出站)", proxy_ip))
            print_line(format_line("本地代理延迟", f"{proxy_latency} ms" if proxy_latency else "检测中..."))
        else:
            print_line(format_line("出口 IP (出站)", f"{red}[检测中/未就绪]{reset}"))
    else:
        print_line(format_line("节点状态", "无活动连接"))
    print_line()
    print_line("【使用方法】")
    print_line(f"  export http_proxy=socks5://127.0.0.1:{proxy_port}")
    print_line(f"  export https_proxy=socks5://127.0.0.1:{proxy_port}")
    print_line("=======================================================")

def start_service():
    print(f"正在启动 AimiliVPN[{INSTANCE.upper()}] 服务...", flush=True)
    subprocess.run(["systemctl", "start", instance_service(INSTANCE)])
    print("已发送启动指令。")
    time.sleep(1)

def stop_service():
    print(f"正在停止 AimiliVPN[{INSTANCE.upper()}] 服务...", flush=True)
    subprocess.run(["systemctl", "stop", instance_service(INSTANCE)])
    print("已发送停止指令。")
    time.sleep(1)

def restart_service():
    print(f"正在重启 AimiliVPN[{INSTANCE.upper()}] 服务...", flush=True)
    subprocess.run(["systemctl", "restart", instance_service(INSTANCE)])
    print("已发送重启指令。")
    time.sleep(1)

def show_logs():
    log_file = instance_log_file(INSTANCE)
    print(f"正在查看 AimiliVPN[{INSTANCE.upper()}] 日志 (按 Ctrl+C 退出)...", flush=True)
    if os.path.exists(log_file):
        try:
            subprocess.run(["tail", "-f", "-n", "50", log_file])
        except KeyboardInterrupt:
            pass
    else:
        print(f"日志文件不存在: {log_file}")
        time.sleep(2)

def update_service():
    print("正在获取远程更新并检测版本...", flush=True)
    if os.path.exists(INSTALL_DIR):
        try:
            os.chdir(INSTALL_DIR)
            if not os.path.exists(".git"):
                print("错误: 当前安装目录不是 Git 仓库，无法通过 Git 更新。")
                time.sleep(3)
                return
            
            # Fetch remote origin updates
            subprocess.run(["git", "fetch", "--all"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Detect remote branch (check origin/main, then origin/master)
            branch = "main"
            for b in ["main", "master"]:
                chk = subprocess.run(["git", "rev-parse", "--verify", f"origin/{b}"], capture_output=True, text=True)
                if chk.returncode == 0:
                    branch = b
                    break
            
            local_commit = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
            remote_commit = subprocess.run(["git", "rev-parse", f"origin/{branch}"], capture_output=True, text=True).stdout.strip()
            
            if local_commit == remote_commit:
                print("\n【版本状态】当前已是最新版本，无需更新！")
                override = input("是否强制重新拉取代码并覆盖安装？(y/N): ").strip().lower()
                if override != 'y':
                    print("已取消更新。")
                    time.sleep(1.5)
                    return
            else:
                print(f"\n【检测到更新】本地版本: {local_commit[:8]}，远程最新版本: {remote_commit[:8]}")
                confirm = input("是否确认开始更新并重启服务？(Y/n): ").strip().lower()
                if confirm not in ('', 'y', 'yes'):
                    print("已取消更新。")
                    time.sleep(1.5)
                    return
            
            print(f"\n正在强制重置本地代码至 origin/{branch} ...", flush=True)
            subprocess.run(["git", "reset", "--hard", f"origin/{branch}"], check=True)
            
            # Clean up python cache files
            print("正在清理 Python 缓存 (pycache)...", flush=True)
            subprocess.run(["find", ".", "-type", "d", "-name", "__pycache__", "-exec", "rm", "-rf", "{}", "+"], check=False)
            
            print("代码拉取成功，正在重新运行安装脚本...", flush=True)
            subprocess.run(["bash", "install.sh"])
            print("更新已完成！")
            time.sleep(2)
        except Exception as e:
            print(f"更新失败: {e}")
            time.sleep(4)
    else:
        print(f"未找到安装目录: {INSTALL_DIR}")
        time.sleep(2)

def uninstall_service():
    confirm = input("确定要完全卸载 AimiliVPN（所有国家实例）吗？(y/N): ")
    if confirm.lower() == 'y':
        print("正在完全卸载 AimiliVPN...", flush=True)
        for cc in discover_instances():
            subprocess.run(["systemctl", "stop", instance_service(cc)])
            subprocess.run(["systemctl", "disable", instance_service(cc)])
        try:
            os.unlink("/lib/systemd/system/aimilivpn@.service")
        except Exception:
            pass
        try:
            os.unlink("/lib/systemd/system/aimilivpn.service")
        except Exception:
            pass
        subprocess.run(["rm", "-rf", ENV_DIR])
        try:
            os.unlink("/usr/bin/ml")
        except Exception:
            pass
        subprocess.run(["rm", "-rf", INSTALL_DIR])
        print("AimiliVPN 已卸载！")
        sys.exit(0)
    else:
        print("已取消卸载。")
        time.sleep(1)

def ask_restart():
    ans = input("配置已保存。是否立即重启服务生效？(Y/n): ").strip().lower()
    if ans in ('', 'y', 'yes'):
        print(f"正在重启 AimiliVPN[{INSTANCE.upper()}] 服务...", flush=True)
        subprocess.run(["systemctl", "restart", instance_service(INSTANCE)])
        print("服务已重启。")
        time.sleep(1.5)

def configure_web():
    cfg = load_ui_cfg()
    while True:
        print("\033[H\033[J", end="")
        print("=======================================================")
        print("               网页绑定与地址后缀配置                  ")
        print("=======================================================")
        print(f"  [1] 切换绑定地址 (当前: {cfg.get('host', '0.0.0.0')})")
        print(f"  [2] 随机重置安全后缀 (当前: {cfg.get('secret_path', '')})")
        print("  [3] 返回主菜单")
        print("=======================================================")
        print("请直接输入数字键 [1-3] 快速执行：", end="", flush=True)
        
        key = getch()
        if key == '1':
            print("\033[H\033[J", end="")
            print("选择网页登录绑定地址：")
            print("  1. 仅允许本地登录 (127.0.0.1 - 更安全)")
            print("  2. 允许公网IP登录 (0.0.0.0 - 方便远程)")
            sel = input("请选择 (1 或 2, 默认2): ").strip()
            if sel == '1':
                cfg['host'] = "127.0.0.1"
            else:
                cfg['host'] = "0.0.0.0"
            save_ui_cfg(cfg)
            print(f"绑定地址已更新为: {cfg['host']}")
            ask_restart()
            break
        elif key == '2':
            print("\033[H\033[J", end="")
            new_path = generate_random_suffix()
            cfg['secret_path'] = new_path
            save_ui_cfg(cfg)
            print("安全登录后缀已随机重置成功！")
            print(f"您的全新安全登录后缀为: {new_path}")
            print(f"新的访问路径为: http://{cfg['host']}:{cfg['port']}/{new_path}/")
            ask_restart()
            break
        elif key == '3' or key == 'q' or key == '\x03':
            break

def configure_port():
    cfg = load_ui_cfg()
    print("\033[H\033[J", end="")
    print("=======================================================")
    print("                      管理端口配置                     ")
    print("=======================================================")
    print(f"当前网页管理端口为: {cfg.get('port', 8787)}")
    try:
        val = input("请输入新的管理端口 (1-65535, 按回车取消): ").strip()
        if val:
            port = int(val)
            if 1 <= port <= 65535:
                cfg['port'] = port
                save_ui_cfg(cfg)
                print(f"管理端口已更新为: {port}")
                ask_restart()
            else:
                print("错误: 端口范围必须在 1 至 65535 之间。")
                time.sleep(2)
    except ValueError:
        print("错误: 输入必须是数字。")
        time.sleep(2)

def configure_credentials():
    cfg = load_ui_cfg()
    while True:
        print("\033[H\033[J", end="")
        print("=======================================================")
        print("                    管理账号密码管理                   ")
        print("=======================================================")
        curr_uname = cfg.get('username', '未配置')
        curr_pwd = cfg.get('password', '')
        masked_pwd = curr_pwd if len(curr_pwd) <= 4 else curr_pwd[:3] + "********" + curr_pwd[-2:]
        print(f"当前管理账号: {curr_uname}")
        print(f"当前管理密码: {masked_pwd}")
        print("  [1] 自定义修改账号密码")
        print("  [2] 随机重置安全密码")
        print("  [3] 返回主菜单")
        print("=======================================================")
        print("请直接输入数字键 [1-3] 快速执行：", end="", flush=True)
        
        key = getch()
        if key == '1':
            print("\033[H\033[J", end="")
            new_uname = input(f"请输入新管理账号 (回车默认 {curr_uname}): ").strip()
            if not new_uname:
                new_uname = curr_uname
            new_pwd = input("请输入新管理密码 (不能为空): ").strip()
            if not new_pwd:
                print("错误: 密码不能为空！")
                time.sleep(2)
                continue
            cfg['username'] = new_uname
            cfg['password'] = new_pwd
            save_ui_cfg(cfg)
            print("账号密码修改成功！")
            print(f"您的新管理账号: {new_uname}")
            print(f"您的新管理密码: {new_pwd}")
            input("\n按任意键返回菜单...")
        elif key == '2':
            print("\033[H\033[J", end="")
            new_pwd = generate_random_password()
            cfg['password'] = new_pwd
            save_ui_cfg(cfg)
            print("密码随机重置成功！")
            print(f"您的全新12位安全密码为: {new_pwd}")
            print("密码已保存在本地，不需要重启服务，刷新浏览器即可登录。")
            input("\n按任意键返回菜单...")
        elif key == '3' or key == 'q' or key == '\x03':
            break

def getch():
    fd = sys.stdin.fileno()
    try:
        old_settings = termios.tcgetattr(fd)
    except termios.error:
        return sys.stdin.read(1)
    try:
        tty.setraw(sys.stdin.fileno())
        ch = sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch

def getch_timeout(timeout=1.0):
    import select
    fd = sys.stdin.fileno()
    try:
        old_settings = termios.tcgetattr(fd)
    except termios.error:
        try:
            r, _, _ = select.select([sys.stdin], [], [], timeout)
            if r:
                ch = sys.stdin.read(1)
                if not ch:
                    time.sleep(timeout)
                    return None
                return ch
        except Exception:
            time.sleep(timeout)
        return None
    try:
        tty.setraw(fd)
        r, _, _ = select.select([sys.stdin], [], [], timeout)
        if r:
            ch = sys.stdin.read(1)
            if not ch:
                return None
            return ch
        return None
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

def get_status_state():
    cfg = load_ui_cfg()
    state = load_state()
    return (
        instance_ui_port(INSTANCE),
        cfg.get("secret_path", "EJsW2EeBo9lY"),
        cfg.get("username", "未配置"),
        cfg.get("password", ""),
        cfg.get("host", "0.0.0.0"),
        state.get("is_connecting", False),
        state.get("active_openvpn_node_id", ""),
        state.get("last_check_message", ""),
        state.get("active_node_latency", ""),
        state.get("proxy_ip", "-"),
        state.get("proxy_latency_ms", 0),
        state.get("proxy_ok", False),
        check_port_listening(instance_proxy_port(INSTANCE)),
        check_service_active(INSTANCE),
        check_openvpn_process(INSTANCE),
        get_service_pid(INSTANCE),
    )

def print_aggregate_status():
    green = "\033[1;32m"
    red = "\033[1;31m"
    yellow = "\033[1;33m"
    bold = "\033[1m"
    reset = "\033[0m"
    instances = discover_instances()
    if not instances:
        print(f"{red}未发现任何已配置的实例 ({ENV_DIR}/*.env){reset}")
        return
    print_line("============================================================")
    print_line(f"        {bold}AimiliVPN 多实例总览{reset}")
    print_line("============================================================")
    for cc in instances:
        env = load_instance_env(cc) or {}
        proxy_port = instance_proxy_port(cc)
        ui_port = instance_ui_port(cc)
        active = check_service_active(cc)
        gateway = check_port_listening(proxy_port)
        ovpn = check_openvpn_process(cc)
        flag = f"{green}[已运行]{reset}" if active else f"{red}[未运行]{reset}"
        gw = f"{green}OK{reset}" if gateway else f"{red}DOWN{reset}"
        vp = f"{green}已连接{reset}" if ovpn else f"{red}未连接{reset}"
        print_line(f"  {bold}[{cc.upper()}]{reset} 服务 {flag}  代理:{proxy_port} {gw}  OpenVPN: {vp}  UI:{ui_port}  TUN:{env.get('TUN_DEV','-')}")
    print_line("============================================================")
    print_line(f"{yellow}单实例详细状态: ml <jp|us|kr> status{reset}")
    print_line(f"{yellow}单实例操作:     ml <jp|us|kr> <start|stop|restart|logs>{reset}")

def main():
    global INSTANCE
    if os.geteuid() != 0:
        print("错误: 必须以 root 权限运行此命令。")
        sys.exit(1)

    instances = discover_instances()
    if not instances:
        print("错误: 未发现任何已配置的实例 (/etc/aimilivpn/*.env)。请先运行 install.sh。")
        sys.exit(1)

    args = sys.argv[1:]
    target_cc = None

    # ml <cc> <cmd> ...
    if args and args[0].lower() in instances:
        target_cc = args[0].lower()
        args = args[1:]

    # bare `ml status` or `ml` with multiple instances → aggregate view
    if target_cc is None and (not args or args[0].lower() == "status") and len(instances) > 1:
        if not args:
            # interactive aggregate dashboard
            print("\033[?1049h\033[?25l\033[H\033[J", end="", flush=True)
            try:
                while True:
                    print("\033[H", end="")
                    print_aggregate_status()
                    print_line("\n\033[1;33m按任意键或 Ctrl+C 退出...\033[0m")
                    print("\033[J", end="", flush=True)
                    key = getch_timeout(2.0)
                    if key is not None:
                        break
            except KeyboardInterrupt:
                pass
            finally:
                print("\033[?1049l\033[?25h", end="", flush=True)
            sys.exit(0)
        else:
            print_aggregate_status()
            sys.exit(0)

    # single-instance fallback (1 instance) — implicit
    if target_cc is None:
        target_cc = instances[0]

    INSTANCE = target_cc

    if args:
        cmd = args[0].lower()
        if cmd == "start":
            start_service()
        elif cmd == "stop":
            stop_service()
        elif cmd == "restart":
            restart_service()
        elif cmd == "status":
            print("\033[?1049h\033[?25l\033[H\033[J", end="", flush=True)
            try:
                last_state = None
                while True:
                    current_state = get_status_state()
                    if current_state != last_state:
                        print("\033[H", end="")
                        print_status()
                        print_line("\n\033[1;33m提示: 正在实时监控状态，自动更新。按任意键或 Ctrl+C 退出...\033[0m")
                        print("\033[J", end="", flush=True)
                        last_state = current_state
                    key = getch_timeout(1.5)
                    if key is not None:
                        break
            except KeyboardInterrupt:
                pass
            finally:
                print("\033[?1049l\033[?25h", end="", flush=True)
        elif cmd == "logs":
            show_logs()
        elif cmd == "update":
            update_service()
        elif cmd == "uninstall":
            uninstall_service()
        elif cmd == "web":
            configure_web()
        elif cmd == "port":
            configure_port()
        elif cmd == "password":
            configure_credentials()
        else:
            print(f"未知命令 '{cmd}'。可用命令: start, stop, restart, status, logs, update, uninstall, web, port, password")
            print(f"用法: ml [{'|'.join(instances)}] <command>")
        sys.exit(0)
        
    options = {
        '1': ("启动服务 (ml start)", start_service),
        '2': ("停止服务 (ml stop)", stop_service),
        '3': ("重启服务 (ml restart)", restart_service),
        '4': ("日志监控 (ml logs)", show_logs),
        '5': ("网页配置 (ml web)", configure_web),
        '6': ("端口配置 (ml port)", configure_port),
        '7': ("账号密码 (ml password)", configure_credentials),
        '8': ("一键更新 (ml update)", update_service),
        '9': ("完全卸载 (ml uninstall)", uninstall_service),
        '0': ("退出终端", None)
    }
    
    # Enter alternate buffer and hide cursor
    print("\033[?1049h\033[?25l\033[H\033[J", end="", flush=True)
    try:
        last_state = None
        while True:
            current_state = get_status_state()
            if current_state != last_state:
                print("\033[H", end="")
                print_status()
                
                bold = "\033[1m"
                reset = "\033[0m"
                green = "\033[1;32m"
                
                print_line(f"【{bold}终端指令菜单栏{reset}】")
                for key in sorted(options.keys()):
                    if key == '0':
                        continue
                    name, _ = options[key]
                    print_line(f"  {green}[{key}]{reset} {name}")
                print_line(f"  {green}[0]{reset} {options['0'][0]}")
                print_line("=======================================================")
                print("请直接输入数字键 [0-9] 快速选择执行：\033[K", end="", flush=True)
                print("\033[J", end="", flush=True)
                last_state = current_state
                
            try:
                key = getch_timeout(1.0)
            except KeyboardInterrupt:
                break
                
            if key is None:
                continue
                
            if key == '\x03' or key == 'q' or key == 'Q':
                break
                
            if key == '0':
                break
                
            if key in ('\r', '\n', '\x0a', '\x0d'):
                last_state = None
                continue
                
            if key in options:
                name, func = options[key]
                if func is None:
                    break
                    
                # Temporarily restore normal terminal scrollback and show cursor
                print("\033[?1049l\033[?25h", end="", flush=True)
                print(f"正在执行: {name}...\n")
                
                try:
                    func()
                except Exception as e:
                    print(f"执行出错: {e}")
                    
                if func not in (start_service, stop_service, restart_service,
                                configure_web, configure_port, configure_credentials, show_logs, update_service):
                    input("\n操作已完成，按回车键返回主菜单...")
                    
                # Re-enter alternate buffer and hide cursor
                print("\033[?1049h\033[?25l\033[H\033[J", end="", flush=True)
                last_state = None
    finally:
        # Exit alternate buffer and show cursor on exit
        print("\033[?1049l\033[?25h", end="", flush=True)

if __name__ == "__main__":
    main()
EOF
chmod +x /usr/bin/ml

# 7. Configure shared UI auth (one login for all instances)
echo -e "\n${YELLOW}[4/4] 正在配置网页管理凭据（所有国家实例共用同一组登录）...${PLAIN}"

FIRST_CC="${CC_LIST[0],,}"
FIRST_AUTH_FILE="${INSTALL_DIR}/data/${FIRST_CC}/ui_auth.json"

if [ ! -f "$FIRST_AUTH_FILE" ]; then
    echo -e "${YELLOW}检测到是首次安装，是否需要自定义配置网页端参数（安全后缀/登录账号密码）？${PLAIN}"
    read -p "是否自定义配置？[y/N]: " is_custom

    SECRET_PATH=$(python3 -c "import random, string; print(''.join(random.choices(string.ascii_letters + string.digits, k=12)))")
    UI_PASSWORD=$(python3 -c "
import random, string
chars = string.ascii_letters + string.digits
while True:
    pwd = ''.join(random.choices(chars, k=12))
    if any(c.islower() for c in pwd) and any(c.isupper() for c in pwd) and any(c.isdigit() for c in pwd):
        print(pwd)
        break
")
    UI_USERNAME=$(python3 -c "
import random, string
chars = string.ascii_letters + string.digits
while True:
    uname = ''.join(random.choices(chars, k=12))
    if uname[0].isalpha() and any(c.islower() for c in uname) and any(c.isupper() for c in uname) and any(c.isdigit() for c in uname):
        print(uname)
        break
")

    if [[ "$is_custom" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "请输入网页登录自定义安全后缀 [字母与数字组合, 默认随机]: " input_suffix
            if [ -z "$input_suffix" ]; then
                break
            fi
            if [[ "$input_suffix" =~ ^[A-Za-z0-9]+$ ]]; then
                SECRET_PATH=$input_suffix
                break
            else
                echo -e "${RED}输入错误: 后缀仅能由英文字母和数字组成！${PLAIN}"
            fi
        done

        read -p "请输入登录账号 [默认 $UI_USERNAME]: " input_user
        if [ -n "$input_user" ]; then
            UI_USERNAME=$input_user
        fi

        while true; do
            read -p "请输入登录密码 [默认随机生成, 建议包含字母、数字与符号]: " input_pass
            if [ -z "$input_pass" ]; then
                break
            fi
            if [ ${#input_pass} -ge 4 ]; then
                UI_PASSWORD=$input_pass
                break
            else
                echo -e "${RED}输入错误: 密码长度不能少于 4 位！${PLAIN}"
            fi
        done
    fi

    # Write the same auth JSON into each instance data dir
    for CC in "${CC_LIST[@]}"; do
        CC="${CC,,}"
        [ -f "/etc/aimilivpn/${CC}.env" ] || continue
        DD="${INSTALL_DIR}/data/${CC}"
        mkdir -p "$DD"
        UI_PORT_VAL="${UI_PORT_MAP[${CC^^}]}"
        python3 -c "
import json
cfg = {
    'host': '0.0.0.0',
    'port': int('$UI_PORT_VAL'),
    'secret_path': '$SECRET_PATH',
    'username': '$UI_USERNAME',
    'password': '$UI_PASSWORD',
}
with open('${DD}/ui_auth.json', 'w', encoding='utf-8') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
"
    done
fi

# 8. Start each instance
echo -e "\n正在启动 AimiliVPN 多实例服务..."
for CC in "${CC_LIST[@]}"; do
    CC="${CC,,}"
    [ -f "/etc/aimilivpn/${CC}.env" ] || continue
    systemctl restart "aimilivpn@${CC}.service" || true
    echo -e "  -> ${GREEN}aimilivpn@${CC}.service${PLAIN} 已发送启动指令"
done

echo -e "\n${YELLOW}首次抓取节点 + 建立加密通道通常需要 30-90 秒，启动状态可用 'ml status' 查看${PLAIN}"

# Read auth back from the first instance's data dir for the summary
SECRET_PATH="EJsW2EeBo9lY"
USERNAME="未配置"
PASSWORD="未配置"
if [ -f "$FIRST_AUTH_FILE" ]; then
    SECRET_PATH=$(python3 -c "import json; print(json.load(open('$FIRST_AUTH_FILE')).get('secret_path', 'EJsW2EeBo9lY'))" 2>/dev/null || echo "EJsW2EeBo9lY")
    USERNAME=$(python3 -c "import json; print(json.load(open('$FIRST_AUTH_FILE')).get('username', '未配置'))" 2>/dev/null || echo "未配置")
    PASSWORD=$(python3 -c "import json; print(json.load(open('$FIRST_AUTH_FILE')).get('password', '未配置'))" 2>/dev/null || echo "未配置")
fi

# Get VPS public IP
echo -e "正在获取 VPS 公网 IP..."
PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org || curl -s --max-time 3 https://ifconfig.me || curl -s --max-time 3 icanhazip.com || echo "您的服务器公网IP")
for CC in "${CC_LIST[@]}"; do
    CC="${CC,,}"
    [ -f "/etc/aimilivpn/${CC}.env" ] || continue
    echo -n "$PUBLIC_IP" > "${INSTALL_DIR}/data/${CC}/public_ip.txt"
done

echo -e "\n${GREEN}==========================================================${PLAIN}"
echo -e "${GREEN}             AimiliVPN 多国家部署已完成！${PLAIN}"
echo -e "${GREEN}==========================================================${PLAIN}"
for CC in "${CC_LIST[@]}"; do
    CC_UP="${CC^^}"
    CC_LO="${CC,,}"
    [ -f "/etc/aimilivpn/${CC_LO}.env" ] || continue
    echo -e "  * [${CC_UP}] 网页面板:    ${BLUE}http://${PUBLIC_IP}:${UI_PORT_MAP[$CC_UP]}/${SECRET_PATH}/${PLAIN}"
    echo -e "  * [${CC_UP}] 出口代理:    ${BLUE}socks5://127.0.0.1:${PROXY_PORT_MAP[$CC_UP]}${PLAIN}"
done
echo -e " --------------------------------------------------------"
echo -e "  * 共用登录账号:  ${YELLOW}${USERNAME}${PLAIN}"
echo -e "  * 共用登录密码:  ${YELLOW}${PASSWORD}${PLAIN}"
echo -e " --------------------------------------------------------"
echo -e "  * 查看实例状态:  ${YELLOW}ml status${PLAIN}  (聚合视图)"
echo -e "  * 单实例操作:    ${YELLOW}ml jp restart${PLAIN} / ${YELLOW}ml us logs${PLAIN} / ${YELLOW}ml kr stop${PLAIN}"
echo -e "=========================================================="
echo
