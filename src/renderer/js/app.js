// ── State ──
let currentPage = 'status';
let env = null;
let gatewayRunning = false;
let currentConfig = null;
let confirmCallback = null;
let uptimeInterval = null;
let gatewayStartedAt = null;

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
  initTooltips();
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
  if (page === 'chat') loadChatFrame();
  if (page === 'models') loadModelsPage();
  if (page === 'channels') loadChannelsPage();
  if (page === 'settings') loadJsonEditor();
  if (page === 'status') loadStatus();
}

// ── Tooltips ──
function initTooltips() {
  const tips = {
    status: t('tooltipStatus'),
    models: t('tooltipModels'),
    channels: t('tooltipChannels'),
    chat: t('tooltipChat'),
    logs: t('tooltipLogs'),
    settings: t('tooltipSettings'),
  };
  document.querySelectorAll('.nav-item').forEach(btn => {
    const page = btn.dataset.page;
    if (tips[page]) btn.title = tips[page];
  });
}

// ── Confirm Dialog ──
function showConfirmDialog(title, message) {
  return new Promise((resolve) => {
    document.getElementById('confirm-dialog-title').textContent = title;
    document.getElementById('confirm-dialog-message').textContent = message;
    document.getElementById('confirm-dialog').style.display = 'flex';
    confirmCallback = resolve;
  });
}
function hideConfirmDialog(result) {
  document.getElementById('confirm-dialog').style.display = 'none';
  if (confirmCallback) { confirmCallback(result); confirmCallback = null; }
}

