#!/usr/bin/env bash
# OpenClaw 一键安装脚本 — ApexYY 专版 (加固版)
# 用法: bash install-apexyy.sh
#
# 预置ApexYY中转全部节点和模型，用户只需要填 API Key
# Claude 和 Codex 是独立产品线，Key 不互通
set -euo pipefail

# 检查 bash 版本 (需要 4+ 支持关联数组)
if (( BASH_VERSINFO[0] < 4 )); then
  echo "[✗] 需要 bash 4+，当前版本: ${BASH_VERSION}"
  echo "    macOS 用户请运行: brew install bash"
  echo "    然后用: /usr/local/bin/bash install-apexyy.sh"
  exit 1
fi

# ========== 颜色定义 ==========
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
step()  { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
ask()   { echo -en "${CYAN}[?]${NC} $* "; }
die()   { err "$*"; exit 1; }

# ========== ApexYY节点 ==========
declare -A NODES
NODES=(
  ["1"]="https://yunyi.rdzhvip.com|国内主节点"
  ["2"]="https://yunyi.cfd|CF国外节点1"
  ["3"]="https://cdn1.yunyi.cfd|CF国外节点2"
  ["4"]="https://cdn2.yunyi.cfd|CF国外节点3"
  ["5"]="http://47.99.42.193|备用节点1"
  ["6"]="http://47.97.100.10|备用节点2"
)

# ========== OS 检测 ==========
detect_os() {
  OS="unknown"
  if [[ "$OSTYPE" == "darwin"* ]]; then OS="macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then OS="linux"
    grep -qi microsoft /proc/version 2>/dev/null && OS="wsl"
  else die "不支持的操作系统: $OSTYPE"; fi
  info "系统: ${OS}"
}

# ========== 网络连通性检查 ==========
check_network() {
  step "网络连通性检查"
  local test_urls=("https://yunyi.rdzhvip.com" "https://yunyi.cfd")
  local reachable=0

  for url in "${test_urls[@]}"; do
    if curl -sS --connect-timeout 5 --max-time 10 -o /dev/null -w '' "$url" 2>/dev/null; then
      info "${url} 可达 ✓"
      reachable=1
    else
      warn "${url} 不可达"
    fi
  done

  if (( reachable == 0 )); then
    err "所有 API 节点均不可达！请检查网络连接。"
    ask "是否继续安装? (y/N)"; read -r ans
    [[ "${ans,,}" != "y" ]] && die "安装中止"
    warn "继续安装，但 API 调用可能失败"
  fi
}

# ========== API Key 格式校验 ==========
validate_api_key() {
  local key="$1"
  local name="$2"

  if [[ -z "$key" ]]; then
    die "${name} 卡密不能为空"
  fi

  if (( ${#key} < 8 )); then
    err "${name} 卡密长度过短 (${#key} 字符)，看起来不像有效的卡密"
    ask "确定要继续吗? (y/N)"; read -r ans
    [[ "${ans,,}" != "y" ]] && die "请检查卡密后重试"
  fi

  if (( ${#key} > 256 )); then
    warn "${name} 卡密长度异常 (${#key} 字符)，请确认是否正确"
  fi

  # 检查是否包含空格或明显的占位符
  if [[ "$key" == *" "* ]]; then
    warn "${name} 卡密包含空格，可能是粘贴错误"
    ask "确定要继续吗? (y/N)"; read -r ans
    [[ "${ans,,}" != "y" ]] && die "请检查卡密后重试"
  fi

  if [[ "$key" == "your-key-here" || "$key" == "xxx" || "$key" == "test" ]]; then
    die "${name} 卡密看起来是占位符，请输入真实的卡密"
  fi
}

# ========== Node.js ==========
ensure_node() {
  step "检查 Node.js"

  # 加载 nvm（如果存在）
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null

  if command -v node &>/dev/null; then
    local ver; ver=$(node -v | sed 's/v//' | cut -d. -f1)
    if (( ver >= 22 )); then info "Node.js $(node -v) ✓"; return 0
    else warn "Node.js $(node -v) 版本过低，需要 22+"; fi
  else warn "未检测到 Node.js"; fi

  ask "自动安装 Node.js 22? (Y/n)"; read -r ans
  [[ "${ans,,}" == "n" ]] && die "请手动安装: https://nodejs.org"

  # 优先用 nvm 升级（如果已有 nvm）
  if command -v nvm &>/dev/null; then
    info "检测到 nvm，使用 nvm 安装 Node.js 22..."
    nvm install 22 && nvm use 22 && nvm alias default 22
    info "Node.js $(node -v) 安装完成"
    return 0
  fi

  case "$OS" in
    macos)
      command -v brew &>/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      brew install node@22 && brew link --overwrite node@22 2>/dev/null ;;
    linux|wsl)
      if command -v apt-get &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
      elif command -v dnf &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
        sudo dnf install -y nodejs
      elif command -v yum &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
        sudo yum install -y nodejs
      elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm nodejs npm
      elif command -v apk &>/dev/null; then
        sudo apk add --no-cache nodejs npm
      elif command -v zypper &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
        sudo zypper install -y nodejs
      else
        die "不支持的包管理器，请手动安装 Node.js 22+: https://nodejs.org"
      fi

      # 如果系统包管理器装完后 PATH 里还是旧版（nvm 覆盖），强制用系统版
      if command -v node &>/dev/null; then
        local new_ver; new_ver=$(node -v | sed 's/v//' | cut -d. -f1)
        if (( new_ver < 22 )); then
          warn "PATH 中仍是旧版 Node，尝试用 nvm 安装..."
          curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
          export NVM_DIR="$HOME/.nvm"
          [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
          nvm install 22 && nvm use 22 && nvm alias default 22
        fi
      fi ;;
  esac

  # 最终验证
  local final_ver; final_ver=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
  if (( final_ver < 22 )); then
    die "Node.js 安装后版本仍为 $(node -v)，请手动升级到 22+: https://nodejs.org"
  fi
  info "Node.js $(node -v) 安装完成"
}

# ========== OpenClaw ==========
ensure_openclaw() {
  step "检查 OpenClaw"
  if command -v openclaw &>/dev/null; then
    info "OpenClaw $(openclaw --version 2>/dev/null) 已安装"
    ask "更新到最新版? (y/N)"; read -r ans
    [[ "${ans,,}" != "y" ]] && return 0
  fi
  info "安装 OpenClaw..."
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -3 || die "安装失败"
  info "OpenClaw $(openclaw --version 2>/dev/null) ✓"
}

# ========== 选节点 ==========
choose_node() {
  step "选择 API 节点"
  echo ""
  echo -e "  ${BOLD}国内用户推荐 1，海外用户推荐 2-4${NC}"
  echo ""
  for i in 1 2 3 4 5 6; do
    local entry="${NODES[$i]}"
    local url="${entry%%|*}"
    local name="${entry#*|}"
    echo "    ${i}) ${name}  ${url}"
  done
  echo ""
  ask "请选择 [1-6] (默认 1):"
  read -r node_choice
  node_choice="${node_choice:-1}"

  local entry="${NODES[${node_choice}]:-${NODES[1]}}"
  AY_BASE_URL="${entry%%|*}"
  AY_NODE_NAME="${entry#*|}"
  info "已选择: ${AY_NODE_NAME} (${AY_BASE_URL})"
}

# ========== 选产品线 + API Key ==========
choose_product() {
  step "选择产品线"
  echo ""
  echo -e "  ${BOLD}Claude 和 Codex 是独立产品线，卡密不互通${NC}"
  echo -e "  ${BOLD}看你买的是哪个，就选哪个${NC}"
  echo ""
  echo "    1) 只有 Claude 的卡密"
  echo "    2) 只有 Codex (OpenAI) 的卡密"
  echo "    3) 两个都有"
  echo ""
  ask "请选择 [1-3] (默认 1):"
  read -r product_choice
  product_choice="${product_choice:-1}"

  HAS_CLAUDE=false
  HAS_CODEX=false
  CLAUDE_KEY=""
  CODEX_KEY=""

  case "$product_choice" in
    1)
      HAS_CLAUDE=true
      ask "请输入 Claude 卡密:"
      read -r CLAUDE_KEY
      validate_api_key "$CLAUDE_KEY" "Claude"
      info "Claude 卡密已记录"
      ;;
    2)
      HAS_CODEX=true
      ask "请输入 Codex 卡密:"
      read -r CODEX_KEY
      validate_api_key "$CODEX_KEY" "Codex"
      info "Codex 卡密已记录"
      ;;
    3)
      HAS_CLAUDE=true
      HAS_CODEX=true
      ask "请输入 Claude 卡密:"
      read -r CLAUDE_KEY
      validate_api_key "$CLAUDE_KEY" "Claude"
      info "Claude 卡密已记录"
      ask "请输入 Codex 卡密:"
      read -r CODEX_KEY
      validate_api_key "$CODEX_KEY" "Codex"
      info "Codex 卡密已记录"
      ;;
    *) die "无效选择" ;;
  esac
}

# ========== 选主模型 ==========
choose_primary() {
  step "选择主模型"
  echo ""

  local i=1
  local -a MODEL_REFS=()

  if [[ "$HAS_CLAUDE" == "true" ]]; then
    echo -e "  ${BOLD}Claude 系列:${NC}"
    echo "    ${i}) Claude Opus 4.6 (最强)"; MODEL_REFS+=("apexyy-claude/claude-opus-4-6"); ((i++))
    echo "    ${i}) Claude Opus 4.5"; MODEL_REFS+=("apexyy-claude/claude-opus-4-5"); ((i++))
    echo "    ${i}) Claude Sonnet 4.5 (均衡)"; MODEL_REFS+=("apexyy-claude/claude-sonnet-4-5"); ((i++))
    echo ""
  fi

  if [[ "$HAS_CODEX" == "true" ]]; then
    echo -e "  ${BOLD}Codex/GPT 系列:${NC}"
    echo "    ${i}) GPT 5.2"; MODEL_REFS+=("apexyy-codex/gpt-5.2"); ((i++))
    echo "    ${i}) GPT Codex 5.3"; MODEL_REFS+=("apexyy-codex/gpt-5.3-codex"); ((i++))
    echo ""
  fi

  ask "请选择主模型 [1-$((i-1))] (默认 1):"
  read -r model_choice
  model_choice="${model_choice:-1}"

  local idx=$((model_choice - 1))
  if (( idx < 0 || idx >= ${#MODEL_REFS[@]} )); then idx=0; fi
  PRIMARY_REF="${MODEL_REFS[$idx]}"
  info "主模型: ${PRIMARY_REF}"

  # Build fallbacks from remaining models
  FALLBACK_REFS=()
  for ref in "${MODEL_REFS[@]}"; do
    [[ "$ref" != "$PRIMARY_REF" ]] && FALLBACK_REFS+=("$ref")
  done
}

# ========== 选渠道 ==========
choose_channels() {
  step "选择消息渠道"
  echo ""
  echo "  1) Telegram — 最简单"
  echo "  2) Discord"
  echo "  3) Slack"
  echo "  4) WhatsApp — 需扫码"
  echo "  5) Signal"
  echo "  6) WebChat — 内置，无需配置"
  echo "  7) 跳过"
  echo ""
  ask "请选择 [1-7] (可多选，如 1,6):"
  read -r ch_choices

  CHANNEL_CMDS=()
  IFS=',' read -ra chs <<< "$ch_choices"
  for ch in "${chs[@]}"; do
    ch=$(echo "$ch" | tr -d ' ')
    case "$ch" in
      1) ask "Telegram Bot Token:"; read -r t
         [[ -n "$t" ]] && CHANNEL_CMDS+=("telegram|${t}") && info "Telegram ✓" ;;
      2) ask "Discord Bot Token:"; read -r t
         [[ -n "$t" ]] && CHANNEL_CMDS+=("discord|${t}") && info "Discord ✓" ;;
      3) ask "Slack Bot Token (xoxb-...):"; read -r sb
         ask "Slack App Token (xapp-...):"; read -r sa
         [[ -n "$sb" && -n "$sa" ]] && CHANNEL_CMDS+=("slack|${sb}|${sa}") && info "Slack ✓" ;;
      4) CHANNEL_CMDS+=("whatsapp|") && info "WhatsApp — 启动后扫码" ;;
      5) ask "Signal 号码 (+86...):"; read -r t
         [[ -n "$t" ]] && CHANNEL_CMDS+=("signal|${t}") && info "Signal ✓" ;;
      6) info "WebChat 无需配置" ;;
      7) info "跳过" ;;
    esac
  done
}

