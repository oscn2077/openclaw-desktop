#!/usr/bin/env bash
# OpenClaw ApexYY 专版 — 静默安装 (加固版)
# Claude 和 Codex 是独立产品线，Key 不互通
#
# 用法 (只有 Claude):
#   AY_CLAUDE_KEY=xxx bash install-apexyy-silent.sh
#
# 用法 (只有 Codex):
#   AY_CODEX_KEY=xxx bash install-apexyy-silent.sh
#
# 用法 (两个都有):
#   AY_CLAUDE_KEY=xxx AY_CODEX_KEY=yyy bash install-apexyy-silent.sh
#
# 用法 (旧版兼容，AY_KEY 同时给 Claude 和 Codex):
#   AY_KEY=xxx bash install-apexyy-silent.sh
#
# Dry-run 模式 (只显示会做什么，不实际执行):
#   AY_CLAUDE_KEY=xxx bash install-apexyy-silent.sh --dry-run
#
# 环境变量:
#   AY_CLAUDE_KEY       — Claude 卡密
#   AY_CODEX_KEY        — Codex 卡密
#   AY_KEY              — (兼容) 同时用于 Claude 和 Codex
#   AY_NODE             — 节点选择 1-6 (默认 1 国内主节点)
#                         1=yunyi.rdzhvip.com 2=yunyi.cfd 3=cdn1.yunyi.cfd
#                         4=cdn2.yunyi.cfd 5=47.99.42.193 6=47.97.100.10
#   AY_PRIMARY          — 主模型 (默认 claude-opus-4-5)
#   TELEGRAM_TOKEN      — Telegram Bot Token
#   DISCORD_TOKEN       — Discord Bot Token
#   SLACK_BOT_TOKEN + SLACK_APP_TOKEN — Slack
#   SIGNAL_NUMBER       — Signal 号码
#   SKIP_NODE_INSTALL=1 — 跳过 Node.js
#   SKIP_OPENCLAW_INSTALL=1 — 跳过 OpenClaw
#   SKIP_DAEMON=1       — 跳过 daemon
#   GATEWAY_PORT        — 端口 (默认 18789)
set -euo pipefail

# 检查 bash 版本 (需要 4+ 支持关联数组)
if (( BASH_VERSINFO[0] < 4 )); then
  echo "[✗] 需要 bash 4+，当前版本: ${BASH_VERSION}"
  exit 1
fi

# ========== 颜色定义 ==========
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
step()  { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
die()   { err "$*"; exit 1; }

# ========== Dry-run 模式 ==========
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

# dry-run 包装器：如果是 dry-run 模式，只打印命令不执行
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[dry-run]${NC} $*"
  else
    "$@"
  fi
}

# ========== 解析 Key ==========
CLAUDE_KEY="${AY_CLAUDE_KEY:-${AY_KEY:-}}"
CODEX_KEY="${AY_CODEX_KEY:-}"

[[ -z "$CLAUDE_KEY" && -z "$CODEX_KEY" ]] && die "请设置 AY_CLAUDE_KEY 或 AY_CODEX_KEY (或 AY_KEY)"

if [[ -n "${AY_KEY:-}" && -z "${AY_CLAUDE_KEY:-}" && -z "${AY_CODEX_KEY:-}" ]]; then
  warn "AY_KEY 仅用于 Claude。如需 Codex 请单独设置 AY_CODEX_KEY"
fi

HAS_CLAUDE=false; [[ -n "$CLAUDE_KEY" ]] && HAS_CLAUDE=true
HAS_CODEX=false; [[ -n "$CODEX_KEY" ]] && HAS_CODEX=true

PORT="${GATEWAY_PORT:-18789}"

