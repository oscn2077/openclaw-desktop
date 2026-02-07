const { app, BrowserWindow, ipcMain, Tray, Menu, shell, dialog } = require('electron');
const path = require('path');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const os = require('os');

// ── Globals ──
let mainWindow = null;
let tray = null;
let gatewayProcess = null;
let gatewayStatus = 'stopped'; // stopped | starting | running | error

// ── Paths ──
const OPENCLAW_HOME = path.join(os.homedir(), '.openclaw');
const CONFIG_PATH = path.join(OPENCLAW_HOME, 'openclaw.json');
const ENV_PATH = path.join(OPENCLAW_HOME, '.env');
const WORKSPACE_PATH = path.join(OPENCLAW_HOME, 'workspace');

// ── App Ready ──
app.whenReady().then(() => {
  createWindow();
  // createTray();  // TODO: system tray icon
});

app.on('window-all-closed', () => {
  // Don't quit on window close — keep running in tray
  // For now, quit entirely
  stopGateway();
  app.quit();
});

// ── Window ──
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 960,
    height: 700,
    minWidth: 800,
    minHeight: 600,
    title: 'OpenClaw Desktop',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    // frameless with custom titlebar later
  });

  mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));

  // Open DevTools in dev mode
  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools();
  }
}

// ── Environment Detection ──
ipcMain.handle('detect-environment', async () => {
  const result = {
    os: {
      platform: process.platform,
      arch: process.arch,
      version: os.release(),
      name: getOSName(),
    },
    node: { installed: false, version: null, path: null },
    openclaw: { installed: false, version: null, path: null },
    docker: { installed: false, version: null },
    configExists: fs.existsSync(CONFIG_PATH),
    workspaceExists: fs.existsSync(WORKSPACE_PATH),
  };

  // Check Node.js
  try {
    result.node.version = execSync('node --version', { encoding: 'utf8' }).trim();
    result.node.installed = true;
    result.node.path = execSync(process.platform === 'win32' ? 'where node' : 'which node', { encoding: 'utf8' }).trim().split('\n')[0];
  } catch (e) { /* not installed */ }

  // Check OpenClaw
  try {
    result.openclaw.version = execSync('openclaw --version', { encoding: 'utf8' }).trim();
    result.openclaw.installed = true;
    result.openclaw.path = execSync(process.platform === 'win32' ? 'where openclaw' : 'which openclaw', { encoding: 'utf8' }).trim().split('\n')[0];
  } catch (e) { /* not installed */ }

  // Check Docker
  try {
    result.docker.version = execSync('docker --version', { encoding: 'utf8' }).trim();
    result.docker.installed = true;
  } catch (e) { /* not installed */ }

  return result;
});

// ── Install OpenClaw ──
ipcMain.handle('install-openclaw', async (event) => {
  return new Promise((resolve, reject) => {
    const cmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
    const proc = spawn(cmd, ['install', '-g', 'openclaw@latest'], {
      env: { ...process.env },
      shell: true,
    });

    let output = '';
    proc.stdout.on('data', (d) => {
      output += d.toString();
      mainWindow.webContents.send('install-progress', d.toString());
    });
    proc.stderr.on('data', (d) => {
      output += d.toString();
      mainWindow.webContents.send('install-progress', d.toString());
    });
    proc.on('close', (code) => {
      if (code === 0) resolve({ success: true, output });
      else resolve({ success: false, output, code });
    });
    proc.on('error', (err) => resolve({ success: false, error: err.message }));
  });
});

