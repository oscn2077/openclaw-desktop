#!/usr/bin/env bash
# OpenClaw 一键安装+配置脚本 (交互式)
# 支持: Ubuntu 22.04+ / Debian 12+ / macOS
# 用法: bash install.sh
set -euo pipefail

# ========== 颜色 ==========
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
step()  { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
ask()   { echo -en "${CYAN}[?]${NC} $* "; }

die() { err "$*"; exit 1; }

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

# ========== Node.js 检测与安装 ==========
ensure_node() {
  step "检查 Node.js"
  if command -v node &>/dev/null; then
    local ver; ver=$(node -v | sed 's/v//' | cut -d. -f1)
    if (( ver >= 22 )); then
      info "Node.js $(node -v) 已安装，满足要求 (>=22)"
      return 0
    else
      warn "Node.js $(node -v) 版本过低，需要 22+"
    fi
  else
    warn "未检测到 Node.js"
  fi
  ask "是否自动安装 Node.js 22? (Y/n)"
  read -r ans
  if [[ "${ans,,}" == "n" ]]; then
    die "请手动安装 Node.js 22+ 后重试: https://nodejs.org"
  fi
  case "$OS" in
    macos) install_node_macos ;;
    linux|wsl) install_node_linux ;;
  esac
}

install_node_linux() {
  info "正在安装 Node.js 22 (Linux)..."
  if command -v apt-get &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - || die "添加 NodeSource 源失败"
    sudo apt-get install -y nodejs || die "安装 Node.js 失败"
  elif command -v dnf &>/dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - || die "添加 NodeSource 源失败"
    sudo dnf install -y nodejs || die "安装 Node.js 失败"
  else
    die "不支持的包管理器，请手动安装 Node.js 22+: https://nodejs.org"
  fi
  info "Node.js $(node -v) 安装完成"
}

install_node_macos() {
  info "正在安装 Node.js 22 (macOS)..."
  if ! command -v brew &>/dev/null; then
    info "先安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "Homebrew 安装失败"
  fi
  brew install node@22 || die "Node.js 安装失败"
  brew link --overwrite node@22 2>/dev/null || true
  info "Node.js $(node -v) 安装完成"
}

# ========== OpenClaw 安装 ==========
ensure_openclaw() {
  step "检查 OpenClaw"
  if command -v openclaw &>/dev/null; then
    local ver; ver=$(openclaw --version 2>/dev/null || echo "unknown")
    info "OpenClaw 已安装: $ver"
    ask "是否重新安装/更新? (y/N)"
    read -r ans
    [[ "${ans,,}" != "y" ]] && return 0
  fi
  info "正在安装 OpenClaw..."
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -5 || die "OpenClaw 安装失败，请检查网络和 npm 配置"
  info "OpenClaw $(openclaw --version 2>/dev/null) 安装完成"
}

# ========== 模型选择 ==========
choose_model() {
  step "选择 AI 模型"
  echo ""
  echo "  ${BOLD}官方 API:${NC}"
  echo "    1) Claude (Anthropic) — 推荐，最强编程能力"
  echo "    2) OpenAI (GPT) — 通用能力强"
  echo "    3) Google Gemini — 免费额度大"
  echo "    4) GLM (智谱 Z.AI) — 国产模型"
  echo ""
  echo "  ${BOLD}中转 API (兼容第三方):${NC}"
  echo "    5) Claude 中转 (Anthropic 兼容)"
  echo "    6) OpenAI 中转 (OpenAI 兼容)"
  echo ""
  ask "请选择 [1-6]:"
  read -r choice

  case "$choice" in
    1) setup_anthropic ;;
    2) setup_openai ;;
    3) setup_gemini ;;
    4) setup_zai ;;
    5) setup_claude_proxy ;;
    6) setup_openai_proxy ;;
    *) warn "无效选择，默认使用 Claude"; setup_anthropic ;;
  esac
}

setup_anthropic() {
  MODEL_PROVIDER="anthropic"
  MODEL_PRIMARY="anthropic/claude-sonnet-4-5"
  AUTH_CHOICE="apiKey"
  ask "请输入 Anthropic API Key (sk-ant-...):"
  read -r API_KEY
  [[ -z "$API_KEY" ]] && die "API Key 不能为空"
  ENV_VARS="ANTHROPIC_API_KEY=${API_KEY}"
  ONBOARD_AUTH_ARGS="--auth-choice apiKey --anthropic-api-key ${API_KEY}"
  MODEL_CONFIG=""
}