# ========== API Key 格式校验 ==========
validate_api_key() {
  local key="$1"
  local name="$2"

  if [[ -z "$key" ]]; then
    die "${name} 卡密不能为空"
  fi

  if (( ${#key} < 8 )); then
    die "${name} 卡密长度过短 (${#key} 字符)，看起来不像有效的卡密"
  fi

  if (( ${#key} > 256 )); then
    warn "${name} 卡密长度异常 (${#key} 字符)，请确认是否正确"
  fi

  if [[ "$key" == *" "* ]]; then
    warn "${name} 卡密包含空格，可能是粘贴错误"
  fi

  if [[ "$key" == "your-key-here" || "$key" == "xxx" || "$key" == "test" ]]; then
    die "${name} 卡密看起来是占位符，请输入真实的卡密"
  fi
}

# 校验 Key
[[ "$HAS_CLAUDE" == "true" ]] && validate_api_key "$CLAUDE_KEY" "Claude"
[[ "$HAS_CODEX" == "true" ]] && validate_api_key "$CODEX_KEY" "Codex"

# ========== 节点映射 ==========
declare -A NODE_URLS NODE_NAMES
NODE_URLS=( ["1"]="https://yunyi.rdzhvip.com" ["2"]="https://yunyi.cfd" ["3"]="https://cdn1.yunyi.cfd" ["4"]="https://cdn2.yunyi.cfd" ["5"]="http://47.99.42.193" ["6"]="http://47.97.100.10" )
NODE_NAMES=( ["1"]="国内主节点" ["2"]="CF国外节点1" ["3"]="CF国外节点2" ["4"]="CF国外节点3" ["5"]="备用节点1" ["6"]="备用节点2" )
AY_NODE_NUM="${AY_NODE:-1}"
AY_BASE="${NODE_URLS[${AY_NODE_NUM}]:-${NODE_URLS[1]}}"
AY_NODE_NAME="${NODE_NAMES[${AY_NODE_NUM}]:-${NODE_NAMES[1]}}"
info "节点: ${AY_NODE_NAME} (${AY_BASE})"

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
    [[ "$DRY_RUN" == "true" ]] && warn "[dry-run] 继续执行" && return 0
    die "网络不可达，安装中止"
  fi
}

check_network

# ========== Dry-run 摘要 ==========
if [[ "$DRY_RUN" == "true" ]]; then
  step "Dry-run 模式 — 以下是将要执行的操作"
  echo ""
  echo -e "  ${BOLD}1. 系统检查${NC}"
  echo "     检查 Node.js >= 22，不满足则自动安装"
  echo ""
  echo -e "  ${BOLD}2. 安装 OpenClaw${NC}"
  echo "     npm install -g openclaw@latest"
  echo ""
  echo -e "  ${BOLD}3. 初始化配置${NC}"
  echo "     openclaw onboard --non-interactive ..."
  echo "     端口: ${PORT}"
  echo ""
  echo -e "  ${BOLD}4. 写入 ApexYY 配置${NC}"
  echo "     配置文件: ~/.openclaw/openclaw.json"
  echo "     节点: ${AY_NODE_NAME} (${AY_BASE})"
  [[ "$HAS_CLAUDE" == "true" ]] && echo "     Claude Provider: apexyy-claude (Key: ${CLAUDE_KEY:0:4}...)"
  [[ "$HAS_CODEX" == "true" ]] && echo "     Codex Provider: apexyy-codex (Key: ${CODEX_KEY:0:4}...)"
  echo ""
  echo -e "  ${BOLD}5. 渠道配置${NC}"
  [[ -n "${TELEGRAM_TOKEN:-}" ]] && echo "     Telegram: 是"
  [[ -n "${DISCORD_TOKEN:-}" ]] && echo "     Discord: 是"
  [[ -n "${SLACK_BOT_TOKEN:-}" ]] && echo "     Slack: 是"
  [[ -n "${SIGNAL_NUMBER:-}" ]] && echo "     Signal: 是"
  [[ -z "${TELEGRAM_TOKEN:-}" && -z "${DISCORD_TOKEN:-}" && -z "${SLACK_BOT_TOKEN:-}" && -z "${SIGNAL_NUMBER:-}" ]] && echo "     无额外渠道 (WebChat 默认可用)"
  echo ""
  echo -e "  ${BOLD}6. 启动 Gateway${NC}"
  echo "     openclaw gateway start"
  echo ""
  echo -e "  ${YELLOW}以上操作未实际执行。去掉 --dry-run 参数以真正安装。${NC}"
  exit 0
fi

# ========== Node.js ==========
if [[ "${SKIP_NODE_INSTALL:-}" != "1" ]]; then
  step "检查 Node.js"
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null

  if ! command -v node &>/dev/null || (( $(node -v | sed 's/v//' | cut -d. -f1) < 22 )); then
    if command -v nvm &>/dev/null; then
      nvm install 22 && nvm use 22 && nvm alias default 22
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      brew install node@22 2>/dev/null
    elif command -v apt-get &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs
    elif command -v dnf &>/dev/null; then
      curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - && sudo dnf install -y nodejs
    elif command -v yum &>/dev/null; then
      curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - && sudo yum install -y nodejs
    elif command -v pacman &>/dev/null; then
      sudo pacman -Sy --noconfirm nodejs npm
    elif command -v apk &>/dev/null; then
      sudo apk add --no-cache nodejs npm
    elif command -v zypper &>/dev/null; then
      curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - && sudo zypper install -y nodejs
    else
      die "请手动安装 Node.js 22+: https://nodejs.org"
    fi

    # nvm 覆盖 PATH 导致还是旧版
    if (( $(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1) < 22 )); then
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      nvm install 22 && nvm use 22 && nvm alias default 22
    fi
  fi
  info "Node.js $(node -v)"
fi

# ========== OpenClaw ==========
if [[ "${SKIP_OPENCLAW_INSTALL:-}" != "1" ]]; then
  step "安装 OpenClaw"
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -3
  info "OpenClaw $(openclaw --version 2>/dev/null)"
fi

# ========== Onboard ==========
step "初始化 OpenClaw"
DAEMON_FLAG="--install-daemon"
[[ "${SKIP_DAEMON:-}" == "1" ]] && DAEMON_FLAG="--skip-daemon"

CONFIG_PATH="$HOME/.openclaw/openclaw.json"

openclaw onboard --non-interactive --accept-risk --mode local --auth-choice skip \
  --gateway-port "${PORT}" --gateway-bind loopback --gateway-auth token \
  --skip-channels --skip-skills --skip-health --skip-ui ${DAEMON_FLAG} 2>&1 | tail -3 || warn "onboard 警告"

# 检查 onboard 是否生成了 openclaw.json，如果没有就手动创建
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

# ========== 确定主模型 ==========
PRIMARY="${AY_PRIMARY:-}"
if [[ -z "$PRIMARY" ]]; then
  if [[ "$HAS_CLAUDE" == "true" ]]; then PRIMARY="claude-opus-4-5"
  else PRIMARY="gpt-5.2"; fi
fi

if [[ "$PRIMARY" == gpt-* || "$PRIMARY" == o3* || "$PRIMARY" == o4* ]]; then
  PRIMARY_REF="apexyy-codex/${PRIMARY}"
else
  PRIMARY_REF="apexyy-claude/${PRIMARY}"
fi

# ========== 写入配置 ==========
step "写入 ApexYY 配置"
AY_CLAUDE_KEY_ENV="$CLAUDE_KEY" AY_CODEX_KEY_ENV="$CODEX_KEY" python3 << PYEOF
import json, os

p = os.path.expanduser("~/.openclaw/openclaw.json")
with open(p) as f: c = json.load(f)
c.setdefault('models', {})['mode'] = 'merge'
c['models'].setdefault('providers', {})
c.setdefault('agents', {}).setdefault('defaults', {})

base = "${AY_BASE}"
has_claude = $( [[ "$HAS_CLAUDE" == "true" ]] && echo "True" || echo "False" )
has_codex = $( [[ "$HAS_CODEX" == "true" ]] && echo "True" || echo "False" )

claude_key = os.environ.get('AY_CLAUDE_KEY_ENV', '')
codex_key = os.environ.get('AY_CODEX_KEY_ENV', '')

if has_claude:
    c['models']['providers']['apexyy-claude'] = {
        'baseUrl': base + '/claude',
        'apiKey': claude_key,
        'auth': 'api-key',
        'api': 'anthropic-messages',
        'headers': {},
        'authHeader': False,
        'models': []
    }

if has_codex:
    c['models']['providers']['apexyy-codex'] = {
        'baseUrl': base + '/codex',
        'apiKey': codex_key,
        'auth': 'api-key',
        'api': 'openai-responses',
        'headers': {},
        'authHeader': False,
        'models': [
            {
                'id': 'gpt-5.2', 'name': 'GPT 5.2', 'reasoning': True,
                'input': ['text', 'image'],
                'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
                'contextWindow': 128000, 'maxTokens': 32768
            },
            {
                'id': 'gpt-5.3-codex', 'name': 'GPT 5.3 Codex', 'reasoning': True,
                'input': ['text', 'image'],
                'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
                'contextWindow': 128000, 'maxTokens': 32768
            }
        ]
    }

primary_ref = "${PRIMARY_REF}"

all_refs = []
if has_claude:
    all_refs += ['apexyy-claude/claude-opus-4-5', 'apexyy-claude/claude-opus-4-6', 'apexyy-claude/claude-sonnet-4-5']
if has_codex:
    all_refs += ['apexyy-codex/gpt-5.2', 'apexyy-codex/gpt-5.3-codex']
fallbacks = [r for r in all_refs if r != primary_ref]

c['agents']['defaults']['model'] = {'primary': primary_ref, 'fallbacks': fallbacks}

with open(p, 'w') as f: json.dump(c, f, indent=2, ensure_ascii=False)
print(f"主模型: {primary_ref}")
if fallbacks: print(f"Failover: {' → '.join(fallbacks)}")
PYEOF

info "ApexYY配置完成"

# ========== 渠道 ==========
[[ -n "${TELEGRAM_TOKEN:-}" ]] && { openclaw channels add --channel telegram --token "${TELEGRAM_TOKEN}" 2>&1 || warn "Telegram 失败"; info "Telegram ✓"; }
[[ -n "${DISCORD_TOKEN:-}" ]] && { openclaw channels add --channel discord --token "${DISCORD_TOKEN}" 2>&1 || warn "Discord 失败"; info "Discord ✓"; }
[[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_APP_TOKEN:-}" ]] && { openclaw channels add --channel slack --bot-token "${SLACK_BOT_TOKEN}" --app-token "${SLACK_APP_TOKEN}" 2>&1 || warn "Slack 失败"; info "Slack ✓"; }
[[ -n "${SIGNAL_NUMBER:-}" ]] && { openclaw channels add --channel signal --signal-number "${SIGNAL_NUMBER}" 2>&1 || warn "Signal 失败"; info "Signal ✓"; }

# ========== 启动 ==========
step "启动 Gateway"
openclaw gateway restart 2>&1 || openclaw gateway start 2>&1 || warn "启动失败"
sleep 2

# 验证启动状态
if openclaw gateway status 2>&1 | grep -qi "running\|online\|listening"; then
  info "Gateway 运行中 ✓"
else
  warn "Gateway 可能未正常启动，请检查: openclaw gateway status"
fi

# ========== 安装摘要 ==========
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
echo -e "    • 节点: ${AY_NODE_NAME} (${AY_BASE})"
echo -e "    • 主模型: ${PRIMARY_REF}"
[[ "$HAS_CLAUDE" == "true" ]] && echo -e "    • Claude Provider: ${GREEN}已配置${NC}"
[[ "$HAS_CODEX" == "true" ]] && echo -e "    • Codex Provider: ${GREEN}已配置${NC}"
echo ""
echo -e "  ${BOLD}🌐 WebChat:${NC} ${CYAN}http://localhost:${PORT}${NC}"
echo -e "  ${BOLD}💰 额度查询:${NC} ${CYAN}https://yunyi.rdzhvip.com/user${NC}"
echo ""
echo -e "  ${BOLD}📋 常用命令:${NC}"
echo "    openclaw gateway status    — 查看状态"
echo "    openclaw gateway restart   — 重启"
echo "    openclaw gateway stop      — 停止"
echo ""
