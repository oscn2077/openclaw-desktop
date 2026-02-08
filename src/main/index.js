const { app, BrowserWindow, ipcMain, Tray, Menu, shell, dialog } = require('electron');
const path = require('path');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const os = require('os');

// ── Auto Updater (uncomment when ready to enable) ──
// const { autoUpdater } = require('electron-updater');
// autoUpdater.logger = require('electron-log');
// autoUpdater.logger.transports.file.level = 'info';

// ── Globals ──
let mainWindow = null;
let tray = null;
let gatewayProcess = null;
let gatewayStatus = 'stopped'; // stopped | starting | running | error
let gatewayStartTime = null;

// ── Paths ──
const OPENCLAW_HOME = path.join(os.homedir(), '.openclaw');
const CONFIG_PATH = path.join(OPENCLAW_HOME, 'openclaw.json');
const ENV_PATH = path.join(OPENCLAW_HOME, '.env');
const WORKSPACE_PATH = path.join(OPENCLAW_HOME, 'workspace');

// ── Safe IPC send helper ──
function sendToRenderer(channel, ...args) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send(channel, ...args);
  }
}

// ── App Ready ──
app.whenReady().then(() => {
  createWindow();
  // createTray();  // TODO: system tray icon

  // Auto Updater (uncomment when ready to enable)
  // autoUpdater.checkForUpdatesAndNotify();
  // autoUpdater.on('update-available', (info) => {
  //   sendToRenderer('update-available', info);
  // });
  // autoUpdater.on('update-downloaded', (info) => {
  //   sendToRenderer('update-downloaded', info);
  //   // Optionally auto-install:
  //   // autoUpdater.quitAndInstall();
  // });
  // autoUpdater.on('error', (err) => {
  //   sendToRenderer('update-error', err.message);
  // });
});

app.on('window-all-closed', () => {
  // Don't quit on window close — keep running in tray
  // For now, quit entirely
  stopGateway();
  app.quit();
});

app.on('before-quit', () => {
  // Ensure gateway is stopped on quit
  stopGateway();
});

// ── Window ──
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 960,
    height: 700,
    minWidth: 800,
    minHeight: 600,
    title: 'OpenClaw Desktop',
    icon: path.join(__dirname, '..', '..', 'assets', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    // frameless with custom titlebar later
  });

  mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));

  // Clean up reference on close
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Open DevTools in dev mode
  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools();
  }
}

// ── Environment Detection ──
ipcMain.handle('detect-environment', async () => {
  try {
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
      result.node.version = execSync('node --version', { encoding: 'utf8', timeout: 5000 }).trim();
      result.node.installed = true;
      result.node.path = execSync(process.platform === 'win32' ? 'where node' : 'which node', { encoding: 'utf8', timeout: 5000 }).trim().split('\n')[0];
    } catch (e) { /* not installed */ }

    // Check OpenClaw
    try {
      result.openclaw.version = execSync('openclaw --version', { encoding: 'utf8', timeout: 5000 }).trim();
      result.openclaw.installed = true;
      result.openclaw.path = execSync(process.platform === 'win32' ? 'where openclaw' : 'which openclaw', { encoding: 'utf8', timeout: 5000 }).trim().split('\n')[0];
    } catch (e) { /* not installed */ }

    // Check Docker
    try {
      result.docker.version = execSync('docker --version', { encoding: 'utf8', timeout: 5000 }).trim();
      result.docker.installed = true;
    } catch (e) { /* not installed */ }

    return result;
  } catch (e) {
    return { error: e.message };
  }
});

// ── Install OpenClaw ──
ipcMain.handle('install-openclaw', async (event) => {
  try {
    return new Promise((resolve) => {
      const cmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
      const proc = spawn(cmd, ['install', '-g', 'openclaw@latest'], {
        env: { ...process.env },
        shell: true,
      });

      let output = '';
      proc.stdout.on('data', (d) => {
        output += d.toString();
        sendToRenderer('install-progress', d.toString());
      });
      proc.stderr.on('data', (d) => {
        output += d.toString();
        sendToRenderer('install-progress', d.toString());
      });
      proc.on('close', (code) => {
        if (code === 0) resolve({ success: true, output });
        else resolve({ success: false, output, code });
      });
      proc.on('error', (err) => resolve({ success: false, error: err.message }));
    });
  } catch (e) {
    return { success: false, error: e.message };
  }
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
  try {
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
  } catch (e) {
    return { error: e.message };
  }
});

