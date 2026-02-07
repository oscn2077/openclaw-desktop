#!/usr/bin/env bash
# OpenClaw ApexYY 专版 — 更新脚本
# 用法: bash update-apexyy.sh
#
# 会执行:
#   1. 停止 Gateway
#   2. npm update -g openclaw
#   3. 重启 Gateway
#   4. 显示新版本号
set -euo pipefail

# ========== 颜色定义 ==========
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
step()  { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
die()   { err "$*"; exit 1; }

echo ""
echo -e "${BOLD}🦞 OpenClaw 更新 — ApexYY 专版${NC}"
echo ""

# ========== 检查 openclaw 是否已安装 ==========
if ! command -v openclaw &>/dev/null; then
  die "OpenClaw 未安装。请先运行: bash install-apexyy.sh"
fi

# 记录旧版本
OLD_VER=$(openclaw --version 2>/dev/null || echo "unknown")
info "当前版本: ${OLD_VER}"

# ========== 1. 停止 Gateway ==========
step "停止 Gateway"
openclaw gateway stop 2>&1 && info "Gateway 已停止" || warn "Gateway 可能未在运行"

# ========== 2. 更新 ==========
step "更新 OpenClaw"
info "正在从 npm 获取最新版本..."
SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest 2>&1 | tail -5 || die "更新失败"

# 记录新版本
NEW_VER=$(openclaw --version 2>/dev/null || echo "unknown")

if [[ "$OLD_VER" == "$NEW_VER" ]]; then
  info "已是最新版本: ${NEW_VER}"
else
  info "更新完成: ${OLD_VER} → ${NEW_VER}"
fi

# ========== 3. 重启 Gateway ==========
step "重启 Gateway"
openclaw gateway start 2>&1 || warn "启动失败"
sleep 2

# 验证启动状态
if openclaw gateway status 2>&1 | grep -qi "running\|online\|listening"; then
  info "Gateway 运行中 ✓"
else
  warn "Gateway 可能未正常启动"
  warn "请手动检查: openclaw gateway status"
fi

# ========== 完成 ==========
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║          ✅ OpenClaw 更新完成                   ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}版本:${NC} ${OLD_VER} → ${GREEN}${NEW_VER}${NC}"
echo -e "  ${BOLD}状态:${NC} Gateway 已重启"
echo -e "  ${BOLD}WebChat:${NC} ${CYAN}http://localhost:18789${NC}"
echo ""
