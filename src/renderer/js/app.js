// ── State ──
let currentPage = 'status';
let env = null;
let gatewayRunning = false;
let currentConfig = null;

// ── Init ──
document.addEventListener('DOMContentLoaded', async () => {
  try {
    const config = await api.getConfig();
    currentConfig = config;
    if (!config) {
      showPage('wizard');
      runEnvCheck();
    } else {
      showPage('status');
      loadStatus(config);
    }
  } catch (e) {
    console.error('Init error:', e);
    showPage('wizard');
    runEnvCheck();
  }

  api.onGatewayStatus((status) => { updateGatewayIndicator(status); });
  api.onGatewayLog((log) => { appendLog(log); });
});

// ── Navigation ──
function showPage(page) {
  document.querySelectorAll('.page').forEach(p => p.style.display = 'none');
  const target = document.getElementById(`page-${page}`);
  if (target) target.style.display = 'block';
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const navBtn = document.querySelector(`.nav-item[data-page="${page}"]`);
  if (navBtn) navBtn.classList.add('active');
  currentPage = page;

  // Page-specific loading
  if (page === 'chat') loadChatFrame();
  if (page === 'models') loadModelsPage();
  if (page === 'channels') loadChannelsPage();
  if (page === 'settings') loadJsonEditor();
  if (page === 'status') loadStatus();
}

// ── Environment Check ──
async function runEnvCheck() {
  try {
    env = await api.detectEnvironment();
  } catch (e) {
    updateCheck('check-os', false, 'Error: ' + e.message);
    return;
  }
  updateCheck('check-os', true, env.os.name);
  if (env.node.installed) {
    updateCheck('check-node', true, env.node.version);
  } else {
    updateCheck('check-node', false, '未安装');
    showEnvAction('需要安装 Node.js (v18+)', async () => {
      api.openExternal('https://nodejs.org/');
    }, '下载 Node.js');
    return;
  }
  if (env.openclaw.installed) {
    updateCheck('check-openclaw', true, env.openclaw.version);
  } else {
    updateCheck('check-openclaw', 'warn', '未安装 — 点击下方按钮安装');
    showEnvAction('安装 OpenClaw...', async () => {
      const btn = document.querySelector('#env-actions button');
      btn.disabled = true;
      btn.textContent = '安装中...';
      updateCheck('check-openclaw', 'loading', '正在安装...');
      try {
        const result = await api.installOpenclaw();
        if (result.success) {
          updateCheck('check-openclaw', true, '安装成功');
          document.getElementById('btn-step1-next').disabled = false;
          document.getElementById('env-actions').style.display = 'none';
        } else {
          updateCheck('check-openclaw', false, '安装失败');
          btn.disabled = false;
          btn.textContent = '重试安装';
        }
      } catch (e) {
        updateCheck('check-openclaw', false, '安装失败: ' + e.message);
        btn.disabled = false;
        btn.textContent = '重试安装';
      }
    }, '一键安装 OpenClaw');
    return;
  }
  document.getElementById('btn-step1-next').disabled = false;
}

function updateCheck(id, status, text) {
  const el = document.getElementById(id);
  if (!el) return;
  const icon = el.querySelector('.check-icon');
  const value = el.querySelector('.check-value');
  value.textContent = text;
  if (status === true) icon.textContent = '✅';
  else if (status === false) icon.textContent = '❌';
  else if (status === 'warn') icon.textContent = '⚠️';
  else if (status === 'loading') icon.textContent = '⏳';
}

function showEnvAction(text, action, btnText) {
  const container = document.getElementById('env-actions');
  container.style.display = 'block';
  if (action && btnText) {
    container.innerHTML = `<p style="margin-bottom:8px;color:var(--text-dim)">${text}</p>
      <button class="btn primary" onclick="(${action.toString()})()">${btnText}</button>`;
  } else {
    container.innerHTML = `<p style="color:var(--red)">${text}</p>`;
  }
}

// ── Wizard ──
function wizardNext(step) {
  document.querySelectorAll('.wizard-step').forEach(s => s.style.display = 'none');
  document.getElementById(`step-${step}`).style.display = 'block';
}

function toggleModel(name) {
  const checked = document.getElementById(`enable-${name}`).checked;
  const card = document.getElementById(`model-${name}`);
  const body = card.querySelector('.model-body');
  body.style.display = checked ? 'block' : 'none';
}

