#!/usr/bin/env bash
# OpenClaw 非交互式安装+配置脚本
# 支持: Ubuntu 22.04+ / Debian 12+ / macOS
#
# 用法示例:
#   CLAUDE_API_KEY=xxx TELEGRAM_TOKEN=xxx bash install-silent.sh
#   OPENAI_API_KEY=xxx DISCORD_TOKEN=xxx bash install-silent.sh
#   CLAUDE_API_KEY=xxx CLAUDE_BASE_URL=https://proxy.example.com/v1 bash install-silent.sh
#   GEMINI_API_KEY=xxx bash install-silent.sh
#   ZAI_API_KEY=xxx bash install-silent.sh
#
# 环境变量:
#   模型 (至少设一个):
#     CLAUDE_API_KEY       — Anthropic Claude API Key
#     CLAUDE_BASE_URL      — Claude 中转 API 地址 (可选，设置后走中转)
#     CLAUDE_MODEL         — 自定义模型 ID (默认 claude-sonnet-4-5)
#     OPENAI_API_KEY       — OpenAI API Key
#     OPENAI_BASE_URL      — OpenAI 中转 API 地址 (可选)
#     OPENAI_MODEL         — 自定义模型 ID (默认 gpt-4o)
#     GEMINI_API_KEY       — Google Gemini API Key
#     ZAI_API_KEY          — Z.AI (GLM) API Key
#
#   渠道 (全部可选):
#     TELEGRAM_TOKEN       — Telegram Bot Token
#     DISCORD_TOKEN        — Discord Bot Token
#     FEISHU_APP_ID        — 飞书 App ID
#     FEISHU_APP_SECRET    — 飞书 App Secret
#
#   其他:
#     GATEWAY_PORT         — Gateway 端口 (默认 18789)
#     GATEWAY_BIND         — Gateway 绑定 (默认 loopback)
#     SKIP_INSTALL         — 设为 1 跳过 OpenClaw 安装
#     SKIP_DAEMON          — 设为 1 跳过 daemon 安装
#     SKIP_NODE_INSTALL    — 设为 1 跳过 Node.js 安装

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
die()   { err "$*"; exit 1; }

GW_PORT="${GATEWAY_PORT:-18789}"
GW_BIND="${GATEWAY_BIND:-loopback}"

# ========== OS 检测 ==========
detect_os() {
  OS="unknown"
  if [[ "$OSTYPE" == "darwin"* ]]; then OS="macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    grep -qi microsoft /proc/version 2>/dev/null && OS="wsl"
  else die "不支持的操作系统: $OSTYPE"; fi
  info "系统: ${OS}"
}

# ========== Node.js ==========
ensure_node() {
  if command -v node &>/dev/null; then
    local ver; ver=$(node -v | sed 's/v//' | cut -d. -f1)
    if (( ver >= 22 )); then
      info "Node.js $(node -v) ✓"; return 0
    fi
  fi
  [[ "${SKIP_NODE_INSTALL:-}" == "1" ]] && die "Node.js 22+ 未安装且 SKIP_NODE_INSTALL=1"
  info "安装 Node.js 22..."
  case "$OS" in
    macos)
      command -v brew &>/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      brew install node@22 && brew link --overwrite node@22 2>/dev/null || true ;;
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
  [[ "${SKIP_INSTALL:-}" == "1" ]] && { info "跳过 OpenClaw 安装"; return 0; }
  info "安装 OpenClaw..."
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -3 || die "OpenClaw 安装失败"
  info "OpenClaw $(openclaw --version 2>/dev/null) ✓"
}

# ========== 确定模型配置 ==========
resolve_model() {
  MODEL_PRIMARY=""
  ENV_BLOCK=""
  MODELS_BLOCK=""

  if [[ -n "${CLAUDE_API_KEY:-}" ]]; then
    if [[ -n "${CLAUDE_BASE_URL:-}" ]]; then
      # 中转 Claude
      local mid="${CLAUDE_MODEL:-claude-sonnet-4-5}"
      MODEL_PRIMARY="custom-claude/${mid}"
      MODELS_BLOCK=$(cat <<EOF
  "models": {
    "mode": "merge",
    "providers": {
      "custom-claude": {
        "baseUrl": "${CLAUDE_BASE_URL}",
        "auth": "api-key",
        "api": "anthropic-messages",
        "apiKey": "${CLAUDE_API_KEY}",
        "models": [{"id": "${mid}", "name": "${mid}", "contextWindow": 200000, "maxTokens": 8192}]
      }
    }
  },
EOF
)
    else
      MODEL_PRIMARY="anthropic/claude-sonnet-4-5"
      ENV_BLOCK="\"ANTHROPIC_API_KEY\": \"${CLAUDE_API_KEY}\""
    fi
  elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
    if [[ -n "${OPENAI_BASE_URL:-}" ]]; then
      local mid="${OPENAI_MODEL:-gpt-4o}"
      MODEL_PRIMARY="custom-openai/${mid}"
      MODELS_BLOCK=$(cat <<EOF
  "models": {
    "mode": "merge",
    "providers": {
      "custom-openai": {
        "baseUrl": "${OPENAI_BASE_URL}",
        "auth": "api-key",
        "api": "openai-completions",
        "apiKey": "${OPENAI_API_KEY}",
        "models": [{"id": "${mid}", "name": "${mid}", "contextWindow": 128000, "maxTokens": 4096}]
      }
    }
  },
EOF
)
    else
      MODEL_PRIMARY="openai/gpt-4o"
      ENV_BLOCK="\"OPENAI_API_KEY\": \"${OPENAI_API_KEY}\""
    fi
  elif [[ -n "${GEMINI_API_KEY:-}" ]]; then
    MODEL_PRIMARY="google/gemini-2.5-pro"
    ENV_BLOCK="\"GEMINI_API_KEY\": \"${GEMINI_API_KEY}\""
  elif [[ -n "${ZAI_API_KEY:-}" ]]; then
    MODEL_PRIMARY="zai/glm-4.7"
    ENV_BLOCK="\"ZAI_API_KEY\": \"${ZAI_API_KEY}\""
  else
    die "未提供任何模型 API Key。请设置 CLAUDE_API_KEY / OPENAI_API_KEY / GEMINI_API_KEY / ZAI_API_KEY 之一"
  fi
  info "模型: ${MODEL_PRIMARY}"
}

