#!/usr/bin/env bash
# OpenClaw 一键安装+配置脚本 v2 (交互式)
# 核心原则：尽量用 openclaw CLI 原生命令，不手拼 JSON
# 支持: Ubuntu 22.04+ / Debian 12+ / macOS
set -euo pipefail

# ========== 颜色 ==========
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
step()  { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
ask()   { echo -en "${CYAN}[?]${NC} $* "; }
die()   { err "$*"; exit 1; }

# ========== OS 检测 ==========
detect_os() {
  OS="unknown"; DISTRO="unknown"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"; DISTRO="macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if grep -qi microsoft /proc/version 2>/dev/null; then
      OS="wsl"
    fi
    if [ -f /etc/os-release ]; then
      DISTRO=$(. /etc/os-release && echo "$ID")
    fi
  else
    die "不支持的操作系统: $OSTYPE"
  fi
  info "检测到系统: ${OS} (${DISTRO})"
}

# ========== Node.js ==========
ensure_node() {
  step "检查 Node.js"
  if command -v node &>/dev/null; then
    local ver; ver=$(node -v | sed 's/v//' | cut -d. -f1)
    if (( ver >= 22 )); then
      info "Node.js $(node -v) ✓"
      return 0
    else
      warn "Node.js $(node -v) 版本过低，需要 22+"
    fi
  else
    warn "未检测到 Node.js"
  fi
  ask "是否自动安装 Node.js 22? (Y/n)"
  read -r ans
  [[ "${ans,,}" == "n" ]] && die "请手动安装 Node.js 22+: https://nodejs.org"
  case "$OS" in
    macos)
      if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "Homebrew 安装失败"
      fi
      brew install node@22 && brew link --overwrite node@22 2>/dev/null || die "Node.js 安装失败"
      ;;
    linux|wsl)
      if command -v apt-get &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - || die "添加 NodeSource 源失败"
        sudo apt-get install -y nodejs || die "安装 Node.js 失败"
      elif command -v dnf &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - || die "添加 NodeSource 源失败"
        sudo dnf install -y nodejs || die "安装 Node.js 失败"
      else
        die "不支持的包管理器，请手动安装: https://nodejs.org"
      fi
      ;;
  esac
  info "Node.js $(node -v) 安装完成"
}

# ========== OpenClaw ==========
ensure_openclaw() {
  step "检查 OpenClaw"
  if command -v openclaw &>/dev/null; then
    local ver; ver=$(openclaw --version 2>/dev/null || echo "unknown")
    info "OpenClaw 已安装: $ver"
    ask "是否更新到最新版? (y/N)"
    read -r ans
    [[ "${ans,,}" != "y" ]] && return 0
  fi
  info "正在安装 OpenClaw..."
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -5 || die "安装失败"
  info "OpenClaw $(openclaw --version 2>/dev/null) 安装完成"
}