setup_openai() {
  MODEL_PROVIDER="openai"
  MODEL_PRIMARY="openai/gpt-4o"
  AUTH_CHOICE="openai-api-key"
  ask "请输入 OpenAI API Key (sk-...):"
  read -r API_KEY
  [[ -z "$API_KEY" ]] && die "API Key 不能为空"
  ENV_VARS="OPENAI_API_KEY=${API_KEY}"
  ONBOARD_AUTH_ARGS="--auth-choice openai-api-key --openai-api-key ${API_KEY}"
  MODEL_CONFIG=""
}

setup_gemini() {
  MODEL_PROVIDER="google"
  MODEL_PRIMARY="google/gemini-2.5-pro"
  AUTH_CHOICE="gemini-api-key"
  ask "请输入 Gemini API Key:"
  read -r API_KEY
  [[ -z "$API_KEY" ]] && die "API Key 不能为空"
  ENV_VARS="GEMINI_API_KEY=${API_KEY}"
  ONBOARD_AUTH_ARGS="--auth-choice gemini-api-key --gemini-api-key ${API_KEY}"
  MODEL_CONFIG=""
}

setup_zai() {
  MODEL_PROVIDER="zai"
  MODEL_PRIMARY="zai/glm-4.7"
  AUTH_CHOICE="zai-api-key"
  ask "请输入 Z.AI API Key (sk-...):"
  read -r API_KEY
  [[ -z "$API_KEY" ]] && die "API Key 不能为空"
  ENV_VARS="ZAI_API_KEY=${API_KEY}"
  ONBOARD_AUTH_ARGS="--auth-choice zai-api-key --zai-api-key ${API_KEY}"
  MODEL_CONFIG=""
}

setup_claude_proxy() {
  MODEL_PROVIDER="custom-claude"
  ask "请输入中转 API 地址 (如 https://api.example.com/v1):"
  read -r BASE_URL
  [[ -z "$BASE_URL" ]] && die "API 地址不能为空"
  ask "请输入 API Key:"
  read -r API_KEY
  [[ -z "$API_KEY" ]] && die "API Key 不能为空"
  ask "请输入模型 ID (默认 claude-sonnet-4-5):"
  read -r MODEL_ID
  MODEL_ID="${MODEL_ID:-claude-sonnet-4-5}"
  ask "请输入模型显示名称 (默认 Claude Sonnet 4.5):"
  read -r MODEL_NAME
  MODEL_NAME="${MODEL_NAME:-Claude Sonnet 4.5}"

  MODEL_PRIMARY="custom-claude/${MODEL_ID}"
  AUTH_CHOICE="skip"
  ENV_VARS=""
  ONBOARD_AUTH_ARGS="--auth-choice skip"
  MODEL_CONFIG=$(cat <<EOF
  "models": {
    "mode": "merge",
    "providers": {
      "custom-claude": {
        "baseUrl": "${BASE_URL}",
        "auth": "api-key",
        "api": "anthropic-messages",
        "apiKey": "${API_KEY}",
        "models": [
          {
            "id": "${MODEL_ID}",
            "name": "${MODEL_NAME}",
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
EOF
)
}

setup_openai_proxy() {
  MODEL_PROVIDER="custom-openai"
  ask "请输入中转 API 地址 (如 https://api.example.com/v1):"
  read -r BASE_URL
  [[ -z "$BASE_URL" ]] && die "API 地址不能为空"
  ask "请输入 API Key:"
  read -r API_KEY
  [[ -z "$API_KEY" ]] && die "API Key 不能为空"
  ask "请输入模型 ID (默认 gpt-4o):"
  read -r MODEL_ID
  MODEL_ID="${MODEL_ID:-gpt-4o}"
  ask "请输入模型显示名称 (默认 GPT-4o):"
  read -r MODEL_NAME
  MODEL_NAME="${MODEL_NAME:-GPT-4o}"

  MODEL_PRIMARY="custom-openai/${MODEL_ID}"
  AUTH_CHOICE="skip"
  ENV_VARS=""
  ONBOARD_AUTH_ARGS="--auth-choice skip"
  MODEL_CONFIG=$(cat <<EOF
  "models": {
    "mode": "merge",
    "providers": {
      "custom-openai": {
        "baseUrl": "${BASE_URL}",
        "auth": "api-key",
        "api": "openai-completions",
        "apiKey": "${API_KEY}",
        "models": [
          {
            "id": "${MODEL_ID}",
            "name": "${MODEL_NAME}",
            "contextWindow": 128000,
            "maxTokens": 4096
          }
        ]
      }
    }
  },
EOF
)
}

# ========== 渠道选择 ==========
choose_channels() {
  step "选择消息渠道"
  echo ""
  echo "  1) Telegram — 推荐，设置最简单"
  echo "  2) Discord — 游戏/社区常用"
  echo "  3) 飞书 (Feishu) — 企业协作"
  echo "  4) WebChat — 内置网页聊天 (无需额外配置)"
  echo "  5) 跳过渠道配置"
  echo ""
  ask "请选择 [1-5] (可多选，用逗号分隔，如 1,4):"
  read -r ch_choices

  CHANNEL_CONFIG=""
  TELEGRAM_TOKEN=""
  DISCORD_TOKEN=""
  FEISHU_APP_ID=""
  FEISHU_APP_SECRET=""
  NEED_FEISHU_PLUGIN=false

  IFS=',' read -ra chs <<< "$ch_choices"
  for ch in "${chs[@]}"; do
    ch=$(echo "$ch" | tr -d ' ')
    case "$ch" in
      1) setup_telegram ;;
      2) setup_discord ;;
      3) setup_feishu ;;
      4) info "WebChat 无需额外配置，启动 Gateway 后即可使用" ;;
      5) info "跳过渠道配置" ;;
      *) warn "忽略无效选项: $ch" ;;
    esac
  done
}

