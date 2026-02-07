# 📋 Changelog

本项目的所有重要变更都会记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

---

## [0.5.0] — 2026-02-08

### 新增
- 📦 **模型管理** — 可视化界面切换和管理 AI 模型
- 📡 **渠道管理** — 在界面中添加/删除 Telegram、Discord 等消息渠道
- 📊 **状态页** — 实时查看 Gateway 运行状态
- ⚙️ **设置编辑器** — 图形化编辑 openclaw.json 配置
- 🔔 **Toast 通知** — 操作反馈通知
- 📖 **USER-GUIDE.md** — 面向零基础用户的完整使用手册（中文）
- 📖 **QUICKSTART.md** — 完善快速上手指南，补充 Windows PowerShell 参数表、静默安装变量表、常见错误解决方案

## [0.4.0] — 2026-02-07

### 修复
- 🔧 **nvm 环境兼容** — 检测 nvm 环境并优先通过 nvm 升级 Node.js
- 🔧 **Windows winget 回退** — winget 不可用时自动回退到直接下载安装
- 🐛 安装脚本 6 个 bug 修复（配置验证、单 provider 限制等）
- 🐛 修复 restart-gateway IPC handler 实际未重启的问题

## [0.3.0] — 2026-02-06

### 变更
- 🏷️ **品牌重命名** — 从通用版重命名为 ApexYY 专版
- 🗑️ 移除通用安装脚本，统一使用 ApexYY 专版脚本
- 🌐 预置 6 个 ApexYY 节点 + 5 个模型 + failover 机制

## [0.2.0] — 2026-02-05

### 新增
- 📜 **Linux/macOS 安装脚本** — 交互式 + 静默安装
- 📜 **Windows PowerShell 安装脚本** — 完整平台覆盖
- 🔧 使用 openclaw CLI 原生命令配置，不再手拼 JSON
- 📖 添加 QUICKSTART.md 快速上手指南

## [0.1.0] — 2026-02-04

### 新增
- 🎉 **初始版本** — Electron 应用骨架
- 🖥️ 配置向导界面
- 🔌 Gateway 控制（启动/停止/重启）
- 📦 基础项目结构（main + renderer）

---

[0.5.0]: https://github.com/oscn2077/openclaw-desktop/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/oscn2077/openclaw-desktop/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/oscn2077/openclaw-desktop/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/oscn2077/openclaw-desktop/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/oscn2077/openclaw-desktop/releases/tag/v0.1.0
