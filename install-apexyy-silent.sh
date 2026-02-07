#!/usr/bin/env bash
# OpenClaw ApexYY 专版 — 静默安装
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

info() { echo "[✓] $*"; }
warn() { echo "[!] $*"; }
die()  { echo "[✗] $*"; exit 1; }

# 解析 Key
CLAUDE_KEY="${AY_CLAUDE_KEY:-${AY_KEY:-}}"
CODEX_KEY="${AY_CODEX_KEY:-${AY_KEY:-}}"

[[ -z "$CLAUDE_KEY" && -z "$CODEX_KEY" ]] && die "请设置 AY_CLAUDE_KEY 或 AY_CODEX_KEY (或 AY_KEY)"

HAS_CLAUDE=false; [[ -n "$CLAUDE_KEY" ]] && HAS_CLAUDE=true
HAS_CODEX=false; [[ -n "$CODEX_KEY" ]] && HAS_CODEX=true

PORT="${GATEWAY_PORT:-18789}"

# 节点映射
declare -A NODE_URLS
NODE_URLS=( ["1"]="https://yunyi.rdzhvip.com" ["2"]="https://yunyi.cfd" ["3"]="https://cdn1.yunyi.cfd" ["4"]="https://cdn2.yunyi.cfd" ["5"]="http://47.99.42.193" ["6"]="http://47.97.100.10" )
AY_BASE="${NODE_URLS[${AY_NODE:-1}]:-${NODE_URLS[1]}}"
info "节点: ${AY_BASE}"

# Node.js
if [[ "${SKIP_NODE_INSTALL:-}" != "1" ]]; then
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

# OpenClaw
if [[ "${SKIP_OPENCLAW_INSTALL:-}" != "1" ]]; then
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -3
  info "OpenClaw $(openclaw --version 2>/dev/null)"
fi

# Onboard
DAEMON_FLAG="--install-daemon"
[[ "${SKIP_DAEMON:-}" == "1" ]] && DAEMON_FLAG="--skip-daemon"

openclaw onboard --non-interactive --accept-risk --mode local --auth-choice skip \
  --gateway-port "${PORT}" --gateway-bind loopback --gateway-auth token \
  --skip-channels --skip-skills --skip-health --skip-ui ${DAEMON_FLAG} 2>&1 | tail -3 || warn "onboard 警告"

# 确定主模型
PRIMARY="${AY_PRIMARY:-}"
if [[ -z "$PRIMARY" ]]; then
  if [[ "$HAS_CLAUDE" == "true" ]]; then PRIMARY="claude-opus-4-5"
  else PRIMARY="gpt-5.2"; fi
fi

# 确定 primary ref
if [[ "$PRIMARY" == gpt-* || "$PRIMARY" == o3* || "$PRIMARY" == o4* ]]; then
  PRIMARY_REF="apexyy-codex/${PRIMARY}"
else
  PRIMARY_REF="apexyy-claude/${PRIMARY}"
fi

# 写入配置
python3 << PYEOF
import json

p = "$HOME/.openclaw/openclaw.json"
with open(p) as f: c = json.load(f)
c.setdefault('models', {})['mode'] = 'merge'
c['models'].setdefault('providers', {})
c.setdefault('agents', {}).setdefault('defaults', {})

base = "${AY_BASE}"
has_claude = $( [[ "$HAS_CLAUDE" == "true" ]] && echo "True" || echo "False" )
has_codex = $( [[ "$HAS_CODEX" == "true" ]] && echo "True" || echo "False" )

if has_claude:
    c['models']['providers']['apexyy-claude'] = {
        'baseUrl': base + '/claude',
        'apiKey': "${CLAUDE_KEY}",
        'auth': 'api-key',
        'api': 'anthropic-messages',
        'headers': {},
        'authHeader': False,
        'models': []
    }

if has_codex:
    c['models']['providers']['apexyy-codex'] = {
        'baseUrl': base + '/codex',
        'apiKey': "${CODEX_KEY}",
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

# Build fallbacks
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

# 渠道
[[ -n "${TELEGRAM_TOKEN:-}" ]] && { openclaw channels add --channel telegram --token "${TELEGRAM_TOKEN}" 2>&1 || warn "Telegram 失败"; info "Telegram ✓"; }
[[ -n "${DISCORD_TOKEN:-}" ]] && { openclaw channels add --channel discord --token "${DISCORD_TOKEN}" 2>&1 || warn "Discord 失败"; info "Discord ✓"; }
[[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_APP_TOKEN:-}" ]] && { openclaw channels add --channel slack --bot-token "${SLACK_BOT_TOKEN}" --app-token "${SLACK_APP_TOKEN}" 2>&1 || warn "Slack 失败"; info "Slack ✓"; }
[[ -n "${SIGNAL_NUMBER:-}" ]] && { openclaw channels add --channel signal --signal-number "${SIGNAL_NUMBER}" 2>&1 || warn "Signal 失败"; info "Signal ✓"; }

# 启动
openclaw gateway restart 2>&1 || openclaw gateway start 2>&1 || warn "启动失败"
sleep 2
info "完成! WebChat: http://localhost:${PORT}"
info "额度查询: https://yunyi.rdzhvip.com/user"
