const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  // Environment
  detectEnvironment: () => ipcRenderer.invoke('detect-environment'),
  installOpenclaw: () => ipcRenderer.invoke('install-openclaw'),

  // Config
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  saveEnv: (envVars) => ipcRenderer.invoke('save-env', envVars),
  generateConfig: (wizardData) => ipcRenderer.invoke('generate-config', wizardData),

  // Config raw (for JSON editor)
  readConfigRaw: () => ipcRenderer.invoke('read-config-raw'),
  writeConfigRaw: (content) => ipcRenderer.invoke('write-config-raw', content),

  // Gateway
  startGateway: () => ipcRenderer.invoke('start-gateway'),
  stopGateway: () => ipcRenderer.invoke('stop-gateway'),
  restartGateway: () => ipcRenderer.invoke('restart-gateway'),
  getGatewayStatus: () => ipcRenderer.invoke('get-gateway-status'),
  getGatewayUrl: () => ipcRenderer.invoke('get-gateway-url'),
  readGatewayLogs: () => ipcRenderer.invoke('read-gateway-logs'),

  // System info
  getSystemInfo: () => ipcRenderer.invoke('get-system-info'),

  // Test connection
  testConnection: (params) => ipcRenderer.invoke('test-connection', params),

  // Events
  onGatewayStatus: (cb) => ipcRenderer.on('gateway-status', (e, status) => cb(status)),
  onGatewayLog: (cb) => ipcRenderer.on('gateway-log', (e, log) => cb(log)),
  onInstallProgress: (cb) => ipcRenderer.on('install-progress', (e, msg) => cb(msg)),

  // Misc
  openExternal: (url) => ipcRenderer.invoke('open-external', url),
});
