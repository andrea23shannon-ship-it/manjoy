// AppState.ts
// 全局状态管理 - React Context + useReducer
// 移植自 Mac 版 AppState.swift

import React, { createContext, useContext, useReducer, ReactNode } from 'react';
import {
  PeerMessageType,
  LyricsStyle,
  SongInfo,
  LyricLine,
  StandbyImageGroup,
  ScreenInfo,
  LogEntry,
  defaultStyle,
  PlaybackAction,
} from '../../shared/types';

// ===== 状态类型 =====
export interface AppStateType {
  isPhoneConnected: boolean;
  connectedDeviceName: string;
  currentSong: SongInfo | null;
  lyrics: LyricLine[];
  currentLineIndex: number;
  currentTime: number;
  lineProgress: number; // 0~1 行内进度
  isPlaying: boolean;
  style: LyricsStyle;
  isProjecting: boolean;
  standbyGroups: StandbyImageGroup[];
  selectedGroupId: string | null;
  standbyDelay: number;
  currentStandbyIndex: number;
  standbyReady: boolean;
  logs: LogEntry[];
  isServerRunning: boolean;
  screens: ScreenInfo[];
  selectedScreenIndex: number;
}

export const initialAppState: AppStateType = {
  isPhoneConnected: false,
  connectedDeviceName: '',
  currentSong: null,
  lyrics: [],
  currentLineIndex: -1,
  currentTime: 0,
  lineProgress: 0,
  isPlaying: false,
  style: defaultStyle,
  isProjecting: false,
  standbyGroups: [],
  selectedGroupId: null,
  standbyDelay: 10,
  currentStandbyIndex: 0,
  standbyReady: false,
  logs: [],
  isServerRunning: false,
  screens: [],
  selectedScreenIndex: 0,
};

// ===== Action 类型 =====
export type AppAction =
  | { type: 'SET_CONNECTION'; payload: { connected: boolean; deviceName: string } }
  | { type: 'SET_SONG_LOADED'; payload: { song: SongInfo; lyrics: LyricLine[] } }
  | { type: 'SET_PLAYBACK_SYNC'; payload: { currentTime: number; isPlaying: boolean; lineProgress: number } }
  | { type: 'SET_LINE_CHANGED'; payload: { lineIndex: number; currentTime: number } }
  | { type: 'SET_PLAYBACK_CONTROL'; payload: { action: string } }
  | { type: 'SET_STYLE'; payload: LyricsStyle }
  | { type: 'SET_PROJECTING'; payload: boolean }
  | { type: 'SET_SCREENS'; payload: ScreenInfo[] }
  | { type: 'SET_SELECTED_SCREEN'; payload: number }
  | { type: 'SET_SERVER_RUNNING'; payload: boolean }
  | { type: 'ADD_LOG'; payload: { message: string } }
  | { type: 'CLEAR_LOGS' }
  | { type: 'SET_STANDBY_READY'; payload: boolean }
  | { type: 'SET_STANDBY_INDEX'; payload: number }
  | { type: 'SET_STANDBY_GROUPS'; payload: StandbyImageGroup[] }
  | { type: 'SET_SELECTED_GROUP'; payload: string | null }
  | { type: 'SET_STANDBY_DELAY'; payload: number };

