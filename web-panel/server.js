#!/usr/bin/env node
// ── OpenClaw Web Panel Server ──
// Express 服务器，端口 5338，只监听 localhost
// 提供和 Electron 版一样的管理功能，但不依赖 Electron

const express = require('express');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync, exec } = require('child_process');

const app = express();
const PORT = process.env.OPENCLAW_PANEL_PORT || 5338;
const BIND = process.env.OPENCLAW_PANEL_BIND || '127.0.0.1';

// ── Paths ──
const OPENCLAW_HOME = path.join(os.homedir(), '.openclaw');
const CONFIG_PATH = path.join(OPENCLAW_HOME, 'openclaw.json');
const ENV_PATH = path.join(OPENCLAW_HOME, '.env');
const WORKSPACE_PATH = path.join(OPENCLAW_HOME, 'workspace');

// ── Middleware ──
app.use(express.json({ limit: '1mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// ── Helpers ──
function readConfig() {
  try {
    if (!fs.existsSync(CONFIG_PATH)) return null;
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch (e) {
    return null;
  }
}

function writeConfig(config) {
  fs.mkdirSync(OPENCLAW_HOME, { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
}

function runCommand(cmd, timeoutMs = 15000) {
  return new Promise((resolve) => {
    exec(cmd, { timeout: timeoutMs, env: { ...process.env, PATH: getEnhancedPath() } }, (error, stdout, stderr) => {
      resolve({
        success: !error,
        stdout: stdout?.trim() || '',
        stderr: stderr?.trim() || '',
        code: error?.code || 0,
      });
    });
  });
}

function runCommandSync(cmd) {
  try {
    return execSync(cmd, {
      encoding: 'utf8',
      timeout: 10000,
      env: { ...process.env, PATH: getEnhancedPath() },
    }).trim();
  } catch (e) {
    return null;
  }
}

function getEnhancedPath() {
  // Ensure common bin paths are included (nvm, npm global, etc.)
  const extra = [
    path.join(os.homedir(), '.nvm/versions/node', process.version, 'bin'),
    '/usr/local/bin',
    '/usr/bin',
    path.join(os.homedir(), '.npm-global/bin'),
  ];
  return [...extra, process.env.PATH].join(':');
}

function getOSName() {
  switch (process.platform) {
    case 'win32': return `Windows ${os.release()}`;
    case 'darwin': return `macOS ${os.release()}`;
    case 'linux': return `Linux ${os.release()}`;
    default: return process.platform;
  }
}

function generateToken() {
  const crypto = require('crypto');
  return crypto.randomBytes(24).toString('hex');
}

// ── API Routes ──

// GET /api/status — Gateway 状态 + 系统信息
app.get('/api/status', async (req, res) => {
  try {
    // Gateway status
    const gwResult = await runCommand('openclaw gateway status');
    let gatewayStatus = 'unknown';
    const combined = (gwResult.stdout + ' ' + gwResult.stderr).toLowerCase();
    if (combined.includes('running') || combined.includes('online') || combined.includes('listening')) {
      gatewayStatus = 'running';
    } else if (combined.includes('stopped') || combined.includes('not running') || combined.includes('inactive')) {
      gatewayStatus = 'stopped';
    } else if (!gwResult.success) {
      gatewayStatus = 'stopped';
    }

    // OpenClaw version
    const openclawVersion = runCommandSync('openclaw --version') || '未安装';

    // Config
    const config = readConfig();

    // System info
    const systemInfo = {
      nodeVersion: process.version,
      os: `${getOSName()} (${process.arch})`,
      platform: process.platform,
      hostname: os.hostname(),
      uptime: os.uptime(),
      memory: {
        total: os.totalmem(),
        free: os.freemem(),
      },
      openclawVersion,
    };

    // Model info from config
    const primary = config?.agents?.defaults?.model?.primary || null;
    const fallbacks = config?.agents?.defaults?.model?.fallbacks || [];
    const providers = config?.models?.providers || {};

    // Channels
    const channels = [];
    if (config?.telegram) channels.push('Telegram');
    if (config?.discord) channels.push('Discord');
    channels.push('WebChat');

    res.json({
      gateway: {
        status: gatewayStatus,
        raw: gwResult.stdout || gwResult.stderr,
      },
      model: { primary, fallbacks },
      providers: Object.keys(providers).length,
      channels,
      system: systemInfo,
      configExists: !!config,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// POST /api/gateway/start
app.post('/api/gateway/start', async (req, res) => {
  try {
    const result = await runCommand('openclaw gateway start', 30000);
    // Give it a moment to start
    await new Promise(r => setTimeout(r, 2000));
    const status = await runCommand('openclaw gateway status');
    const combined = (status.stdout + ' ' + status.stderr).toLowerCase();
    const running = combined.includes('running') || combined.includes('online') || combined.includes('listening');
    res.json({
      success: result.success || running,
      output: result.stdout || result.stderr,
      status: running ? 'running' : 'unknown',
    });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// POST /api/gateway/stop
app.post('/api/gateway/stop', async (req, res) => {
  try {
    const result = await runCommand('openclaw gateway stop', 15000);
    res.json({
      success: true,
      output: result.stdout || result.stderr,
    });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// POST /api/gateway/restart
app.post('/api/gateway/restart', async (req, res) => {
  try {
    const result = await runCommand('openclaw gateway restart', 30000);
    await new Promise(r => setTimeout(r, 2000));
    const status = await runCommand('openclaw gateway status');
    const combined = (status.stdout + ' ' + status.stderr).toLowerCase();
    const running = combined.includes('running') || combined.includes('online') || combined.includes('listening');
    res.json({
      success: result.success || running,
      output: result.stdout || result.stderr,
      status: running ? 'running' : 'unknown',
    });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// GET /api/config — 读取配置
app.get('/api/config', (req, res) => {
  try {
    const config = readConfig();
    if (!config) {
      return res.json({ exists: false, config: null });
    }
    res.json({ exists: true, config });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// POST /api/config — 写入配置（JSON 对象）
app.post('/api/config', (req, res) => {
  try {
    const config = req.body;
    if (!config || typeof config !== 'object') {
      return res.status(400).json({ error: '无效的配置数据' });
    }
    writeConfig(config);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// GET /api/config/raw — 读取原始配置文本
app.get('/api/config/raw', (req, res) => {
  try {
    if (!fs.existsSync(CONFIG_PATH)) {
      return res.json({ success: false, error: '配置文件不存在' });
    }
    const content = fs.readFileSync(CONFIG_PATH, 'utf8');
    res.json({ success: true, content });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// POST /api/config/raw — 写入原始配置文本
app.post('/api/config/raw', (req, res) => {
  try {
    const { content } = req.body;
    if (!content) {
      return res.status(400).json({ success: false, error: '内容不能为空' });
    }
    // Validate JSON
    JSON.parse(content);
    fs.mkdirSync(OPENCLAW_HOME, { recursive: true });
    fs.writeFileSync(CONFIG_PATH, content);
    res.json({ success: true });
  } catch (e) {
    if (e instanceof SyntaxError) {
      return res.status(400).json({ success: false, error: 'JSON 格式错误: ' + e.message });
    }
    res.status(500).json({ success: false, error: e.message });
  }
});

// POST /api/config/generate — 从向导数据生成配置
app.post('/api/config/generate', (req, res) => {
  try {
    const wizardData = req.body;
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

    // ApexYY 节点映射
    const nodeMap = {
      'domestic': 'https://yunyi.rdzhvip.com',
      'overseas': 'https://yunyi.cfd',
      'overseas2': 'https://cdn1.yunyi.cfd',
      'overseas3': 'https://cdn2.yunyi.cfd',
    };

    const baseUrl = nodeMap[wizardData.node] || wizardData.customNode || 'https://yunyi.rdzhvip.com';

    // Process models
    if (wizardData.models) {
      for (const model of wizardData.models) {
        if (model.type === 'proxy') {
          const providerId = model.providerId;
          const providerConfig = {
            baseUrl: model.baseUrl || baseUrl + (model.product === 'codex' ? '/codex' : '/claude'),
            apiKey: model.apiKey,
            auth: 'api-key',
            api: model.apiFormat || 'anthropic-messages',
            headers: {},
            authHeader: false,
          };

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
          envVars[model.envKey] = model.apiKey;
          if (!config.agents.defaults.model.primary) {
            config.agents.defaults.model.primary = model.modelRef;
          } else {
            config.agents.defaults.model.fallbacks.push(model.modelRef);
          }
        }
      }
    }

    // Simple wizard mode (product + key + node)
    if (wizardData.product && wizardData.apiKey) {
      const product = wizardData.product;
      const apiKey = wizardData.apiKey;

      if (product === 'claude' || product === 'both') {
        const claudeKey = product === 'both' ? wizardData.claudeKey || apiKey : apiKey;
        config.models.providers['apexyy-claude'] = {
          baseUrl: baseUrl + '/claude',
          apiKey: claudeKey,
          auth: 'api-key',
          api: 'anthropic-messages',
          headers: {},
          authHeader: false,
          models: [],
        };
        config.agents.defaults.model.primary = 'apexyy-claude/claude-opus-4-6';
      }

      if (product === 'codex' || product === 'both') {
        const codexKey = product === 'both' ? wizardData.codexKey || apiKey : apiKey;
        config.models.providers['apexyy-codex'] = {
          baseUrl: baseUrl + '/codex',
          apiKey: codexKey,
          auth: 'api-key',
          api: 'openai-responses',
          headers: {},
          authHeader: false,
          models: [
            { id: 'gpt-5.2', name: 'GPT 5.2', reasoning: true, input: ['text', 'image'], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 32768 },
            { id: 'gpt-5.3-codex', name: 'GPT 5.3 Codex', reasoning: true, input: ['text', 'image'], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 32768 },
          ],
        };
        if (!config.agents.defaults.model.primary) {
          config.agents.defaults.model.primary = 'apexyy-codex/gpt-5.2';
        } else {
          config.agents.defaults.model.fallbacks.push('apexyy-codex/gpt-5.2');
        }
      }
    }

    // Process channels
    if (wizardData.channels) {
      for (const ch of wizardData.channels) {
        if (ch.type === 'telegram' && ch.botToken) {
          config.telegram = { token: ch.botToken, allowedUsers: ch.allowedUsers || [] };
        } else if (ch.type === 'discord' && ch.botToken) {
          config.discord = { token: ch.botToken };
        }
      }
    }

    // Write config
    writeConfig(config);

    // Write .env if needed
    if (Object.keys(envVars).length > 0) {
      const lines = Object.entries(envVars).filter(([k, v]) => v).map(([k, v]) => `${k}=${v}`);
      fs.writeFileSync(ENV_PATH, lines.join('\n') + '\n');
      try { fs.chmodSync(ENV_PATH, 0o600); } catch (e) { /* ignore */ }
    }

    res.json({ success: true, config, envVars });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// GET /api/logs — 读取日志
app.get('/api/logs', async (req, res) => {
  try {
    const lines = parseInt(req.query.lines) || 200;

    // Try multiple log sources
    let logContent = '';

    // 1. Try journalctl for systemd service
    const journalResult = await runCommand(`journalctl -u openclaw-gateway --no-pager -n ${lines} 2>/dev/null`);
    if (journalResult.success && journalResult.stdout && !journalResult.stdout.includes('No entries')) {
      logContent = journalResult.stdout;
    }

    // 2. Try log file
    if (!logContent) {
      const logPaths = [
        path.join(OPENCLAW_HOME, 'logs', 'gateway.log'),
        path.join(OPENCLAW_HOME, 'gateway.log'),
      ];
      for (const logPath of logPaths) {
        if (fs.existsSync(logPath)) {
          const content = fs.readFileSync(logPath, 'utf8');
          const allLines = content.split('\n');
          logContent = allLines.slice(-lines).join('\n');
          break;
        }
      }
    }

    // 3. Try openclaw gateway status as fallback
    if (!logContent) {
      const statusResult = await runCommand('openclaw gateway status');
      logContent = statusResult.stdout || statusResult.stderr || '(暂无日志)';
    }

    res.json({ success: true, content: logContent });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// ── SPA Fallback ──
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ── Start Server ──
app.listen(PORT, BIND, () => {
  console.log(`\n🦞 OpenClaw Web Panel`);
  console.log(`   地址: http://${BIND}:${PORT}`);
  console.log(`   配置: ${CONFIG_PATH}`);
  console.log(`   按 Ctrl+C 停止\n`);
});