# ========== 应用配置 ==========
apply_config() {
  step "应用配置"

  local CONFIG_PATH="$HOME/.openclaw/openclaw.json"

  # 1. 用 openclaw onboard 建基础配置
  info "初始化 OpenClaw..."
  openclaw onboard --non-interactive \
    --accept-risk \
    --mode local \
    --auth-choice skip \
    --gateway-port 18789 \
    --gateway-bind loopback \
    --gateway-auth token \
    --skip-channels \
    --skip-skills \
    --skip-health \
    --skip-ui \
    --install-daemon 2>&1 | tail -5 || warn "onboard 有警告，继续..."

  # 1.5 检查 onboard 是否生成了 openclaw.json，如果没有就手动创建
  if [[ ! -f "$CONFIG_PATH" ]]; then
    warn "openclaw onboard 未生成配置文件，手动创建..."
    mkdir -p "$HOME/.openclaw"
    cat > "$CONFIG_PATH" << 'JSONEOF'
{
  "gateway": {
    "port": 18789,
    "bind": "loopback",
    "auth": "token"
  },
  "models": {
    "mode": "merge",
    "providers": {}
  },
  "agents": {
    "defaults": {}
  },
  "channels": {}
}
JSONEOF
    info "已手动创建 openclaw.json"
  fi

  # 2. 写入ApexYY provider 配置
  info "写入ApexYY模型配置..."

  local py_has_claude="False"; [[ "$HAS_CLAUDE" == "true" ]] && py_has_claude="True"
  local py_has_codex="False"; [[ "$HAS_CODEX" == "true" ]] && py_has_codex="True"

  # 转义 fallbacks 为 python list
  local fb_py="["
  local _ref
  for _ref in "${FALLBACK_REFS[@]+"${FALLBACK_REFS[@]}"}"; do
    [[ -n "$_ref" ]] && fb_py+="'${_ref}',"
  done
  fb_py+="]"

  AY_CLAUDE_KEY="$CLAUDE_KEY" AY_CODEX_KEY="$CODEX_KEY" python3 << PYEOF
import json, os

config_path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(config_path) as f:
    config = json.load(f)

config.setdefault('models', {})['mode'] = 'merge'
config['models'].setdefault('providers', {})
config.setdefault('agents', {}).setdefault('defaults', {})

base_url = "${AY_BASE_URL}"
has_claude = ${py_has_claude}
has_codex = ${py_has_codex}

claude_key = os.environ.get('AY_CLAUDE_KEY', '')
codex_key = os.environ.get('AY_CODEX_KEY', '')

if has_claude:
    config['models']['providers']['apexyy-claude'] = {
        'baseUrl': base_url + '/claude',
        'apiKey': claude_key,
        'auth': 'api-key',
        'api': 'anthropic-messages',
        'headers': {},
        'authHeader': False,
        'models': []
    }

if has_codex:
    config['models']['providers']['apexyy-codex'] = {
        'baseUrl': base_url + '/codex',
        'apiKey': codex_key,
        'auth': 'api-key',
        'api': 'openai-responses',
        'headers': {},
        'authHeader': False,
        'models': [
            {
                'id': 'gpt-5.2',
                'name': 'GPT 5.2',
                'reasoning': True,
                'input': ['text', 'image'],
                'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
                'contextWindow': 128000,
                'maxTokens': 32768
            },
            {
                'id': 'gpt-5.3-codex',
                'name': 'GPT 5.3 Codex',
                'reasoning': True,
                'input': ['text', 'image'],
                'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
                'contextWindow': 128000,
                'maxTokens': 32768
            }
        ]
    }

config['agents']['defaults']['model'] = {
    'primary': "${PRIMARY_REF}",
    'fallbacks': ${fb_py}
}

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

providers = list(config['models']['providers'].keys())
print(f"已配置 Provider: {', '.join(providers)}")
print(f"主模型: ${PRIMARY_REF}")
fallbacks = ${fb_py}
if fallbacks:
    print(f"Failover: {' → '.join(fallbacks)}")
PYEOF

  info "模型配置完成"

  # 3. 添加渠道
  for entry in "${CHANNEL_CMDS[@]+"${CHANNEL_CMDS[@]}"}"; do
    [[ -z "$entry" ]] && continue
    local ch_type="${entry%%|*}"
    local ch_rest="${entry#*|}"
    case "$ch_type" in
      telegram)
        openclaw channels add --channel telegram --token "$ch_rest" 2>&1 || warn "Telegram 添加失败"
        info "Telegram 渠道已添加" ;;
      discord)
        openclaw channels add --channel discord --token "$ch_rest" 2>&1 || warn "Discord 添加失败"
        info "Discord 渠道已添加" ;;
      slack)
        local sb="${ch_rest%%|*}"; local sa="${ch_rest#*|}"
        openclaw channels add --channel slack --bot-token "$sb" --app-token "$sa" 2>&1 || warn "Slack 添加失败"
        info "Slack 渠道已添加" ;;
      whatsapp)
        openclaw channels add --channel whatsapp 2>&1 || warn "WhatsApp 添加失败"
        info "WhatsApp 已添加" ;;
      signal)
        openclaw channels add --channel signal --signal-number "$ch_rest" 2>&1 || warn "Signal 添加失败"
        info "Signal 渠道已添加" ;;
    esac
  done
}