# ========== 模型选择 ==========
# 官方 API 用 openclaw onboard --non-interactive
# 中转 API 用 openclaw config + 手动写 providers
choose_model() {
  step "选择 AI 模型"
  echo ""
  echo "  ${BOLD}官方 API（用 OpenClaw 原生支持）:${NC}"
  echo "    1) Claude (Anthropic) — 最强编程+推理"
  echo "    2) OpenAI (GPT) — 通用能力强"
  echo "    3) Google Gemini — 免费额度大"
  echo "    4) GLM (智谱) — 国产免费模型"
  echo "    5) Moonshot (Kimi) — 国产长上下文"
  echo "    6) MiniMax — 国产多模态"
  echo "    7) 小米 — 国产"
  echo ""
  echo "  ${BOLD}中转 API（第三方代理）:${NC}"
  echo "    8) Claude 中转 (Anthropic 兼容接口)"
  echo "    9) OpenAI 中转 (OpenAI 兼容接口)"
  echo ""
  ask "请选择 [1-9]:"
  read -r choice

  USE_ONBOARD=true  # 是否用 openclaw onboard 来配置
  ONBOARD_ARGS=""
  CUSTOM_PROVIDER_JSON=""

  case "$choice" in
    1)
      ask "请输入 Anthropic API Key (sk-ant-...):"
      read -r API_KEY
      [[ -z "$API_KEY" ]] && die "API Key 不能为空"
      ONBOARD_ARGS="--auth-choice apiKey --anthropic-api-key ${API_KEY}"
      ;;
    2)
      ask "请输入 OpenAI API Key (sk-...):"
      read -r API_KEY
      [[ -z "$API_KEY" ]] && die "API Key 不能为空"
      ONBOARD_ARGS="--auth-choice openai-api-key --openai-api-key ${API_KEY}"
      ;;
    3)
      ask "请输入 Gemini API Key (从 https://aistudio.google.com/apikey 获取):"
      read -r API_KEY
      [[ -z "$API_KEY" ]] && die "API Key 不能为空"
      ONBOARD_ARGS="--auth-choice gemini-api-key --gemini-api-key ${API_KEY}"
      ;;
    4)
      ask "请输入 Z.AI API Key (从 https://open.bigmodel.cn 获取):"
      read -r API_KEY
      [[ -z "$API_KEY" ]] && die "API Key 不能为空"
      ONBOARD_ARGS="--auth-choice zai-api-key --zai-api-key ${API_KEY}"
      ;;
    5)
      ask "请输入 Moonshot API Key:"
      read -r API_KEY
      [[ -z "$API_KEY" ]] && die "API Key 不能为空"
      ONBOARD_ARGS="--auth-choice moonshot-api-key --moonshot-api-key ${API_KEY}"
      ;;
    6)
      ask "请输入 MiniMax API Key:"
      read -r API_KEY
      [[ -z "$API_KEY" ]] && die "API Key 不能为空"
      ONBOARD_ARGS="--auth-choice minimax-api --minimax-api-key ${API_KEY}"
      ;;
    7)
      ask "请输入小米 API Key:"
      read -r API_KEY
      [[ -z "$API_KEY" ]] && die "API Key 不能为空"
      ONBOARD_ARGS="--auth-choice xiaomi-api-key --xiaomi-api-key ${API_KEY}"
      ;;
    8) setup_claude_proxy ;;
    9) setup_openai_proxy ;;
    *) warn "无效选择，默认 Claude"; ask "请输入 API Key:"; read -r API_KEY; ONBOARD_ARGS="--auth-choice apiKey --anthropic-api-key ${API_KEY}" ;;
  esac
}

setup_claude_proxy() {
  USE_ONBOARD=false
  ask "请输入中转 API 地址 (如 https://api.example.com/claude):"
  read -r PROXY_URL
  [[ -z "$PROXY_URL" ]] && die "地址不能为空"
  ask "请输入 API Key:"
  read -r PROXY_KEY
  [[ -z "$PROXY_KEY" ]] && die "Key 不能为空"

  echo ""
  echo "  可选模型:"
  echo "    1) claude-opus-4-6 (最强)"
  echo "    2) claude-sonnet-4-5 (均衡)"
  echo "    3) 自定义模型 ID"
  ask "请选择 [1-3] (默认 1):"
  read -r m
  case "${m:-1}" in
    1) P_MODEL_ID="claude-opus-4-6"; P_MODEL_NAME="Claude Opus 4.6" ;;
    2) P_MODEL_ID="claude-sonnet-4-5"; P_MODEL_NAME="Claude Sonnet 4.5" ;;
    3) ask "模型 ID:"; read -r P_MODEL_ID; ask "显示名称:"; read -r P_MODEL_NAME ;;
    *) P_MODEL_ID="claude-opus-4-6"; P_MODEL_NAME="Claude Opus 4.6" ;;
  esac

  ask "给这个中转取个名字 (如 my-proxy, 默认 claude-proxy):"
  read -r PROVIDER_ID
  PROVIDER_ID="${PROVIDER_ID:-claude-proxy}"

  # 生成 JSON 片段，后面用 python3 合并到配置
  CUSTOM_PROVIDER_JSON=$(cat <<EOJSON
{
  "providers": {
    "${PROVIDER_ID}": {
      "baseUrl": "${PROXY_URL}",
      "apiKey": "${PROXY_KEY}",
      "auth": "api-key",
      "api": "anthropic-messages",
      "headers": {},
      "authHeader": false,
      "models": []
    }
  }
}
EOJSON
)
  CUSTOM_PRIMARY="${PROVIDER_ID}/${P_MODEL_ID}"
  CUSTOM_ALIAS="${P_MODEL_NAME}"
}