// ── Gateway Control ──
ipcMain.handle('start-gateway', async () => {
  try {
    if (gatewayProcess) return { success: false, error: 'Already running' };

    gatewayStatus = 'starting';
    sendToRenderer('gateway-status', gatewayStatus);

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
        sendToRenderer('gateway-log', text);
        if (!started && (text.includes('listening') || text.includes('ready') || text.includes('Gateway'))) {
          started = true;
          gatewayStatus = 'running';
          gatewayStartTime = Date.now();
          sendToRenderer('gateway-status', gatewayStatus);
          resolve({ success: true });
        }
      };

      gatewayProcess.stdout.on('data', onData);
      gatewayProcess.stderr.on('data', onData);

      gatewayProcess.on('close', (code) => {
        gatewayProcess = null;
        gatewayStatus = 'stopped';
        sendToRenderer('gateway-status', gatewayStatus);
        if (!started) {
          resolve({ success: false, error: `Exited with code ${code}` });
        }
      });

      gatewayProcess.on('error', (err) => {
        gatewayProcess = null;
        gatewayStatus = 'error';
        sendToRenderer('gateway-status', gatewayStatus);
        if (!started) {
          resolve({ success: false, error: err.message });
        }
      });

      // Timeout
      setTimeout(() => {
        if (!started) {
          gatewayStatus = 'running'; // assume running
          gatewayStartTime = Date.now();
          sendToRenderer('gateway-status', gatewayStatus);
          resolve({ success: true });
        }
      }, 10000);
    });
  } catch (e) {
    return { success: false, error: e.message };
  }
});

ipcMain.handle('stop-gateway', async () => {
  try {
    return stopGateway();
  } catch (e) {
    return { success: false, error: e.message };
  }
});

ipcMain.handle('get-gateway-status', async () => {
  return gatewayStatus;
});