function toggleProxyFields(name) {
  const type = document.getElementById(`${name}-type`).value;
  const proxyUrl = document.getElementById(`${name}-proxy-url`);
  if (proxyUrl) proxyUrl.style.display = type === 'proxy' ? 'block' : 'none';
}

function toggleChannel(name) {
  const checked = document.getElementById(`enable-${name}`).checked;
  const card = document.querySelector(`#enable-${name}`).closest('.channel-card');
  const body = card.querySelector('.channel-body');
  if (body) body.style.display = checked ? 'block' : 'none';
}

// ── Collect Model Data (Wizard) ──
function collectModelData() {
  const models = [];
  if (document.getElementById('enable-claude')?.checked) {
    const type = document.getElementById('claude-type').value;
    const apiKey = document.getElementById('claude-api-key').value;
    const model = document.getElementById('claude-model').value;
    if (!apiKey) return { error: 'Claude 已启用但未填写 API Key' };
    if (type === 'proxy') {
      const baseUrl = document.getElementById('claude-base-url').value;
      if (!baseUrl) return { error: 'Claude 中转模式需要填写中转地址' };
      models.push({ type: 'proxy', providerId: 'apexyy-claude', baseUrl, apiFormat: 'anthropic-messages', apiKey, primaryModelId: model, models: [] });
    } else {
      models.push({ type: 'official', envKey: 'ANTHROPIC_API_KEY', apiKey, modelRef: `anthropic/${model}` });
    }
  }
  if (document.getElementById('enable-codex')?.checked) {
    const type = document.getElementById('codex-type').value;
    const apiKey = document.getElementById('codex-api-key').value;
    const model = document.getElementById('codex-model').value;
    if (!apiKey) return { error: 'Codex 已启用但未填写 API Key' };
    if (type === 'proxy') {
      const baseUrl = document.getElementById('codex-base-url').value;
      if (!baseUrl) return { error: 'Codex 中转模式需要填写中转地址' };
      const codexModels = {
        'gpt-5.2': { id: 'gpt-5.2', name: 'GPT 5.2', reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 },
        'gpt-codex-5.3': { id: 'gpt-codex-5.3', name: 'GPT Codex 5.3', reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 },
        'gpt-4.1': { id: 'gpt-4.1', name: 'GPT 4.1', reasoning: false, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 },
        'o3': { id: 'o3', name: 'o3', reasoning: true, input: ['text', 'image'], contextWindow: 200000, maxTokens: 100000 },
        'o4-mini': { id: 'o4-mini', name: 'o4-mini', reasoning: true, input: ['text', 'image'], contextWindow: 200000, maxTokens: 100000 },
      };
      models.push({ type: 'proxy', providerId: 'apexyy-codex', baseUrl, apiFormat: 'openai-responses', apiKey, primaryModelId: model, models: [codexModels[model] || { id: model, name: model, reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 }] });
    } else {
      models.push({ type: 'official', envKey: 'OPENAI_API_KEY', apiKey, modelRef: `openai/${model}` });
    }
  }
  if (document.getElementById('enable-gemini')?.checked) {
    const apiKey = document.getElementById('gemini-api-key').value;
    if (!apiKey) return { error: 'Gemini 已启用但未填写 API Key' };
    models.push({ type: 'official', envKey: 'GEMINI_API_KEY', apiKey, modelRef: `google/${document.getElementById('gemini-model').value}` });
  }
  if (document.getElementById('enable-glm')?.checked) {
    const apiKey = document.getElementById('glm-api-key').value;
    if (!apiKey) return { error: 'GLM 已启用但未填写 API Key' };
    models.push({ type: 'official', envKey: 'ZAI_API_KEY', apiKey, modelRef: `zai/${document.getElementById('glm-model').value}` });
  }
  return { models };
}

// ── Finish Wizard ──
async function finishWizard() {
  const collected = collectModelData();
  if (collected.error) { showToast(collected.error, 'error'); return; }
  if (collected.models.length === 0) { showToast('请至少配置一个 AI 模型', 'error'); return; }
  const wizardData = { models: collected.models, channels: [] };
  if (document.getElementById('enable-telegram')?.checked) {
    wizardData.channels.push({ type: 'telegram', botToken: document.getElementById('telegram-token').value });
  }
  if (document.getElementById('enable-discord')?.checked) {
    wizardData.channels.push({ type: 'discord', botToken: document.getElementById('discord-token').value });
  }
  try {
    const { config, envVars } = await api.generateConfig(wizardData);
    await api.saveConfig(config);
    await api.saveEnv(envVars);
    currentConfig = config;
    showPage('status');
    loadStatus(config);
    startGateway();
    showToast('配置已保存，正在启动 Gateway...');
  } catch (e) {
    showToast('保存配置失败: ' + e.message, 'error');
  }
}