setup_telegram() {
  ask "请输入 Telegram Bot Token (从 @BotFather 获取):"
  read -r TELEGRAM_TOKEN
  [[ -z "$TELEGRAM_TOKEN" ]] && { warn "Telegram Token 为空，跳过"; return; }
  CHANNEL_CONFIG="${CHANNEL_CONFIG}
    \"telegram\": {
      \"enabled\": true,
      \"botToken\": \"${TELEGRAM_TOKEN}\",
      \"dmPolicy\": \"pairing\"
    },"
  info "Telegram 配置完成"
}

setup_discord() {
  ask "请输入 Discord Bot Token:"
  read -r DISCORD_TOKEN
  [[ -z "$DISCORD_TOKEN" ]] && { warn "Discord Token 为空，跳过"; return; }
  CHANNEL_CONFIG="${CHANNEL_CONFIG}
    \"discord\": {
      \"enabled\": true,
      \"token\": \"${DISCORD_TOKEN}\"
    },"
  info "Discord 配置完成"
}

setup_feishu() {
  NEED_FEISHU_PLUGIN=true
  ask "请输入飞书 App ID (cli_xxx):"
  read -r FEISHU_APP_ID
  [[ -z "$FEISHU_APP_ID" ]] && { warn "飞书 App ID 为空，跳过"; NEED_FEISHU_PLUGIN=false; return; }
  ask "请输入飞书 App Secret:"
  read -r FEISHU_APP_SECRET
  [[ -z "$FEISHU_APP_SECRET" ]] && { warn "飞书 App Secret 为空，跳过"; NEED_FEISHU_PLUGIN=false; return; }
  CHANNEL_CONFIG="${CHANNEL_CONFIG}
    \"feishu\": {
      \"enabled\": true,
      \"dmPolicy\": \"pairing\",
      \"accounts\": {
        \"main\": {
          \"appId\": \"${FEISHU_APP_ID}\",
          \"appSecret\": \"${FEISHU_APP_SECRET}\"
        }
      }
    },"
  info "飞书配置完成"
}

# ========== 生成配置 ==========
generate_config() {
  step "生成配置文件"
  local config_dir="$HOME/.openclaw"
  mkdir -p "$config_dir"

  # 生成 gateway token
  local gw_token
  gw_token=$(openssl rand -hex 24 2>/dev/null || head -c 48 /dev/urandom | xxd -p | tr -d '\n' | head -c 48)

  # 清理 channel config 末尾逗号
  CHANNEL_CONFIG=$(echo "$CHANNEL_CONFIG" | sed '$ s/,$//')

  # 构建 env 块
  local env_block=""
  if [[ -n "${ENV_VARS:-}" ]]; then
    local key="${ENV_VARS%%=*}"
    local val="${ENV_VARS#*=}"
    env_block="\"env\": { \"${key}\": \"${val}\" },"
  fi

  # 构建 channels 块
  local channels_block=""
  if [[ -n "${CHANNEL_CONFIG:-}" ]]; then
    channels_block="\"channels\": {${CHANNEL_CONFIG}
  },"
  fi

  # 构建 models 块
  local models_block="${MODEL_CONFIG:-}"

  cat > "$config_dir/openclaw.json" <<EOF
{
  ${env_block}
  "agents": {
    "defaults": {
      "maxConcurrent": 4,
      "workspace": "${config_dir}/workspace",
      "model": {
        "primary": "${MODEL_PRIMARY}",
        "fallbacks": []
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "${gw_token}"
    },
    "port": 18789,
    "bind": "loopback",
    "tailscale": { "mode": "off" }
  },
  ${channels_block}
  ${models_block}
  "wizard": {
    "lastRunAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "lastRunVersion": "2026.2.6-3",
    "lastRunCommand": "install.sh",
    "lastRunMode": "local"
  },
  "meta": {
    "lastTouchedVersion": "2026.2.6-3",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  }
}
EOF

  # 生成 .env 文件
  if [[ -n "${ENV_VARS:-}" ]]; then
    echo "${ENV_VARS}" > "$config_dir/.env"
    info ".env 文件已生成"
  fi

  # 写入 Telegram/Discord token 到 .env
  if [[ -n "${TELEGRAM_TOKEN:-}" ]]; then
    echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN}" >> "$config_dir/.env"
  fi
  if [[ -n "${DISCORD_TOKEN:-}" ]]; then
    echo "DISCORD_BOT_TOKEN=${DISCORD_TOKEN}" >> "$config_dir/.env"
  fi

  info "配置文件已生成: $config_dir/openclaw.json"
}

