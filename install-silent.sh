#!/usr/bin/env bash
# OpenClaw 静默安装脚本 v2
# 用法: CLAUDE_API_KEY=xxx bash install-silent.sh
#   或: CLAUDE_BASE_URL=xxx CLAUDE_PROXY_KEY=xxx bash install-silent.sh
#
# 环境变量:
#   === 官方 API (选一个) ===
#   ANTHROPIC_API_KEY    — Anthropic Claude
#   OPENAI_API_KEY       — OpenAI GPT
#   GEMINI_API_KEY       — Google Gemini
#   ZAI_API_KEY          — 智谱 GLM
#   MOONSHOT_API_KEY     — Moonshot Kimi
#   MINIMAX_API_KEY      — MiniMax
#   XIAOMI_API_KEY       — 小米
#
#   === 中转 API ===
#   CLAUDE_BASE_URL + CLAUDE_PROXY_KEY  — Claude 中转
#   CLAUDE_MODEL_ID                     — 模型 ID (默认 claude-sonnet-4-5)
#   CLAUDE_PROVIDER_NAME                — Provider 名 (默认 claude-proxy)
#
#   OPENAI_BASE_URL + OPENAI_PROXY_KEY  — OpenAI 中转
#   OPENAI_MODEL_ID                     — 模型 ID (默认 gpt-4o)
#   OPENAI_PROVIDER_NAME                — Provider 名 (默认 openai-proxy)
#
#   === 渠道 ===
#   TELEGRAM_TOKEN       — Telegram Bot Token
#   DISCORD_TOKEN        — Discord Bot Token
#   SLACK_BOT_TOKEN + SLACK_APP_TOKEN — Slack
#   SIGNAL_NUMBER        — Signal 号码
#
#   === 控制 ===
#   SKIP_NODE_INSTALL=1  — 跳过 Node.js 安装
#   SKIP_OPENCLAW_INSTALL=1 — 跳过 OpenClaw 安装
#   SKIP_DAEMON=1        — 跳过 daemon 安装
#   GATEWAY_PORT         — Gateway 端口 (默认 18789)

set -euo pipefail

info()  { echo "[✓] $*"; }
warn()  { echo "[!] $*"; }
err()   { echo "[✗] $*"; }
die()   { err "$*"; exit 1; }

PORT="${GATEWAY_PORT:-18789}"

# ── Node.js ──
if [[ "${SKIP_NODE_INSTALL:-}" != "1" ]]; then
  if ! command -v node &>/dev/null || (( $(node -v | sed 's/v//' | cut -d. -f1) < 22 )); then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install node@22 2>/dev/null || die "Node.js 安装失败"
    elif command -v apt-get &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
      sudo apt-get install -y nodejs || die "Node.js 安装失败"
    else
      die "请手动安装 Node.js 22+"
    fi
  fi
  info "Node.js $(node -v)"
fi

# ── OpenClaw ──
if [[ "${SKIP_OPENCLAW_INSTALL:-}" != "1" ]]; then
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -3
  info "OpenClaw $(openclaw --version 2>/dev/null)"
fi

# ── 确定模型配置方式 ──
USE_PROXY=false
ONBOARD_AUTH_ARGS=""

if [[ -n "${CLAUDE_BASE_URL:-}" && -n "${CLAUDE_PROXY_KEY:-}" ]]; then
  USE_PROXY=true
  PROXY_TYPE="claude"
elif [[ -n "${OPENAI_BASE_URL:-}" && -n "${OPENAI_PROXY_KEY:-}" ]]; then
  USE_PROXY=true
  PROXY_TYPE="openai"
elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice apiKey --anthropic-api-key ${ANTHROPIC_API_KEY}"
elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice openai-api-key --openai-api-key ${OPENAI_API_KEY}"
elif [[ -n "${GEMINI_API_KEY:-}" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice gemini-api-key --gemini-api-key ${GEMINI_API_KEY}"
elif [[ -n "${ZAI_API_KEY:-}" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice zai-api-key --zai-api-key ${ZAI_API_KEY}"
elif [[ -n "${MOONSHOT_API_KEY:-}" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice moonshot-api-key --moonshot-api-key ${MOONSHOT_API_KEY}"
elif [[ -n "${MINIMAX_API_KEY:-}" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice minimax-api --minimax-api-key ${MINIMAX_API_KEY}"
elif [[ -n "${XIAOMI_API_KEY:-}" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice xiaomi-api-key --xiaomi-api-key ${XIAOMI_API_KEY}"
else
  die "未提供任何 API Key。请设置环境变量，如: ANTHROPIC_API_KEY=xxx 或 CLAUDE_BASE_URL=xxx CLAUDE_PROXY_KEY=xxx"
fi

# ── 基础配置 (onboard) ──
DAEMON_FLAG="--install-daemon"
[[ "${SKIP_DAEMON:-}" == "1" ]] && DAEMON_FLAG="--skip-daemon"

if [[ "$USE_PROXY" == "true" ]]; then
  ONBOARD_AUTH_ARGS="--auth-choice skip"
fi

info "运行 openclaw onboard..."
openclaw onboard --non-interactive \
  --accept-risk \
  --mode local \
  ${ONBOARD_AUTH_ARGS} \
  --gateway-port "${PORT}" \
  --gateway-bind loopback \
  --gateway-auth token \
  --skip-channels \
  --skip-skills \
  --skip-health \
  --skip-ui \
  ${DAEMON_FLAG} 2>&1 | tail -5 || warn "onboard 有警告"

# ── 中转 API 注入 ──
if [[ "$USE_PROXY" == "true" ]]; then
  info "配置中转 API..."
  if [[ "$PROXY_TYPE" == "claude" ]]; then
    PROV_NAME="${CLAUDE_PROVIDER_NAME:-claude-proxy}"
    MODEL_ID="${CLAUDE_MODEL_ID:-claude-sonnet-4-5}"
    python3 -c "
import json
p = '$HOME/.openclaw/openclaw.json'
with open(p) as f: c = json.load(f)
c.setdefault('models',{}).setdefault('providers',{})['${PROV_NAME}'] = {
    'baseUrl': '${CLAUDE_BASE_URL}',
    'apiKey': '${CLAUDE_PROXY_KEY}',
    'auth': 'api-key',
    'api': 'anthropic-messages',
    'headers': {},
    'authHeader': False,
    'models': []
}
c.setdefault('agents',{}).setdefault('defaults',{})['model'] = {'primary':'${PROV_NAME}/${MODEL_ID}','fallbacks':[]}
with open(p,'w') as f: json.dump(c,f,indent=2)
"
  else
    PROV_NAME="${OPENAI_PROVIDER_NAME:-openai-proxy}"
    MODEL_ID="${OPENAI_MODEL_ID:-gpt-5.2}"
    python3 -c "
import json
p = '$HOME/.openclaw/openclaw.json'
with open(p) as f: c = json.load(f)
c.setdefault('models',{}).setdefault('providers',{})['${PROV_NAME}'] = {
    'baseUrl': '${OPENAI_BASE_URL}',
    'apiKey': '${OPENAI_PROXY_KEY}',
    'auth': 'api-key',
    'api': 'openai-responses',
    'headers': {},
    'authHeader': False,
    'models': [{'id':'${MODEL_ID}','name':'${MODEL_ID}','reasoning':True,'input':['text','image'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':128000,'maxTokens':32768}]
}
c.setdefault('agents',{}).setdefault('defaults',{})['model'] = {'primary':'${PROV_NAME}/${MODEL_ID}','fallbacks':[]}
with open(p,'w') as f: json.dump(c,f,indent=2)
"
  fi
  info "中转 API 配置完成"
fi

# ── 渠道 (用 CLI) ──
[[ -n "${TELEGRAM_TOKEN:-}" ]] && {
  openclaw channels add --channel telegram --token "${TELEGRAM_TOKEN}" 2>&1 || warn "Telegram 添加失败"
  info "Telegram ✓"
}
[[ -n "${DISCORD_TOKEN:-}" ]] && {
  openclaw channels add --channel discord --token "${DISCORD_TOKEN}" 2>&1 || warn "Discord 添加失败"
  info "Discord ✓"
}
[[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_APP_TOKEN:-}" ]] && {
  openclaw channels add --channel slack --bot-token "${SLACK_BOT_TOKEN}" --app-token "${SLACK_APP_TOKEN}" 2>&1 || warn "Slack 添加失败"
  info "Slack ✓"
}
[[ -n "${SIGNAL_NUMBER:-}" ]] && {
  openclaw channels add --channel signal --signal-number "${SIGNAL_NUMBER}" 2>&1 || warn "Signal 添加失败"
  info "Signal ✓"
}

# ── 启动 ──
openclaw gateway restart 2>&1 || openclaw gateway start 2>&1 || warn "Gateway 启动失败"
sleep 2
info "安装完成! WebChat: http://localhost:${PORT}"
