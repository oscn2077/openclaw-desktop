// ── OpenClaw Web Panel — Frontend ──
// Pure JS, no frameworks

// ── State ──
let currentPage = 'status';
let currentConfig = null;
let wizardProduct = null;
let wizardNode = 'domestic';
let wizardChannels = {};
let logRefreshTimer = null;

// ── API Helper ──
async function api(method, url, body) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(url, opts);
  return res.json();
}

// ── Init ──
document.addEventListener('DOMContentLoaded', async () => {
  await loadStatus();
  // Check if config exists, if not show wizard
  const configRes = await api('GET', '/api/config');
  if (!configRes.exists) {
    showPage('wizard');
  }
});

// ── Navigation ──
function showPage(page) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  const target = document.getElementById('page-' + page);
  if (target) target.classList.add('active');
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const navBtn = document.querySelector('.nav-item[data-page="' + page + '"]');
  if (navBtn) navBtn.classList.add('active');
  currentPage = page;

  if (page === 'status') loadStatus();
  if (page === 'models') loadModelsPage();
  if (page === 'channels') loadChannelsPage();
  if (page === 'settings') loadJsonEditor();
  if (page === 'logs') { loadLogs(); startLogRefresh(); }
  if (page !== 'logs') stopLogRefresh();
}

// ── Status Page ──
async function loadStatus() {
  try {
    const data = await api('GET', '/api/status');
    // Gateway status
    updateGatewayUI(data.gateway.status);
    // Model
    setText('status-model', data.model.primary || '未配置');
    const providerName = data.model.primary ? data.model.primary.split('/')[0] : '';
    setText('status-model-provider', providerName ? 'Provider: ' + providerName : '');
    setText('status-fallbacks', data.model.fallbacks.length > 0 ? data.model.fallbacks.join(' → ') : '无');
    setText('status-channels', data.channels.join(', '));
    setText('status-providers', data.providers.toString());
    // System info
    setText('sys-node', data.system.nodeVersion);
    setText('sys-os', data.system.os);
    setText('sys-openclaw', data.system.openclawVersion);
    setText('sys-hostname', data.system.hostname);
    setText('sidebar-version', data.system.openclawVersion || '');
    // WebChat link
    const configRes = await api('GET', '/api/config');
    if (configRes.exists && configRes.config) {
      currentConfig = configRes.config;
      const port = configRes.config.gateway?.port || 18789;
      const token = configRes.config.gateway?.auth?.token || '';
      const link = document.getElementById('webchat-link');
      if (link) {
        link.href = 'http://localhost:' + port + (token ? '/?token=' + token : '');
      }
      // Provider list
      renderProviderStatus(configRes.config);
    }
  } catch (e) {
    console.error('loadStatus error:', e);
  }
}

function renderProviderStatus(config) {
  const providers = config?.models?.providers || {};
  const el = document.getElementById('status-provider-list');
  if (Object.keys(providers).length === 0) {
    el.innerHTML = '';
    return;
  }
  let html = '<div class="section-card"><h3>📦 Provider 列表</h3>';
  for (const [id, p] of Object.entries(providers)) {
    html += '<div style="margin-bottom:12px;padding:10px;background:var(--bg);border-radius:var(--radius);border:1px solid var(--border);">';
    html += '<div class="info-row"><span class="info-label">ID</span><span class="info-value">' + esc(id) + '</span></div>';
    html += '<div class="info-row"><span class="info-label">API</span><span class="info-value">' + esc(p.api || 'unknown') + '</span></div>';
    html += '<div class="info-row"><span class="info-label">Base URL</span><span class="info-value">' + esc(p.baseUrl || 'N/A') + '</span></div>';
    html += '<div class="info-row"><span class="info-label">Key</span><span class="info-value">' + (p.apiKey ? '••••' + p.apiKey.slice(-4) : 'N/A') + '</span></div>';
    html += '</div>';
  }
  html += '</div>';
  el.innerHTML = html;
}

// ── Gateway Control ──
function updateGatewayUI(status) {
  const badge = document.getElementById('status-gateway-badge');
  const text = document.getElementById('status-gateway-text');
  const indicator = document.getElementById('gateway-indicator');
  const btnStart = document.getElementById('btn-start');
  const btnStop = document.getElementById('btn-stop');
  const btnRestart = document.getElementById('btn-restart');

  badge.className = 'gateway-badge ' + status;
  indicator.className = 'indicator ' + status;

  const labels = { stopped: '已停止', starting: '启动中...', running: '运行中', error: '错误', unknown: '未知' };
  text.textContent = labels[status] || status;
  indicator.querySelector('.text').textContent = labels[status] || status;

  if (status === 'running') {
    btnStart.style.display = 'none';
    btnStop.style.display = 'inline-flex';
    btnRestart.style.display = 'inline-flex';
  } else {
    btnStart.style.display = 'inline-flex';
    btnStop.style.display = 'none';
    btnRestart.style.display = 'none';
  }
}