# ========== 安装飞书插件 ==========
install_feishu_plugin() {
  if [[ "${NEED_FEISHU_PLUGIN:-false}" == "true" ]]; then
    step "安装飞书插件"
    openclaw plugins install @openclaw/feishu 2>&1 || warn "飞书插件安装失败，请稍后手动运行: openclaw plugins install @openclaw/feishu"
    info "飞书插件安装完成"
  fi
}

# ========== 初始化 Workspace ==========
init_workspace() {
  step "初始化工作空间"
  local ws="$HOME/.openclaw/workspace"
  mkdir -p "$ws"
  if [[ ! -f "$ws/AGENTS.md" ]]; then
    openclaw setup 2>&1 || warn "workspace 初始化可能不完整"
  fi
  info "工作空间就绪: $ws"
}

# ========== 启动 Gateway ==========
start_gateway() {
  step "启动 Gateway"
  ask "是否安装 Gateway 为系统服务并启动? (Y/n)"
  read -r ans
  if [[ "${ans,,}" == "n" ]]; then
    info "跳过 Gateway 启动。你可以稍后运行:"
    echo "  openclaw gateway install"
    echo "  openclaw gateway start"
    return 0
  fi

  openclaw gateway install 2>&1 || warn "Gateway 服务安装失败"
  openclaw gateway start 2>&1 || warn "Gateway 启动失败"

  sleep 2
  if openclaw gateway status 2>&1 | grep -qi "running"; then
    info "Gateway 已启动 ✓"
  else
    warn "Gateway 可能未正常启动，请检查: openclaw gateway status"
  fi
}

# ========== 完成 ==========
finish() {
  step "安装完成! 🎉"
  echo ""
  echo -e "  ${BOLD}常用命令:${NC}"
  echo "    openclaw gateway status    — 查看 Gateway 状态"
  echo "    openclaw gateway restart   — 重启 Gateway"
  echo "    openclaw doctor            — 健康检查"
  echo "    openclaw dashboard         — 打开控制面板"
  echo "    openclaw logs --follow     — 查看实时日志"
  echo ""
  if [[ -n "${TELEGRAM_TOKEN:-}" ]]; then
    echo -e "  ${BOLD}Telegram:${NC}"
    echo "    在 Telegram 中找到你的 Bot 并发送消息"
    echo "    首次需要配对: openclaw pairing approve telegram <CODE>"
    echo ""
  fi
  if [[ -n "${DISCORD_TOKEN:-}" ]]; then
    echo -e "  ${BOLD}Discord:${NC}"
    echo "    邀请 Bot 到你的服务器并 @提及它"
    echo "    DM 首次需要配对: openclaw pairing approve discord <CODE>"
    echo ""
  fi
  if [[ "${NEED_FEISHU_PLUGIN:-false}" == "true" ]]; then
    echo -e "  ${BOLD}飞书:${NC}"
    echo "    确保飞书应用已发布并配置了事件订阅"
    echo "    首次需要配对: openclaw pairing approve feishu <CODE>"
    echo ""
  fi
  echo -e "  ${BOLD}文档:${NC} https://docs.openclaw.ai"
  echo ""
}

# ========== 主流程 ==========
main() {
  echo ""
  echo -e "${BOLD}🦞 OpenClaw 一键安装脚本${NC}"
  echo -e "   支持 Ubuntu 22.04+ / Debian 12+ / macOS"
  echo ""

  detect_os
  ensure_node
  ensure_openclaw
  choose_model
  choose_channels
  generate_config
  install_feishu_plugin
  init_workspace
  start_gateway
  finish
}

main "$@"