// ── Status Page (P2) ──
async function loadStatus(config) {
  try {
    if (!config) config = await api.getConfig();
    if (!config) return;
    currentConfig = config;

    // Primary model
    const primary = config.agents?.defaults?.model?.primary || '未配置';
    document.getElementById('status-model').textContent = primary;
    const providerName = primary.split('/')[0] || '';
    document.getElementById('status-model-provider').textContent = providerName ? `Provider: ${providerName}` : '';

    // Fallbacks
    const fallbacks = config.agents?.defaults?.model?.fallbacks || [];
    document.getElementById('status-fallbacks').textContent = fallbacks.length > 0 ? fallbacks.join(' → ') : '无';

    // Channels
    const channels = [];
    if (config.telegram) channels.push('Telegram');
    if (config.discord) channels.push('Discord');
    channels.push('WebChat');
    document.getElementById('status-channels').textContent = channels.join(', ');

    // Providers count
    const providers = config.models?.providers || {};
    const providerCount = Object.keys(providers).length;
    document.getElementById('status-providers').textContent = providerCount.toString();

    // Provider status list
    const listEl = document.getElementById('status-provider-list');
    if (providerCount > 0) {
      let html = '<h3 style="margin-bottom:12px;">Provider 列表</h3>';
      for (const [id, p] of Object.entries(providers)) {
        html += `<div class="section-card" style="margin-bottom:8px;">
          <div class="info-row"><span class="info-label">ID</span><span class="info-value">${esc(id)}</span></div>
          <div class="info-row"><span class="info-label">API</span><span class="info-value">${esc(p.api || 'unknown')}</span></div>
          <div class="info-row"><span class="info-label">Base URL</span><span class="info-value">${esc(p.baseUrl || 'N/A')}</span></div>
          <div class="info-row"><span class="info-label">Key</span><span class="info-value">${p.apiKey ? '••••' + p.apiKey.slice(-4) : 'N/A'}</span></div>
        </div>`;
      }
      listEl.innerHTML = html;
    } else {
      listEl.innerHTML = '<p class="hint">暂无 Provider，请前往模型管理页面添加</p>';
    }

    // Gateway status
    const status = await api.getGatewayStatus();
    updateGatewayIndicator(status);
  } catch (e) {
    console.error('loadStatus error:', e);
  }
}

// ── Gateway Control ──
async function startGateway() {
  try {
    document.getElementById('btn-start').disabled = true;
    document.getElementById('btn-start').textContent = '启动中...';
    const result = await api.startGateway();
    if (result.success) {
      updateGatewayIndicator('running');
    } else {
      updateGatewayIndicator('error');
      document.getElementById('status-gateway-value').textContent = `错误: ${result.error}`;
      showToast('Gateway 启动失败: ' + result.error, 'error');
    }
  } catch (e) {
    updateGatewayIndicator('error');
    showToast('Gateway 启动失败: ' + e.message, 'error');
  }
  document.getElementById('btn-start').disabled = false;
  document.getElementById('btn-start').textContent = '启动';
}

async function stopGateway() {
  try {
    await api.stopGateway();
    updateGatewayIndicator('stopped');
    showToast('Gateway 已停止');
  } catch (e) {
    showToast('停止失败: ' + e.message, 'error');
  }
}

async function restartGateway() {
  try {
    showToast('正在重启 Gateway...');
    await api.stopGateway();
    updateGatewayIndicator('starting');
    await new Promise(r => setTimeout(r, 1000));
    const result = await api.startGateway();
    if (result.success) {
      updateGatewayIndicator('running');
      showToast('Gateway 已重启');
    } else {
      updateGatewayIndicator('error');
      showToast('重启失败: ' + result.error, 'error');
    }
  } catch (e) {
    showToast('重启失败: ' + e.message, 'error');
  }
}

function updateGatewayIndicator(status) {
  const indicator = document.getElementById('gateway-indicator');
  const statusValue = document.getElementById('status-gateway-value');
  const btnStart = document.getElementById('btn-start');
  const btnStop = document.getElementById('btn-stop');
  const btnRestart = document.getElementById('btn-restart');
  indicator.className = `indicator ${status}`;
  const labels = { stopped: '已停止', starting: '启动中...', running: '运行中', error: '错误' };
  indicator.querySelector('.text').textContent = labels[status] || status;
  if (statusValue) statusValue.textContent = labels[status] || status;
  if (status === 'running') {
    btnStart.style.display = 'none';
    btnStop.style.display = 'inline-block';
    if (btnRestart) btnRestart.style.display = 'inline-block';
  } else {
    btnStart.style.display = 'inline-block';
    btnStop.style.display = 'none';
    if (btnRestart) btnRestart.style.display = 'none';
  }
}