async function gatewayStart() {
  const btn = document.getElementById('btn-start');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner"></span> 启动中...';
  updateGatewayUI('starting');
  try {
    const res = await api('POST', '/api/gateway/start');
    if (res.success) {
      updateGatewayUI('running');
      showToast('Gateway 已启动', 'success');
    } else {
      updateGatewayUI('error');
      showToast('启动失败: ' + (res.error || res.output), 'error');
    }
  } catch (e) {
    updateGatewayUI('error');
    showToast('启动失败: ' + e.message, 'error');
  }
  btn.disabled = false;
  btn.innerHTML = '启动';
}

async function gatewayStop() {
  showLoading('正在停止 Gateway...');
  try {
    await api('POST', '/api/gateway/stop');
    updateGatewayUI('stopped');
    showToast('Gateway 已停止');
  } catch (e) {
    showToast('停止失败: ' + e.message, 'error');
  }
  hideLoading();
}

async function gatewayRestart() {
  showLoading('正在重启 Gateway...');
  try {
    const res = await api('POST', '/api/gateway/restart');
    if (res.success) {
      updateGatewayUI('running');
      showToast('Gateway 已重启', 'success');
    } else {
      updateGatewayUI('error');
      showToast('重启失败: ' + (res.error || ''), 'error');
    }
  } catch (e) {
    showToast('重启失败: ' + e.message, 'error');
  }
  hideLoading();
}

// ── Wizard ──
function selectProduct(product) {
  wizardProduct = product;
  document.querySelectorAll('#wizard-step-1 .wizard-card').forEach(c => c.classList.remove('selected'));
  document.getElementById('wz-product-' + product).classList.add('selected');
}

function selectNode(el) {
  document.querySelectorAll('.node-option').forEach(n => n.classList.remove('selected'));
  el.classList.add('selected');
  wizardNode = el.dataset.node;
}

function toggleWizardChannel(ch) {
  const card = document.getElementById('wz-ch-' + ch);
  if (wizardChannels[ch]) {
    delete wizardChannels[ch];
    card.classList.remove('selected');
  } else {
    wizardChannels[ch] = true;
    card.classList.add('selected');
  }
}

function wizardNext(step) {
  if (step === 2 && !wizardProduct) {
    showToast('请先选择一个产品', 'error');
    return;
  }
  // Validate keys
  if (step === 2) {
    if (wizardProduct === 'claude' && !document.getElementById('wz-claude-key').value.trim()) {
      showToast('请输入 Claude 卡密', 'error'); return;
    }
    if (wizardProduct === 'codex' && !document.getElementById('wz-codex-key').value.trim()) {
      showToast('请输入 Codex 卡密', 'error'); return;
    }
    if (wizardProduct === 'both') {
      if (!document.getElementById('wz-both-claude-key').value.trim()) { showToast('请输入 Claude 卡密', 'error'); return; }
      if (!document.getElementById('wz-both-codex-key').value.trim()) { showToast('请输入 Codex 卡密', 'error'); return; }
    }
  }
  document.querySelectorAll('.wizard-step').forEach(s => s.classList.remove('active'));
  document.getElementById('wizard-step-' + step).classList.add('active');
  // Update step dots
  for (let i = 1; i <= 3; i++) {
    const dot = document.getElementById('step-dot-' + i);
    dot.className = 'step-dot';
    if (i < step) dot.classList.add('done');
    if (i === step) dot.classList.add('active');
  }
}

function wizardPrev(step) {
  document.querySelectorAll('.wizard-step').forEach(s => s.classList.remove('active'));
  document.getElementById('wizard-step-' + step).classList.add('active');
  for (let i = 1; i <= 3; i++) {
    const dot = document.getElementById('step-dot-' + i);
    dot.className = 'step-dot';
    if (i < step) dot.classList.add('done');
    if (i === step) dot.classList.add('active');
  }
}

