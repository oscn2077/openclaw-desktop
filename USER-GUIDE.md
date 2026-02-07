# 🦞 OpenClaw 使用手册 — ApexYY 专版

> 这是一份写给完全不懂技术的朋友的使用手册。
> 每一步都可以直接复制粘贴，跟着做就行。

---

## 📋 目录

1. [你需要准备什么](#1-你需要准备什么)
2. [安装（分平台）](#2-安装)
   - [Windows 电脑](#windows-电脑)
   - [Mac 电脑](#mac-电脑)
   - [Linux 电脑](#linux-电脑)
3. [开始使用](#3-开始使用)
4. [日常操作](#4-日常操作)
5. [常见问题](#5-常见问题)
6. [出了问题怎么办](#6-出了问题怎么办)

---

## 1. 你需要准备什么

在开始之前，你需要有：

- ✅ **一台电脑**（Windows、Mac 或 Linux 都行）
- ✅ **能上网**
- ✅ **你的卡密**（就是一串字符，买的时候会给你）

> 💡 **什么是卡密？**
> 卡密就像是一把钥匙，用来证明你有权使用 AI 服务。买了之后会给你一串字符，比如 `sk-xxxxxxxxxxxx`。

> 💡 **Claude 和 Codex 是什么？**
> 这是两个不同的 AI 产品，就像可口可乐和百事可乐一样，是两个牌子。
> - **Claude** — Anthropic 公司的 AI（推荐，更聪明）
> - **Codex** — OpenAI 公司的 AI（GPT 系列）
>
> 你买的是哪个的卡密，就用哪个。**两个的卡密不能混用！**

---

## 2. 安装

选择你的电脑类型，跟着做就行：

---

### Windows 电脑

#### 方法一：一键安装（推荐，最简单）

**第 1 步：打开 PowerShell**

1. 按键盘上的 `Win` 键（就是左下角那个 Windows 图标的键）
2. 输入 `PowerShell`
3. 看到 "Windows PowerShell"，**右键点它**，选 **"以管理员身份运行"**
4. 如果弹出提示问你"是否允许"，点 **"是"**

> ⚠️ 一定要用 **管理员身份** 打开！不然后面可能会报错。

**第 2 步：允许运行脚本**

在打开的蓝色窗口里，复制粘贴下面这行，然后按回车：

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

如果问你确认，输入 `Y` 然后按回车。

**第 3 步：运行安装命令**

复制粘贴下面这行，按回车：

```powershell
irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 | iex
```

然后跟着屏幕上的提示操作：
- 选你买的是 Claude 还是 Codex（输入数字 1、2 或 3）
- 输入你的卡密
- 选节点（国内用户选 1，海外用户选 2）

等它跑完，看到 **"安装完成! 🎉"** 就成功了！

#### 方法二：如果方法一不行

如果上面的命令报错，试试先手动下载再运行：

```powershell
irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 -OutFile install.ps1
.\install.ps1
```

---

### Mac 电脑

**第 1 步：打开终端**

1. 按 `Command + 空格`（打开 Spotlight 搜索）
2. 输入 `终端` 或 `Terminal`
3. 按回车打开它

> 终端就是一个可以输入命令的窗口，别怕，跟着复制粘贴就行。

**第 2 步：运行安装命令**

复制粘贴下面这行，按回车：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.sh)
```

然后跟着屏幕上的提示操作：
- 如果问你要不要安装 Node.js，输入 `Y` 按回车
- 选你买的是 Claude 还是 Codex
- 输入你的卡密
- 选节点（国内选 1，海外选 2）
- 选消息渠道（不知道选什么就选 7 跳过，以后再加）

等它跑完，看到 **"安装完成! 🎉"** 就成功了！

> 💡 如果提示要输入电脑密码，就输入你开机时用的密码（输入时屏幕上不会显示，这是正常的，输完按回车就行）。

---

### Linux 电脑

#### 方法一：交互式安装（推荐）

打开终端，复制粘贴：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.sh)
```

跟着提示操作就行，和 Mac 一样。

#### 方法二：静默安装（一行搞定）

如果你只有 Claude 卡密：

```bash
AY_CLAUDE_KEY=把这里换成你的卡密 bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

如果你只有 Codex 卡密：

```bash
AY_CODEX_KEY=把这里换成你的卡密 bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

如果两个都有：

```bash
AY_CLAUDE_KEY=你的Claude卡密 AY_CODEX_KEY=你的Codex卡密 bash <(curl -fsSL https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy-silent.sh)
```

> 💡 **注意：** 把 `把这里换成你的卡密` 替换成你真正的卡密，不要带引号。

---

## 3. 开始使用

### 打开聊天界面

安装完成后，打开浏览器（Chrome、Edge、Safari 都行），在地址栏输入：

```
http://localhost:18789
```

> 💡 **localhost 是什么？** 就是"你自己的电脑"的意思。这个地址只有你自己能访问，别人看不到。

你会看到一个聊天界面，这就是 **WebChat**。在下面的输入框里打字，就可以和 AI 对话了！

### 第一次对话

试试输入：

```
你好，请介绍一下你自己
```

如果 AI 回复了，说明一切正常！🎉

### 如果打不开怎么办？

1. 确认安装时没有报错
2. 试试重启一下（看下面的"日常操作"部分）
3. 如果还是不行，看"出了问题怎么办"部分

---

## 4. 日常操作

### 怎么启动？

如果电脑重启了，或者 AI 没反应了，需要重新启动。

**Windows：** 打开 PowerShell，输入：
```powershell
openclaw gateway start
```

**Mac / Linux：** 打开终端，输入：
```bash
openclaw gateway start
```

> 💡 正常情况下安装时已经设置了开机自动启动，不需要手动操作。

### 怎么重启？

改了设置之后，或者 AI 反应不对了，重启一下：

**所有平台通用：**
```bash
openclaw gateway restart
```

### 怎么停止？

不想用了，想关掉：

```bash
openclaw gateway stop
```

### 怎么看运行状态？

想知道现在是不是在运行：

```bash
openclaw gateway status
```

如果显示 `running` 或 `online`，就是正常运行中。

### 怎么查额度？

打开浏览器，访问：

**👉 https://yunyi.rdzhvip.com/user**

用你买卡密时的账号登录，就能看到剩余额度。

---

## 5. 常见问题

### 怎么换模型？

> 模型就是 AI 的"大脑"，不同模型有不同的能力。

**可选的模型：**

| 模型名称 | 说明 | 适合 |
|----------|------|------|
| claude-opus-4-6 | Claude 最强版 | 复杂任务、写代码 |
| claude-opus-4-5 | Claude 强力版 | 日常使用（默认） |
| claude-sonnet-4-5 | Claude 均衡版 | 速度快、省额度 |
| gpt-5.2 | GPT 最新版 | 日常使用 |
| gpt-5.3-codex | GPT 代码版 | 写代码 |

**怎么换：**

1. 找到配置文件：
   - **Windows：** `C:\Users\你的用户名\.openclaw\openclaw.json`
   - **Mac / Linux：** `~/.openclaw/openclaw.json`

2. 用记事本（或任何文本编辑器）打开它

3. 找到这一行：
   ```
   "primary": "apexyy-claude/claude-opus-4-5"
   ```

4. 把 `claude-opus-4-5` 换成你想要的模型名称，比如：
   ```
   "primary": "apexyy-claude/claude-opus-4-6"
   ```

   > ⚠️ Claude 的模型前面是 `apexyy-claude/`，Codex 的模型前面是 `apexyy-codex/`

5. 保存文件

6. 重启：
   ```bash
   openclaw gateway restart
   ```

### 怎么换节点？

> 节点就是 AI 服务的"入口"。如果觉得慢，可以换一个试试。

**可选的节点：**

| 编号 | 地址 | 说明 |
|------|------|------|
| 1 | yunyi.rdzhvip.com | 国内主节点（推荐国内用户） |
| 2 | yunyi.cfd | 国外节点（推荐海外用户） |
| 3 | cdn1.yunyi.cfd | 国外备用 |
| 4 | cdn2.yunyi.cfd | 国外备用 |
| 5 | 47.99.42.193 | IP 直连备用 |
| 6 | 47.97.100.10 | IP 直连备用 |

**怎么换：**

1. 打开配置文件（同上）
2. 找到 `baseUrl` 那一行，比如：
   ```
   "baseUrl": "https://yunyi.rdzhvip.com/claude"
   ```
3. 把域名部分换掉，比如换成国外节点：
   ```
   "baseUrl": "https://yunyi.cfd/claude"
   ```
   > ⚠️ 注意：后面的 `/claude` 或 `/codex` 不要改！只改域名部分。
4. 保存，然后重启：
   ```bash
   openclaw gateway restart
   ```

### 怎么添加 Telegram 机器人？

如果你想通过 Telegram 和 AI 聊天：

1. 在 Telegram 里找 `@BotFather`，发送 `/newbot`，按提示创建一个机器人
2. 你会得到一个 Token（一串数字和字母）
3. 在终端运行：
   ```bash
   openclaw channels add --channel telegram --token 你的Token
   openclaw gateway restart
   ```
4. 在 Telegram 里找到你的机器人，发消息就能聊了

### 怎么添加 Discord 机器人？

1. 去 [Discord 开发者后台](https://discord.com/developers/applications) 创建一个应用
2. 在 Bot 页面获取 Token
3. 在终端运行：
   ```bash
   openclaw channels add --channel discord --token 你的Token
   openclaw gateway restart
   ```

---

## 6. 出了问题怎么办

### 🔴 安装时报错："npm 不是内部或外部命令"

**原因：** Node.js 没装好。

**解决：**
1. 去 https://nodejs.org 下载安装 Node.js（选 LTS 版本）
2. 安装时一路点"下一步"
3. **关掉 PowerShell，重新打开**，再试一次

### 🔴 安装时报错："权限不够" 或 "Permission denied"

**Windows 解决：**
- 确保用 **管理员身份** 打开 PowerShell（右键 → 以管理员身份运行）

**Mac / Linux 解决：**
- 在命令前面加 `sudo`，比如：
  ```bash
  sudo npm install -g openclaw@latest
  ```
- 会要求输入密码，输入你的开机密码（不会显示在屏幕上）

### 🔴 安装时报错："apt lock" 或 "dpkg lock"

**原因：** 系统正在后台更新软件，锁住了。

**解决：** 等几分钟再试，或者运行：
```bash
sudo killall apt apt-get 2>/dev/null
sudo rm /var/lib/dpkg/lock-frontend 2>/dev/null
sudo rm /var/lib/apt/lists/lock 2>/dev/null
sudo dpkg --configure -a
```
然后重新运行安装命令。

### 🔴 安装时报错："nvm" 相关错误

**原因：** 你之前装过 nvm（Node 版本管理器），和系统的 Node.js 冲突了。

**解决：**
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22
nvm alias default 22
```
然后重新运行安装命令。

### 🔴 打开 localhost:18789 显示"无法访问"

**可能原因 1：** 服务没启动

**解决：**
```bash
openclaw gateway start
```

**可能原因 2：** 端口被占用

**解决：**
```bash
openclaw gateway status
```
看看有没有报错信息。如果端口被占了，可以换一个端口：
1. 打开配置文件
2. 找到 `"port": 18789`
3. 换成别的数字，比如 `"port": 28789`
4. 保存，重启
5. 然后用 `http://localhost:28789` 访问

### 🔴 AI 回复很慢或者没反应

1. **检查网络：** 确保你能上网
2. **检查额度：** 去 https://yunyi.rdzhvip.com/user 看看额度是不是用完了
3. **换节点：** 可能当前节点不稳定，试试换一个（参考上面"怎么换节点"）
4. **重启试试：**
   ```bash
   openclaw gateway restart
   ```

### 🔴 报错 "API key invalid" 或 "Unauthorized"

**原因：** 卡密不对，或者过期了。

**解决：**
1. 检查卡密有没有复制完整（前后不要有空格）
2. 确认 Claude 的卡密用在 Claude 上，Codex 的卡密用在 Codex 上（不能混用！）
3. 去 https://yunyi.rdzhvip.com/user 确认卡密状态

### 🔴 报错 "ECONNREFUSED" 或 "连接被拒绝"

**原因：** 连不上 API 节点。

**解决：**
1. 检查网络连接
2. 换一个节点试试（参考"怎么换节点"）
3. 如果在国内，用节点 1（yunyi.rdzhvip.com）
4. 如果在国外，用节点 2（yunyi.cfd）

### 🔴 Windows 报错 "无法加载文件...因为在此系统上禁止运行脚本"

**解决：** 打开管理员 PowerShell，运行：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
输入 `Y` 确认，然后重新运行安装命令。

### 🔴 Mac 报错 "command not found: openclaw"

**原因：** 安装路径没加到系统路径里。

**解决：**
```bash
# 如果用的 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# 如果用的 Homebrew
export PATH="/opt/homebrew/bin:$PATH"

# 验证
openclaw --version
```

如果上面的都不行，试试重新安装：
```bash
npm install -g openclaw@latest
```

---

## 🆘 还是搞不定？

1. **截图报错信息** — 把报错的那个红色文字截图
2. **联系卖家** — 把截图发给卖你卡密的人
3. **说明你的系统** — 告诉对方你用的是 Windows / Mac / Linux

---

## 📝 小贴士

- 💡 **改了任何设置后，都要重启：** `openclaw gateway restart`
- 💡 **不确定状态，就看一下：** `openclaw gateway status`
- 💡 **额度快用完了，去充值：** https://yunyi.rdzhvip.com/user
- 💡 **想省额度？** 换成 `claude-sonnet-4-5`，速度快还省钱
- 💡 **配置文件改坏了？** 重新运行安装脚本，会自动覆盖

---

> 📅 最后更新：2026-02-08
> 📦 仓库：https://github.com/oscn2077/openclaw-desktop