// ── Models Page (P0) ──
async function loadModelsPage() {
  try {
    const config = await api.getConfig();
    if (!config) { document.getElementById('provider-list').innerHTML = '<p class="hint">尚未配置，请先完成初始设置</p>'; return; }
    currentConfig = config;

    // Current model info
    const primary = config.agents?.defaults?.model?.primary || '未配置';
    const fallbacks = config.agents?.defaults?.model?.fallbacks || [];
    document.getElementById('models-primary').textContent = primary;
    document.getElementById('models-fallbacks').textContent = fallbacks.length > 0 ? fallbacks.join(' → ') : '无';

    // Provider list
    const providers = config.models?.providers || {};
    const listEl = document.getElementById('provider-list');
    if (Object.keys(providers).length === 0) {
      listEl.innerHTML = '<p class="hint">暂无 Provider，点击右上角添加</p>';
      return;
    }

    let html = '';
    for (const [id, p] of Object.entries(providers)) {
      const isPrimary = primary.startsWith(id + '/');
      html += `<div class="provider-card ${isPrimary ? 'is-primary' : ''}">
        <div class="provider-header">
          <div class="provider-name">${esc(id)} ${isPrimary ? '<span class="badge-primary">主模型</span>' : ''}</div>
          <div class="provider-actions">
            ${!isPrimary ? `<button class="btn small" onclick="setPrimaryProvider('${esc(id)}')">设为主模型</button>` : ''}
            <button class="btn small danger" onclick="deleteProvider('${esc(id)}')">删除</button>
          </div>
        </div>
        <div class="provider-details">
          <div class="info-row"><span class="info-label">API 格式</span><span class="info-value">${esc(p.api || 'unknown')}</span></div>
          <div class="info-row"><span class="info-label">Base URL</span><span class="info-value">${esc(p.baseUrl || 'N/A')}</span></div>
          <div class="info-row"><span class="info-label">API Key</span><span class="info-value">${p.apiKey ? '••••' + p.apiKey.slice(-4) : 'N/A'}</span></div>
          ${p.models && p.models.length > 0 ? `<div class="info-row"><span class="info-label">模型</span><span class="info-value">${p.models.map(m => esc(m.id || m)).join(', ')}</span></div>` : ''}
        </div>
      </div>`;
    }
    listEl.innerHTML = html;
  } catch (e) {
    showToast('加载模型配置失败: ' + e.message, 'error');
  }
}

function showAddProviderDialog() { document.getElementById('add-provider-dialog').style.display = 'flex'; }
function hideAddProviderDialog() { document.getElementById('add-provider-dialog').style.display = 'none'; }

async function addProvider() {
  const id = document.getElementById('new-provider-id').value.trim();
  const apiFormat = document.getElementById('new-provider-api').value;
  const baseUrl = document.getElementById('new-provider-url').value.trim();
  const apiKey = document.getElementById('new-provider-key').value.trim();
  const setPrimary = document.getElementById('new-provider-set-primary').checked;
  const modelId = document.getElementById('new-provider-model-id').value.trim();

  if (!id) { showToast('请填写 Provider ID', 'error'); return; }
  if (!/^[a-zA-Z0-9-]+$/.test(id)) { showToast('Provider ID 只能包含英文、数字和连字符', 'error'); return; }
  if (!baseUrl) { showToast('请填写 Base URL', 'error'); return; }
  if (!apiKey) { showToast('请填写 API Key', 'error'); return; }

  try {
    const config = await api.getConfig();
    if (!config.models) config.models = { mode: 'merge', providers: {} };
    if (!config.models.providers) config.models.providers = {};
    if (config.models.providers[id]) { showToast('Provider ID 已存在', 'error'); return; }

    const providerConfig = {
      baseUrl, apiKey, auth: 'api-key', api: apiFormat, headers: {}, authHeader: false,
    };
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
      config.agents.defaults.model.primary = `${id}/${modelId}`;
      if (oldPrimary && !config.agents.defaults.model.fallbacks) config.agents.defaults.model.fallbacks = [];
      if (oldPrimary) config.agents.defaults.model.fallbacks.push(oldPrimary);
    }

    await api.saveConfig(config);
    currentConfig = config;
    hideAddProviderDialog();
    loadModelsPage();
    showToast('Provider 已添加，需重启 Gateway 生效');
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
  if (!confirm(`确定删除 Provider "${id}"？`)) return;
  try {
    const config = await api.getConfig();
    if (config.models?.providers?.[id]) {
      delete config.models.providers[id];
      // If primary model was from this provider, clear it
      const primary = config.agents?.defaults?.model?.primary || '';
      if (primary.startsWith(id + '/')) {
        const fallbacks = config.agents.defaults.model.fallbacks || [];
        config.agents.defaults.model.primary = fallbacks.shift() || null;
        config.agents.defaults.model.fallbacks = fallbacks;
      }
      // Also remove from fallbacks
      if (config.agents?.defaults?.model?.fallbacks) {
        config.agents.defaults.model.fallbacks = config.agents.defaults.model.fallbacks.filter(f => !f.startsWith(id + '/'));
      }
      await api.saveConfig(config);
      currentConfig = config;
      loadModelsPage();
      showToast('Provider 已删除，需重启 Gateway 生效');
    }
  } catch (e) {
    showToast('删除失败: ' + e.message, 'error');
  }
}