async function finishWizard() {
  showLoading('正在生成配置...');
  try {
    const data = { node: wizardNode, channels: [] };
    if (wizardProduct === 'claude') {
      data.product = 'claude';
      data.apiKey = document.getElementById('wz-claude-key').value.trim();
    } else if (wizardProduct === 'codex') {
      data.product = 'codex';
      data.apiKey = document.getElementById('wz-codex-key').value.trim();
    } else if (wizardProduct === 'both') {
      data.product = 'both';
      data.claudeKey = document.getElementById('wz-both-claude-key').value.trim();
      data.codexKey = document.getElementById('wz-both-codex-key').value.trim();
    }
    // Channels
    if (wizardChannels.telegram) {
      const token = document.getElementById('wz-telegram-token').value.trim();
      if (token) data.channels.push({ type: 'telegram', botToken: token });
    }
    if (wizardChannels.discord) {
      const token = document.getElementById('wz-discord-token').value.trim();
      if (token) data.channels.push({ type: 'discord', botToken: token });
    }
    const res = await api('POST', '/api/config/generate', data);
    if (res.success) {
      showToast('配置已生成！正在启动 Gateway...', 'success');
      hideLoading();
      showPage('status');
      await loadStatus();
      // Auto-start gateway
      await gatewayStart();
    } else {
      showToast('生成配置失败: ' + (res.error || ''), 'error');
      hideLoading();
    }
  } catch (e) {
    showToast('配置失败: ' + e.message, 'error');
    hideLoading();
  }
}

// ── Models Page ──
async function loadModelsPage() {
  try {
    const configRes = await api('GET', '/api/config');
    if (!configRes.exists || !configRes.config) {
      document.getElementById('provider-list').innerHTML = '<div class="empty-state"><div class="empty-icon">🧠</div><div class="empty-text">尚未配置，请先完成初始设置</div></div>';
      return;
    }
    const config = configRes.config;
    currentConfig = config;
    const primary = config.agents?.defaults?.model?.primary || '未配置';
    const fallbacks = config.agents?.defaults?.model?.fallbacks || [];
    setText('models-primary', primary);
    setText('models-fallbacks', fallbacks.length > 0 ? fallbacks.join(' → ') : '无');

    const providers = config.models?.providers || {};
    const listEl = document.getElementById('provider-list');
    if (Object.keys(providers).length === 0) {
      listEl.innerHTML = '<div class="empty-state"><div class="empty-icon">📦</div><div class="empty-text">暂无 Provider，点击右上角添加</div></div>';
      return;
    }
    let html = '';
    for (const [id, p] of Object.entries(providers)) {
      const isPrimary = primary.startsWith(id + '/');
      html += '<div class="provider-card ' + (isPrimary ? 'is-primary' : '') + '">';
      html += '<div class="provider-header"><div class="provider-name">' + esc(id);
      if (isPrimary) html += ' <span class="badge-primary">主模型</span>';
      html += '</div><div class="provider-actions">';
      if (!isPrimary) html += '<button class="btn small" onclick="setPrimaryProvider(\'' + esc(id) + '\')">设为主模型</button>';
      html += '<button class="btn small danger" onclick="deleteProvider(\'' + esc(id) + '\')">删除</button>';
      html += '</div></div>';
      html += '<div class="provider-details">';
      html += '<div class="info-row"><span class="info-label">API 格式</span><span class="info-value">' + esc(p.api || 'unknown') + '</span></div>';
      html += '<div class="info-row"><span class="info-label">Base URL</span><span class="info-value">' + esc(p.baseUrl || 'N/A') + '</span></div>';
      html += '<div class="info-row"><span class="info-label">API Key</span><span class="info-value">' + (p.apiKey ? '••••' + p.apiKey.slice(-4) : 'N/A') + '</span></div>';
      if (p.models && p.models.length > 0) {
        html += '<div class="info-row"><span class="info-label">模型</span><span class="info-value">' + p.models.map(m => esc(m.id || m)).join(', ') + '</span></div>';
      }
      html += '</div></div>';
    }
    listEl.innerHTML = html;
  } catch (e) {
    showToast('加载模型配置失败: ' + e.message, 'error');
  }
}

