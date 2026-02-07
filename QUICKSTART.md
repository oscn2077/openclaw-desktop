# OpenClaw 快速上手 — ApexYY 专版

> Desktop 版上线前的应急方案，纯命令行 + 配置文件，2 分钟搞定。
> 
> 🆕 完全不懂技术？请看 [USER-GUIDE.md](USER-GUIDE.md)（小白手册）

---

## 一、一键安装（推荐）

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

带渠道 + 指定节点 + 指定模型：
```bash
AY_CLAUDE_KEY=xxx AY_NODE=2 AY_PRIMARY=claude-opus-4-6 TELEGRAM_TOKEN=bot_token bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

**静默安装环境变量一览：**

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `AY_CLAUDE_KEY` | Claude 卡密 | — |
| `AY_CODEX_KEY` | Codex 卡密 | — |
| `AY_KEY` | 兼容旧版，同时给 Claude 和 Codex | — |
| `AY_NODE` | 节点选择 1-6 | 1 (国内) |
| `AY_PRIMARY` | 主模型 | claude-opus-4-5 |
| `GATEWAY_PORT` | 端口 | 18789 |
| `TELEGRAM_TOKEN` | Telegram Bot Token | — |
| `DISCORD_TOKEN` | Discord Bot Token | — |
| `SLACK_BOT_TOKEN` | Slack Bot Token | — |
| `SLACK_APP_TOKEN` | Slack App Token | — |
| `SIGNAL_NUMBER` | Signal 号码 | — |
| `SKIP_NODE_INSTALL` | 跳过 Node.js 安装 | — |
| `SKIP_OPENCLAW_INSTALL` | 跳过 OpenClaw 安装 | — |
| `SKIP_DAEMON` | 跳过 daemon 安装 | — |

### Windows — PowerShell（管理员）

一键安装（交互式）：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 | iex
```

带参数（静默）：
```powershell
irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 -OutFile install.ps1
.\install.ps1 -ClaudeKey "你的卡密" -Node 1
```

**PowerShell 参数一览：**

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-ClaudeKey` | Claude 卡密 | — |
| `-CodexKey` | Codex 卡密 | — |
| `-Node` | 节点 1-6 | 1 |
| `-Primary` | 主模型 | claude-opus-4-5 |
| `-TelegramToken` | Telegram Bot Token | — |
| `-DiscordToken` | Discord Bot Token | — |

### Windows — WSL（备选）
```powershell
wsl --install
# 重启后进 WSL，跑 Linux 命令
```

---

## 二、手动安装

如果一键脚本不适合你，可以手动操作。

### 安装环境

#### Windows

1. 安装 [Git](https://git-scm.com/)（安装时一路默认即可）
2. 安装 [Node.js 22+](https://nodejs.org/)（选 LTS 版本，一路默认）
3. 打开 **PowerShell**（管理员），如果报脚本禁止运行：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
4. 安装 OpenClaw：
```powershell
npm config set registry https://registry.npmmirror.com/
npm i -g openclaw
```

#### macOS

```bash
# 如果没有 Node.js，先装 Homebrew + Node
brew install node@22

# 安装 OpenClaw
npm i -g openclaw
```

#### Linux (Ubuntu/Debian)

```bash
# 安装 Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# 安装 OpenClaw
npm i -g openclaw
```

#### Linux (CentOS/RHEL/Fedora)

```bash
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs   # 或 sudo yum install -y nodejs
npm i -g openclaw
```

### 初始化

```bash
openclaw onboard
```

按提示选：
- Onboarding mode → **QuickStart**
- Model/auth provider → **Skip for now**
- Filter models → **All providers**
- Default model → **Keep current**
- Channel → **Skip for now**
- Skills → **No**
- Hooks → 三个都选上

### 配置模型

找到配置文件：
- **Windows**: `C:\Users\你的用户名\.openclaw\openclaw.json`
- **macOS / Linux**: `~/.openclaw/openclaw.json`

#### 只有 Claude 的卡密

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "apexyy-claude": {
        "baseUrl": "https://yunyi.rdzhvip.com/claude",
        "apiKey": "你的ApexYY卡密",
        "auth": "api-key",
        "api": "anthropic-messages",
        "headers": {},
        "authHeader": false,
        "models": []
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "apexyy-claude/claude-opus-4-5",
        "fallbacks": ["apexyy-claude/claude-opus-4-6", "apexyy-claude/claude-sonnet-4-5"]
      },
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 },
      "compaction": { "mode": "safeguard" }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "随便填一串字符当密码"
    },
    "port": 18789,
    "bind": "loopback"
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    }
  }
}
```