function stopGateway() {
  if (gatewayProcess) {
    try {
      gatewayProcess.kill();
    } catch (e) {
      // Process may already be dead
    }
    gatewayProcess = null;
  }
  gatewayStatus = 'stopped';
  gatewayStartTime = null;
  sendToRenderer('gateway-status', gatewayStatus);
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
ipcMain.handle('restart-gateway', async () => {
  try {
    stopGateway();
    await new Promise(r => setTimeout(r, 1000));
    const cmd = process.platform === 'win32' ? 'openclaw.cmd' : 'openclaw';
    const gw = spawn(cmd, ['gateway', 'start'], { stdio: 'pipe', detached: true, shell: true });
    gw.unref();
    gatewayProcess = gw;
    return { success: true, restarted: true };
  } catch (e) {
    return { success: false, error: e.message };
  }
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
  try {
    // Validate URL to prevent arbitrary command execution
    const parsed = new URL(url);
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
      await shell.openExternal(url);
      return { success: true };
    }
    return { success: false, error: 'Only http/https URLs are allowed' };
  } catch (e) {
    return { success: false, error: e.message };
  }
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

// ── Test API Connection ──
ipcMain.handle('test-connection', async (event, { baseUrl, apiKey, apiFormat }) => {
  try {
    const https = require('https');
    const http = require('http');

    return new Promise((resolve) => {
      try {
        let testUrl, options, postData;

        if (apiFormat === 'anthropic-messages') {
          // Anthropic-style: POST /v1/messages with minimal payload
          testUrl = new URL(baseUrl.replace(/\/$/, '') + '/v1/messages');
          postData = JSON.stringify({
            model: 'claude-sonnet-4-5',
            max_tokens: 1,
            messages: [{ role: 'user', content: 'hi' }],
          });
          options = {
            hostname: testUrl.hostname,
            port: testUrl.port || (testUrl.protocol === 'https:' ? 443 : 80),
            path: testUrl.pathname,
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'Content-Length': Buffer.byteLength(postData),
            },
            timeout: 15000,
          };
        } else if (apiFormat === 'openai-responses' || apiFormat === 'openai-chat') {
          // OpenAI-style: POST /v1/chat/completions
          testUrl = new URL(baseUrl.replace(/\/$/, '') + '/v1/chat/completions');
          postData = JSON.stringify({
            model: 'gpt-4.1',
            max_tokens: 1,
            messages: [{ role: 'user', content: 'hi' }],
          });
          options = {
            hostname: testUrl.hostname,
            port: testUrl.port || (testUrl.protocol === 'https:' ? 443 : 80),
            path: testUrl.pathname,
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${apiKey}`,
              'Content-Length': Buffer.byteLength(postData),
            },
            timeout: 15000,
          };
        } else if (apiFormat === 'gemini') {
          // Gemini: just check the API key with a models list
          testUrl = new URL(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`);
          options = {
            hostname: testUrl.hostname,
            port: 443,
            path: testUrl.pathname + testUrl.search,
            method: 'GET',
            headers: {},
            timeout: 15000,
          };
          postData = null;
        } else if (apiFormat === 'zhipu') {
          // Zhipu/GLM: POST chat completions
          testUrl = new URL('https://open.bigmodel.cn/api/paas/v4/chat/completions');
          postData = JSON.stringify({
            model: 'glm-4-flash',
            max_tokens: 1,
            messages: [{ role: 'user', content: 'hi' }],
          });
          options = {
            hostname: testUrl.hostname,
            port: 443,
            path: testUrl.pathname,
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${apiKey}`,
              'Content-Length': Buffer.byteLength(postData),
            },
            timeout: 15000,
          };
        } else {
          resolve({ success: false, error: 'Unknown API format' });
          return;
        }

        const proto = (testUrl.protocol === 'https:') ? https : http;
        const req = proto.request(options, (res) => {
          let body = '';
          res.on('data', (chunk) => { body += chunk; });
          res.on('end', () => {
            // 200 = success, 401/403 = bad key, anything else = at least reachable
            if (res.statusCode === 200 || res.statusCode === 201) {
              resolve({ success: true });
            } else if (res.statusCode === 401 || res.statusCode === 403) {
              resolve({ success: false, error: `认证失败 (HTTP ${res.statusCode})，请检查 API Key` });
            } else if (res.statusCode === 400) {
              // 400 often means the API is reachable but request was bad — key is valid
              resolve({ success: true, note: 'API 可达，Key 格式正确' });
            } else {
              resolve({ success: false, error: `HTTP ${res.statusCode}: ${body.slice(0, 200)}` });
            }
          });
        });

        req.on('error', (err) => {
          resolve({ success: false, error: `连接失败: ${err.message}` });
        });

        req.on('timeout', () => {
          req.destroy();
          resolve({ success: false, error: '连接超时 (15s)' });
        });

        if (postData) req.write(postData);
        req.end();
      } catch (e) {
        resolve({ success: false, error: e.message });
      }
    });
  } catch (e) {
    return { success: false, error: e.message };
  }
});

// ── System Info ──
ipcMain.handle('get-system-info', async () => {
  try {
    const info = {
      nodeVersion: process.version,
      electronVersion: process.versions.electron,
      os: `${getOSName()} (${process.arch})`,
      platform: process.platform,
      openclawVersion: null,
      gatewayUptime: null,
    };

    try {
      info.openclawVersion = execSync('openclaw --version', { encoding: 'utf8', timeout: 5000 }).trim();
    } catch (e) {
      info.openclawVersion = '未安装';
    }

    // Gateway uptime
    if (gatewayProcess && gatewayStatus === 'running') {
      info.gatewayUptime = Date.now() - (gatewayStartTime || Date.now());
    }

    return info;
  } catch (e) {
    return { error: e.message };
  }
});
