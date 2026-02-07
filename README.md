<div align="center">

# 🦞 OpenClaw Desktop — ApexYY 专版

**一键部署 OpenClaw，无脑上手 AI 助手。**

[![GitHub release](https://img.shields.io/github/v/release/oscn2077/openclaw-desktop?style=flat-square&label=版本)](https://github.com/oscn2077/openclaw-desktop/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/平台-Windows%20%7C%20macOS%20%7C%20Linux-brightgreen?style=flat-square)](#支持的平台)

> 把 Claude Opus 4.6 / GPT 5.3 装进你的电脑，一行命令搞定。

</div>

---

## ✨ 功能特性

- 🚀 **一键安装** — 一行命令完成全部配置，零基础也能用
- 🖥️ **全平台支持** — Windows / macOS / Linux / WSL，哪里都能跑
- 🔧 **自动配置** — 自动安装 Node.js、配置模型、启动服务
- 🌐 **多节点** — 6 个节点自动选择，国内国外都快
- 🤖 **双产品线** — 同时支持 Claude (Anthropic) 和 Codex (OpenAI)
- 💬 **多渠道** — WebChat / Telegram / Discord / 飞书，一处部署多处使用
- 📦 **模型管理** — 可视化切换模型、管理渠道、查看状态
- 🔒 **本地运行** — 数据不经第三方，隐私有保障

---

## 🚀 快速开始

拿到卡密后，选择你的平台，复制粘贴一行命令即可：

### Linux / macOS / WSL

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.sh)
```

### Windows (PowerShell 管理员)

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 | iex
```

### 静默安装 (Linux / macOS)

```bash
AY_CLAUDE_KEY=你的卡密 bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

安装完成后，打开浏览器访问 **http://localhost:18789** 即可开始对话 🎉

---

<!-- 
## 📸 截图

> TODO: 添加截图

| WebChat 界面 | 模型管理 | 状态页 |
|:---:|:---:|:---:|
| ![WebChat](docs/screenshots/webchat.png) | ![Models](docs/screenshots/models.png) | ![Status](docs/screenshots/status.png) |

-->

## 📖 文档

| 文档 | 说明 |
|------|------|
| **[QUICKSTART.md](QUICKSTART.md)** | 快速上手指南 — 安装参数、手动配置、节点列表、常见错误 |
| **[USER-GUIDE.md](USER-GUIDE.md)** | 小白手册 — 每一步都有截图和解释，完全不懂技术也能跟着做 |
| **[CHANGELOG.md](CHANGELOG.md)** | 版本更新日志 |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | 贡献指南 |

---

## 🖥️ 支持的平台

### 操作系统

| 平台 | 安装方式 | 状态 |
|------|---------|------|
| Ubuntu / Debian | bash 脚本 | ✅ |
| CentOS / RHEL / Fedora | bash 脚本 | ✅ |
| Arch / Manjaro | bash 脚本 | ✅ |
| Alpine | bash 脚本 | ✅ |
| openSUSE | bash 脚本 | ✅ |
| macOS (Intel & Apple Silicon) | bash 脚本 | ✅ |
| Windows 10/11 | PowerShell 脚本 | ✅ |
| WSL | bash 脚本 | ✅ |

### 支持的模型

| 产品线 | 模型 | 说明 | API 格式 |
|--------|------|------|---------|
| Claude | claude-opus-4-6 | 最强 | anthropic-messages |
| Claude | claude-opus-4-5 | 强力（默认） | anthropic-messages |
| Claude | claude-sonnet-4-5 | 均衡 | anthropic-messages |
| Codex | gpt-5.2 | GPT 最新 | openai-responses |
| Codex | gpt-5.3-codex | GPT 代码版 | openai-responses |

> ⚠️ Claude 和 Codex 是独立产品线，卡密不互通。

### 支持的消息渠道

| 渠道 | 状态 |
|------|------|
| WebChat | ✅ 开箱即用 |
| Telegram | ✅ |
| Discord | ✅ |
| 飞书 | ✅ |
| 微信 | 🔜 即将支持 |
| 钉钉 | 🔜 即将支持 |

---

## 📁 项目结构

```
openclaw-desktop/
├── src/
│   ├── main/              # Electron 主进程
│   │   ├── index.js       # 主入口
│   │   └── preload.js     # 预加载脚本
│   └── renderer/          # Electron 渲染进程
│       ├── index.html      # 主页面
│       ├── css/style.css   # 样式
│       └── js/app.js       # 前端逻辑
├── install-apexyy.sh       # Linux/macOS/WSL 交互式安装脚本
├── install-apexyy-silent.sh # Linux/macOS/WSL 静默安装脚本
├── install-apexyy.ps1      # Windows PowerShell 安装脚本
├── QUICKSTART.md            # 快速上手指南
├── USER-GUIDE.md            # 小白使用手册
├── CHANGELOG.md             # 版本更新日志
├── CONTRIBUTING.md          # 贡献指南
├── LICENSE                  # MIT 许可证
└── package.json             # 项目配置
```

---

## ❓ FAQ

<details>
<summary><b>Q: Claude 和 Codex 有什么区别？</b></summary>

它们是两个不同公司的 AI 产品：
- **Claude** — Anthropic 公司出品，推荐用于日常对话和复杂任务
- **Codex** — OpenAI 公司出品 (GPT 系列)，擅长代码生成

两者的卡密独立，不能混用。
</details>

<details>
<summary><b>Q: 国内用户选哪个节点？</b></summary>

推荐节点 1（`yunyi.rdzhvip.com`），这是国内主节点，速度最快。海外用户推荐节点 2（`yunyi.cfd`）。
</details>

<details>
<summary><b>Q: 安装后怎么访问？</b></summary>

打开浏览器，访问 `http://localhost:18789`。这是本地地址，只有你自己能访问。
</details>

<details>
<summary><b>Q: 怎么查看剩余额度？</b></summary>

访问 https://yunyi.rdzhvip.com/user ，用购买卡密时的账号登录即可查看。
</details>

<details>
<summary><b>Q: 改了配置不生效？</b></summary>

修改 `~/.openclaw/openclaw.json` 后，需要重启服务：

```bash
openclaw gateway restart
```
</details>

<details>
<summary><b>Q: 报错 "command not found: openclaw"？</b></summary>

Node.js 的全局路径可能不在系统 PATH 中：

```bash
export PATH="$(npm config get prefix)/bin:$PATH"
```

或者重新安装：`npm i -g openclaw@latest`
</details>

<details>
<summary><b>Q: 支持同时使用 Claude 和 Codex 吗？</b></summary>

支持！安装时选择"两个都有"，或者在配置文件中同时配置两个 provider。详见 [QUICKSTART.md](QUICKSTART.md)。
</details>

---

## 🛠️ 开发

```bash
git clone https://github.com/oscn2077/openclaw-desktop.git
cd openclaw-desktop
npm install

npm run dev          # 开发模式
npm run build:win    # 构建 Windows .exe
npm run build:mac    # 构建 macOS .dmg
npm run build:linux  # 构建 Linux AppImage
```

---

## 📄 许可证

[MIT License](LICENSE) © 2026 ApexYY

---

<div align="center">

**[快速上手](QUICKSTART.md)** · **[使用手册](USER-GUIDE.md)** · **[更新日志](CHANGELOG.md)** · **[额度查询](https://yunyi.rdzhvip.com/user)**

🦞 Made with ❤️ by ApexYY

</div>
