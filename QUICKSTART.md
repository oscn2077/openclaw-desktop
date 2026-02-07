# OpenClaw 快速上手 — ApexYY 专版

> Desktop 版上线前的应急方案，纯命令行 + 配置文件，2 分钟搞定。

---

## 一、安装环境

### Windows

1. 安装 [Git](https://git-scm.com/)（安装时一路默认即可）
2. 安装 [Node.js](https://nodejs.org/)（选 LTS 版本，一路默认）
3. 打开 **PowerShell**（如果报脚本禁止运行，先执行）：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
4. 安装 OpenClaw：
```powershell
npm config set registry https://registry.npmmirror.com/
npm i -g openclaw
```

### macOS

```bash
# 如果没有 Node.js，先装 Homebrew + Node
brew install node

# 安装 OpenClaw
npm i -g openclaw
```

### Linux (Ubuntu/Debian)

```bash
# 一键脚本（推荐）
curl -fsSL https://openclaw.ai/install.sh | bash
```

或者手动：
```bash
# 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# 安装 OpenClaw
npm i -g openclaw
```

---

## 二、初始化

所有平台通用：
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

---

## 三、配置模型

找到配置文件：
- **Windows**: `C:\Users\你的用户名\.openclaw\openclaw.json`
- **macOS**: `~/.openclaw/openclaw.json`
- **Linux**: `~/.openclaw/openclaw.json`

### 只有 Claude 的卡密

把配置文件内容替换为：

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
        "primary": "apexyy-claude/claude-opus-4-5"
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

### 只有 Codex (OpenAI) 的卡密

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
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "apexyy-codex/gpt-5.2"
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

### 两个都有（Claude + Codex）

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
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "apexyy-claude/claude-opus-4-5",
        "fallbacks": ["apexyy-codex/gpt-5.2"]
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

## 四、启动

### Windows

```powershell
openclaw gateway start
```

如果报 Gateway service install failed，用管理员身份打开 PowerShell 再试，或者直接前台运行：
```powershell
openclaw gateway
```

### macOS / Linux

```bash
openclaw gateway start
```

启动后会自动打开浏览器，访问 `http://127.0.0.1:18789/?token=你设的token`

如果没自动打开，手动在浏览器输入上面的地址。

---

## 五、常用命令

```bash
# 查看状态
openclaw status

# 重启（改完配置后要重启）
openclaw gateway restart

# 停止
openclaw gateway stop

# 查看额度（云驿）
# 浏览器打开 https://yunyi.rdzhvip.com/user
```

---

## 常见问题

**Q: npm 安装报错权限不够？**
- Windows: 用管理员 PowerShell
- macOS/Linux: `sudo npm i -g openclaw`

**Q: 改了配置没生效？**
- `openclaw gateway restart`

**Q: Claude 和 Codex 的卡密能混用吗？**
- 不能，两个是独立产品线，各用各的卡密

**Q: 怎么换模型？**
- 改配置文件里 `agents.defaults.model.primary` 的值
- Claude 可选: `claude-opus-4-5`, `claude-opus-4-6`, `claude-sonnet-4-5`
- Codex 可选: `gpt-5.2`, `gpt-codex-5.3`, `gpt-4.1`, `o3`, `o4-mini`