async function setPrimaryProvider(id) {
  try {
    const config = await api.getConfig();
    const provider = config.models?.providers?.[id];
    if (!provider) return;
    // Determine model ID
    let modelId = '';
    if (provider.models && provider.models.length > 0) {
      modelId = provider.models[0].id || provider.models[0];
    } else {
      modelId = prompt('请输入该 Provider 的模型 ID（例如 claude-opus-4-6）:');
      if (!modelId) return;
    }
    const newPrimary = `${id}/${modelId}`;
    const oldPrimary = config.agents?.defaults?.model?.primary;
    if (!config.agents) config.agents = { defaults: { model: {} } };
    if (!config.agents.defaults) config.agents.defaults = { model: {} };
    if (!config.agents.defaults.model) config.agents.defaults.model = {};
    config.agents.defaults.model.primary = newPrimary;
    if (!config.agents.defaults.model.fallbacks) config.agents.defaults.model.fallbacks = [];
    if (oldPrimary && oldPrimary !== newPrimary) {
      // Remove newPrimary from fallbacks if it was there
      config.agents.defaults.model.fallbacks = config.agents.defaults.model.fallbacks.filter(f => f !== newPrimary);
      // Add old primary to fallbacks
      config.agents.defaults.model.fallbacks.unshift(oldPrimary);
    }
    await api.saveConfig(config);
    currentConfig = config;
    loadModelsPage();
    showToast(`主模型已切换为 ${newPrimary}，需重启 Gateway 生效`);
  } catch (e) {
    showToast('切换失败: ' + e.message, 'error');
  }
}

// ── Channels Page (P1) ──
async function loadChannelsPage() {
  try {
    const config = await api.getConfig();
    if (!config) { document.getElementById('channel-list').innerHTML = '<p class="hint">尚未配置</p>'; return; }
    currentConfig = config;
    const listEl = document.getElementById('channel-list');
    let html = '';
    let hasChannels = false;

    if (config.telegram) {
      hasChannels = true;
      const token = config.telegram.token || '';
      const users = config.telegram.allowedUsers || [];
      html += `<div class="channel-manage-card">
        <div class="channel-manage-header">
          <span class="channel-manage-icon">📱</span>
          <span class="channel-manage-name">Telegram</span>
          <button class="btn small danger" onclick="deleteChannel('telegram')">删除</button>
        </div>
        <div class="provider-details">
          <div class="info-row"><span class="info-label">Bot Token</span><span class="info-value">${token ? '••••' + token.slice(-6) : 'N/A'}</span></div>
          <div class="info-row"><span class="info-label">允许用户</span><span class="info-value">${users.length > 0 ? users.join(', ') : '所有人'}</span></div>
        </div>
      </div>`;
    }

    if (config.discord) {
      hasChannels = true;
      const token = config.discord.token || '';
      html += `<div class="channel-manage-card">
        <div class="channel-manage-header">
          <span class="channel-manage-icon">🎮</span>
          <span class="channel-manage-name">Discord</span>
          <button class="btn small danger" onclick="deleteChannel('discord')">删除</button>
        </div>
        <div class="provider-details">
          <div class="info-row"><span class="info-label">Bot Token</span><span class="info-value">${token ? '••••' + token.slice(-6) : 'N/A'}</span></div>
        </div>
      </div>`;
    }

    // Always show WebChat
    html += `<div class="channel-manage-card">
      <div class="channel-manage-header">
        <span class="channel-manage-icon">🌐</span>
        <span class="channel-manage-name">WebChat</span>
        <span class="badge" style="background:var(--green);">内置</span>
      </div>
      <div class="provider-details">
        <div class="info-row"><span class="info-label">状态</span><span class="info-value">始终可用</span></div>
      </div>
    </div>`;

    if (!hasChannels) {
      html = '<p class="hint" style="margin-bottom:16px;">暂无外部渠道，点击右上角添加</p>' + html;
    }
    listEl.innerHTML = html;
  } catch (e) {
    showToast('加载渠道配置失败: ' + e.message, 'error');
  }
}

