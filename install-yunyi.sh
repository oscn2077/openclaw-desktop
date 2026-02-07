#!/usr/bin/env bash
# OpenClaw 一键安装脚本 — 云翼 (YunYi) 专版
# 用法: bash install-yunyi.sh
#
# 预置云翼中转全部节点和模型，用户只需要填 API Key
# Claude 和 Codex 是独立产品线，Key 不互通
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
step()  { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
ask()   { echo -en "${CYAN}[?]${NC} $* "; }
die()   { err "$*"; exit 1; }

# ========== 云翼节点 ==========
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

# ========== Node.js ==========
ensure_node() {
  step "检查 Node.js"
  if command -v node &>/dev/null; then
    local ver; ver=$(node -v | sed 's/v//' | cut -d. -f1)
    if (( ver >= 22 )); then info "Node.js $(node -v) ✓"; return 0
    else warn "Node.js $(node -v) 版本过低"; fi
  else warn "未检测到 Node.js"; fi

  ask "自动安装 Node.js 22? (Y/n)"; read -r ans
  [[ "${ans,,}" == "n" ]] && die "请手动安装: https://nodejs.org"

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
      else die "不支持的包管理器"; fi ;;
  esac
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
  YY_BASE_URL="${entry%%|*}"
  YY_NODE_NAME="${entry#*|}"
  info "已选择: ${YY_NODE_NAME} (${YY_BASE_URL})"
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
      [[ -z "$CLAUDE_KEY" ]] && die "卡密不能为空"
      info "Claude 卡密已记录"
      ;;
    2)
      HAS_CODEX=true
      ask "请输入 Codex 卡密:"
      read -r CODEX_KEY
      [[ -z "$CODEX_KEY" ]] && die "卡密不能为空"
      info "Codex 卡密已记录"
      ;;
    3)
      HAS_CLAUDE=true
      HAS_CODEX=true
      ask "请输入 Claude 卡密:"
      read -r CLAUDE_KEY
      [[ -z "$CLAUDE_KEY" ]] && die "Claude 卡密不能为空"
      info "Claude 卡密已记录"
      ask "请输入 Codex 卡密:"
      read -r CODEX_KEY
      [[ -z "$CODEX_KEY" ]] && die "Codex 卡密不能为空"
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
    echo "    ${i}) Claude Opus 4.6 (最强)"; MODEL_REFS+=("yunyi-claude/claude-opus-4-6"); ((i++))
    echo "    ${i}) Claude Opus 4.5"; MODEL_REFS+=("yunyi-claude/claude-opus-4-5"); ((i++))
    echo "    ${i}) Claude Sonnet 4.5 (均衡)"; MODEL_REFS+=("yunyi-claude/claude-sonnet-4-5"); ((i++))
    echo ""
  fi

  if [[ "$HAS_CODEX" == "true" ]]; then
    echo -e "  ${BOLD}Codex/GPT 系列:${NC}"
    echo "    ${i}) GPT 5.2"; MODEL_REFS+=("yunyi-codex/gpt-5.2"); ((i++))
    echo "    ${i}) GPT Codex 5.3"; MODEL_REFS+=("yunyi-codex/gpt-5.3-codex"); ((i++))
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

  # 2. 写入云翼 provider 配置
  info "写入云翼模型配置..."

  # 构建 python 参数
  local py_has_claude="False"; [[ "$HAS_CLAUDE" == "true" ]] && py_has_claude="True"
  local py_has_codex="False"; [[ "$HAS_CODEX" == "true" ]] && py_has_codex="True"

  # 转义 fallbacks 为 python list
  local fb_py="["
  for ref in "${FALLBACK_REFS[@]:-}"; do
    [[ -n "$ref" ]] && fb_py+="'${ref}',"
  done
  fb_py+="]"

  python3 << PYEOF
import json

config_path = "$HOME/.openclaw/openclaw.json"
with open(config_path) as f:
    config = json.load(f)

config.setdefault('models', {})['mode'] = 'merge'
config['models'].setdefault('providers', {})
config.setdefault('agents', {}).setdefault('defaults', {})

base_url = "${YY_BASE_URL}"
has_claude = ${py_has_claude}
has_codex = ${py_has_codex}

# Claude provider — models 为空数组，自动检测
if has_claude:
    config['models']['providers']['yunyi-claude'] = {
        'baseUrl': base_url + '/claude',
        'apiKey': "${CLAUDE_KEY}",
        'auth': 'api-key',
        'api': 'anthropic-messages',
        'headers': {},
        'authHeader': False,
        'models': []
    }

# Codex provider — 需要显式声明模型
if has_codex:
    config['models']['providers']['yunyi-codex'] = {
        'baseUrl': base_url + '/codex',
        'apiKey': "${CODEX_KEY}",
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

# 设置主模型和 fallback
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
  for entry in "${CHANNEL_CMDS[@]:-}"; do
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
  if openclaw gateway status 2>&1 | grep -qi "running\|online\|listening"; then
    info "Gateway 运行中 ✓"
  else
    warn "请检查: openclaw gateway status"
  fi
}

# ========== 验证 ==========
verify() {
  step "验证"
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

# ========== 完成 ==========
finish() {
  step "安装完成! 🎉"
  echo ""
  echo -e "  ${BOLD}云翼节点:${NC} ${YY_NODE_NAME} (${YY_BASE_URL})"
  echo ""
  echo -e "  ${BOLD}常用命令:${NC}"
  echo "    openclaw gateway status    — 查看状态"
  echo "    openclaw gateway restart   — 重启"
  echo "    openclaw doctor            — 健康检查"
  echo ""
  echo -e "  ${BOLD}WebChat:${NC} http://localhost:18789"
  echo ""
  echo -e "  ${BOLD}额度查询:${NC} https://yunyi.rdzhvip.com/user"
  echo ""
  echo -e "  ${BOLD}切换节点:${NC}"
  echo "    编辑 ~/.openclaw/openclaw.json 中的 baseUrl"
  echo "    然后 openclaw gateway restart"
  echo ""
}

# ========== 主流程 ==========
main() {
  echo ""
  echo -e "${BOLD}🦞 OpenClaw 一键安装 — 云翼 (YunYi) 专版${NC}"
  echo -e "   预置全部云翼节点 + Claude/Codex 模型"
  echo ""

  detect_os
  ensure_node
  ensure_openclaw
  choose_node
  choose_product
  choose_primary
  choose_channels
  apply_config
  start_gateway
  verify
  finish
}

main "$@"
