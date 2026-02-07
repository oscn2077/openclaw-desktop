// ── State ──
let currentPage = 'status';
let env = null;
let gatewayRunning = false;

// ── Init ──
document.addEventListener('DOMContentLoaded', async () => {
  // Check if first run
  const config = await api.getConfig();
  if (!config) {
    showPage('wizard');
    runEnvCheck();
  } else {
    showPage('status');
    loadStatus(config);
  }

  // Listen for gateway status changes
  api.onGatewayStatus((status) => {
    updateGatewayIndicator(status);
  });

  api.onGatewayLog((log) => {
    appendLog(log);
  });
});

// ── Navigation ──
function showPage(page) {
  // Hide all pages
  document.querySelectorAll('.page').forEach(p => p.style.display = 'none');
  // Show target
  const target = document.getElementById(`page-${page}`);
  if (target) target.style.display = 'block';
  // Update nav
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const navBtn = document.querySelector(`.nav-item[data-page="${page}"]`);
  if (navBtn) navBtn.classList.add('active');
  currentPage = page;

  // Load chat iframe when switching to chat
  if (page === 'chat') loadChatFrame();
}

// ── Environment Check ──
async function runEnvCheck() {
  env = await api.detectEnvironment();

  // OS
  updateCheck('check-os', true, env.os.name);

  // Node.js
  if (env.node.installed) {
    updateCheck('check-node', true, env.node.version);
  } else {
    updateCheck('check-node', false, '未安装');
    showEnvAction('需要安装 Node.js (v18+)', async () => {
      api.openExternal('https://nodejs.org/');
    }, '下载 Node.js');
    return;
  }

  // OpenClaw
  if (env.openclaw.installed) {
    updateCheck('check-openclaw', true, env.openclaw.version);
  } else {
    updateCheck('check-openclaw', 'warn', '未安装 — 点击下方按钮安装');
    showEnvAction('安装 OpenClaw...', async () => {
      const btn = document.querySelector('#env-actions button');
      btn.disabled = true;
      btn.textContent = '安装中...';
      updateCheck('check-openclaw', 'loading', '正在安装...');

      const result = await api.installOpenclaw();
      if (result.success) {
        updateCheck('check-openclaw', true, '安装成功');
        document.getElementById('btn-step1-next').disabled = false;
        document.getElementById('env-actions').style.display = 'none';
      } else {
        updateCheck('check-openclaw', false, '安装失败');
        btn.disabled = false;
        btn.textContent = '重试安装';
        showEnvAction(`安装失败: ${result.error || result.output?.slice(-200)}`, null);
      }
    }, '一键安装 OpenClaw');
    return;
  }

  // All good
  document.getElementById('btn-step1-next').disabled = false;
}

function updateCheck(id, status, text) {
  const el = document.getElementById(id);
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
}

// ── Model Toggle ──
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

// ── Channel Toggle ──
function toggleChannel(name) {
  const checked = document.getElementById(`enable-${name}`).checked;
  const card = checked
    ? document.querySelector(`#enable-${name}`).closest('.channel-card')
    : document.querySelector(`#enable-${name}`).closest('.channel-card');
  const body = card.querySelector('.channel-body');
  if (body) body.style.display = checked ? 'block' : 'none';
}

// ── Collect Model Data ──
function collectModelData() {
  const models = [];

  // Collect Claude
  if (document.getElementById('enable-claude')?.checked) {
    const type = document.getElementById('claude-type').value;
    const apiKey = document.getElementById('claude-api-key').value;
    const model = document.getElementById('claude-model').value;

    if (!apiKey) return { error: 'Claude 已启用但未填写 API Key' };

    if (type === 'proxy') {
      const baseUrl = document.getElementById('claude-base-url').value;
      if (!baseUrl) return { error: 'Claude 中转模式需要填写中转地址' };
      models.push({
        type: 'proxy',
        providerId: 'apexyy-claude',
        baseUrl,
        apiFormat: 'anthropic-messages',
        apiKey,
        primaryModelId: model,
        models: [],  // Claude proxy auto-detects models
      });
    } else {
      models.push({
        type: 'official',
        envKey: 'ANTHROPIC_API_KEY',
        apiKey,
        modelRef: `anthropic/${model}`,
      });
    }
  }

  // Collect Codex (OpenAI)
  if (document.getElementById('enable-codex')?.checked) {
    const type = document.getElementById('codex-type').value;
    const apiKey = document.getElementById('codex-api-key').value;
    const model = document.getElementById('codex-model').value;

    if (!apiKey) return { error: 'Codex 已启用但未填写 API Key' };

    if (type === 'proxy') {
      const baseUrl = document.getElementById('codex-base-url').value;
      if (!baseUrl) return { error: 'Codex 中转模式需要填写中转地址' };

      // Build model declarations for OpenAI/Codex proxy
      const codexModels = {
        'gpt-5.2': { id: 'gpt-5.2', name: 'GPT 5.2', reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 },
        'gpt-codex-5.3': { id: 'gpt-codex-5.3', name: 'GPT Codex 5.3', reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 },
        'gpt-4.1': { id: 'gpt-4.1', name: 'GPT 4.1', reasoning: false, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 },
        'o3': { id: 'o3', name: 'o3', reasoning: true, input: ['text', 'image'], contextWindow: 200000, maxTokens: 100000 },
        'o4-mini': { id: 'o4-mini', name: 'o4-mini', reasoning: true, input: ['text', 'image'], contextWindow: 200000, maxTokens: 100000 },
      };

      models.push({
        type: 'proxy',
        providerId: 'apexyy-codex',
        baseUrl,
        apiFormat: 'openai-responses',
        apiKey,
        primaryModelId: model,
        models: [codexModels[model] || { id: model, name: model, reasoning: true, input: ['text', 'image'], contextWindow: 128000, maxTokens: 32768 }],
      });
    } else {
      models.push({
        type: 'official',
        envKey: 'OPENAI_API_KEY',
        apiKey,
        modelRef: `openai/${model}`,
      });
    }
  }

  // Collect Gemini
  if (document.getElementById('enable-gemini')?.checked) {
    const apiKey = document.getElementById('gemini-api-key').value;
    if (!apiKey) return { error: 'Gemini 已启用但未填写 API Key' };
    const model = document.getElementById('gemini-model').value;
    models.push({
      type: 'official',
      envKey: 'GEMINI_API_KEY',
      apiKey,
      modelRef: `google/${model}`,
    });
  }

  // Collect GLM
  if (document.getElementById('enable-glm')?.checked) {
    const apiKey = document.getElementById('glm-api-key').value;
    if (!apiKey) return { error: 'GLM 已启用但未填写 API Key' };
    const model = document.getElementById('glm-model').value;
    models.push({
      type: 'official',
      envKey: 'ZAI_API_KEY',
      apiKey,
      modelRef: `zai/${model}`,
    });
  }

  return { models };
}