// ── Loading State Helper ──
function setButtonLoading(btn, loading, originalText) {
  if (loading) {
    btn._originalText = btn.textContent;
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> ' + (originalText || t('loading'));
  } else {
    btn.disabled = false;
    btn.textContent = btn._originalText || originalText || '';
  }
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
    updateCheck('check-node', false, t('nodeNotInstalled'));
    showEnvAction(t('needNode'), async () => {
      api.openExternal('https://nodejs.org/');
    }, t('downloadNode'));
    return;
  }
  if (env.openclaw.installed) {
    updateCheck('check-openclaw', true, env.openclaw.version);
  } else {
    updateCheck('check-openclaw', 'warn', t('openclawNotInstalled'));
    showEnvAction(t('installing'), async () => {
      const btn = document.querySelector('#env-actions button');
      btn.disabled = true;
      btn.textContent = t('installing');
      updateCheck('check-openclaw', 'loading', t('installing'));
      try {
        const result = await api.installOpenclaw();
        if (result.success) {
          updateCheck('check-openclaw', true, t('installSuccess'));
          document.getElementById('btn-step1-next').disabled = false;
          document.getElementById('env-actions').style.display = 'none';
        } else {
          updateCheck('check-openclaw', false, t('installFailed'));
          btn.disabled = false;
          btn.textContent = t('retryInstall');
        }
      } catch (e) {
        updateCheck('check-openclaw', false, t('installFailed') + ': ' + e.message);
        btn.disabled = false;
        btn.textContent = t('retryInstall');
      }
    }, t('installOpenclaw'));
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

// ── Wizard Navigation ──
function wizardNext(step) {
  document.querySelectorAll('.wizard-step').forEach(s => s.style.display = 'none');
  document.getElementById(`step-${step}`).style.display = 'block';
  // Update progress bar
  for (let i = 1; i <= 3; i++) {
    const stepEl = document.getElementById(`progress-step-${i}`);
    const lineEl = document.getElementById(`progress-line-${i}`);
    if (i <= step) {
      stepEl.classList.add('active');
      if (i < step) stepEl.classList.add('completed');
      else stepEl.classList.remove('completed');
    } else {
      stepEl.classList.remove('active', 'completed');
    }
    if (lineEl) {
      if (i < step) lineEl.classList.add('active');
      else lineEl.classList.remove('active');
    }
  }
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

// ── Input Validation ──
function validateApiKey(value, type) {
  if (!value || value.trim() === '') return t('apiKeyRequired');
  if (value.trim().length < 8) return 'API Key 太短，请检查';
  if (type === 'gemini' && !value.startsWith('AIza')) return 'Gemini API Key 通常以 AIza 开头';
  return null;
}

// ── Test Connection (Wizard) ──
async function testWizardConnection() {
  const btn = document.getElementById('btn-test-connection');
  const resultEl = document.getElementById('test-connection-result');
  // Find first enabled model
  let testParams = null;
  if (document.getElementById('enable-claude')?.checked) {
    const type = document.getElementById('claude-type').value;
    const apiKey = document.getElementById('claude-api-key').value.trim();
    if (apiKey) {
      const baseUrl = type === 'proxy' ? document.getElementById('claude-base-url').value.trim() : 'https://api.anthropic.com';
      testParams = { baseUrl, apiKey, apiFormat: 'anthropic-messages' };
    }
  }
  if (!testParams && document.getElementById('enable-codex')?.checked) {
    const type = document.getElementById('codex-type').value;
    const apiKey = document.getElementById('codex-api-key').value.trim();
    if (apiKey) {
      const baseUrl = type === 'proxy' ? document.getElementById('codex-base-url').value.trim() : 'https://api.openai.com';
      testParams = { baseUrl, apiKey, apiFormat: 'openai-responses' };
    }
  }
  if (!testParams && document.getElementById('enable-gemini')?.checked) {
    const apiKey = document.getElementById('gemini-api-key').value.trim();
    if (apiKey) testParams = { baseUrl: '', apiKey, apiFormat: 'gemini' };
  }
  if (!testParams && document.getElementById('enable-glm')?.checked) {
    const apiKey = document.getElementById('glm-api-key').value.trim();
    if (apiKey) testParams = { baseUrl: '', apiKey, apiFormat: 'zhipu' };
  }
  if (!testParams) {
    resultEl.textContent = t('testNoModel');
    resultEl.className = 'test-result test-error';
    return;
  }
  setButtonLoading(btn, true, t('testing'));
  resultEl.textContent = '';
  resultEl.className = 'test-result';
  try {
    const result = await api.testConnection(testParams);
    if (result.success) {
      resultEl.textContent = t('testSuccess');
      resultEl.className = 'test-result test-success';
    } else {
      resultEl.textContent = t('testFailed', { error: result.error });
      resultEl.className = 'test-result test-error';
    }
  } catch (e) {
    resultEl.textContent = t('testFailed', { error: e.message });
    resultEl.className = 'test-result test-error';
  }
  setButtonLoading(btn, false, '🔗 ' + t('testConnection'));
}

// ── Collect Model Data (Wizard) ──
function collectModelData() {
  const models = [];
  if (document.getElementById('enable-claude')?.checked) {
    const type = document.getElementById('claude-type').value;
    const apiKey = document.getElementById('claude-api-key').value;
    const model = document.getElementById('claude-model').value;
    if (!apiKey) return { error: t('claudeNoKey') };
    if (type === 'proxy') {
      const baseUrl = document.getElementById('claude-base-url').value;
      if (!baseUrl) return { error: t('claudeNoProxy') };
      models.push({ type: 'proxy', providerId: 'apexyy-claude', baseUrl, apiFormat: 'anthropic-messages', apiKey, primaryModelId: model, models: [] });
    } else {
      models.push({ type: 'official', envKey: 'ANTHROPIC_API_KEY', apiKey, modelRef: `anthropic/${model}` });
    }
  }
  if (document.getElementById('enable-codex')?.checked) {
    const type = document.getElementById('codex-type').value;
    const apiKey = document.getElementById('codex-api-key').value;
    const model = document.getElementById('codex-model').value;
    if (!apiKey) return { error: t('codexNoKey') };
    if (type === 'proxy') {
      const baseUrl = document.getElementById('codex-base-url').value;
      if (!baseUrl) return { error: t('codexNoProxy') };
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
    if (!apiKey) return { error: t('geminiNoKey') };
    models.push({ type: 'official', envKey: 'GEMINI_API_KEY', apiKey, modelRef: `google/${document.getElementById('gemini-model').value}` });
  }
  if (document.getElementById('enable-glm')?.checked) {
    const apiKey = document.getElementById('glm-api-key').value;
    if (!apiKey) return { error: t('glmNoKey') };
    models.push({ type: 'official', envKey: 'ZAI_API_KEY', apiKey, modelRef: `zai/${document.getElementById('glm-model').value}` });
  }
  return { models };
}

// ── Finish Wizard ──
async function finishWizard() {
  const collected = collectModelData();
  if (collected.error) { showToast(collected.error, 'error'); return; }
  if (collected.models.length === 0) { showToast(t('needOneModel'), 'error'); return; }
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
    showToast(t('configSaving'));
  } catch (e) {
    showToast(t('configSaveFailedWizard', { error: e.message }), 'error');
  }
}

// ── Status Page ──
async function loadStatus(config) {
  try {
    if (!config) config = await api.getConfig();
    if (!config) return;
    currentConfig = config;
    const primary = config.agents?.defaults?.model?.primary || t('notConfigured');
    document.getElementById('status-model').textContent = primary;
    const providerName = primary.split('/')[0] || '';
    document.getElementById('status-model-provider').textContent = providerName ? `Provider: ${providerName}` : '';
    const fallbacks = config.agents?.defaults?.model?.fallbacks || [];
    document.getElementById('status-fallbacks').textContent = fallbacks.length > 0 ? fallbacks.join(' → ') : t('none');
    const channels = [];
    if (config.telegram) channels.push('Telegram');
    if (config.discord) channels.push('Discord');
    channels.push('WebChat');
    document.getElementById('status-channels').textContent = channels.join(', ');
    const providers = config.models?.providers || {};
    const providerCount = Object.keys(providers).length;
    document.getElementById('status-providers').textContent = providerCount.toString();
    const listEl = document.getElementById('status-provider-list');
    if (providerCount > 0) {
      let html = `<h3 style="margin-bottom:12px;">${t('providerList')}</h3>`;
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
      listEl.innerHTML = `<p class="hint">${t('noProviderHint')}</p>`;
    }
    const status = await api.getGatewayStatus();
    updateGatewayIndicator(status);
    loadSystemInfo();
    refreshStatusLogs();
  } catch (e) {
    console.error('loadStatus error:', e);
  }
}

// ── System Info ──
async function loadSystemInfo() {
  try {
    const info = await api.getSystemInfo();
    document.getElementById('sysinfo-node').textContent = info.nodeVersion || '-';
    document.getElementById('sysinfo-openclaw').textContent = info.openclawVersion || '-';
    document.getElementById('sysinfo-os').textContent = info.os || '-';
    if (info.gatewayUptime) {
      gatewayStartedAt = Date.now() - info.gatewayUptime;
      startUptimeTimer();
    } else {
      document.getElementById('sysinfo-uptime').textContent = t('gatewayStopped');
    }
  } catch (e) {
    console.error('loadSystemInfo error:', e);
  }
}

function startUptimeTimer() {
  if (uptimeInterval) clearInterval(uptimeInterval);
  updateUptimeDisplay();
  uptimeInterval = setInterval(updateUptimeDisplay, 60000);
}

function stopUptimeTimer() {
  if (uptimeInterval) { clearInterval(uptimeInterval); uptimeInterval = null; }
  document.getElementById('sysinfo-uptime').textContent = t('gatewayStopped');
}

function updateUptimeDisplay() {
  if (!gatewayStartedAt) return;
  const ms = Date.now() - gatewayStartedAt;
  const minutes = Math.floor(ms / 60000);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  const el = document.getElementById('sysinfo-uptime');
  if (days > 0) el.textContent = t('uptimeDays', { d: days, h: hours % 24, m: minutes % 60 });
  else if (hours > 0) el.textContent = t('uptimeHours', { h: hours, m: minutes % 60 });
  else el.textContent = t('uptimeMinutes', { m: minutes || '<1' });
}

// ── Copy Diagnostics ──
async function copyDiagnostics() {
  try {
    const info = await api.getSystemInfo();
    const config = currentConfig || {};
    const providers = config.models?.providers || {};
    const primary = config.agents?.defaults?.model?.primary || 'N/A';
    const text = [
      '=== OpenClaw Desktop 诊断信息 ===',
      `Node.js: ${info.nodeVersion}`,
      `Electron: ${info.electronVersion}`,
      `OpenClaw: ${info.openclawVersion}`,
      `OS: ${info.os}`,
      `Gateway: ${gatewayRunning ? 'running' : 'stopped'}`,
      `Primary Model: ${primary}`,
      `Providers: ${Object.keys(providers).join(', ') || 'none'}`,
      `Channels: ${[config.telegram ? 'telegram' : '', config.discord ? 'discord' : '', 'webchat'].filter(Boolean).join(', ')}`,
      `Time: ${new Date().toISOString()}`,
    ].join('\n');
    await navigator.clipboard.writeText(text);
    showToast(t('diagnosticsCopied'), 'success');
  } catch (e) {
    showToast('复制失败: ' + e.message, 'error');
  }
}

// ── Status Logs ──
async function refreshStatusLogs() {
  try {
    const result = await api.readGatewayLogs();
    const el = document.getElementById('status-log-output');
    if (result.success) {
      const lines = result.content.split('\n');
      el.textContent = lines.slice(-50).join('\n');
      el.scrollTop = el.scrollHeight;
    } else {
      el.textContent = '(暂无日志)';
    }
  } catch (e) {
    console.error('refreshStatusLogs error:', e);
  }
}

// ── Gateway Control ──
async function startGateway() {
  const btn = document.getElementById('btn-start');
  try {
    setButtonLoading(btn, true, t('starting'));
    const result = await api.startGateway();
    if (result.success) {
      updateGatewayIndicator('running');
      gatewayStartedAt = Date.now();
      startUptimeTimer();
    } else {
      updateGatewayIndicator('error');
      document.getElementById('status-gateway-value').textContent = `错误: ${result.error}`;
      showToast(t('gatewayStartFailed', { error: result.error }), 'error');
    }
  } catch (e) {
    updateGatewayIndicator('error');
    showToast(t('gatewayStartFailed', { error: e.message }), 'error');
  }
  setButtonLoading(btn, false, t('start'));
}

async function stopGateway() {
  const btn = document.getElementById('btn-stop');
  try {
    setButtonLoading(btn, true, t('stopping'));
    await api.stopGateway();
    updateGatewayIndicator('stopped');
    gatewayStartedAt = null;
    stopUptimeTimer();
    showToast(t('gatewayStopping'));
  } catch (e) {
    showToast(t('gatewayStopFailed', { error: e.message }), 'error');
  }
  setButtonLoading(btn, false, t('stop'));
}

async function restartGateway() {
  const btn = document.getElementById('btn-restart');
  try {
    setButtonLoading(btn, true, t('restarting'));
    showToast(t('gatewayRestarting'));
    await api.stopGateway();
    updateGatewayIndicator('starting');
    await new Promise(r => setTimeout(r, 1000));
    const result = await api.startGateway();
    if (result.success) {
      updateGatewayIndicator('running');
      gatewayStartedAt = Date.now();
      startUptimeTimer();
      showToast(t('gatewayRestarted'));
    } else {
      updateGatewayIndicator('error');
      showToast(t('gatewayRestartFailed', { error: result.error }), 'error');
    }
  } catch (e) {
    showToast(t('gatewayRestartFailed', { error: e.message }), 'error');
  }
  setButtonLoading(btn, false, t('restart'));
}

function updateGatewayIndicator(status) {
  const indicator = document.getElementById('gateway-indicator');
  const statusValue = document.getElementById('status-gateway-value');
  const btnStart = document.getElementById('btn-start');
  const btnStop = document.getElementById('btn-stop');
  const btnRestart = document.getElementById('btn-restart');
  indicator.className = `indicator ${status}`;
  const labels = { stopped: t('gatewayStopped'), starting: t('gatewayStarting'), running: t('gatewayRunning'), error: t('gatewayError') };
  indicator.querySelector('.text').textContent = labels[status] || status;
  if (statusValue) statusValue.textContent = labels[status] || status;
  gatewayRunning = status === 'running';
  if (status === 'running') {
    btnStart.style.display = 'none';
    btnStop.style.display = 'inline-block';
    if (btnRestart) btnRestart.style.display = 'inline-block';
    if (!gatewayStartedAt) { gatewayStartedAt = Date.now(); startUptimeTimer(); }
  } else {
    btnStart.style.display = 'inline-block';
    btnStop.style.display = 'none';
    if (btnRestart) btnRestart.style.display = 'none';
    if (status === 'stopped') { gatewayStartedAt = null; stopUptimeTimer(); }
  }
  // Update chat status
  updateChatStatus(status === 'running' ? 'connected' : 'disconnected');
}

// ── Models Page ──
async function loadModelsPage() {
  try {
    const config = await api.getConfig();
    if (!config) { document.getElementById('provider-list').innerHTML = `<p class="hint">${t('notConfiguredYet')}</p>`; return; }
    currentConfig = config;
    const primary = config.agents?.defaults?.model?.primary || t('notConfigured');
    const fallbacks = config.agents?.defaults?.model?.fallbacks || [];
    document.getElementById('models-primary').textContent = primary;
    document.getElementById('models-fallbacks').textContent = fallbacks.length > 0 ? fallbacks.join(' → ') : t('none');
    const providers = config.models?.providers || {};
    const listEl = document.getElementById('provider-list');
    if (Object.keys(providers).length === 0) {
      listEl.innerHTML = `<p class="hint">${t('noProviderAdd')}</p>`;
      return;
    }
    let html = '';
    for (const [id, p] of Object.entries(providers)) {
      const isPrimary = primary.startsWith(id + '/');
      html += `<div class="provider-card ${isPrimary ? 'is-primary' : ''}">
        <div class="provider-header">
          <div class="provider-name">${esc(id)} ${isPrimary ? '<span class="badge-primary">主模型</span>' : ''}</div>
          <div class="provider-actions">
            ${!isPrimary ? `<button class="btn small" onclick="setPrimaryProvider('${esc(id)}')">${t('setPrimary')}</button>` : ''}
            <button class="btn small danger" onclick="deleteProvider('${esc(id)}')">${t('delete')}</button>
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
    showToast(t('loadModelsFailed', { error: e.message }), 'error');
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
  if (!id) { showToast(t('providerIdRequired'), 'error'); return; }
  if (!/^[a-zA-Z0-9-]+$/.test(id)) { showToast(t('providerIdInvalid'), 'error'); return; }
  if (!baseUrl) { showToast(t('baseUrlRequired'), 'error'); return; }
  if (!apiKey) { showToast(t('apiKeyRequired'), 'error'); return; }
  const btn = document.getElementById('btn-add-provider');
  setButtonLoading(btn, true, t('saving'));
  try {
    const config = await api.getConfig();
    if (!config.models) config.models = { mode: 'merge', providers: {} };
    if (!config.models.providers) config.models.providers = {};
    if (config.models.providers[id]) { showToast(t('providerIdExists'), 'error'); setButtonLoading(btn, false, t('add')); return; }
    const providerConfig = { baseUrl, apiKey, auth: 'api-key', api: apiFormat, headers: {}, authHeader: false };
    if (apiFormat === 'anthropic-messages') { providerConfig.models = []; }
    else { providerConfig.models = modelId ? [{ id: modelId, name: modelId, reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 }] : []; }
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
    showToast(t('providerAdded'));
    document.getElementById('new-provider-id').value = '';
    document.getElementById('new-provider-url').value = '';
    document.getElementById('new-provider-key').value = '';
    document.getElementById('new-provider-model-id').value = '';
    document.getElementById('new-provider-set-primary').checked = false;
  } catch (e) {
    showToast(t('addFailed', { error: e.message }), 'error');
  }
  setButtonLoading(btn, false, t('add'));
}

async function deleteProvider(id) {
  const confirmed = await showConfirmDialog(t('delete'), t('confirmDeleteProvider', { id }));
  if (!confirmed) return;
  try {
    const config = await api.getConfig();
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
      await api.saveConfig(config);
      currentConfig = config;
      loadModelsPage();
      showToast(t('providerDeleted'));
    }
  } catch (e) {
    showToast(t('deleteFailed', { error: e.message }), 'error');
  }
}

async function setPrimaryProvider(id) {
  try {
    const config = await api.getConfig();
    const provider = config.models?.providers?.[id];
    if (!provider) return;
    let modelId = '';
    if (provider.models && provider.models.length > 0) {
      modelId = provider.models[0].id || provider.models[0];
    } else {
      modelId = prompt(t('enterModelId'));
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
      config.agents.defaults.model.fallbacks = config.agents.defaults.model.fallbacks.filter(f => f !== newPrimary);
      config.agents.defaults.model.fallbacks.unshift(oldPrimary);
    }
    await api.saveConfig(config);
    currentConfig = config;
    loadModelsPage();
    showToast(t('primarySwitched', { model: newPrimary }));
  } catch (e) {
    showToast(t('switchFailed', { error: e.message }), 'error');
  }
}

// ── Channels Page ──
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
          <button class="btn small danger" onclick="deleteChannel('telegram')">${t('delete')}</button>
        </div>
        <div class="provider-details">
          <div class="info-row"><span class="info-label">Bot Token</span><span class="info-value">${token ? '••••' + token.slice(-6) : 'N/A'}</span></div>
          <div class="info-row"><span class="info-label">${t('allowedUsers')}</span><span class="info-value">${users.length > 0 ? users.join(', ') : t('allUsers')}</span></div>
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
          <button class="btn small danger" onclick="deleteChannel('discord')">${t('delete')}</button>
        </div>
        <div class="provider-details">
          <div class="info-row"><span class="info-label">Bot Token</span><span class="info-value">${token ? '••••' + token.slice(-6) : 'N/A'}</span></div>
        </div>
      </div>`;
    }
    html += `<div class="channel-manage-card">
      <div class="channel-manage-header">
        <span class="channel-manage-icon">🌐</span>
        <span class="channel-manage-name">WebChat</span>
        <span class="badge" style="background:var(--green);">${t('builtIn')}</span>
      </div>
      <div class="provider-details">
        <div class="info-row"><span class="info-label">状态</span><span class="info-value">${t('alwaysAvailable')}</span></div>
      </div>
    </div>`;
    if (!hasChannels) {
      html = `<p class="hint" style="margin-bottom:16px;">${t('noChannelHint')}</p>` + html;
    }
    listEl.innerHTML = html;
  } catch (e) {
    showToast(t('loadChannelsFailed', { error: e.message }), 'error');
  }
}

function showAddChannelDialog() { document.getElementById('add-channel-dialog').style.display = 'flex'; onChannelTypeChange(); }
function hideAddChannelDialog() { document.getElementById('add-channel-dialog').style.display = 'none'; }

function onChannelTypeChange() {
  const type = document.getElementById('new-channel-type').value;
  const helpEl = document.getElementById('new-channel-help');
  const usersGroup = document.getElementById('channel-allowed-users-group');
  if (type === 'telegram') {
    helpEl.textContent = t('telegramHelp');
    usersGroup.style.display = 'block';
  } else {
    helpEl.textContent = t('discordHelp');
    usersGroup.style.display = 'none';
  }
}

async function addChannel() {
  const type = document.getElementById('new-channel-type').value;
  const token = document.getElementById('new-channel-token').value.trim();
  if (!token) { showToast(t('tokenRequired'), 'error'); return; }
  const btn = document.getElementById('btn-add-channel');
  setButtonLoading(btn, true, t('saving'));
  try {
    const config = await api.getConfig();
    const name = type === 'telegram' ? 'Telegram' : 'Discord';
    if (type === 'telegram') {
      if (config.telegram) { showToast(t('channelExists', { name }), 'error'); setButtonLoading(btn, false, t('add')); return; }
      const allowedStr = document.getElementById('new-channel-allowed-users').value.trim();
      const allowedUsers = allowedStr ? allowedStr.split(',').map(s => s.trim()).filter(Boolean) : [];
      config.telegram = { token, allowedUsers };
    } else if (type === 'discord') {
      if (config.discord) { showToast(t('channelExists', { name }), 'error'); setButtonLoading(btn, false, t('add')); return; }
      config.discord = { token };
    }
    await api.saveConfig(config);
    currentConfig = config;
    hideAddChannelDialog();
    loadChannelsPage();
    showToast(t('channelAdded', { name }));
    document.getElementById('new-channel-token').value = '';
    document.getElementById('new-channel-allowed-users').value = '';
  } catch (e) {
    showToast(t('addFailed', { error: e.message }), 'error');
  }
  setButtonLoading(btn, false, t('add'));
}

async function deleteChannel(type) {
  const name = type === 'telegram' ? 'Telegram' : 'Discord';
  const confirmed = await showConfirmDialog(t('delete'), t('confirmDeleteChannel', { name }));
  if (!confirmed) return;
  try {
    const config = await api.getConfig();
    delete config[type];
    await api.saveConfig(config);
    currentConfig = config;
    loadChannelsPage();
    showToast(t('channelDeleted', { name }));
  } catch (e) {
    showToast(t('deleteFailed', { error: e.message }), 'error');
  }
}

// ── Settings / JSON Editor ──
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
    showToast(t('configLoadFailed', { error: e.message }), 'error');
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
    errorEl.textContent = t('jsonError', { error: e.message });
    errorEl.style.display = 'block';
  }
}

