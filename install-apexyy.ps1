# OpenClaw ApexYY 专版 — Windows 安装脚本
# 用法: 右键以管理员身份运行 PowerShell，粘贴以下命令:
#   irm https://raw.githubusercontent.com/oscn2077/openclaw-desktop/main/install-apexyy.ps1 | iex
#
# 或者手动下载后运行:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   .\install-apexyy.ps1
#
# 参数 (可选):
#   -ClaudeKey "你的卡密"
#   -CodexKey "你的卡密"
#   -Node 1          # 1=国内 2=国外
#   -TelegramToken "bot_token"

param(
    [string]$ClaudeKey = "",
    [string]$CodexKey = "",
    [int]$Node = 1,
    [string]$Primary = "",
    [string]$TelegramToken = "",
    [string]$DiscordToken = ""
)

$ErrorActionPreference = "Stop"

function Info($msg) { Write-Host "[✓] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Err($msg)  { Write-Host "[✗] $msg" -ForegroundColor Red }
function Step($msg) { Write-Host "`n>>> $msg" -ForegroundColor Cyan }

# ========== 节点 ==========
$Nodes = @{
    1 = "https://yunyi.rdzhvip.com"
    2 = "https://yunyi.cfd"
    3 = "https://cdn1.yunyi.cfd"
    4 = "https://cdn2.yunyi.cfd"
    5 = "http://47.99.42.193"
    6 = "http://47.97.100.10"
}
$NodeNames = @{
    1 = "国内主节点"
    2 = "CF国外节点1"
    3 = "CF国外节点2"
    4 = "CF国外节点3"
    5 = "备用节点1"
    6 = "备用节点2"
}

# ========== 检查 Node.js ==========
Step "检查 Node.js"
$nodeVer = $null
try { $nodeVer = (node -v 2>$null) } catch {}

if ($nodeVer) {
    $major = [int]($nodeVer -replace 'v(\d+)\..*', '$1')
    if ($major -ge 22) {
        Info "Node.js $nodeVer"
    } else {
        Warn "Node.js $nodeVer 版本过低，需要 22+"
        $nodeVer = $null
    }
}

if (-not $nodeVer) {
    Warn "未检测到 Node.js 22+，正在安装..."
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    } else {
        # 没有 winget，直接下载 Node.js 安装包
        Warn "未找到 winget，尝试直接下载 Node.js..."
        $nodeUrl = "https://nodejs.org/dist/v22.15.0/node-v22.15.0-x64.msi"
        $nodeMsi = Join-Path $env:TEMP "node-install.msi"
        try {
            Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing
            Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /qn" -Wait -NoNewWindow
            Remove-Item $nodeMsi -Force -ErrorAction SilentlyContinue
        } catch {
            Err "自动下载失败，请手动安装 Node.js: https://nodejs.org"
            Start-Process "https://nodejs.org"
            exit 1
        }
    }
    # 刷新 PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Info "Node.js $(node -v)"
}

# ========== 检查 Git ==========
Step "检查 Git"
$hasGit = Get-Command git -ErrorAction SilentlyContinue
if (-not $hasGit) {
    Warn "未检测到 Git，正在安装..."
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        winget install Git.Git --accept-package-agreements --accept-source-agreements
    } else {
        Warn "未找到 winget，尝试直接下载 Git..."
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
        $gitExe = Join-Path $env:TEMP "git-install.exe"
        try {
            Invoke-WebRequest -Uri $gitUrl -OutFile $gitExe -UseBasicParsing
            Start-Process $gitExe -ArgumentList "/VERYSILENT /NORESTART" -Wait -NoNewWindow
            Remove-Item $gitExe -Force -ErrorAction SilentlyContinue
        } catch {
            Err "自动下载失败，请手动安装 Git: https://git-scm.com"
            Start-Process "https://git-scm.com"
            exit 1
        }
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}
Info "Git $(git --version 2>$null)"

# ========== 安装 OpenClaw ==========
Step "安装 OpenClaw"
# 配置国内镜像
npm config set registry https://registry.npmmirror.com/ 2>$null
$env:SHARP_IGNORE_GLOBAL_LIBVIPS = "1"
npm install -g openclaw@latest 2>&1 | Select-Object -Last 3
Info "OpenClaw $(openclaw --version 2>$null)"

# ========== 初始化 ==========
Step "初始化 OpenClaw"
openclaw onboard --non-interactive --accept-risk --mode local --auth-choice skip `
    --gateway-port 18789 --gateway-bind loopback --gateway-auth token `
    --skip-channels --skip-skills --skip-health --skip-ui --install-daemon 2>&1 | Select-Object -Last 3