function showAddChannelDialog() { document.getElementById('add-channel-dialog').style.display = 'flex'; onChannelTypeChange(); }
function hideAddChannelDialog() { document.getElementById('add-channel-dialog').style.display = 'none'; }

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
    const config = await api.getConfig();
    if (type === 'telegram') {
      if (config.telegram) { showToast('Telegram 已配置，请先删除再重新添加', 'error'); return; }
      const allowedStr = document.getElementById('new-channel-allowed-users').value.trim();
      const allowedUsers = allowedStr ? allowedStr.split(',').map(s => s.trim()).filter(Boolean) : [];
      config.telegram = { token, allowedUsers };
    } else if (type === 'discord') {
      if (config.discord) { showToast('Discord 已配置，请先删除再重新添加', 'error'); return; }
      config.discord = { token };
    }
    await api.saveConfig(config);
    currentConfig = config;
    hideAddChannelDialog();
    loadChannelsPage();
    showToast(`${type === 'telegram' ? 'Telegram' : 'Discord'} 渠道已添加，需重启 Gateway 生效`);
    document.getElementById('new-channel-token').value = '';
    document.getElementById('new-channel-allowed-users').value = '';
  } catch (e) {
    showToast('添加失败: ' + e.message, 'error');
  }
}

async function deleteChannel(type) {
  const name = type === 'telegram' ? 'Telegram' : 'Discord';
  if (!confirm(`确定删除 ${name} 渠道？`)) return;
  try {
    const config = await api.getConfig();
    delete config[type];
    await api.saveConfig(config);
    currentConfig = config;
    loadChannelsPage();
    showToast(`${name} 渠道已删除，需重启 Gateway 生效`);
  } catch (e) {
    showToast('删除失败: ' + e.message, 'error');
  }
}

// ── Settings / JSON Editor (P3) ──
async function loadJsonEditor() {
  try {
    const result = await api.readConfigRaw();
    const editor = document.getElementById('json-editor');
    const errorEl = document.getElementById('json-editor-error');
    if (result.success) {
      editor.value = result.content;
      errorEl.style.display = 'none';
    } else {
      editor.value = '';
      errorEl.textContent = result.error;
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
    JSON.parse(content); // validate
  } catch (e) {
    errorEl.textContent = 'JSON 格式错误，无法保存: ' + e.message;
    errorEl.style.display = 'block';
    return;
  }
  try {
    const result = await api.writeConfigRaw(content);
    if (result.success) {
      errorEl.style.display = 'none';
      showToast('配置已保存，需重启 Gateway 生效');
    } else {
      errorEl.textContent = '保存失败: ' + result.error;
      errorEl.style.display = 'block';
    }
  } catch (e) {
    showToast('保存失败: ' + e.message, 'error');
  }
}

// ── Chat ──
async function loadChatFrame() {
  try {
    const { url, token } = await api.getGatewayUrl();
    const frame = document.getElementById('chat-frame');
    frame.src = `${url}/?token=${token}`;
  } catch (e) {
    console.error('loadChatFrame error:', e);
  }
}

async function openWebChat() {
  try {
    const { url, token } = await api.getGatewayUrl();
    api.openExternal(`${url}/?token=${token}`);
  } catch (e) {
    showToast('无法打开 WebChat: ' + e.message, 'error');
  }
}

// ── Logs ──
function appendLog(text) {
  const el = document.getElementById('log-output');
  if (el) {
    el.textContent += text;
    el.scrollTop = el.scrollHeight;
  }
}

// ── Toast Notifications (P4) ──
function showToast(message, type = 'info') {
  // Remove existing toast
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);

  // Animate in
  requestAnimationFrame(() => { toast.classList.add('show'); });

  // Auto remove
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
