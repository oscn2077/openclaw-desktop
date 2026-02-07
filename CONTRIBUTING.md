# 🤝 贡献指南

感谢你对 OpenClaw Desktop 的关注！欢迎任何形式的贡献。

## 如何贡献

### 报告 Bug

1. 先搜索 [Issues](https://github.com/oscn2077/openclaw-desktop/issues) 看看是否已有人报告
2. 如果没有，[创建新 Issue](https://github.com/oscn2077/openclaw-desktop/issues/new)，请包含：
   - 你的操作系统和版本
   - 复现步骤
   - 期望行为 vs 实际行为
   - 错误日志（如果有）

### 提交功能建议

在 [Issues](https://github.com/oscn2077/openclaw-desktop/issues) 中描述你想要的功能，说明使用场景和预期效果。

### 提交代码

1. **Fork** 本仓库
2. 创建你的分支：`git checkout -b feature/你的功能名`
3. 提交更改：`git commit -m 'feat: 添加某某功能'`
4. 推送分支：`git push origin feature/你的功能名`
5. 创建 **Pull Request**

### Commit 规范

请使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式（不影响功能）
refactor: 重构
test: 测试
chore: 构建/工具变更
```

## 开发环境

```bash
git clone https://github.com/oscn2077/openclaw-desktop.git
cd openclaw-desktop
npm install
npm run dev
```

## 项目结构

```
src/
├── main/          # Electron 主进程
└── renderer/      # Electron 渲染进程（UI）
```

## 行为准则

- 尊重每一位贡献者
- 保持友善和建设性的讨论
- 专注于技术问题本身

---

再次感谢你的贡献！🦞
