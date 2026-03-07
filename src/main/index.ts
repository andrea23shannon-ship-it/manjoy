import {
  app,
  BrowserWindow,
  ipcMain,
  dialog,
  screen,
  Menu,
  shell,
} from 'electron';
import path from 'path';
import Store from 'electron-store';

const isDev = !app.isPackaged;
import { WebSocketServer } from './WebSocketServer';
import { BonjourService } from './BonjourService';
import { ScreenManager } from './ScreenManager';
import { PeerMessage } from '../shared/types';
import fs from 'fs';
import os from 'os';

// Initialize persistent storage
const store = new Store<{
  style?: Record<string, unknown>;
  standbyGroups?: unknown[];
  importedFonts?: string[];
}>();

// Declare window variables
let mainWindow: BrowserWindow | null = null;
let projectionWindow: BrowserWindow | null = null;
let wsServer: WebSocketServer | null = null;
let bonjourService: BonjourService | null = null;
let screenManager: ScreenManager | null = null;

// IPC Channel constants
const IPC_CHANNELS = {
  PEER_MESSAGE: 'peer-message',
  CONNECTION_CHANGED: 'connection-changed',
  SCREENS_UPDATED: 'screens-updated',
  START_SERVER: 'start-server',
  STOP_SERVER: 'stop-server',
  START_PROJECTION: 'start-projection',
  STOP_PROJECTION: 'stop-projection',
  GET_SCREENS: 'get-screens',
  OPEN_FILE_DIALOG: 'open-file-dialog',
  SAVE_STYLE: 'save-style',
  LOAD_STYLE: 'load-style',
  SAVE_STANDBY_GROUPS: 'save-standby-groups',
  LOAD_STANDBY_GROUPS: 'load-standby-groups',
  IMPORT_FONT: 'import-font',
  GET_FONTS: 'get-fonts',
  REMOVE_FONT: 'remove-font',
};

/**
 * Create the main control window
 */
function createMainWindow(): void {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
    },
    icon: path.join(__dirname, '../../assets/icon.png'),
  });

  const startUrl = isDev
    ? 'http://localhost:5173'
    : `file://${path.join(__dirname, '../renderer/index.html')}`;

  mainWindow.loadURL(startUrl);

  if (isDev) {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

/**
 * Create projection window on specified display
 */
function createProjectionWindow(displayId: number): void {
  const displays = screen.getAllDisplays();
  const targetDisplay = displays.find((d) => d.id === displayId);

  console.log(`[Projection] Requested display ID: ${displayId}`);
  console.log(`[Projection] Available displays:`, displays.map(d => ({
    id: d.id, bounds: d.bounds, isPrimary: d.id === screen.getPrimaryDisplay().id
  })));

  if (!targetDisplay) {
    console.error(`[Projection] Display with ID ${displayId} not found`);
    return;
  }

  projectionWindow = new BrowserWindow({
    x: targetDisplay.bounds.x,
    y: targetDisplay.bounds.y,
    width: targetDisplay.bounds.width,
    height: targetDisplay.bounds.height,
    fullscreen: false,
    fullscreenable: true,
    frame: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    movable: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
    },
  });

  // On Windows, use setBounds + simpleFullscreen instead of fullscreen
  // to ensure the window appears on the correct display
  projectionWindow.setBounds(targetDisplay.bounds);
  projectionWindow.setSimpleFullScreen(true);

  const projectionUrl = isDev
    ? 'http://localhost:5173/projection.html'
    : `file://${path.join(__dirname, '../renderer/projection.html')}`;

  projectionWindow.loadURL(projectionUrl);

  if (isDev) {
    projectionWindow.webContents.openDevTools({ mode: 'detach' });
  }

  projectionWindow.on('closed', () => {
    projectionWindow = null;
  });
}

/**
 * Initialize WebSocket server
 */
function initializeWebSocketServer(): void {
  if (wsServer) {
    return;
  }

  wsServer = new WebSocketServer(9600);

  wsServer.on('message', (message: PeerMessage) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send(IPC_CHANNELS.PEER_MESSAGE, message);
    }
    if (projectionWindow && !projectionWindow.isDestroyed()) {
      projectionWindow.webContents.send(IPC_CHANNELS.PEER_MESSAGE, message);
    }
  });

  wsServer.on('connection', (connected: boolean, deviceName?: string) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send(IPC_CHANNELS.CONNECTION_CHANGED, {
        connected,
        deviceName,
      });
    }
  });

  wsServer.start();
  console.log('WebSocket server started on port 9600');
}