setup_openai_proxy() {
  USE_ONBOARD=false
  ask "请输入中转 API 地址 (如 https://api.example.com/v1):"
  read -r PROXY_URL
  [[ -z "$PROXY_URL" ]] && die "地址不能为空"
  ask "请输入 API Key:"
  read -r PROXY_KEY
  [[ -z "$PROXY_KEY" ]] && die "Key 不能为空"

  echo ""
  echo "  可选模型:"
  echo "    1) gpt-5.2"
  echo "    2) gpt-codex-5.3"
  echo "    3) gpt-4.1"
  echo "    4) o3"
  echo "    5) 自定义模型 ID"
  ask "请选择 [1-5] (默认 1):"
  read -r m
  case "${m:-1}" in
    1) P_MODEL_ID="gpt-5.2"; P_MODEL_NAME="GPT-5.2" ;;
    2) P_MODEL_ID="gpt-codex-5.3"; P_MODEL_NAME="GPT Codex 5.3" ;;
    3) P_MODEL_ID="gpt-4.1"; P_MODEL_NAME="GPT-4.1" ;;
    4) P_MODEL_ID="o3"; P_MODEL_NAME="o3" ;;
    5) ask "模型 ID:"; read -r P_MODEL_ID; ask "显示名称:"; read -r P_MODEL_NAME ;;
    *) P_MODEL_ID="gpt-5.2"; P_MODEL_NAME="GPT-5.2" ;;
  esac

  ask "给这个中转取个名字 (默认 openai-proxy):"
  read -r PROVIDER_ID
  PROVIDER_ID="${PROVIDER_ID:-openai-proxy}"

  CUSTOM_PROVIDER_JSON=$(cat <<EOJSON
{
  "providers": {
    "${PROVIDER_ID}": {
      "baseUrl": "${PROXY_URL}",
      "apiKey": "${PROXY_KEY}",
      "auth": "api-key",
      "api": "openai-responses",
      "headers": {},
      "authHeader": false,
      "models": [
        {
          "id": "${P_MODEL_ID}",
          "name": "${P_MODEL_NAME}",
          "reasoning": true,
          "input": ["text", "image"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 128000,
          "maxTokens": 32768
        }
      ]
    }
  }
}
EOJSON
)
  CUSTOM_PRIMARY="${PROVIDER_ID}/${P_MODEL_ID}"
  CUSTOM_ALIAS="${P_MODEL_NAME}"
}