async function addProvider() {
  const id = document.getElementById('new-provider-id').value.trim();
  const apiFormat = document.getElementById('new-provider-api').value;
  const baseUrl = document.getElementById('new-provider-url').value.trim();
  const apiKey = document.getElementById('new-provider-key').value.trim();
  const modelId = document.getElementById('new-provider-model-id').value.trim();
  const setPrimary = document.getElementById('new-provider-set-primary').checked;

  if (!id) { showToast('请填写 Provider ID', 'error'); return; }
  if (!/^[a-zA-Z0-9-]+$/.test(id)) { showToast('Provider ID 只能包含英文、数字和连字符', 'error'); return; }
  if (!baseUrl) { showToast('请填写 Base URL', 'error'); return; }
  if (!apiKey) { showToast('请填写 API Key', 'error'); return; }

  try {
    const configRes = await api('GET', '/api/config');
    const config = configRes.config || { models: { mode: 'merge', providers: {} }, agents: { defaults: { model: {} } } };
    if (!config.models) config.models = { mode: 'merge', providers: {} };
    if (!config.models.providers) config.models.providers = {};
    if (config.models.providers[id]) { showToast('Provider ID 已存在', 'error'); return; }

    const providerConfig = { baseUrl, apiKey, auth: 'api-key', api: apiFormat, headers: {}, authHeader: false };
    if (apiFormat === 'anthropic-messages') {
      providerConfig.models = [];
    } else {
      providerConfig.models = modelId ? [{ id: modelId, name: modelId, reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 }] : [];
    }
    config.models.providers[id] = providerConfig;

    if (setPrimary && modelId) {
      if (!config.agents) config.agents = { defaults: { model: {} } };
      if (!config.agents.defaults) config.agents.defaults = { model: {} };
      if (!config.agents.defaults.model) config.agents.defaults.model = {};
      const oldPrimary = config.agents.defaults.model.primary;
      config.agents.defaults.model.primary = id + '/' + modelId;
      if (!config.agents.defaults.model.fallbacks) config.agents.defaults.model.fallbacks = [];
      if (oldPrimary) config.agents.defaults.model.fallbacks.push(oldPrimary);
    }

    await api('POST', '/api/config', config);
    hideDialog('add-provider-dialog');
    loadModelsPage();
    showToast('Provider 已添加，需重启 Gateway 生效', 'success');
    // Clear form
    document.getElementById('new-provider-id').value = '';
    document.getElementById('new-provider-url').value = '';
    document.getElementById('new-provider-key').value = '';
    document.getElementById('new-provider-model-id').value = '';
    document.getElementById('new-provider-set-primary').checked = false;
  } catch (e) {
    showToast('添加失败: ' + e.message, 'error');
  }
}

async function deleteProvider(id) {
  if (!confirm('确定删除 Provider "' + id + '"？')) return;
  try {
    const configRes = await api('GET', '/api/config');
    const config = configRes.config;
    if (config.models?.providers?.[id]) {
      delete config.models.providers[id];
      const primary = config.agents?.defaults?.model?.primary || '';
      if (primary.startsWith(id + '/')) {
        const fallbacks = config.agents.defaults.model.fallbacks || [];
        config.agents.defaults.model.primary = fallbacks.shift() || null;
        config.agents.defaults.model.fallbacks = fallbacks;
      }
      if (config.agents?.defaults?.model?.fallbacks) {
        config.agents.defaults.model.fallbacks = config.agents.defaults.model.fallbacks.filter(f => !f.startsWith(id + '/'));
      }
      await api('POST', '/api/config', config);
      loadModelsPage();
      showToast('Provider 已删除，需重启 Gateway 生效', 'success');
    }
  } catch (e) {
    showToast('删除失败: ' + e.message, 'error');
  }
}

async function setPrimaryProvider(id) {
  try {
    const configRes = await api('GET', '/api/config');
    const config = configRes.config;
    const provider = config.models?.providers?.[id];
    if (!provider) return;
    let modelId = '';
    if (provider.models && provider.models.length > 0) {
      modelId = provider.models[0].id || provider.models[0];
    } else {
      modelId = prompt('请输入该 Provider 的模型 ID（例如 claude-opus-4-6）:');
      if (!modelId) return;
    }
    const newPrimary = id + '/' + modelId;
    const oldPrimary = config.agents?.defaults?.model?.primary;
    if (!config.agents) config.agents = { defaults: { model: {} } };
    if (!config.agents.defaults) config.agents.defaults = { model: {} };
    if (!config.agents.defaults.model) config.agents.defaults.model = {};
    config.agents.defaults.model.primary = newPrimary;
    if (!config.agents.defaults.model.fallbacks) config.agents.defaults.model.fallbacks = [];
    config.agents.defaults.model.fallbacks = config.agents.defaults.model.fallbacks.filter(f => f !== newPrimary);
    if (oldPrimary && oldPrimary !== newPrimary) {
      config.agents.defaults.model.fallbacks.unshift(oldPrimary);
    }
    await api('POST', '/api/config', config);
    loadModelsPage();
    showToast('主模型已切换为 ' + newPrimary + '，需重启 Gateway 生效', 'success');
  } catch (e) {
    showToast('切换失败: ' + e.message, 'error');
  }
}

