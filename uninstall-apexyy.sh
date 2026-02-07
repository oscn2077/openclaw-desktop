#!/usr/bin/env bash
# OpenClaw ApexYY 专版 — 卸载脚本
# 用法: bash uninstall-apexyy.sh
#
# 会执行:
#   1. 停止 Gateway
#   2. 卸载 openclaw npm 包
#   3. 删除 ~/.openclaw 目录 (需确认)
#   4. 保留 Node.js (用户可能还需要)
set -euo pipefail

# ========== 颜色定义 ==========
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
step()  { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
ask()   { echo -en "${CYAN}[?]${NC} $* "; }

echo ""
echo -e "${BOLD}🦞 OpenClaw 卸载 — ApexYY 专版${NC}"
echo ""

# ========== 1. 停止 Gateway ==========
step "停止 Gateway"
if command -v openclaw &>/dev/null; then
  openclaw gateway stop 2>&1 && info "Gateway 已停止" || warn "Gateway 可能未在运行"
else
  warn "未找到 openclaw 命令，跳过停止步骤"
fi

# ========== 2. 卸载 openclaw npm 包 ==========
step "卸载 OpenClaw"
if command -v openclaw &>/dev/null; then
  local_ver=$(openclaw --version 2>/dev/null || echo "unknown")
  info "当前版本: ${local_ver}"
  npm uninstall -g openclaw 2>&1 && info "OpenClaw 已卸载" || warn "npm 卸载失败"
else
  warn "OpenClaw 未安装，跳过"
fi

# ========== 3. 删除 ~/.openclaw 目录 ==========
step "清理配置目录"
OPENCLAW_DIR="$HOME/.openclaw"
if [[ -d "$OPENCLAW_DIR" ]]; then
  echo ""
  echo -e "  ${YELLOW}警告: 以下目录将被删除:${NC}"
  echo "    ${OPENCLAW_DIR}"
  echo ""
  echo -e "  包含内容:"
  echo "    • openclaw.json (配置文件，含 API Key)"
  echo "    • workspace/ (工作区，含 AI 记忆)"
  echo "    • 其他运行时数据"
  echo ""

  # 显示目录大小
  local dir_size
  dir_size=$(du -sh "$OPENCLAW_DIR" 2>/dev/null | cut -f1 || echo "未知")
  echo -e "  目录大小: ${dir_size}"
  echo ""

  ask "确定要删除 ${OPENCLAW_DIR}? (y/N)"
  read -r ans
  if [[ "${ans,,}" == "y" ]]; then
    rm -rf "$OPENCLAW_DIR"
    info "已删除 ${OPENCLAW_DIR}"
  else
    warn "保留 ${OPENCLAW_DIR}"
    echo "  如需手动删除: rm -rf ${OPENCLAW_DIR}"
  fi
else
  info "配置目录不存在，无需清理"
fi

# ========== 4. Node.js 保留说明 ==========
step "Node.js"
if command -v node &>/dev/null; then
  info "Node.js $(node -v) 已保留 (其他程序可能需要)"
  echo "  如需卸载 Node.js:"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "    brew uninstall node"
  elif command -v apt-get &>/dev/null; then
    echo "    sudo apt-get remove nodejs"
  elif command -v dnf &>/dev/null; then
    echo "    sudo dnf remove nodejs"
  else
    echo "    请使用系统包管理器卸载"
  fi
  echo "  如使用 nvm: nvm uninstall <version>"
fi

# ========== 完成 ==========
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║          ✅ OpenClaw 卸载完成                   ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}已执行:${NC}"
echo "    • Gateway 已停止"
echo "    • OpenClaw npm 包已卸载"
if [[ ! -d "$HOME/.openclaw" ]]; then
  echo "    • ~/.openclaw 目录已删除"
else
  echo -e "    • ~/.openclaw 目录 ${YELLOW}已保留${NC}"
fi
echo "    • Node.js 已保留"
echo ""
echo "  如需重新安装: bash install-apexyy.sh"
echo ""