# ========== 交互式输入 (如果没传参数) ==========
if (-not $ClaudeKey -and -not $CodexKey) {
    Step "选择产品线"
    Write-Host ""
    Write-Host "  Claude 和 Codex 是独立产品线，卡密不互通" -ForegroundColor White
    Write-Host ""
    Write-Host "    1) 只有 Claude 的卡密"
    Write-Host "    2) 只有 Codex (OpenAI) 的卡密"
    Write-Host "    3) 两个都有"
    Write-Host ""
    $choice = Read-Host "[?] 请选择 [1-3] (默认 1)"
    if (-not $choice) { $choice = "1" }

    switch ($choice) {
        "1" {
            $ClaudeKey = Read-Host "[?] 请输入 Claude 卡密"
            if (-not $ClaudeKey) { Err "卡密不能为空"; exit 1 }
        }
        "2" {
            $CodexKey = Read-Host "[?] 请输入 Codex 卡密"
            if (-not $CodexKey) { Err "卡密不能为空"; exit 1 }
        }
        "3" {
            $ClaudeKey = Read-Host "[?] 请输入 Claude 卡密"
            if (-not $ClaudeKey) { Err "Claude 卡密不能为空"; exit 1 }
            $CodexKey = Read-Host "[?] 请输入 Codex 卡密"
            if (-not $CodexKey) { Err "Codex 卡密不能为空"; exit 1 }
        }
    }

    # 选节点
    Step "选择 API 节点"
    Write-Host "  国内用户推荐 1，海外用户推荐 2-4" -ForegroundColor White
    foreach ($i in 1..6) {
        Write-Host "    $i) $($NodeNames[$i])  $($Nodes[$i])"
    }
    $nodeChoice = Read-Host "[?] 请选择 [1-6] (默认 1)"
    if ($nodeChoice) { $Node = [int]$nodeChoice }
}

$BaseUrl = $Nodes[$Node]
if (-not $BaseUrl) { $BaseUrl = $Nodes[1] }
Info "节点: $($NodeNames[$Node]) ($BaseUrl)"

# ========== 确定主模型 ==========
if (-not $Primary) {
    if ($ClaudeKey) { $Primary = "claude-opus-4-5" }
    else { $Primary = "gpt-5.2" }
}

if ($Primary -match "^gpt|^o3|^o4") {
    $PrimaryRef = "apexyy-codex/$Primary"
} else {
    $PrimaryRef = "apexyy-claude/$Primary"
}

# ========== 写入配置 ==========
Step "写入 ApexYY 模型配置"

$configPath = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# 确保 models.providers 存在
if (-not $config.models) { $config | Add-Member -NotePropertyName "models" -NotePropertyValue @{} }
if (-not $config.models.providers) { $config.models | Add-Member -NotePropertyName "providers" -NotePropertyValue @{} }
$config.models.mode = "merge"

# 确保 agents.defaults 存在
if (-not $config.agents) { $config | Add-Member -NotePropertyName "agents" -NotePropertyValue @{} }
if (-not $config.agents.defaults) { $config.agents | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{} }

# Claude provider
if ($ClaudeKey) {
    $config.models.providers | Add-Member -NotePropertyName "apexyy-claude" -NotePropertyValue @{
        baseUrl = "$BaseUrl/claude"
        apiKey = $ClaudeKey
        auth = "api-key"
        api = "anthropic-messages"
        headers = @{}
        authHeader = $false
        models = [System.Collections.ArrayList]@()
    } -Force
    Info "Claude provider 已配置"
}

# Codex provider
if ($CodexKey) {
    $config.models.providers | Add-Member -NotePropertyName "apexyy-codex" -NotePropertyValue @{
        baseUrl = "$BaseUrl/codex"
        apiKey = $CodexKey
        auth = "api-key"
        api = "openai-responses"
        headers = @{}
        authHeader = $false
        models = @(
            @{
                id = "gpt-5.2"; name = "GPT 5.2"; reasoning = $true
                input = @("text", "image")
                cost = @{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }
                contextWindow = 128000; maxTokens = 32768
            },
            @{
                id = "gpt-5.3-codex"; name = "GPT 5.3 Codex"; reasoning = $true
                input = @("text", "image")
                cost = @{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }
                contextWindow = 128000; maxTokens = 32768
            }
        )
    } -Force
    Info "Codex provider 已配置"
}

# 主模型 + fallbacks
$fallbacks = @()
if ($ClaudeKey) {
    $fallbacks += @("apexyy-claude/claude-opus-4-5", "apexyy-claude/claude-opus-4-6", "apexyy-claude/claude-sonnet-4-5")
}
if ($CodexKey) {
    $fallbacks += @("apexyy-codex/gpt-5.2", "apexyy-codex/gpt-5.3-codex")
}
$fallbacks = $fallbacks | Where-Object { $_ -ne $PrimaryRef }

$config.agents.defaults.model = @{
    primary = $PrimaryRef
    fallbacks = $fallbacks
}

$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
Info "主模型: $PrimaryRef"
if ($fallbacks.Count -gt 0) { Info "Failover: $($fallbacks -join ' → ')" }

# ========== 渠道 ==========
if ($TelegramToken) {
    openclaw channels add --channel telegram --token $TelegramToken 2>&1 | Out-Null
    Info "Telegram 渠道已添加"
}
if ($DiscordToken) {
    openclaw channels add --channel discord --token $DiscordToken 2>&1 | Out-Null
    Info "Discord 渠道已添加"
}

# ========== 启动 ==========
Step "启动 Gateway"
try { openclaw gateway restart 2>&1 | Out-Null } catch {}
try { openclaw gateway start 2>&1 | Out-Null } catch {}
Start-Sleep -Seconds 2

Step "安装完成! 🎉"
Write-Host ""
Write-Host "  常用命令:" -ForegroundColor White
Write-Host "    openclaw gateway status    — 查看状态"
Write-Host "    openclaw gateway restart   — 重启"
Write-Host ""
Write-Host "  WebChat: http://localhost:18789" -ForegroundColor White
Write-Host "  额度查询: https://yunyi.rdzhvip.com/user" -ForegroundColor White
Write-Host ""
