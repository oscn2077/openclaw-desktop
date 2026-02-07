# OpenClaw Web Panel

适用于 Linux 服务器（无 GUI 环境）的 Web 管理面板，功能和 Electron 桌面版一致。

## 快速开始

```bash
cd web-panel
npm install
npm start
```

然后在浏览器打开 `http://localhost:5338`

## 功能

- **📊 状态页** — Gateway 运行状态、模型信息、系统信息
- **🧙 配置向导** — 三步完成初始配置（选产品 → 选节点 → 选渠道）
- **🧠 模型管理** — 添加/删除 Provider，切换主模型
- **💬 渠道管理** — 添加/删除 Telegram、Discord 渠道
- **⚙️ 配置编辑器** — 直接编辑 openclaw.json，JSON 验证 + 格式化
- **📋 日志查看** — Gateway 日志，支持自动刷新

## 技术细节

- **后端**: Express.js，端口 5338
- **前端**: 纯 HTML/CSS/JS，无框架依赖
- **安全**: 默认只监听 `127.0.0.1`，不暴露到公网
- **配置**: 读写 `~/.openclaw/openclaw.json`
- **Gateway 控制**: 通过 `openclaw gateway start/stop/restart/status` 命令

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OPENCLAW_PANEL_PORT` | `5338` | Web 面板端口 |
| `OPENCLAW_PANEL_BIND` | `127.0.0.1` | 绑定地址 |

## API 路由

```
GET  /api/status          — Gateway 状态 + 系统信息
POST /api/gateway/start   — 启动 Gateway
POST /api/gateway/stop    — 停止 Gateway
POST /api/gateway/restart — 重启 Gateway
GET  /api/config          — 读取配置（JSON 对象）
POST /api/config          — 写入配置（JSON 对象）
GET  /api/config/raw      — 读取配置（原始文本）
POST /api/config/raw      — 写入配置（原始文本）
POST /api/config/generate — 从向导数据生成配置
GET  /api/logs            — 读取 Gateway 日志
```

## 与安装脚本集成

在 Linux 服务器上（无 DISPLAY），安装脚本会自动安装并启动 Web 面板：

```bash
bash install-apexyy.sh
# 安装完成后，Web 面板自动运行在 http://localhost:5338
```