// ── Finish Wizard ──
async function finishWizard() {
  const collected = collectModelData();
  if (collected.error) {
    alert(collected.error);
    return;
  }
  if (collected.models.length === 0) {
    alert('请至少配置一个 AI 模型');
    return;
  }

  const wizardData = { models: collected.models, channels: [] };

  // Collect Telegram
  if (document.getElementById('enable-telegram')?.checked) {
    wizardData.channels.push({
      type: 'telegram',
      botToken: document.getElementById('telegram-token').value,
    });
  }

  // Collect Discord
  if (document.getElementById('enable-discord')?.checked) {
    wizardData.channels.push({
      type: 'discord',
      botToken: document.getElementById('discord-token').value,
    });
  }

  // Generate and save config
  const { config, envVars } = await api.generateConfig(wizardData);
  await api.saveConfig(config);
  await api.saveEnv(envVars);

  // Switch to status page
  showPage('status');
  loadStatus(config);

  // Auto-start gateway
  startGateway();
}

// ── Status Page ──
async function loadStatus(config) {
  if (!config) config = await api.getConfig();
  if (!config) return;

  // Model
  const primary = config.agents?.defaults?.model?.primary || '未配置';
  document.getElementById('status-model').textContent = primary;

  // Channels
  const channels = [];
  if (config.telegram) channels.push('Telegram');
  if (config.discord) channels.push('Discord');
  channels.push('WebChat');
  document.getElementById('status-channels').textContent = channels.join(', ');

  // Gateway status
  const status = await api.getGatewayStatus();
  updateGatewayIndicator(status);
}

// ── Gateway Control ──
async function startGateway() {
  document.getElementById('btn-start').disabled = true;
  document.getElementById('btn-start').textContent = '启动中...';
  const result = await api.startGateway();
  if (result.success) {
    updateGatewayIndicator('running');
  } else {
    updateGatewayIndicator('error');
    document.getElementById('status-gateway-value').textContent = `错误: ${result.error}`;
  }
  document.getElementById('btn-start').disabled = false;
  document.getElementById('btn-start').textContent = '启动';
}

async function stopGateway() {
  await api.stopGateway();
  updateGatewayIndicator('stopped');
}

function updateGatewayIndicator(status) {
  const indicator = document.getElementById('gateway-indicator');
  const statusValue = document.getElementById('status-gateway-value');
  const btnStart = document.getElementById('btn-start');
  const btnStop = document.getElementById('btn-stop');

  indicator.className = `indicator ${status}`;

  const labels = {
    stopped: '已停止',
    starting: '启动中...',
    running: '运行中',
    error: '错误',
  };

  indicator.querySelector('.text').textContent = labels[status] || status;
  if (statusValue) statusValue.textContent = labels[status] || status;

  if (status === 'running') {
    btnStart.style.display = 'none';
    btnStop.style.display = 'inline-block';
  } else {
    btnStart.style.display = 'inline-block';
    btnStop.style.display = 'none';
  }
}

// ── Chat ──
async function loadChatFrame() {
  const { url, token } = await api.getGatewayUrl();
  const frame = document.getElementById('chat-frame');
  frame.src = `${url}/?token=${token}`;
}

async function openWebChat() {
  const { url, token } = await api.getGatewayUrl();
  api.openExternal(`${url}/?token=${token}`);
}

// ── Logs ──
function appendLog(text) {
  const el = document.getElementById('log-output');
  if (el) {
    el.textContent += text;
    el.scrollTop = el.scrollHeight;
  }
}
