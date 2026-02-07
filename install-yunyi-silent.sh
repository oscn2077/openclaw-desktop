#!/usr/bin/env bash
# OpenClaw 云翼专版 — 静默安装
# 用法:
#   YY_KEY=xxx bash install-yunyi-silent.sh
#   YY_KEY=xxx YY_NODE=1 YY_PRIMARY=claude-opus-4-6 TELEGRAM_TOKEN=xxx bash install-yunyi-silent.sh
#
# 环境变量:
#   YY_KEY              — (必填) 云翼 API Key
#   YY_NODE             — 节点选择 1-6 (默认 1 国内主节点)
#                         1=yunyi.rdzhvip.com 2=yunyi.cfd 3=cdn1.yunyi.cfd
#                         4=cdn2.yunyi.cfd 5=47.99.42.193 6=47.97.100.10
#   YY_PRIMARY          — 主模型 (默认 claude-opus-4-6)
#   YY_INSTALL_ALL      — 安装全部模型 1/0 (默认 1)
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

[[ -z "${YY_KEY:-}" ]] && die "请设置 YY_KEY 环境变量"

PORT="${GATEWAY_PORT:-18789}"

# 节点映射
declare -A NODE_URLS
NODE_URLS=( ["1"]="https://yunyi.rdzhvip.com" ["2"]="https://yunyi.cfd" ["3"]="https://cdn1.yunyi.cfd" ["4"]="https://cdn2.yunyi.cfd" ["5"]="http://47.99.42.193" ["6"]="http://47.97.100.10" )
YY_BASE="${NODE_URLS[${YY_NODE:-1}]:-${NODE_URLS[1]}}"
info "节点: ${YY_BASE}"

# Node.js
if [[ "${SKIP_NODE_INSTALL:-}" != "1" ]]; then
  if ! command -v node &>/dev/null || (( $(node -v | sed 's/v//' | cut -d. -f1) < 22 )); then
    if [[ "$OSTYPE" == "darwin"* ]]; then brew install node@22 2>/dev/null
    elif command -v apt-get &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs
    else die "请手动安装 Node.js 22+"; fi
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

# 写入云翼配置
PRIMARY="${YY_PRIMARY:-claude-opus-4-6}"
INSTALL_ALL="${YY_INSTALL_ALL:-1}"

python3 << PYEOF
import json

p = "$HOME/.openclaw/openclaw.json"
with open(p) as f: c = json.load(f)
c.setdefault('models',{}).setdefault('providers',{})
c.setdefault('agents',{}).setdefault('defaults',{})

base = "${YY_BASE}"
key = "${YY_KEY}"

c['models']['providers']['yunyi-claude'] = {
    'baseUrl': base + '/claude', 'auth': 'api-key', 'api': 'anthropic-messages', 'apiKey': key,
    'models': [
        {'id':'claude-opus-4-6','name':'Claude Opus 4.6','contextWindow':200000,'maxTokens':8192},
        {'id':'claude-sonnet-4-5','name':'Claude Sonnet 4.5','contextWindow':200000,'maxTokens':8192},
        {'id':'claude-haiku-4-5','name':'Claude Haiku 4.5','contextWindow':200000,'maxTokens':8192},
    ]
}
c['models']['providers']['yunyi-codex'] = {
    'baseUrl': base + '/codex', 'auth': 'api-key', 'api': 'openai-responses', 'apiKey': key,
    'models': [
        {'id':'gpt-5.3-codex','name':'GPT 5.3 Codex','contextWindow':128000,'maxTokens':32768},
        {'id':'gpt-5.2','name':'GPT 5.2','contextWindow':128000,'maxTokens':32768},
    ]
}

primary_id = "${PRIMARY}"
if primary_id in ('gpt-5.3-codex','gpt-5.2'):
    primary_ref = f"yunyi-codex/{primary_id}"
else:
    primary_ref = f"yunyi-claude/{primary_id}"

if "${INSTALL_ALL}" == "1":
    fallbacks = [
        'yunyi-claude/claude-opus-4-6','yunyi-claude/claude-sonnet-4-5',
        'yunyi-codex/gpt-5.3-codex','yunyi-codex/gpt-5.2','yunyi-claude/claude-haiku-4-5'
    ]
    fallbacks = [f for f in fallbacks if f != primary_ref]
else:
    fallbacks = []

c['agents']['defaults']['model'] = {'primary': primary_ref, 'fallbacks': fallbacks}

aliases = {}
for pn, pd in c['models']['providers'].items():
    for m in pd.get('models',[]):
        aliases[f"{pn}/{m['id']}"] = {'alias': m['name']}
c['agents']['defaults']['models'] = aliases

with open(p,'w') as f: json.dump(c,f,indent=2,ensure_ascii=False)
print(f"主模型: {primary_ref}")
print(f"Failover: {' → '.join(fallbacks)}" if fallbacks else "无 failover")
PYEOF

info "云翼配置完成"

# 渠道
[[ -n "${TELEGRAM_TOKEN:-}" ]] && { openclaw channels add --channel telegram --token "${TELEGRAM_TOKEN}" 2>&1 || warn "Telegram 失败"; info "Telegram ✓"; }
[[ -n "${DISCORD_TOKEN:-}" ]] && { openclaw channels add --channel discord --token "${DISCORD_TOKEN}" 2>&1 || warn "Discord 失败"; info "Discord ✓"; }
[[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_APP_TOKEN:-}" ]] && { openclaw channels add --channel slack --bot-token "${SLACK_BOT_TOKEN}" --app-token "${SLACK_APP_TOKEN}" 2>&1 || warn "Slack 失败"; info "Slack ✓"; }
[[ -n "${SIGNAL_NUMBER:-}" ]] && { openclaw channels add --channel signal --signal-number "${SIGNAL_NUMBER}" 2>&1 || warn "Signal 失败"; info "Signal ✓"; }

# 启动
openclaw gateway restart 2>&1 || openclaw gateway start 2>&1 || warn "启动失败"
sleep 2
info "完成! WebChat: http://localhost:${PORT}"
