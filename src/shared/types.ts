// types.ts
// 共享类型定义 - 与 iOS/Mac 端 LyricsModels.swift 完全对应

// 歌词行
export interface LyricLine {
  id: string;        // UUID
  time: number;      // 秒数（如 63.5 = 1:03.5）
  text: string;      // 歌词文本
  translation?: string; // 翻译（可选）
}

// 歌曲信息
export interface SongInfo {
  title: string;
  artist: string;
  album?: string;
  duration?: number;  // 总时长（秒）
}

// 手机→投屏端 消息类型
export enum PeerMessageType {
  SongLoaded = 'songLoaded',
  PlaybackSync = 'playbackSync',
  LineChanged = 'lineChanged',
  PlaybackControl = 'playbackControl',
}

// 消息协议（与 Swift PeerMessage 对应）
export interface PeerMessage {
  type: PeerMessageType;
  payload: string; // Base64编码的JSON（Swift端是Data）
}

// 各消息负载
export interface SongLoadedPayload {
  song: SongInfo;
  lyrics: LyricLine[];
}

export interface PlaybackSyncPayload {
  currentTime: number;
  isPlaying: boolean;
  lineProgress: number; // 行内进度 0~1
}

export interface LineChangedPayload {
  lineIndex: number;
  currentTime: number;
}

export enum PlaybackAction {
  Play = 'play',
  Pause = 'pause',
  Stop = 'stop',
}

export interface PlaybackControlPayload {
  action: PlaybackAction;
}

// 动画风格类型（14种）
export enum AnimationStyleType {
  None = 'none',
  Smooth = 'smooth',
  Fade = 'fade',
  Scale = 'scale',
  Karaoke = 'karaoke',
  Bounce = 'bounce',
  Wave = 'wave',
  Pulse = 'pulse',
  Typewriter = 'typewriter',
  SlideIn = 'slideIn',
  CharBounce = 'charBounce',
  Scatter = 'scatter',
  Float3D = 'float3D',
  RandomSize = 'randomSize',
}

// 动画风格显示名
export const AnimationStyleNames: Record<AnimationStyleType, string> = {
  [AnimationStyleType.None]: '无动画',
  [AnimationStyleType.Smooth]: '平滑滚动',
  [AnimationStyleType.Fade]: '淡入淡出',
  [AnimationStyleType.Scale]: '缩放高亮',
  [AnimationStyleType.Karaoke]: '卡拉OK逐字',
  [AnimationStyleType.Bounce]: '弹跳节拍',
  [AnimationStyleType.Wave]: '波浪律动',
  [AnimationStyleType.Pulse]: '脉冲呼吸',
  [AnimationStyleType.Typewriter]: '打字机',
  [AnimationStyleType.SlideIn]: '滑入聚焦',
  [AnimationStyleType.CharBounce]: '逐字弹入',
  [AnimationStyleType.Scatter]: '散落歌词',
  [AnimationStyleType.Float3D]: '3D浮现',
  [AnimationStyleType.RandomSize]: '随机大小',
};

// 字重
export enum FontWeight {
  Regular = 'regular',
  Medium = 'medium',
  Semibold = 'semibold',
  Bold = 'bold',
  Heavy = 'heavy',
}

export const FontWeightValues: Record<FontWeight, number> = {
  [FontWeight.Regular]: 400,
  [FontWeight.Medium]: 500,
  [FontWeight.Semibold]: 600,
  [FontWeight.Bold]: 700,
  [FontWeight.Heavy]: 900,
};

// 文字对齐
export enum TextAlignmentType {
  Leading = 'leading',
  Center = 'center',
  Trailing = 'trailing',
}

export const TextAlignmentNames: Record<TextAlignmentType, string> = {
  [TextAlignmentType.Leading]: '左对齐',
  [TextAlignmentType.Center]: '居中',
  [TextAlignmentType.Trailing]: '右对齐',
};

// 可编码颜色（与 Swift CodableColor 对应）
export interface CodableColor {
  r: number;
  g: number;
  b: number;
  a: number;
}

export function colorToCSS(c: CodableColor): string {
  return `rgba(${Math.round(c.r * 255)}, ${Math.round(c.g * 255)}, ${Math.round(c.b * 255)}, ${c.a})`;
}

export function colorToHex(c: CodableColor): string {
  const r = Math.round(c.r * 255).toString(16).padStart(2, '0');
  const g = Math.round(c.g * 255).toString(16).padStart(2, '0');
  const b = Math.round(c.b * 255).toString(16).padStart(2, '0');
  return `#${r}${g}${b}`;
}

export function hexToColor(hex: string, a: number = 1.0): CodableColor {
  const h = hex.replace('#', '');
  return {
    r: parseInt(h.substring(0, 2), 16) / 255,
    g: parseInt(h.substring(2, 4), 16) / 255,
    b: parseInt(h.substring(4, 6), 16) / 255,
    a,
  };
}

// 歌词样式配置（与 Swift LyricsStyle 对应）
export interface LyricsStyle {
  fontName: string;
  fontSize: number;
  fontWeight: FontWeight;
  currentLineColor: CodableColor;
  currentLineGlow: boolean;
  otherLineColor: CodableColor;
  pastLineColor: CodableColor;
  backgroundColor: CodableColor;
  backgroundOpacity: number;
  backgroundImage?: string;
  animationStyle: AnimationStyleType;
  animationSpeed: number;
  alignment: TextAlignmentType;
  lineSpacing: number;
  showTranslation: boolean;
  visibleLineCount: number;
  padding: number;
}

// 默认样式（与 Swift 默认值对应）
export const defaultStyle: LyricsStyle = {
  fontName: 'Microsoft YaHei',  // Windows 中文默认字体
  fontSize: 48,
  fontWeight: FontWeight.Bold,
  currentLineColor: { r: 1, g: 0.85, b: 0, a: 1 },     // 金色
  currentLineGlow: true,
  otherLineColor: { r: 1, g: 1, b: 1, a: 0.5 },         // 半透明白
  pastLineColor: { r: 0.6, g: 0.6, b: 0.6, a: 0.4 },
  backgroundColor: { r: 0, g: 0, b: 0, a: 1 },           // 黑色
  backgroundOpacity: 1.0,
  animationStyle: AnimationStyleType.Smooth,
  animationSpeed: 0.5,
  alignment: TextAlignmentType.Center,
  lineSpacing: 20,
  showTranslation: true,
  visibleLineCount: 5,
  padding: 40,
};

// 待机图片分组
export interface StandbyImageGroup {
  id: string;
  name: string;
  imagePaths: string[];
  enabled: boolean;
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
  slideInterval: number;
}

// 日志条目
export interface LogEntry {
  id: string;
  time: Date;
  message: string;
}

// 线状态枚举
export enum LineState {
  Past = 'past',
  Current = 'current',
  Upcoming = 'upcoming',
}

// IPC 通道名
export const IPC_CHANNELS = {
  // 主进程→渲染进程
  PEER_MESSAGE: 'peer-message',
  CONNECTION_CHANGED: 'connection-changed',
  SCREENS_UPDATED: 'screens-updated',
  // 渲染进程→主进程
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
} as const;

// 屏幕信息（与 ScreenManager.ts 返回值对应）
export interface ScreenInfo {
  id: number;
  label: string;
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  workArea: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  scaleFactor: number;
  isPrimary: boolean;
  isExternal: boolean;
  rotation: number;
}