// ── Channels Page ──
async function loadChannelsPage() {
  try {
    const configRes = await api('GET', '/api/config');
    if (!configRes.exists || !configRes.config) {
      document.getElementById('channel-list').innerHTML = '<div class="empty-state"><div class="empty-icon">💬</div><div class="empty-text">尚未配置</div></div>';
      return;
    }
    const config = configRes.config;
    currentConfig = config;
    const listEl = document.getElementById('channel-list');
    let html = '';
    let hasChannels = false;

    if (config.telegram) {
      hasChannels = true;
      const token = config.telegram.token || '';
      const users = config.telegram.allowedUsers || [];
      html += '<div class="channel-manage-card"><div class="channel-manage-header">';
      html += '<span class="channel-manage-icon">📱</span><span class="channel-manage-name">Telegram</span>';
      html += '<button class="btn small danger" onclick="deleteChannel(\'telegram\')">删除</button></div>';
      html += '<div class="provider-details">';
      html += '<div class="info-row"><span class="info-label">Bot Token</span><span class="info-value">' + (token ? '••••' + token.slice(-6) : 'N/A') + '</span></div>';
      html += '<div class="info-row"><span class="info-label">允许用户</span><span class="info-value">' + (users.length > 0 ? users.join(', ') : '所有人') + '</span></div>';
      html += '</div></div>';
    }

    if (config.discord) {
      hasChannels = true;
      const token = config.discord.token || '';
      html += '<div class="channel-manage-card"><div class="channel-manage-header">';
      html += '<span class="channel-manage-icon">🎮</span><span class="channel-manage-name">Discord</span>';
      html += '<button class="btn small danger" onclick="deleteChannel(\'discord\')">删除</button></div>';
      html += '<div class="provider-details">';
      html += '<div class="info-row"><span class="info-label">Bot Token</span><span class="info-value">' + (token ? '••••' + token.slice(-6) : 'N/A') + '</span></div>';
      html += '</div></div>';
    }

    // WebChat always available
    html += '<div class="channel-manage-card"><div class="channel-manage-header">';
    html += '<span class="channel-manage-icon">🌐</span><span class="channel-manage-name">WebChat</span>';
    html += '<span class="badge green">内置</span></div>';
    html += '<div class="provider-details"><div class="info-row"><span class="info-label">状态</span><span class="info-value">始终可用</span></div></div></div>';

    if (!hasChannels) {
      html = '<p class="hint" style="margin-bottom:16px;">暂无外部渠道，点击右上角添加</p>' + html;
    }
    listEl.innerHTML = html;
  } catch (e) {
    showToast('加载渠道配置失败: ' + e.message, 'error');
  }
}

function onChannelTypeChange() {
  const type = document.getElementById('new-channel-type').value;
  const helpEl = document.getElementById('new-channel-help');
  const usersGroup = document.getElementById('channel-allowed-users-group');
  if (type === 'telegram') {
    helpEl.textContent = '从 @BotFather 获取';
    usersGroup.style.display = 'block';
  } else {
    helpEl.textContent = '从 Discord Developer Portal 获取';
    usersGroup.style.display = 'none';
  }
}

async function addChannel() {
  const type = document.getElementById('new-channel-type').value;
  const token = document.getElementById('new-channel-token').value.trim();
  if (!token) { showToast('请填写 Bot Token', 'error'); return; }

  try {
    const configRes = await api('GET', '/api/config');
    const config = configRes.config || {};
    if (type === 'telegram') {
      if (config.telegram) { showToast('Telegram 已配置，请先删除再重新添加', 'error'); return; }
      const allowedStr = document.getElementById('new-channel-allowed-users').value.trim();
      const allowedUsers = allowedStr ? allowedStr.split(',').map(s => s.trim()).filter(Boolean) : [];
      config.telegram = { token, allowedUsers };
    } else if (type === 'discord') {
      if (config.discord) { showToast('Discord 已配置，请先删除再重新添加', 'error'); return; }
      config.discord = { token };
    }
    await api('POST', '/api/config', config);
    hideDialog('add-channel-dialog');
    loadChannelsPage();
    showToast((type === 'telegram' ? 'Telegram' : 'Discord') + ' 渠道已添加，需重启 Gateway 生效', 'success');
    document.getElementById('new-channel-token').value = '';
    document.getElementById('new-channel-allowed-users').value = '';
  } catch (e) {
    showToast('添加失败: ' + e.message, 'error');
  }
}