#### 只有 Codex (OpenAI) 的卡密

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "apexyy-codex": {
        "baseUrl": "https://yunyi.rdzhvip.com/codex",
        "apiKey": "你的ApexYY卡密",
        "auth": "api-key",
        "api": "openai-responses",
        "headers": {},
        "authHeader": false,
        "models": [
          {
            "id": "gpt-5.2",
            "name": "GPT 5.2",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000,
            "maxTokens": 32768
          },
          {
            "id": "gpt-5.3-codex",
            "name": "GPT 5.3 Codex",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000,
            "maxTokens": 32768
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "apexyy-codex/gpt-5.2",
        "fallbacks": ["apexyy-codex/gpt-5.3-codex"]
      },
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 },
      "compaction": { "mode": "safeguard" }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "随便填一串字符当密码"
    },
    "port": 18789,
    "bind": "loopback"
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    }
  }
}
```

#### 两个都有（Claude + Codex）

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "apexyy-claude": {
        "baseUrl": "https://yunyi.rdzhvip.com/claude",
        "apiKey": "你的Claude卡密",
        "auth": "api-key",
        "api": "anthropic-messages",
        "headers": {},
        "authHeader": false,
        "models": []
      },
      "apexyy-codex": {
        "baseUrl": "https://yunyi.rdzhvip.com/codex",
        "apiKey": "你的Codex卡密",
        "auth": "api-key",
        "api": "openai-responses",
        "headers": {},
        "authHeader": false,
        "models": [
          {
            "id": "gpt-5.2",
            "name": "GPT 5.2",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000,
            "maxTokens": 32768
          },
          {
            "id": "gpt-5.3-codex",
            "name": "GPT 5.3 Codex",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000,
            "maxTokens": 32768
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "apexyy-claude/claude-opus-4-5",
        "fallbacks": ["apexyy-claude/claude-opus-4-6", "apexyy-claude/claude-sonnet-4-5", "apexyy-codex/gpt-5.2", "apexyy-codex/gpt-5.3-codex"]
      },
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 },
      "compaction": { "mode": "safeguard" }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "随便填一串字符当密码"
    },
    "port": 18789,
    "bind": "loopback"
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    }
  }
}
```

> ⚠️ **国外服务器**把 `yunyi.rdzhvip.com` 换成 `yunyi.cfd`

---

## 三、启动

```bash
openclaw gateway start
```

启动后访问 `http://localhost:18789`

---

## 四、节点列表

| 编号 | 地址 | 说明 |
|------|------|------|
| 1 | `https://yunyi.rdzhvip.com` | 国内主节点（推荐国内用户） |
| 2 | `https://yunyi.cfd` | CF 国外节点 1（推荐海外用户） |
| 3 | `https://cdn1.yunyi.cfd` | CF 国外节点 2 |
| 4 | `https://cdn2.yunyi.cfd` | CF 国外节点 3 |
| 5 | `http://47.99.42.193` | 备用节点 1（IP 直连） |
| 6 | `http://47.97.100.10` | 备用节点 2（IP 直连） |

---

## 五、可用模型

| 产品线 | 模型 ID | 说明 | API 格式 |
|--------|---------|------|---------|
| Claude | `claude-opus-4-6` | 最强 | anthropic-messages |
| Claude | `claude-opus-4-5` | 强力（默认） | anthropic-messages |
| Claude | `claude-sonnet-4-5` | 均衡 | anthropic-messages |
| Codex | `gpt-5.2` | GPT 最新 | openai-responses |
| Codex | `gpt-5.3-codex` | GPT 代码版 | openai-responses |

> ⚠️ Claude 和 Codex 是独立产品线，卡密不互通
> - Claude `models: []`（空数组，自动检测）
> - Codex 需要完整模型声明（`api: openai-responses`）

---

## 六、常用命令

```bash
openclaw gateway status     # 查看状态
openclaw gateway start      # 启动
openclaw gateway stop       # 停止
openclaw gateway restart    # 重启（改完配置后必须重启）
openclaw doctor             # 健康检查
openclaw --version          # 查看版本
```

---

## 七、常见错误与解决方案

### npm 安装报错权限不够

**Windows:** 用管理员 PowerShell

**macOS / Linux:**
```bash
sudo npm i -g openclaw
```

### nvm 版本冲突

如果系统装了 nvm 但 Node 版本低于 22：
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22
nvm alias default 22
```

### apt lock（Ubuntu/Debian）

```bash
sudo killall apt apt-get 2>/dev/null
sudo rm /var/lib/dpkg/lock-frontend 2>/dev/null
sudo rm /var/lib/apt/lists/lock 2>/dev/null
sudo dpkg --configure -a
```

### Windows 脚本执行策略

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Gateway 启动失败 / 端口被占

```bash
# 查看谁占了端口
lsof -i :18789        # macOS / Linux
netstat -ano | findstr 18789   # Windows

# 换端口：编辑 openclaw.json 中 "port": 18789 改成别的
openclaw gateway restart
```

### "command not found: openclaw"

```bash
# 检查 npm 全局路径
npm config get prefix

# 确保在 PATH 中
export PATH="$(npm config get prefix)/bin:$PATH"

# 或重新安装
npm i -g openclaw@latest
```

### API Key 无效 / Unauthorized

1. 检查卡密是否完整（前后无空格）
2. Claude 卡密只能用在 `apexyy-claude`，Codex 卡密只能用在 `apexyy-codex`
3. 去 https://yunyi.rdzhvip.com/user 确认卡密状态

### 连接超时 / ECONNREFUSED

1. 检查网络
2. 换节点（国内用 1，国外用 2）
3. 试试 IP 直连节点（5 或 6）

---

## 额度查询

https://yunyi.rdzhvip.com/user