# ========== 渠道选择 ==========
# 全部用 openclaw channels add CLI
choose_channels() {
  step "选择消息渠道"
  echo ""
  echo "  1) Telegram — 最简单，推荐"
  echo "  2) Discord"
  echo "  3) Slack"
  echo "  4) WhatsApp — 需要扫码"
  echo "  5) Signal"
  echo "  6) 飞书 (Feishu)"
  echo "  7) WebChat — 内置，无需配置"
  echo "  8) 跳过"
  echo ""
  ask "请选择 [1-8] (可多选，逗号分隔，如 1,7):"
  read -r ch_choices

  CHANNELS_TO_ADD=()
  NEED_FEISHU_PLUGIN=false

  IFS=',' read -ra chs <<< "$ch_choices"
  for ch in "${chs[@]}"; do
    ch=$(echo "$ch" | tr -d ' ')
    case "$ch" in
      1)
        ask "Telegram Bot Token (从 @BotFather 获取):"
        read -r TG_TOKEN
        if [[ -n "$TG_TOKEN" ]]; then
          CHANNELS_TO_ADD+=("telegram:${TG_TOKEN}")
          info "Telegram ✓"
        fi
        ;;
      2)
        ask "Discord Bot Token:"
        read -r DC_TOKEN
        if [[ -n "$DC_TOKEN" ]]; then
          CHANNELS_TO_ADD+=("discord:${DC_TOKEN}")
          info "Discord ✓"
        fi
        ;;
      3)
        ask "Slack Bot Token (xoxb-...):"
        read -r SL_BOT
        ask "Slack App Token (xapp-...):"
        read -r SL_APP
        if [[ -n "$SL_BOT" && -n "$SL_APP" ]]; then
          CHANNELS_TO_ADD+=("slack:${SL_BOT}:${SL_APP}")
          info "Slack ✓"
        fi
        ;;
      4)
        info "WhatsApp 需要启动后扫码，稍后配置"
        CHANNELS_TO_ADD+=("whatsapp:")
        ;;
      5)
        ask "Signal 号码 (如 +8613800138000):"
        read -r SIG_NUM
        if [[ -n "$SIG_NUM" ]]; then
          CHANNELS_TO_ADD+=("signal:${SIG_NUM}")
          info "Signal ✓"
        fi
        ;;
      6)
        NEED_FEISHU_PLUGIN=true
        ask "飞书 App ID (cli_xxx):"
        read -r FS_ID
        ask "飞书 App Secret:"
        read -r FS_SECRET
        if [[ -n "$FS_ID" && -n "$FS_SECRET" ]]; then
          CHANNELS_TO_ADD+=("feishu:${FS_ID}:${FS_SECRET}")
          info "飞书 ✓"
        else
          NEED_FEISHU_PLUGIN=false
        fi
        ;;
      7) info "WebChat 无需配置，启动 Gateway 后自动可用" ;;
      8) info "跳过渠道配置" ;;
    esac
  done
}

# ========== 执行配置 ==========
apply_config() {
  step "应用配置"

  if [[ "$USE_ONBOARD" == "true" ]]; then
    # 官方 API：用 openclaw onboard 原生命令
    info "使用 openclaw onboard 配置模型..."
    openclaw onboard --non-interactive \
      --accept-risk \
      --mode local \
      ${ONBOARD_ARGS} \
      --gateway-port 18789 \
      --gateway-bind loopback \
      --gateway-auth token \
      --skip-channels \
      --skip-skills \
      --skip-health \
      --skip-ui \
      --install-daemon 2>&1 | tail -10 || warn "onboard 可能有警告，继续..."
    info "模型配置完成"
  else
    # 中转 API：先用 skip 跑 onboard 建基础配置，再注入 provider
    info "初始化基础配置..."
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
      --install-daemon 2>&1 | tail -5 || warn "onboard 可能有警告，继续..."

    # 用 python3 安全地合并 provider 到配置
    info "注入中转 API 配置..."
    python3 -c "
import json, sys

config_path = '$HOME/.openclaw/openclaw.json'
with open(config_path) as f:
    config = json.load(f)

provider_json = json.loads('''${CUSTOM_PROVIDER_JSON}''')

# 合并 providers
if 'models' not in config:
    config['models'] = {}
if 'providers' not in config['models']:
    config['models']['providers'] = {}
config['models']['providers'].update(provider_json['providers'])

# 设置 primary model
if 'agents' not in config:
    config['agents'] = {}
if 'defaults' not in config['agents']:
    config['agents']['defaults'] = {}
config['agents']['defaults']['model'] = {
    'primary': '${CUSTOM_PRIMARY}',
    'fallbacks': []
}
config['agents']['defaults']['models'] = {
    '${CUSTOM_PRIMARY}': {
        'alias': '${CUSTOM_ALIAS}'
    }
}

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
print('Provider 配置已写入')
" || die "配置写入失败"
    info "中转 API 配置完成"
  fi

  # 用 CLI 添加渠道
  for ch_entry in "${CHANNELS_TO_ADD[@]:-}"; do
    [[ -z "$ch_entry" ]] && continue
    local ch_type="${ch_entry%%:*}"
    local ch_data="${ch_entry#*:}"

    case "$ch_type" in
      telegram)
        [[ -n "$ch_data" ]] && {
          openclaw channels add --channel telegram --token "$ch_data" 2>&1 || warn "Telegram 添加失败，请手动: openclaw channels add --channel telegram --token YOUR_TOKEN"
          info "Telegram 渠道已添加"
        }
        ;;
      discord)
        [[ -n "$ch_data" ]] && {
          openclaw channels add --channel discord --token "$ch_data" 2>&1 || warn "Discord 添加失败"
          info "Discord 渠道已添加"
        }
        ;;
      slack)
        local sl_bot="${ch_data%%:*}"
        local sl_app="${ch_data#*:}"
        openclaw channels add --channel slack --bot-token "$sl_bot" --app-token "$sl_app" 2>&1 || warn "Slack 添加失败"
        info "Slack 渠道已添加"
        ;;
      whatsapp)
        openclaw channels add --channel whatsapp 2>&1 || warn "WhatsApp 添加失败"
        info "WhatsApp 已添加，启动后需要扫码"
        ;;
      signal)
        openclaw channels add --channel signal --signal-number "$ch_data" 2>&1 || warn "Signal 添加失败"
        info "Signal 渠道已添加"
        ;;
      feishu)
        # 飞书需要先装插件
        if [[ "${NEED_FEISHU_PLUGIN}" == "true" ]]; then
          openclaw plugins install @openclaw/feishu 2>&1 || warn "飞书插件安装失败"
        fi
        # 飞书的 channels add 可能不支持直接传参，需要写配置
        local fs_id="${ch_data%%:*}"
        local fs_secret="${ch_data#*:}"
        python3 -c "