async function deleteChannel(type) {
  const name = type === 'telegram' ? 'Telegram' : 'Discord';
  if (!confirm('确定删除 ' + name + ' 渠道？')) return;
  try {
    const configRes = await api('GET', '/api/config');
    const config = configRes.config;
    delete config[type];
    await api('POST', '/api/config', config);
    loadChannelsPage();
    showToast(name + ' 渠道已删除，需重启 Gateway 生效', 'success');
  } catch (e) {
    showToast('删除失败: ' + e.message, 'error');
  }
}

// ── Settings / JSON Editor ──
async function loadJsonEditor() {
  try {
    const res = await api('GET', '/api/config/raw');
    const editor = document.getElementById('json-editor');
    const errorEl = document.getElementById('json-editor-error');
    if (res.success) {
      editor.value = res.content;
      errorEl.style.display = 'none';
    } else {
      editor.value = '';
      errorEl.textContent = res.error || '加载失败';
      errorEl.style.display = 'block';
    }
  } catch (e) {
    showToast('加载配置文件失败: ' + e.message, 'error');
  }
}

function formatJsonEditor() {
  const editor = document.getElementById('json-editor');
  const errorEl = document.getElementById('json-editor-error');
  try {
    const parsed = JSON.parse(editor.value);
    editor.value = JSON.stringify(parsed, null, 2);
    errorEl.style.display = 'none';
    showToast('已格式化');
  } catch (e) {
    errorEl.textContent = 'JSON 格式错误: ' + e.message;
    errorEl.style.display = 'block';
  }
}

async function saveJsonEditor() {
  const editor = document.getElementById('json-editor');
  const errorEl = document.getElementById('json-editor-error');
  const content = editor.value;
  try {
    JSON.parse(content);
  } catch (e) {
    errorEl.textContent = 'JSON 格式错误，无法保存: ' + e.message;
    errorEl.style.display = 'block';
    return;
  }
  try {
    const res = await api('POST', '/api/config/raw', { content });
    if (res.success) {
      errorEl.style.display = 'none';
      showToast('配置已保存，需重启 Gateway 生效', 'success');
    } else {
      errorEl.textContent = '保存失败: ' + res.error;
      errorEl.style.display = 'block';
    }
  } catch (e) {
    showToast('保存失败: ' + e.message, 'error');
  }
}

async function saveAndRestart() {
  await saveJsonEditor();
  const errorEl = document.getElementById('json-editor-error');
  if (errorEl.style.display !== 'block') {
    await gatewayRestart();
  }
}

// ── Logs ──
async function loadLogs() {
  try {
    const res = await api('GET', '/api/logs?lines=300');
    const el = document.getElementById('log-output');
    if (res.success) {
      el.textContent = res.content || '(暂无日志)';
      el.scrollTop = el.scrollHeight;
    } else {
      el.textContent = '加载日志失败: ' + (res.error || '');
    }
  } catch (e) {
    document.getElementById('log-output').textContent = '加载日志失败: ' + e.message;
  }
}

function startLogRefresh() {
  stopLogRefresh();
  if (document.getElementById('log-auto-refresh').checked) {
    logRefreshTimer = setInterval(loadLogs, 5000);
  }
}

function stopLogRefresh() {
  if (logRefreshTimer) {
    clearInterval(logRefreshTimer);
    logRefreshTimer = null;
  }
}

function toggleLogAutoRefresh() {
  if (document.getElementById('log-auto-refresh').checked) {
    startLogRefresh();
  } else {
    stopLogRefresh();
  }
}

// ── Dialog ──
function showDialog(id) {
  const el = document.getElementById(id);
  if (el) el.classList.add('show');
}

function hideDialog(id) {
  const el = document.getElementById(id);
  if (el) el.classList.remove('show');
}

// ── Loading ──
function showLoading(text) {
  setText('loading-text', text || '处理中...');
  document.getElementById('loading-overlay').classList.add('show');
}

function hideLoading() {
  document.getElementById('loading-overlay').classList.remove('show');
}

// ── Toast ──
function showToast(message, type) {
  type = type || 'info';
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();
  const toast = document.createElement('div');
  toast.className = 'toast toast-' + type;
  toast.textContent = message;
  document.body.appendChild(toast);
  requestAnimationFrame(() => { toast.classList.add('show'); });
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

// ── Utility ──
function esc(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function setText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}