// ===== Reducer =====
function appStateReducer(state: AppStateType, action: AppAction): AppStateType {
  switch (action.type) {
    case 'SET_CONNECTION':
      return {
        ...state,
        isPhoneConnected: action.payload.connected,
        connectedDeviceName: action.payload.deviceName,
      };

    case 'SET_SONG_LOADED':
      return {
        ...state,
        currentSong: action.payload.song,
        lyrics: action.payload.lyrics,
        currentLineIndex: -1,
        currentTime: 0,
        lineProgress: 0,
        isPlaying: false,
      };

    case 'SET_PLAYBACK_SYNC':
      return {
        ...state,
        currentTime: action.payload.currentTime,
        isPlaying: action.payload.isPlaying,
        lineProgress: action.payload.lineProgress,
      };

    case 'SET_LINE_CHANGED':
      return {
        ...state,
        currentLineIndex: action.payload.lineIndex,
        currentTime: action.payload.currentTime,
        lineProgress: 0, // 换行时重置进度
      };

    case 'SET_PLAYBACK_CONTROL': {
      const act = action.payload.action;
      if (act === 'play') return { ...state, isPlaying: true };
      if (act === 'pause') return { ...state, isPlaying: false };
      if (act === 'stop') return { ...state, isPlaying: false, currentTime: 0, currentLineIndex: -1 };
      return state;
    }

    case 'SET_STYLE':
      return { ...state, style: action.payload };

    case 'SET_PROJECTING':
      return { ...state, isProjecting: action.payload };

    case 'SET_SCREENS':
      return { ...state, screens: action.payload };

    case 'SET_SELECTED_SCREEN':
      return { ...state, selectedScreenIndex: action.payload };

    case 'SET_SERVER_RUNNING':
      return { ...state, isServerRunning: action.payload };

    case 'ADD_LOG': {
      const entry: LogEntry = {
        id: crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}_${Math.random()}`,
        time: new Date(),
        message: action.payload.message,
      };
      const logs = [...state.logs, entry];
      if (logs.length > 200) logs.splice(0, 50);
      return { ...state, logs };
    }

    case 'CLEAR_LOGS':
      return { ...state, logs: [] };

    case 'SET_STANDBY_READY':
      return { ...state, standbyReady: action.payload };

    case 'SET_STANDBY_INDEX':
      return { ...state, currentStandbyIndex: action.payload };

    case 'SET_STANDBY_GROUPS':
      return { ...state, standbyGroups: action.payload };

    case 'SET_SELECTED_GROUP':
      return { ...state, selectedGroupId: action.payload };

    case 'SET_STANDBY_DELAY':
      return { ...state, standbyDelay: action.payload };

    default:
      return state;
  }
}

// ===== Context =====
export const AppStateContext = createContext<AppStateType>(initialAppState);
export const AppDispatchContext = createContext<React.Dispatch<AppAction>>(() => {});

// ===== Provider =====
interface Props { children: ReactNode }

export function AppStateProvider({ children }: Props) {
  const [state, dispatch] = useReducer(appStateReducer, initialAppState);
  return (
    <AppStateContext.Provider value={state}>
      <AppDispatchContext.Provider value={dispatch}>
        {children}
      </AppDispatchContext.Provider>
    </AppStateContext.Provider>
  );
}

// ===== Hooks =====
export function useAppState(): AppStateType {
  return useContext(AppStateContext);
}

export function useAppDispatch(): React.Dispatch<AppAction> {
  return useContext(AppDispatchContext);
}

// ===== 处理来自手机的 PeerMessage =====
// 消息已在 WebSocketServer 中解码：type 是字符串，payload 是已解码的 JSON 对象
export function handlePeerMessage(
  dispatch: React.Dispatch<AppAction>,
  message: { type: string; payload: any }
): void {
  switch (message.type) {
    case PeerMessageType.SongLoaded: // 'songLoaded'
      if (message.payload?.song && message.payload?.lyrics) {
        dispatch({
          type: 'SET_SONG_LOADED',
          payload: { song: message.payload.song, lyrics: message.payload.lyrics },
        });
        dispatch({
          type: 'ADD_LOG',
          payload: { message: `收到歌曲: ${message.payload.song.title} - ${message.payload.song.artist}, 共${message.payload.lyrics.length}行歌词` },
        });
      }
      break;

    case PeerMessageType.PlaybackSync: // 'playbackSync'
      dispatch({
        type: 'SET_PLAYBACK_SYNC',
        payload: {
          currentTime: message.payload.currentTime ?? 0,
          isPlaying: message.payload.isPlaying ?? false,
          lineProgress: message.payload.lineProgress ?? 0,
        },
      });
      break;

    case PeerMessageType.LineChanged: // 'lineChanged'
      dispatch({
        type: 'SET_LINE_CHANGED',
        payload: {
          lineIndex: message.payload.lineIndex ?? 0,
          currentTime: message.payload.currentTime ?? 0,
        },
      });
      break;

    case PeerMessageType.PlaybackControl: // 'playbackControl'
      dispatch({
        type: 'SET_PLAYBACK_CONTROL',
        payload: { action: message.payload.action ?? 'pause' },
      });
      const actionName = message.payload.action === 'play' ? '播放' :
                          message.payload.action === 'pause' ? '暂停' : '停止';
      dispatch({ type: 'ADD_LOG', payload: { message: actionName } });
      break;

    default:
      console.warn(`[AppState] 未知消息类型: ${message.type}`);
      break;
  }
}

// ===== 设置 IPC 监听 =====
export function setupIPCListeners(dispatch: React.Dispatch<AppAction>): void {
  const api = (window as any).electronAPI;
  if (!api) {
    console.warn('electronAPI 不可用');
    return;
  }

  // 监听手机消息
  api.onPeerMessage((message: any) => {
    handlePeerMessage(dispatch, message);
  });

  // 监听连接状态
  api.onConnectionChanged((connected: boolean, deviceName: string) => {
    dispatch({
      type: 'SET_CONNECTION',
      payload: { connected, deviceName },
    });
    dispatch({
      type: 'ADD_LOG',
      payload: { message: connected ? `手机 ${deviceName} 已连接` : `手机 ${deviceName} 已断开` },
    });
  });

  // 监听屏幕变化
  api.onScreensUpdated((screens: ScreenInfo[]) => {
    dispatch({ type: 'SET_SCREENS', payload: screens });
  });
}