// ── Config Management ──
ipcMain.handle('get-config', async () => {
  try {
    if (!fs.existsSync(CONFIG_PATH)) return null;
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch (e) {
    return null;
  }
});

ipcMain.handle('save-config', async (event, config) => {
  try {
    fs.mkdirSync(OPENCLAW_HOME, { recursive: true });
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
    return { success: true };
  } catch (e) {
    return { success: false, error: e.message };
  }
});

ipcMain.handle('save-env', async (event, envVars) => {
  try {
    fs.mkdirSync(OPENCLAW_HOME, { recursive: true });
    const lines = Object.entries(envVars)
      .filter(([k, v]) => v)
      .map(([k, v]) => `${k}=${v}`);
    fs.writeFileSync(ENV_PATH, lines.join('\n') + '\n');
    if (process.platform !== 'win32') {
      fs.chmodSync(ENV_PATH, 0o600);
    }
    return { success: true };
  } catch (e) {
    return { success: false, error: e.message };
  }
});

// ── Generate Config from Wizard ──
ipcMain.handle('generate-config', async (event, wizardData) => {
  const config = {
    agents: {
      defaults: {
        maxConcurrent: 4,
        subagents: { maxConcurrent: 8 },
        compaction: { mode: 'safeguard' },
        workspace: WORKSPACE_PATH,
        model: {
          primary: null,
          fallbacks: [],
        },
        models: {},
      },
    },
    gateway: {
      mode: 'local',
      auth: {
        mode: 'token',
        token: generateToken(),
      },
      port: 18789,
      bind: 'loopback',
    },
    models: {
      mode: 'merge',
      providers: {},
    },
  };

  const envVars = {};

  // Process models
  for (const model of wizardData.models) {
    if (model.type === 'proxy') {
      // Third-party proxy (中转)
      const providerId = model.providerId;
      const providerConfig = {
        baseUrl: model.baseUrl,
        apiKey: model.apiKey,
        auth: 'api-key',
        api: model.apiFormat || 'anthropic-messages',
        headers: {},
        authHeader: false,
      };

      // Claude proxy: empty models array (auto-detected)
      // OpenAI/Codex proxy: need explicit model declarations
      if (model.apiFormat === 'anthropic-messages') {
        providerConfig.models = [];
      } else {
        providerConfig.models = (model.models || []).map(m => ({
          id: m.id,
          name: m.name,
          reasoning: m.reasoning || false,
          input: m.input || ['text'],
          cost: m.cost || { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
          contextWindow: m.contextWindow || 128000,
          maxTokens: m.maxTokens || 32768,
        }));
      }

      config.models.providers[providerId] = providerConfig;

      // Set primary model
      const primaryModelId = model.primaryModelId || (model.models?.[0]?.id);
      if (primaryModelId) {
        const modelRef = `${providerId}/${primaryModelId}`;
        if (!config.agents.defaults.model.primary) {
          config.agents.defaults.model.primary = modelRef;
        } else {
          config.agents.defaults.model.fallbacks.push(modelRef);
        }
      }
    } else if (model.type === 'official') {
      // Official API — use built-in provider, store key in .env
      const envKey = model.envKey;
      envVars[envKey] = model.apiKey;

      if (!config.agents.defaults.model.primary) {
        config.agents.defaults.model.primary = model.modelRef;
      } else {
        config.agents.defaults.model.fallbacks.push(model.modelRef);
      }
    }
  }

  // Process channels
  if (wizardData.channels) {
    for (const ch of wizardData.channels) {
      if (ch.type === 'telegram') {
        config.telegram = {
          token: ch.botToken,
          allowedUsers: ch.allowedUsers || [],
        };
      } else if (ch.type === 'discord') {
        config.discord = {
          token: ch.botToken,
        };
      }
      // More channels...
    }
  }

  return { config, envVars };
});

// ── Gateway Control ──
ipcMain.handle('start-gateway', async () => {
  if (gatewayProcess) return { success: false, error: 'Already running' };

  gatewayStatus = 'starting';
  mainWindow.webContents.send('gateway-status', gatewayStatus);

  return new Promise((resolve) => {
    const cmd = process.platform === 'win32' ? 'openclaw.cmd' : 'openclaw';
    gatewayProcess = spawn(cmd, ['gateway', 'start', '--foreground'], {
      env: { ...process.env },
      shell: true,
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let started = false;

    const onData = (data) => {
      const text = data.toString();
      mainWindow.webContents.send('gateway-log', text);
      if (!started && (text.includes('listening') || text.includes('ready') || text.includes('Gateway'))) {
        started = true;
        gatewayStatus = 'running';
        mainWindow.webContents.send('gateway-status', gatewayStatus);
        resolve({ success: true });
      }
    };

    gatewayProcess.stdout.on('data', onData);
    gatewayProcess.stderr.on('data', onData);

    gatewayProcess.on('close', (code) => {
      gatewayProcess = null;
      gatewayStatus = 'stopped';
      mainWindow.webContents.send('gateway-status', gatewayStatus);
      if (!started) {
        resolve({ success: false, error: `Exited with code ${code}` });
      }
    });

    gatewayProcess.on('error', (err) => {
      gatewayProcess = null;
      gatewayStatus = 'error';
      mainWindow.webContents.send('gateway-status', gatewayStatus);
      if (!started) {
        resolve({ success: false, error: err.message });
      }
    });

    // Timeout
    setTimeout(() => {
      if (!started) {
        gatewayStatus = 'running'; // assume running
        mainWindow.webContents.send('gateway-status', gatewayStatus);
        resolve({ success: true });
      }
    }, 10000);
  });
});

ipcMain.handle('stop-gateway', async () => {
  return stopGateway();
});

ipcMain.handle('get-gateway-status', async () => {
  return gatewayStatus;
});

function stopGateway() {
  if (gatewayProcess) {
    gatewayProcess.kill();
    gatewayProcess = null;
  }
  gatewayStatus = 'stopped';
  if (mainWindow) {
    mainWindow.webContents.send('gateway-status', gatewayStatus);
  }
  return { success: true };
}

// ── Helpers ──
function generateToken() {
  const crypto = require('crypto');
  return crypto.randomBytes(24).toString('hex');
}

function getOSName() {
  switch (process.platform) {
    case 'win32': return `Windows ${os.release()}`;
    case 'darwin': return `macOS ${os.release()}`;
    case 'linux': return `Linux ${os.release()}`;
    default: return process.platform;
  }
}

// ── Restart Gateway ──
ipcMain.handle('restart-gateway', async (event) => {
  stopGateway();
  await new Promise(r => setTimeout(r, 500));
  // Re-invoke start-gateway
  const result = await new Promise((resolve) => {
    const handler = ipcMain.handler?.['start-gateway'];
    // Just trigger start via the same logic
    resolve({ restarting: true });
  });
  return result;
});

// ── Read Config File Raw ──
ipcMain.handle('read-config-raw', async () => {
  try {
    if (!fs.existsSync(CONFIG_PATH)) return { success: false, error: 'Config file not found' };
    const content = fs.readFileSync(CONFIG_PATH, 'utf8');
    return { success: true, content };
  } catch (e) {
    return { success: false, error: e.message };
  }
});

// ── Write Config File Raw ──
ipcMain.handle('write-config-raw', async (event, content) => {
  try {
    // Validate JSON first
    JSON.parse(content);
    fs.mkdirSync(OPENCLAW_HOME, { recursive: true });
    fs.writeFileSync(CONFIG_PATH, content);
    return { success: true };
  } catch (e) {
    return { success: false, error: e.message };
  }
});

// ── Read Gateway Logs ──
ipcMain.handle('read-gateway-logs', async () => {
  try {
    const logPath = path.join(OPENCLAW_HOME, 'logs', 'gateway.log');
    if (!fs.existsSync(logPath)) return { success: true, content: '(暂无日志)' };
    const content = fs.readFileSync(logPath, 'utf8');
    // Return last 200 lines
    const lines = content.split('\n');
    return { success: true, content: lines.slice(-200).join('\n') };
  } catch (e) {
    return { success: false, error: e.message };
  }
});

// ── Open External Links ──
ipcMain.handle('open-external', async (event, url) => {
  shell.openExternal(url);
});

ipcMain.handle('get-gateway-url', async () => {
  try {
    const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    const port = config.gateway?.port || 18789;
    const token = config.gateway?.auth?.token || '';
    return { port, token, url: `http://127.0.0.1:${port}` };
  } catch (e) {
    return { port: 18789, token: '', url: 'http://127.0.0.1:18789' };
  }
});
