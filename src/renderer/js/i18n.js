// ── i18n - Internationalization ──
// All user-facing strings extracted here for future multi-language support

const i18n = {
  zh: {
    // App
    appName: 'OpenClaw Desktop',
    appTitle: '🦞 OpenClaw',

    // Sidebar
    navStatus: '状态',
    navModels: '模型',
    navChannels: '渠道',
    navChat: '对话',
    navLogs: '日志',
    navSettings: '设置',

    // Gateway status
    gatewayStopped: '已停止',
    gatewayStarting: '启动中...',
    gatewayRunning: '运行中',
    gatewayError: '错误',

    // Wizard
    wizardTitle: '🦞 欢迎使用 OpenClaw Desktop',
    wizardSubtitle: '让我们花 2 分钟完成初始设置',
    wizardStep1Title: '第 1 步：环境检测',
    wizardStep2Title: '第 2 步：配置 AI 模型',
    wizardStep3Title: '第 3 步：聊天渠道（可选）',
    wizardStep1Short: '环境检测',
    wizardStep2Short: '模型配置',
    wizardStep3Short: '渠道设置',
    stepOf: '步骤 {current}/{total}',

    // Environment check
    checkOS: '操作系统',
    checkNode: 'Node.js',
    checkOpenclaw: 'OpenClaw',
    nodeNotInstalled: '未安装',
    downloadNode: '下载 Node.js',
    needNode: '需要安装 Node.js (v18+)',
    openclawNotInstalled: '未安装 — 点击下方按钮安装',
    installOpenclaw: '一键安装 OpenClaw',
    installing: '安装中...',
    installSuccess: '安装成功',
    installFailed: '安装失败',
    retryInstall: '重试安装',

    // Buttons
    nextStep: '下一步',
    prevStep: '上一步',
    finish: '🚀 完成设置',
    skipFinish: '跳过，直接开始',
    start: '启动',
    stop: '停止',
    restart: '重启',
    save: '保存',
    cancel: '取消',
    add: '添加',
    delete: '删除',
    reload: '重新加载',
    format: '格式化',
    close: '关闭',
    copy: '复制',
    copied: '已复制！',
    testConnection: '测试连接',
    testing: '测试中...',
    openInBrowser: '在浏览器中打开',
    copyDiagnostics: '📋 复制诊断信息',

    // Status page
    statusTitle: '📊 系统状态',
    statusGateway: 'Gateway',
    statusPrimaryModel: '主模型',
    statusFallbackChain: 'Fallback 链',
    statusChannels: '聊天渠道',
    statusWebChat: 'WebChat',
    statusProviders: 'Providers',
    statusSystemInfo: '系统信息',
    statusUptime: '运行时间',
    statusGatewayLogs: 'Gateway 日志（最近 50 行）',
    openWebChat: '打开网页聊天 →',
    notConfigured: '未配置',
    none: '无',
    detecting: '检测中...',
    providerList: 'Provider 列表',
    noProviderHint: '暂无 Provider，请前往模型管理页面添加',

    // System info
    nodeVersion: 'Node.js 版本',
    openclawVersion: 'OpenClaw 版本',
    osInfo: '操作系统',
    platform: '平台',
    uptimeLabel: '运行时间',
    uptimeDays: '{d}天 {h}小时 {m}分钟',
    uptimeHours: '{h}小时 {m}分钟',
    uptimeMinutes: '{m}分钟',
    diagnosticsCopied: '诊断信息已复制到剪贴板',

    // Models page
    modelsTitle: '🧠 模型管理',
    addProvider: '+ 添加 Provider',
    currentModelConfig: '当前模型配置',
    primaryModel: '主模型',
    fallbackChain: 'Fallback 链',
    noProviderAdd: '暂无 Provider，点击右上角添加',
    notConfiguredYet: '尚未配置，请先完成初始设置',
    setPrimary: '设为主模型',
    providerIdLabel: 'Provider ID',
    providerIdPlaceholder: '例如: my-openai',
    providerIdHelp: '唯一标识符，只能用英文、数字和连字符',
    apiFormatLabel: 'API 格式',
    baseUrlLabel: 'Base URL',
    apiKeyLabel: 'API Key',
    apiKeyPlaceholder: '你的 API Key / 卡密',
    setPrimaryCheckbox: '设为主模型 Provider',
    defaultModelId: '默认模型 ID',
    defaultModelIdPlaceholder: '例如: claude-opus-4-6',
    defaultModelIdHelp: '设为主模型时需要填写',
    providerIdExists: 'Provider ID 已存在',
    providerIdRequired: '请填写 Provider ID',
    providerIdInvalid: 'Provider ID 只能包含英文、数字和连字符',
    baseUrlRequired: '请填写 Base URL',
    apiKeyRequired: '请填写 API Key',
    providerAdded: 'Provider 已添加，需重启 Gateway 生效',
    providerDeleted: 'Provider 已删除，需重启 Gateway 生效',
    primarySwitched: '主模型已切换为 {model}，需重启 Gateway 生效',
    addFailed: '添加失败: {error}',
    deleteFailed: '删除失败: {error}',
    switchFailed: '切换失败: {error}',
    loadModelsFailed: '加载模型配置失败: {error}',
    enterModelId: '请输入该 Provider 的模型 ID（例如 claude-opus-4-6）:',

    // Confirm dialogs
    confirmDeleteProvider: '确定删除 Provider "{id}"？此操作不可撤销。',
    confirmDeleteChannel: '确定删除 {name} 渠道？此操作不可撤销。',

    // Channels page
    channelsTitle: '💬 渠道管理',
    addChannel: '+ 添加渠道',
    noChannelHint: '暂无外部渠道，点击右上角添加',
    channelType: '渠道类型',
    botToken: 'Bot Token',
    botTokenPlaceholder: '你的 Bot Token',
    telegramHelp: '从 @BotFather 获取',
    discordHelp: '从 Discord Developer Portal 获取',
    allowedUsers: '允许的用户 (可选)',
    allowedUsersPlaceholder: '用户ID，多个用逗号分隔',
    allowedUsersHelp: '留空则所有人可用',
    allUsers: '所有人',
    builtIn: '内置',
    alwaysAvailable: '始终可用',
    channelAdded: '{name} 渠道已添加，需重启 Gateway 生效',
    channelDeleted: '{name} 渠道已删除，需重启 Gateway 生效',
    channelExists: '{name} 已配置，请先删除再重新添加',
    tokenRequired: '请填写 Bot Token',
    loadChannelsFailed: '加载渠道配置失败: {error}',

    // Chat page
    chatTitle: '🗨️ 对话',
    chatConnected: '已连接',
    chatDisconnected: '未连接',
    chatConnecting: '连接中...',
    chatLoadFailed: '无法加载 WebChat: {error}',
    chatOpenFailed: '无法打开 WebChat: {error}',

    // Logs page
    logsTitle: '📋 日志',

    // Settings page
    settingsTitle: '⚙️ 设置',
    advancedMode: '高级模式：配置文件编辑器',
    advancedHint: '直接编辑 openclaw.json，修改后需重启 Gateway 生效',
    jsonError: 'JSON 格式错误: {error}',
    jsonSaveError: 'JSON 格式错误，无法保存: {error}',
    configSaved: '配置已保存，需重启 Gateway 生效',
    configSaveFailed: '保存失败: {error}',
    configLoadFailed: '加载配置文件失败: {error}',
    aboutTitle: '关于',
    configFile: '配置文件',
    workDir: '工作目录',
    saveConfig: '保存配置',

    // Wizard model setup
    modelHint: '至少配置一个模型即可开始使用',
    claudeLabel: 'Claude (Anthropic)',
    codexLabel: 'Codex (OpenAI)',
    geminiLabel: 'Google Gemini',
    glmLabel: '智谱 GLM',
    accessType: '接入方式',
    proxyApi: '中转 API',
    officialApi: '官方 API',
    proxyUrl: '中转地址',
    proxyHelpDomestic: '国内用 yunyi.rdzhvip.com/claude，国外用 yunyi.cfd/claude',
    proxyHelpCodex: '国内用 yunyi.rdzhvip.com/codex，国外用 yunyi.cfd/codex',
    apiKeyKami: 'API Key（卡密）',
    kamiPlaceholder: '你的卡密',
    kamiHelpCodex: 'Claude 和 Codex 的卡密不互通，看你买的是哪个',
    defaultModel: '默认模型',
    getApiKey: '获取免费 API Key →',
    getGlmApiKey: '获取 API Key →',

    // Wizard channel setup
    channelHint: '先跳过也行，网页版聊天开箱即用',
    comingSoon: '即将支持',

    // Wizard validation
    claudeNoKey: 'Claude 已启用但未填写 API Key',
    claudeNoProxy: 'Claude 中转模式需要填写中转地址',
    codexNoKey: 'Codex 已启用但未填写 API Key',
    codexNoProxy: 'Codex 中转模式需要填写中转地址',
    geminiNoKey: 'Gemini 已启用但未填写 API Key',
    glmNoKey: 'GLM 已启用但未填写 API Key',
    needOneModel: '请至少配置一个 AI 模型',
    configSaving: '配置已保存，正在启动 Gateway...',
    configSaveFailedWizard: '保存配置失败: {error}',

    // Test connection
    testSuccess: '✅ 连接成功！API Key 有效',
    testFailed: '❌ 连接失败: {error}',
    testNoModel: '请先启用并填写至少一个模型的 API Key',

    // Gateway control
    startingGateway: '启动中...',
    gatewayStartFailed: 'Gateway 启动失败: {error}',
    gatewayStopping: 'Gateway 已停止',
    gatewayStopFailed: '停止失败: {error}',
    gatewayRestarting: '正在重启 Gateway...',
    gatewayRestarted: 'Gateway 已重启',
    gatewayRestartFailed: '重启失败: {error}',

    // Tooltips
    tooltipStatus: '查看 Gateway 运行状态和系统信息',
    tooltipModels: '管理 AI 模型 Provider 和 Fallback 链',
    tooltipChannels: '配置 Telegram、Discord 等聊天渠道',
    tooltipChat: '内置 WebChat 对话界面',
    tooltipLogs: '查看 Gateway 实时日志',
    tooltipSettings: '编辑配置文件和高级设置',

    // Loading
    loading: '加载中...',
    saving: '保存中...',
    starting: '启动中...',
    stopping: '停止中...',
    restarting: '重启中...',
  },
};

// Current language
let currentLang = 'zh';

// Get translated string with optional interpolation
function t(key, params = {}) {
  const lang = i18n[currentLang] || i18n.zh;
  let str = lang[key] || key;
  for (const [k, v] of Object.entries(params)) {
    str = str.replace(`{${k}}`, v);
  }
  return str;
}

// Set language
function setLanguage(lang) {
  if (i18n[lang]) currentLang = lang;
}