async function saveJsonEditor() {
  const editor = document.getElementById('json-editor');
  const errorEl = document.getElementById('json-editor-error');
  const content = editor.value;
  try { JSON.parse(content); } catch (e) {
    errorEl.textContent = t('jsonSaveError', { error: e.message });
    errorEl.style.display = 'block';
    return;
  }
  const btn = document.getElementById('btn-save-config');
  setButtonLoading(btn, true, t('saving'));
  try {
    const result = await api.writeConfigRaw(content);
    if (result.success) {
      errorEl.style.display = 'none';
      showToast(t('configSaved'));
    } else {
      errorEl.textContent = t('configSaveFailed', { error: result.error });
      errorEl.style.display = 'block';
    }
  } catch (e) {
    showToast(t('configSaveFailed', { error: e.message }), 'error');
  }
  setButtonLoading(btn, false, t('saveConfig'));
}

// ── Chat ──
function updateChatStatus(status) {
  const el = document.getElementById('chat-status');
  if (!el) return;
  const dot = el.querySelector('.dot');
  const text = el.querySelector('.chat-status-text');
  el.className = `chat-status chat-${status}`;
  if (status === 'connected') text.textContent = t('chatConnected');
  else if (status === 'connecting') text.textContent = t('chatConnecting');
  else text.textContent = t('chatDisconnected');
}

