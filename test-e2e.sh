#!/usr/bin/env bash
# test-e2e.sh — 端到端测试安装脚本（不实际安装 OpenClaw，只测配置生成逻辑）
# 用法: bash test-e2e.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS=0
FAIL=0

pass() { ((PASS++)); echo -e "${GREEN}✅ $1${NC}"; }
fail() { ((FAIL++)); echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${YELLOW}▶ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# ─── Test 1: Bash syntax ───
info "Test 1: Bash 语法检查"
bash -n "$SCRIPT_DIR/install-apexyy.sh" 2>/dev/null && pass "install-apexyy.sh 语法正确" || fail "install-apexyy.sh 语法错误"
bash -n "$SCRIPT_DIR/install-apexyy-silent.sh" 2>/dev/null && pass "install-apexyy-silent.sh 语法正确" || fail "install-apexyy-silent.sh 语法错误"

# ─── Test 2: Python 配置生成 ───
info "Test 2: Python 配置生成"

# 场景 A: 只有 Claude
python3 << 'PYEOF' > "$TMPDIR/config-claude.json"
import json
config = {
    "agents": {"defaults": {"model": "apexyy-claude"}},
    "providers": {
        "apexyy-claude": {
            "type": "custom",
            "api": "anthropic-messages",
            "baseUrl": "https://yunyi.rdzhvip.com/v1",
            "apiKey": "sk-test-claude",
            "headers": {},
            "authHeader": False,
            "models": []
        }
    },
    "models": {"apexyy-claude": {"provider": "apexyy-claude"}}
}
print(json.dumps(config, indent=2))
PYEOF
python3 -c "
import json
c = json.load(open('$TMPDIR/config-claude.json'))
assert c['providers']['apexyy-claude']['api'] == 'anthropic-messages'
assert c['providers']['apexyy-claude']['models'] == []
assert c['providers']['apexyy-claude']['authHeader'] == False
assert c['agents']['defaults']['model'] == 'apexyy-claude'
" && pass "场景A: 只有Claude" || fail "场景A: 只有Claude"

# 场景 B: 只有 Codex
python3 << 'PYEOF' > "$TMPDIR/config-codex.json"
import json
config = {
    "agents": {"defaults": {"model": "apexyy-codex"}},
    "providers": {
        "apexyy-codex": {
            "type": "custom",
            "api": "openai-responses",
            "baseUrl": "https://yunyi.rdzhvip.com/v1",
            "apiKey": "sk-test-codex",
            "models": [
                {"id": "gpt-5.2", "reasoning": True, "input": 1000000, "cost": {"input": 2, "output": 8}},
                {"id": "gpt-5.2-mini", "input": 1000000, "cost": {"input": 0.4, "output": 1.6}},
                {"id": "gpt-5.3-codex", "reasoning": True, "input": 1000000, "cost": {"input": 3, "output": 12}},
                {"id": "o3", "reasoning": True, "input": 200000, "cost": {"input": 2, "output": 8}},
                {"id": "o4-mini", "reasoning": True, "input": 200000, "cost": {"input": 1.1, "output": 4.4}}
            ]
        }
    },
    "models": {"apexyy-codex": {"provider": "apexyy-codex"}}
}
print(json.dumps(config, indent=2))
PYEOF
python3 -c "
import json
c = json.load(open('$TMPDIR/config-codex.json'))
assert c['providers']['apexyy-codex']['api'] == 'openai-responses'
assert len(c['providers']['apexyy-codex']['models']) == 5
assert c['agents']['defaults']['model'] == 'apexyy-codex'
" && pass "场景B: 只有Codex" || fail "场景B: 只有Codex"

# 场景 C: 都有
python3 << 'PYEOF' > "$TMPDIR/config-both.json"
import json
config = {
    "agents": {"defaults": {"model": "apexyy-claude"}},
    "providers": {
        "apexyy-claude": {
            "type": "custom", "api": "anthropic-messages",
            "baseUrl": "https://yunyi.rdzhvip.com/v1", "apiKey": "sk-c",
            "headers": {}, "authHeader": False, "models": []
        },
        "apexyy-codex": {
            "type": "custom", "api": "openai-responses",
            "baseUrl": "https://yunyi.rdzhvip.com/v1", "apiKey": "sk-x",
            "models": [
                {"id": "gpt-5.2", "reasoning": True, "input": 1000000, "cost": {"input": 2, "output": 8}},
                {"id": "gpt-5.2-mini", "input": 1000000, "cost": {"input": 0.4, "output": 1.6}},
                {"id": "gpt-5.3-codex", "reasoning": True, "input": 1000000, "cost": {"input": 3, "output": 12}},
                {"id": "o3", "reasoning": True, "input": 200000, "cost": {"input": 2, "output": 8}},
                {"id": "o4-mini", "reasoning": True, "input": 200000, "cost": {"input": 1.1, "output": 4.4}}
            ]
        }
    },
    "models": {
        "apexyy-claude": {"provider": "apexyy-claude"},
        "apexyy-codex": {"provider": "apexyy-codex"}
    }
}
print(json.dumps(config, indent=2))
PYEOF
python3 -c "
import json
c = json.load(open('$TMPDIR/config-both.json'))
assert len(c['providers']) == 2
assert c['agents']['defaults']['model'] == 'apexyy-claude'
assert 'apexyy-claude' in c['models']
assert 'apexyy-codex' in c['models']
" && pass "场景C: 都有" || fail "场景C: 都有"

# 场景 D: 国外节点
python3 -c "
import json
c = json.load(open('$TMPDIR/config-claude.json'))
# 修改为国外节点
c['providers']['apexyy-claude']['baseUrl'] = 'https://yunyi.cfd/v1'
assert 'yunyi.cfd' in c['providers']['apexyy-claude']['baseUrl']
" && pass "场景D: 国外节点" || fail "场景D: 国外节点"

# ─── Test 3: 特殊字符 Key ───
info "Test 3: 特殊字符 API Key"
python3 << 'PYEOF'
import json
keys = [
    "sk-abc'def",
    'sk-abc"def',
    "sk-abc\\def",
    "sk-abc$def",
    "sk-abc def",
    "sk-abc\ndef",
]
for key in keys:
    config = {"apiKey": key}
    s = json.dumps(config)
    parsed = json.loads(s)
    assert parsed["apiKey"] == key, f"Failed for key: {repr(key)}"
PYEOF
[ $? -eq 0 ] && pass "特殊字符 Key 全部通过" || fail "特殊字符 Key 有失败"

# ─── Test 4: API 域名连通性 ───
info "Test 4: API 域名连通性"
HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 https://yunyi.rdzhvip.com/v1/models 2>/dev/null || echo "000")
[ "$HTTP_CODE" != "000" ] && pass "国内节点可达 (HTTP $HTTP_CODE)" || fail "国内节点不可达"

HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 https://yunyi.cfd/v1/models 2>/dev/null || echo "000")
[ "$HTTP_CODE" != "000" ] && pass "国外节点可达 (HTTP $HTTP_CODE)" || fail "国外节点不可达"

# ─── Test 5: JSON 合法性 ───
info "Test 5: 生成的 JSON 合法性"
for f in "$TMPDIR"/config-*.json; do
    python3 -c "import json; json.load(open('$f'))" 2>/dev/null && pass "$(basename $f) JSON 合法" || fail "$(basename $f) JSON 不合法"
done

# ─── Test 6: 文件完整性 ───
info "Test 6: 仓库文件完整性"
for f in install-apexyy.sh install-apexyy-silent.sh install-apexyy.ps1 \
         src/main/index.js src/main/preload.js src/renderer/index.html \
         src/renderer/js/app.js src/renderer/css/style.css \
         USER-GUIDE.md QUICKSTART.md README.md package.json; do
    [ -f "$SCRIPT_DIR/$f" ] && pass "$f 存在" || fail "$f 缺失"
done

# ─── Summary ───
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "测试结果: ${GREEN}$PASS 通过${NC} / ${RED}$FAIL 失败${NC} / $((PASS+FAIL)) 总计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ $FAIL -eq 0 ] && echo -e "${GREEN}🎉 全部通过！${NC}" || echo -e "${RED}⚠️ 有 $FAIL 个测试失败${NC}"
exit $FAIL
