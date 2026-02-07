# OpenClaw Desktop — ApexYY 专版

🦞 OpenClaw 桌面版 — 一键部署，无脑上手。

## 应急版（Desktop 上线前）

### Linux / macOS / WSL — 交互式
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.sh)
```

支持：Ubuntu / Debian / CentOS / Fedora / RHEL / Arch / Manjaro / Alpine / openSUSE / macOS / WSL

### Linux / macOS / WSL — 静默安装

只有 Claude 卡密：
```bash
AY_CLAUDE_KEY=你的卡密 bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

只有 Codex 卡密：
```bash
AY_CODEX_KEY=你的卡密 bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

两个都有：
```bash
AY_CLAUDE_KEY=claude卡密 AY_CODEX_KEY=codex卡密 bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

带渠道 + 指定节点：
```bash
AY_CLAUDE_KEY=xxx AY_NODE=2 TELEGRAM_TOKEN=bot_token bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

### Windows — PowerShell（管理员）

一键安装（交互式）：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 | iex
```

带参数：
```powershell
irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 -OutFile install.ps1
.\install.ps1 -ClaudeKey "你的卡密" -Node 1 -TelegramToken "bot_token"
```

### Windows — WSL（备选）
```powershell
wsl --install
# 重启后进 WSL，跑 Linux 命令
```

### 手动配置
见 [QUICKSTART.md](QUICKSTART.md)

## Desktop 版开发

```bash
npm install
npm run dev        # 开发模式
npm run build:win  # Windows .exe
npm run build:mac  # macOS .dmg
```

## 支持的模型

| 产品线 | 模型 | API 格式 |
|--------|------|---------|
| Claude | Opus 4.6 / 4.5, Sonnet 4.5 | anthropic-messages |
| Codex | GPT 5.2, Codex 5.3 | openai-responses |

> ⚠️ Claude 和 Codex 是独立产品线，卡密不互通

## 支持的渠道

WebChat（开箱即用）/ Telegram / Discord / 飞书 / 微信（即将）/ 钉钉（即将）

## 额度查询

https://yunyi.rdzhvip.com/user