async function loadChatFrame() {
  updateChatStatus('connecting');
  try {
    const { url, token } = await api.getGatewayUrl();
    const frame = document.getElementById('chat-frame');
    frame.src = `${url}/?token=${token}`;
    frame.onload = () => {
      if (gatewayRunning) updateChatStatus('connected');
    };
    frame.onerror = () => { updateChatStatus('disconnected'); };
  } catch (e) {
    console.error('loadChatFrame error:', e);
    updateChatStatus('disconnected');
  }
}

async function openWebChat() {
  try {
    const { url, token } = await api.getGatewayUrl();
    api.openExternal(`${url}/?token=${token}`);
  } catch (e) {
    showToast(t('chatOpenFailed', { error: e.message }), 'error');
  }
}

async function openWebChatExternal() {
  await openWebChat();
}

// ── Logs ──
function appendLog(text) {
  const el = document.getElementById('log-output');
  if (el) {
    el.textContent += text;
    el.scrollTop = el.scrollHeight;
  }
  // Also append to status logs if visible
  const statusLog = document.getElementById('status-log-output');
  if (statusLog) {
    statusLog.textContent += text;
    // Keep only last 50 lines
    const lines = statusLog.textContent.split('\n');
    if (lines.length > 50) statusLog.textContent = lines.slice(-50).join('\n');
    statusLog.scrollTop = statusLog.scrollHeight;
  }
}

// ── Toast Notifications ──
function showToast(message, type = 'info') {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
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