# ========== 启动 ==========
start_gateway() {
  step "启动 Gateway"
  openclaw gateway restart 2>&1 || openclaw gateway start 2>&1 || warn "启动失败"
  sleep 2

  # 验证启动状态
  if openclaw gateway status 2>&1 | grep -qi "running\|online\|listening"; then
    info "Gateway 运行中 ✓"
  else
    warn "Gateway 可能未正常启动"
    warn "请手动检查: openclaw gateway status"
    warn "尝试手动启动: openclaw gateway start"
  fi
}

# ========== 验证 ==========
verify() {
  step "验证配置"
  python3 -c "
import json
with open('$HOME/.openclaw/openclaw.json') as f:
    c = json.load(f)
p = c.get('agents',{}).get('defaults',{}).get('model',{})
print(f\"  主模型: {p.get('primary','?')}\")
fb = p.get('fallbacks',[])
if fb: print(f\"  Failover: {' → '.join(fb)}\")
providers = c.get('models',{}).get('providers',{})
for name, data in providers.items():
    models = [m['id'] for m in data.get('models',[])]
    label = ', '.join(models) if models else '(自动检测)'
    print(f\"  {name}: {label} ({data.get('baseUrl','?')})\")
" 2>/dev/null || true
}

# ========== 安装摘要 ==========
print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║          🎉 OpenClaw 安装完成!                  ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}📦 已安装:${NC}"
  echo -e "    • Node.js $(node -v 2>/dev/null || echo '?')"
  echo -e "    • OpenClaw $(openclaw --version 2>/dev/null || echo '?')"
  echo ""
  echo -e "  ${BOLD}⚙️  已配置:${NC}"
  echo -e "    • ApexYY节点: ${AY_NODE_NAME} (${AY_BASE_URL})"
  echo -e "    • 主模型: ${PRIMARY_REF}"
  [[ "$HAS_CLAUDE" == "true" ]] && echo -e "    • Claude Provider: ${GREEN}已配置${NC}"
  [[ "$HAS_CODEX" == "true" ]] && echo -e "    • Codex Provider: ${GREEN}已配置${NC}"
  if [[ ${#CHANNEL_CMDS[@]} -gt 0 ]]; then
    echo -e "    • 消息渠道: ${#CHANNEL_CMDS[@]} 个"
  fi
  echo ""
  echo -e "  ${BOLD}🌐 WebChat:${NC}"
  echo -e "    ${CYAN}http://localhost:18789${NC}"
  echo -e "    在浏览器中打开即可开始对话"
  echo ""
  # Web Panel info (if installed)
  if [[ -f "$HOME/.openclaw/web-panel/server.js" ]]; then
    echo -e "  ${BOLD}🖥️  Web 管理面板:${NC}"
    echo -e "    ${CYAN}http://localhost:5338${NC}"
    echo -e "    管理 Gateway、模型、渠道、配置"
    echo ""
  fi
  echo -e "  ${BOLD}📋 常用命令:${NC}"
  echo "    openclaw gateway status    — 查看状态"
  echo "    openclaw gateway restart   — 重启"
  echo "    openclaw gateway stop      — 停止"
  echo "    openclaw doctor            — 健康检查"
  echo ""
  echo -e "  ${BOLD}💰 额度查询:${NC}"
  echo -e "    ${CYAN}https://yunyi.rdzhvip.com/user${NC}"
  echo ""
  echo -e "  ${BOLD}🔄 切换节点:${NC}"
  echo "    编辑 ~/.openclaw/openclaw.json 中的 baseUrl"
  echo "    然后 openclaw gateway restart"
  echo ""
  echo -e "  ${BOLD}🗑️  卸载方法:${NC}"
  echo "    1. openclaw gateway stop"
  echo "    2. npm uninstall -g openclaw"
  echo "    3. rm -rf ~/.openclaw"
  echo "    或使用卸载脚本: bash uninstall-apexyy.sh"
  echo ""
  echo -e "  ${BOLD}🔄 更新方法:${NC}"
  echo "    bash update-apexyy.sh"
  echo "    或手动: npm update -g openclaw && openclaw gateway restart"
  echo ""
}

# ========== Web 管理面板 ==========
install_web_panel() {
  # 只在 Linux 服务器（无 GUI）上安装
  if [[ "$OS" != "linux" ]] && [[ "$OS" != "wsl" ]]; then
    return 0
  fi

  # 如果有 DISPLAY 或者是 WSL，跳过（有 GUI 可以用 Electron 版）
  if [[ -n "${DISPLAY:-}" ]] || [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    return 0
  fi

  step "安装 Web 管理面板"
  info "检测到 Linux 服务器（无 GUI），安装 Web 管理面板..."

  local PANEL_DIR="$HOME/.openclaw/web-panel"
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local SOURCE_DIR="${SCRIPT_DIR}/web-panel"

  # 检查源文件是否存在
  if [[ ! -d "$SOURCE_DIR" ]]; then
    warn "Web 面板源文件不存在 (${SOURCE_DIR})，跳过"
    return 0
  fi

  # 复制文件
  mkdir -p "$PANEL_DIR"
  cp -r "$SOURCE_DIR"/* "$PANEL_DIR/"

  # 安装依赖
  cd "$PANEL_DIR" && npm install --production 2>&1 | tail -3 || warn "npm install 有警告"

  # 创建 systemd 服务
  local SERVICE_FILE="$HOME/.config/systemd/user/openclaw-web-panel.service"
  mkdir -p "$(dirname "$SERVICE_FILE")"
  cat > "$SERVICE_FILE" << EOF
[Unit]
Description=OpenClaw Web Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=${PANEL_DIR}
ExecStart=$(which node) ${PANEL_DIR}/server.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=default.target
EOF

  # 启动服务
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable openclaw-web-panel 2>/dev/null || true
  systemctl --user start openclaw-web-panel 2>/dev/null || true

  # 检查是否启动成功
  sleep 2
  if systemctl --user is-active openclaw-web-panel &>/dev/null; then
    info "Web 管理面板已启动 ✓"
    info "地址: http://localhost:5338"
  else
    # 如果 systemd 不可用，直接后台启动
    warn "systemd 用户服务不可用，使用 nohup 启动..."
    cd "$PANEL_DIR"
    nohup node server.js > "$HOME/.openclaw/web-panel.log" 2>&1 &
    local panel_pid=$!
    sleep 2
    if kill -0 "$panel_pid" 2>/dev/null; then
      info "Web 管理面板已启动 (PID: ${panel_pid}) ✓"
      info "地址: http://localhost:5338"
      echo "$panel_pid" > "$PANEL_DIR/.pid"
    else
      warn "Web 管理面板启动失败，请手动启动: cd ${PANEL_DIR} && node server.js"
    fi
  fi
}

# ========== 主流程 ==========
main() {
  echo ""
  echo -e "${BOLD}🦞 OpenClaw 一键安装 — ApexYY 专版${NC}"
  echo -e "   预置全部ApexYY节点 + Claude/Codex 模型"
  echo ""

  detect_os
  check_network
  ensure_node
  ensure_openclaw
  choose_node
  choose_product
  choose_primary
  choose_channels
  apply_config
  start_gateway
  install_web_panel
  verify
  print_summary
}

main "$@"
