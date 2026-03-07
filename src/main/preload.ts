// preload.ts
// Electron 预加载脚本 - 安全暴露 IPC 桥接到渲染进程

import { contextBridge, ipcRenderer } from 'electron';

// IPC 通道名（与 main/index.ts 保持一致）
const IPC = {
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

contextBridge.exposeInMainWorld('electronAPI', {
  // 服务器控制
  startServer: () => ipcRenderer.invoke(IPC.START_SERVER),
  stopServer: () => ipcRenderer.invoke(IPC.STOP_SERVER),

  // 投影控制
  startProjection: (screenIndex: number) => ipcRenderer.invoke(IPC.START_PROJECTION, screenIndex),
  stopProjection: () => ipcRenderer.invoke(IPC.STOP_PROJECTION),

  // 屏幕信息
  getScreens: () => ipcRenderer.invoke(IPC.GET_SCREENS),

  // 文件对话框
  openFileDialog: (options: any) => ipcRenderer.invoke(IPC.OPEN_FILE_DIALOG, options),

  // 样式持久化
  saveStyle: (style: any) => ipcRenderer.invoke(IPC.SAVE_STYLE, style),
  loadStyle: () => ipcRenderer.invoke(IPC.LOAD_STYLE),

  // 待机图片组
  saveStandbyGroups: (groups: any) => ipcRenderer.invoke(IPC.SAVE_STANDBY_GROUPS, groups),
  loadStandbyGroups: () => ipcRenderer.invoke(IPC.LOAD_STANDBY_GROUPS),

  // 字体管理
  importFont: (filePath: string, fontName: string) => ipcRenderer.invoke(IPC.IMPORT_FONT, filePath, fontName),
  getFonts: () => ipcRenderer.invoke(IPC.GET_FONTS),
  removeFont: (fontName: string) => ipcRenderer.invoke(IPC.REMOVE_FONT, fontName),

  // 事件监听（主进程→渲染进程）
  onPeerMessage: (callback: (message: any) => void) =>
    ipcRenderer.on(IPC.PEER_MESSAGE, (_event, message) => callback(message)),

  onConnectionChanged: (callback: (connected: boolean, deviceName: string) => void) =>
    ipcRenderer.on(IPC.CONNECTION_CHANGED, (_event, data) => callback(data.connected, data.deviceName || '')),

  onScreensUpdated: (callback: (screens: any[]) => void) =>
    ipcRenderer.on(IPC.SCREENS_UPDATED, (_event, screens) => callback(screens)),
});