/**
 * Initialize Bonjour service
 */
function initializeBonjourService(): void {
  if (bonjourService) {
    return;
  }

  bonjourService = new BonjourService(9600, {
    app: 'LyricsCaster',
    role: 'projector',
  });

  bonjourService.start();
  console.log('Bonjour service started');
}

/**
 * Initialize screen manager
 */
function initializeScreenManager(): void {
  if (screenManager) {
    return;
  }

  screenManager = new ScreenManager();

  screen.on('display-added', () => {
    notifyScreensUpdated();
  });

  screen.on('display-removed', () => {
    notifyScreensUpdated();
  });

  console.log('Screen manager initialized');
}

/**
 * Notify renderer process about screen changes
 */
function notifyScreensUpdated(): void {
  if (!screenManager) return;

  const screens = screenManager.getScreens();
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send(IPC_CHANNELS.SCREENS_UPDATED, screens);
  }
}

/**
 * Setup IPC handlers
 */
function setupIpcHandlers(): void {
  // Start WebSocket server
  ipcMain.handle(IPC_CHANNELS.START_SERVER, async () => {
    try {
      initializeWebSocketServer();
      initializeBonjourService();
      return { success: true };
    } catch (error) {
      console.error('Failed to start server:', error);
      return { success: false, error: String(error) };
    }
  });

  // Query server status (so renderer can sync on mount)
  ipcMain.handle('get-server-status', async () => {
    return {
      isRunning: wsServer !== null,
      connectedCount: wsServer?.getConnectedCount() || 0,
    };
  });

  // Get network info for diagnostics
  ipcMain.handle('get-network-info', async () => {
    const interfaces = os.networkInterfaces();
    const ips: string[] = [];
    for (const name in interfaces) {
      for (const iface of interfaces[name] || []) {
        if (iface.family === 'IPv4' && !iface.internal) {
          ips.push(iface.address);
        }
      }
    }
    return {
      localIPs: ips,
      port: 9600,
      bonjourActive: bonjourService?.isActive() || false,
      wsRunning: wsServer !== null,
    };
  });

  // Stop WebSocket server
  ipcMain.handle(IPC_CHANNELS.STOP_SERVER, async () => {
    if (wsServer) {
      wsServer.stop();
      wsServer = null;
    }
    if (bonjourService) {
      bonjourService.stop();
      bonjourService = null;
    }
    return { success: true };
  });

  // Start projection on specified display
  ipcMain.handle(IPC_CHANNELS.START_PROJECTION, async (_event, displayId: number) => {
    if (projectionWindow) {
      console.warn('Projection window already running');
      return { success: false, error: 'Projection already running' };
    }
    createProjectionWindow(displayId);
    return { success: true };
  });

  // Stop projection
  ipcMain.handle(IPC_CHANNELS.STOP_PROJECTION, async () => {
    if (projectionWindow && !projectionWindow.isDestroyed()) {
      projectionWindow.close();
      projectionWindow = null;
    }
    return { success: true };
  });

  // Get available screens
  ipcMain.handle(IPC_CHANNELS.GET_SCREENS, async () => {
    if (!screenManager) {
      initializeScreenManager();
    }
    return screenManager?.getScreens() || [];
  });

  // Open file dialog
  ipcMain.handle(
    IPC_CHANNELS.OPEN_FILE_DIALOG,
    async (_event, options: { type: 'image' | 'font' }) => {
      const filters =
        options.type === 'image'
          ? [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp'] }]
          : [{ name: 'Fonts', extensions: ['ttf', 'otf', 'woff', 'woff2'] }];

      const result = await dialog.showOpenDialog(mainWindow!, {
        properties: ['openFile'],
        filters,
      });

      if (result.canceled) {
        return { canceled: true };
      }

      return { canceled: false, filePath: result.filePaths[0] };
    }
  );

  // Save style
  ipcMain.handle(IPC_CHANNELS.SAVE_STYLE, async (_event, style: Record<string, unknown>) => {
    try {
      store.set('style', style);
      return { success: true };
    } catch (error) {
      console.error('Failed to save style:', error);
      return { success: false, error: String(error) };
    }
  });

  // Load style
  ipcMain.handle(IPC_CHANNELS.LOAD_STYLE, async () => {
    try {
      const style = store.get('style');
      return { success: true, style };
    } catch (error) {
      console.error('Failed to load style:', error);
      return { success: false, error: String(error) };
    }
  });

  // Save standby groups
  ipcMain.handle(
    IPC_CHANNELS.SAVE_STANDBY_GROUPS,
    async (_event, groups: unknown[]) => {
      try {
        store.set('standbyGroups', groups);
        return { success: true };
      } catch (error) {
        console.error('Failed to save standby groups:', error);
        return { success: false, error: String(error) };
      }
    }
  );

  // Load standby groups
  ipcMain.handle(IPC_CHANNELS.LOAD_STANDBY_GROUPS, async () => {
    try {
      const groups = store.get('standbyGroups');
      return { success: true, groups };
    } catch (error) {
      console.error('Failed to load standby groups:', error);
      return { success: false, error: String(error) };
    }
  });

  // Import font
  ipcMain.handle(IPC_CHANNELS.IMPORT_FONT, async (_event, filePath: string, fontName: string) => {
    try {
      const fontsDir = path.join(app.getPath('userData'), 'fonts');
      if (!fs.existsSync(fontsDir)) {
        fs.mkdirSync(fontsDir, { recursive: true });
      }

      const fileName = path.basename(filePath);
      const destPath = path.join(fontsDir, fileName);
      fs.copyFileSync(filePath, destPath);

      const fonts = store.get('importedFonts', []) as string[];
      if (!fonts.includes(fontName)) {
        fonts.push(fontName);
        store.set('importedFonts', fonts);
      }

      return { success: true, fontPath: destPath };
    } catch (error) {
      console.error('Failed to import font:', error);
      return { success: false, error: String(error) };
    }
  });

  // Get imported fonts
  ipcMain.handle(IPC_CHANNELS.GET_FONTS, async () => {
    try {
      const fonts = store.get('importedFonts', []);
      return { success: true, fonts };
    } catch (error) {
      console.error('Failed to get fonts:', error);
      return { success: false, error: String(error) };
    }
  });

  // Remove font
  ipcMain.handle(IPC_CHANNELS.REMOVE_FONT, async (_event, fontName: string) => {
    try {
      const fonts = store.get('importedFonts', []) as string[];
      const updatedFonts = fonts.filter((f) => f !== fontName);
      store.set('importedFonts', updatedFonts);
      return { success: true };
    } catch (error) {
      console.error('Failed to remove font:', error);
      return { success: false, error: String(error) };
    }
  });
}

/**
 * App ready handler
 */
app.on('ready', () => {
  createMainWindow();
  initializeScreenManager();
  setupIpcHandlers();

  // Auto-start server on app launch
  initializeWebSocketServer();
  initializeBonjourService();

  // On Windows, try to add firewall rule (requires admin, may fail silently)
  if (process.platform === 'win32') {
    const { exec } = require('child_process');
    const appPath = app.getPath('exe');
    // Add inbound rule for the app
    exec(
      `netsh advfirewall firewall add rule name="LyricsCaster" dir=in action=allow program="${appPath}" enable=yes profile=any`,
      (error: any) => {
        if (error) {
          console.log('[Firewall] Could not auto-add rule (may need admin rights):', error.message);
        } else {
          console.log('[Firewall] Firewall rule added for LyricsCaster');
        }
      }
    );
    // Also add rule for port 9600
    exec(
      `netsh advfirewall firewall add rule name="LyricsCaster Port 9600" dir=in action=allow protocol=tcp localport=9600 enable=yes profile=any`,
      (error: any) => {
        if (error) {
          console.log('[Firewall] Could not auto-add port rule:', error.message);
        } else {
          console.log('[Firewall] Port 9600 firewall rule added');
        }
      }
    );
  }
});

/**
 * Quit app when all windows are closed
 */
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

/**
 * Re-create window on macOS when dock icon is clicked
 */
app.on('activate', () => {
  if (mainWindow === null) {
    createMainWindow();
  }
});

/**
 * Handle app termination
 */
app.on('before-quit', () => {
  if (wsServer) {
    wsServer.stop();
  }
  if (bonjourService) {
    bonjourService.stop();
  }
});

export { mainWindow, projectionWindow };