# ========== 确定渠道配置 ==========
resolve_channels() {
  CHANNEL_BLOCK=""
  NEED_FEISHU=false

  if [[ -n "${TELEGRAM_TOKEN:-}" ]]; then
    CHANNEL_BLOCK="${CHANNEL_BLOCK}
    \"telegram\": {\"enabled\": true, \"botToken\": \"${TELEGRAM_TOKEN}\", \"dmPolicy\": \"pairing\"},"
    [[ -n "$ENV_BLOCK" ]] && ENV_BLOCK="${ENV_BLOCK},"
    ENV_BLOCK="${ENV_BLOCK} \"TELEGRAM_BOT_TOKEN\": \"${TELEGRAM_TOKEN}\""
    info "渠道: Telegram ✓"
  fi

  if [[ -n "${DISCORD_TOKEN:-}" ]]; then
    CHANNEL_BLOCK="${CHANNEL_BLOCK}
    \"discord\": {\"enabled\": true, \"token\": \"${DISCORD_TOKEN}\"},"
    [[ -n "$ENV_BLOCK" ]] && ENV_BLOCK="${ENV_BLOCK},"
    ENV_BLOCK="${ENV_BLOCK} \"DISCORD_BOT_TOKEN\": \"${DISCORD_TOKEN}\""
    info "渠道: Discord ✓"
  fi

  if [[ -n "${FEISHU_APP_ID:-}" ]] && [[ -n "${FEISHU_APP_SECRET:-}" ]]; then
    NEED_FEISHU=true
    CHANNEL_BLOCK="${CHANNEL_BLOCK}
    \"feishu\": {\"enabled\": true, \"dmPolicy\": \"pairing\", \"accounts\": {\"main\": {\"appId\": \"${FEISHU_APP_ID}\", \"appSecret\": \"${FEISHU_APP_SECRET}\"}}},"
    info "渠道: 飞书 ✓"
  fi

  # 去掉末尾逗号
  CHANNEL_BLOCK=$(echo "$CHANNEL_BLOCK" | sed '$ s/,$//')
}

# ========== 生成配置 ==========
generate_config() {
  local config_dir="$HOME/.openclaw"
  mkdir -p "$config_dir"

  local gw_token
  gw_token=$(openssl rand -hex 24 2>/dev/null || head -c 48 /dev/urandom | xxd -p | tr -d '\n' | head -c 48)

  local env_section=""
  [[ -n "$ENV_BLOCK" ]] && env_section="\"env\": {${ENV_BLOCK}},"

  local ch_section=""
  [[ -n "$CHANNEL_BLOCK" ]] && ch_section="\"channels\": {${CHANNEL_BLOCK}},"

  cat > "$config_dir/openclaw.json" <<EOF
{
  ${env_section}
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
    "auth": {"mode": "token", "token": "${gw_token}"},
    "port": ${GW_PORT},
    "bind": "${GW_BIND}",
    "tailscale": {"mode": "off"}
  },
  ${ch_section}
  ${MODELS_BLOCK}
  "wizard": {
    "lastRunAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "lastRunVersion": "2026.2.6-3",
    "lastRunCommand": "install-silent.sh",
    "lastRunMode": "local"
  },
  "meta": {
    "lastTouchedVersion": "2026.2.6-3",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  }
}
EOF

  info "配置已写入: $config_dir/openclaw.json"
}

# ========== 安装插件 + 初始化 + 启动 ==========
post_install() {
  # 飞书插件
  if [[ "$NEED_FEISHU" == "true" ]]; then
    info "安装飞书插件..."
    openclaw plugins install @openclaw/feishu 2>&1 || warn "飞书插件安装失败"
  fi

  # 初始化 workspace
  mkdir -p "$HOME/.openclaw/workspace"
  openclaw setup 2>&1 || warn "workspace 初始化可能不完整"

  # 安装并启动 daemon
  if [[ "${SKIP_DAEMON:-}" != "1" ]]; then
    info "安装 Gateway 服务..."
    openclaw gateway install 2>&1 || warn "Gateway 服务安装失败"
    openclaw gateway start 2>&1 || warn "Gateway 启动失败"
    sleep 2
    if openclaw gateway status 2>&1 | grep -qi "running"; then
      info "Gateway 已启动 ✓"
    else
      warn "Gateway 可能未正常启动"
    fi
  else
    info "跳过 daemon 安装 (SKIP_DAEMON=1)"
  fi
}

# ========== 主流程 ==========
main() {
  info "OpenClaw 非交互式安装开始"
  detect_os
  ensure_node
  ensure_openclaw
  resolve_model
  resolve_channels
  generate_config
  post_install
  info "安装完成! 🎉"
  echo ""
  echo "  常用命令:"
  echo "    openclaw gateway status    — 查看状态"
  echo "    openclaw gateway restart   — 重启"
  echo "    openclaw doctor            — 健康检查"
  echo "    openclaw logs --follow     — 实时日志"
  echo ""
}

main "$@"
