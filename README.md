# OpenClaw Desktop

🦞 OpenClaw 桌面版 — 一键部署，无脑上手。

## 开发

```bash
# 安装依赖
npm install

# 开发模式运行
npm run dev

# 打包
npm run build:win    # Windows .exe
npm run build:mac    # macOS .dmg
npm run build:linux  # Linux .AppImage
```

## 功能

- ✅ 环境自动检测（Node.js / OpenClaw）
- ✅ 一键安装 OpenClaw
- ✅ 图形化配置向导（模型 + 渠道）
- ✅ 支持官方 API 和中转 API
- ✅ Gateway 启停控制
- ✅ 内嵌 WebChat
- ✅ 日志查看

## 支持的模型

| 模型 | 官方 API | 中转 API |
|------|---------|---------|
| Claude (Opus/Sonnet) | ✅ | ✅ |
| OpenAI (GPT-5/Codex) | ✅ | ✅ |
| Google Gemini | ✅ | — |
| 智谱 GLM | ✅ | — |

## 支持的渠道

| 渠道 | 状态 |
|------|------|
| WebChat | ✅ 开箱即用 |
| Telegram | ✅ |
| Discord | ✅ |
| 飞书 | ✅ |
| 微信 | 🔜 即将支持 |
| 钉钉 | 🔜 即将支持 |