import json
config_path = '$HOME/.openclaw/openclaw.json'
with open(config_path) as f:
    config = json.load(f)
if 'channels' not in config:
    config['channels'] = {}
config['channels']['feishu'] = {
    'enabled': True,
    'dmPolicy': 'pairing',
    'accounts': {
        'main': {
            'appId': '${fs_id}',
            'appSecret': '${fs_secret}'
        }
    }
}
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
" 2>&1 || warn "飞书配置写入失败"
        info "飞书渠道已添加"
        ;;
    esac
  done
}

# ========== 启动 ==========
start_gateway() {
  step "启动 Gateway"
  openclaw gateway restart 2>&1 || openclaw gateway start 2>&1 || warn "Gateway 启动失败"
  sleep 2
  if openclaw gateway status 2>&1 | grep -qi "running\|online\|listening"; then
    info "Gateway 已启动 ✓"
  else
    warn "Gateway 可能未正常启动，请检查: openclaw gateway status"
  fi
}

# ========== 验证 ==========
verify() {
  step "验证配置"
  echo ""

  # 检查配置文件
  if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
    info "配置文件存在 ✓"
  else
    err "配置文件不存在!"
  fi

  # 检查模型
  local primary
  primary=$(python3 -c "
import json
with open('$HOME/.openclaw/openclaw.json') as f:
    c = json.load(f)
print(c.get('agents',{}).get('defaults',{}).get('model',{}).get('primary','未配置'))
" 2>/dev/null || echo "未知")
  info "主模型: ${primary}"

  # 检查渠道
  openclaw channels list 2>&1 | head -10 || true

  # 健康检查
  openclaw doctor 2>&1 | tail -5 || true
}

# ========== 完成 ==========
finish() {
  step "安装完成! 🎉"
  echo ""
  echo -e "  ${BOLD}常用命令:${NC}"
  echo "    openclaw gateway status    — 查看状态"
  echo "    openclaw gateway restart   — 重启"
  echo "    openclaw doctor            — 健康检查"
  echo "    openclaw channels list     — 查看渠道"
  echo "    openclaw models status     — 查看模型"
  echo ""
  echo -e "  ${BOLD}WebChat:${NC}"
  echo "    浏览器打开 http://localhost:18789"
  echo ""
  echo -e "  ${BOLD}文档:${NC} https://docs.openclaw.ai"
  echo ""
}

# ========== 主流程 ==========
main() {
  echo ""
  echo -e "${BOLD}🦞 OpenClaw 一键安装脚本 v2${NC}"
  echo -e "   基于 OpenClaw CLI 原生命令，确保配置正确"
  echo ""

  detect_os
  ensure_node
  ensure_openclaw
  choose_model
  choose_channels
  apply_config
  start_gateway
  verify
  finish
}

main "$@"
