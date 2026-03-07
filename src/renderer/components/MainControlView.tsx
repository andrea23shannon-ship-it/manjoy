import React, { useState, useCallback, useEffect } from 'react';
import { useAppState, useAppDispatch } from '../models/AppState';
import { formatTime, getVisibleLines, getTotalDuration, getProgressPercentage } from '../models/LyricsModels';
import { colorToCSS, LyricsStyle } from '../../shared/types';
import StyleEditorView from './StyleEditorView';
import StandbyImageSheet from './StandbyImageSheet';

// ===== STYLES =====
const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column' as const,
    height: '100vh',
    backgroundColor: '#f5f5f5',
    fontFamily: 'Segoe UI, sans-serif',
  } as React.CSSProperties,

  header: {
    display: 'flex',
    gap: '16px',
    padding: '16px',
    backgroundColor: '#ffffff',
    borderBottom: '1px solid #e0e0e0',
    flexWrap: 'wrap' as const,
  } as React.CSSProperties,

  card: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '12px 16px',
    backgroundColor: '#f9f9f9',
    border: '1px solid #d0d0d0',
    borderRadius: '6px',
    fontSize: '14px',
  } as React.CSSProperties,

  connectionCard: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '12px 16px',
    backgroundColor: '#f9f9f9',
    border: '1px solid #d0d0d0',
    borderRadius: '6px',
    fontSize: '14px',
    minWidth: '280px',
  } as React.CSSProperties,

  statusDot: {
    width: '12px',
    height: '12px',
    borderRadius: '50%',
    flexShrink: 0,
  } as React.CSSProperties,

  statusDotConnected: {
    backgroundColor: '#4CAF50',
  } as React.CSSProperties,

  statusDotDisconnected: {
    backgroundColor: '#f44336',
  } as React.CSSProperties,

  button: {
    padding: '8px 16px',
    backgroundColor: '#2196F3',
    color: '#ffffff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    cursor: 'pointer',
    fontWeight: '600' as const,
    transition: 'background-color 0.2s',
  } as React.CSSProperties,

  buttonSecondary: {
    padding: '8px 16px',
    backgroundColor: '#757575',
    color: '#ffffff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    cursor: 'pointer',
    fontWeight: '600' as const,
    transition: 'background-color 0.2s',
  } as React.CSSProperties,

  content: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column' as const,
    overflow: 'hidden',
  } as React.CSSProperties,

  tabBar: {
    display: 'flex',
    backgroundColor: '#ffffff',
    borderBottom: '2px solid #e0e0e0',
    padding: '0 16px',
    gap: '24px',
  } as React.CSSProperties,

  tab: {
    padding: '12px 0',
    fontSize: '14px',
    fontWeight: '600' as const,
    cursor: 'pointer',
    color: '#666',
    borderBottom: '3px solid transparent',
    transition: 'all 0.2s',
  } as React.CSSProperties,

  tabActive: {
    color: '#2196F3',
    borderBottomColor: '#2196F3',
  } as React.CSSProperties,

  tabContent: {
    flex: 1,
    overflow: 'auto',
    padding: '16px',
  } as React.CSSProperties,

  lyricsContainer: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '8px',
  } as React.CSSProperties,

  lyricLine: {
    padding: '12px',
    backgroundColor: '#ffffff',
    border: '1px solid #e0e0e0',
    borderRadius: '4px',
    fontSize: '14px',
    transition: 'all 0.2s',
  } as React.CSSProperties,

  lyricLineCurrentHighlight: {
    backgroundColor: '#FFD700',
    color: '#000000',
    fontWeight: 'bold' as const,
    borderColor: '#FFC700',
  } as React.CSSProperties,

  lyricLineNext: {
    backgroundColor: '#e3f2fd',
    color: '#1976d2',
  } as React.CSSProperties,

  lyricLinePast: {
    color: '#999',
  } as React.CSSProperties,

  lyricLineUpcoming: {
    opacity: 0.5,
  } as React.CSSProperties,

  logContainer: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '8px',
    fontFamily: 'Consolas, monospace',
    fontSize: '12px',
  } as React.CSSProperties,

  logEntry: {
    padding: '8px 12px',
    backgroundColor: '#f5f5f5',
    border: '1px solid #e0e0e0',
    borderRadius: '4px',
    borderLeftWidth: '3px',
    borderLeftStyle: 'solid',
  } as React.CSSProperties,

  logEntryInfo: {
    borderLeftColor: '#2196F3',
  } as React.CSSProperties,

  logEntryWarn: {
    borderLeftColor: '#FF9800',
  } as React.CSSProperties,

  logEntryError: {
    borderLeftColor: '#f44336',
  } as React.CSSProperties,

  projectionPreview: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#000000',
    borderRadius: '8px',
    minHeight: '300px',
    color: '#ffffff',
    fontSize: '14px',
  } as React.CSSProperties,

  previewCanvas: {
    maxWidth: '100%',
    maxHeight: '100%',
    borderRadius: '4px',
  } as React.CSSProperties,

  progressBar: {
    width: '100%',
    height: '4px',
    backgroundColor: '#e0e0e0',
    borderRadius: '2px',
    overflow: 'hidden',
    marginTop: '8px',
  } as React.CSSProperties,

  progressFill: {
    height: '100%',
    backgroundColor: '#2196F3',
    transition: 'width 0.1s linear',
  } as React.CSSProperties,

  timeDisplay: {
    fontSize: '12px',
    color: '#666',
    marginTop: '4px',
    textAlign: 'center' as const,
  } as React.CSSProperties,

  modalOverlay: {
    position: 'fixed' as const,
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
  } as React.CSSProperties,

  emptyState: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    color: '#999',
    fontSize: '16px',
  } as React.CSSProperties,
};

type TabType = '投影预览' | '歌词列表' | '日志';

export default function MainControlView() {
  const state = useAppState();
  const dispatch = useAppDispatch();
  const [activeTab, setActiveTab] = useState<TabType>('投影预览');
  const [showStyleEditor, setShowStyleEditor] = useState(false);
  const [showStandbyManager, setShowStandbyManager] = useState(false);
  const [networkInfo, setNetworkInfo] = useState<{ localIPs: string[]; port: number; bonjourActive: boolean } | null>(null);

  // Load network info on mount
  useEffect(() => {
    const api = (window as any).electronAPI;
    if (api?.getNetworkInfo) {
      api.getNetworkInfo().then((info: any) => {
        setNetworkInfo(info);
      });
    }
  }, []);

  const handleStartServer = useCallback(async () => {
    if (window.electronAPI?.startServer) {
      try {
        await window.electronAPI.startServer();
        dispatch({ type: 'SET_SERVER_RUNNING', payload: true });
        dispatch({ type: 'ADD_LOG', payload: { message: '服务器已启动' } });
      } catch (err) {
        dispatch({ type: 'ADD_LOG', payload: { message: `启动服务器失败: ${err}` } });
      }
    }
  }, [dispatch]);

  const handleStopServer = useCallback(() => {
    if (window.electronAPI?.stopServer) {
      window.electronAPI.stopServer();
    }
  }, []);

  const handleStartProjection = useCallback(() => {
    if (window.electronAPI?.startProjection && state.screens.length > 0) {
      const screen = state.screens[state.selectedScreenIndex];
      if (screen) {
        window.electronAPI.startProjection(screen.id);
      }
    }
  }, [state.selectedScreenIndex, state.screens]);

  const handleStopProjection = useCallback(() => {
    if (window.electronAPI?.stopProjection) {
      window.electronAPI.stopProjection();
    }
  }, []);

  const visibleLines = getVisibleLines(state.lyrics, state.currentLineIndex, 10);
  const totalDuration = getTotalDuration(state.lyrics);
  const progress = getProgressPercentage(state.currentTime, totalDuration);

  const connectionStatus = state.isPhoneConnected ? 'connected' : 'disconnected';

  return (
    <div style={styles.container}>
      {/* Header Section */}
      <div style={styles.header}>
        {/* Connection Status Card */}
        <div style={styles.connectionCard}>
          <div
            style={{
              ...styles.statusDot,
              ...(connectionStatus === 'connected'
                ? styles.statusDotConnected
                : styles.statusDotDisconnected),
            }}
          />
          <div>
            <div style={{ fontSize: '12px', color: '#666' }}>连接状态</div>
            <div style={{ fontWeight: 'bold' as const }}>
              {state.isPhoneConnected ? state.connectedDeviceName || '已连接' : '未连接'}
            </div>
          </div>
          <button
            style={{
              ...styles.button,
              ...(state.isServerRunning ? { backgroundColor: '#4CAF50', cursor: 'default' } : {}),
            }}
            onClick={handleStartServer}
            disabled={state.isServerRunning}
            title={state.isServerRunning ? '服务器已运行' : '启动服务器'}
          >
            {state.isServerRunning ? '服务运行中' : '启动服务'}
          </button>
        </div>

        {/* Network Info Card */}
        {networkInfo && networkInfo.localIPs.length > 0 && (
          <div style={{ ...styles.card, backgroundColor: '#e8f5e9', borderColor: '#a5d6a7' }}>
            <div>
              <div style={{ fontSize: '12px', color: '#388e3c' }}>本机地址 (手机需在同一WiFi)</div>
              <div style={{ fontWeight: 'bold' as const, fontSize: '13px' }}>
                {networkInfo.localIPs.map((ip, i) => (
                  <span key={i}>
                    {i > 0 && ' / '}
                    ws://{ip}:{networkInfo.port}
                  </span>
                ))}
              </div>
              <div style={{ fontSize: '11px', color: '#666', marginTop: '2px' }}>
                Bonjour: {networkInfo.bonjourActive ? '已广播' : '未启动'}
              </div>
            </div>
          </div>
        )}

        {/* Projector Status Card */}
        <div style={styles.card}>
          <div>
            <div style={{ fontSize: '12px', color: '#666' }}>投影状态</div>
            <div style={{ fontWeight: 'bold' as const }}>
              {state.isProjecting ? `投影中 (屏幕 ${state.selectedScreenIndex})` : '未投影'}
            </div>
          </div>
          {state.screens.length > 0 && (
            <>
              <select
                value={state.selectedScreenIndex}
                onChange={(e) =>
                  dispatch({
                    type: 'SET_SELECTED_SCREEN',
                    payload: parseInt(e.target.value, 10),
                  })
                }
                style={{
                  padding: '6px',
                  borderRadius: '4px',
                  border: '1px solid #d0d0d0',
                  fontSize: '12px',
                }}
              >
                {state.screens.map((screen, idx) => (
                  <option key={idx} value={idx}>
                    {screen.label}
                  </option>
                ))}
              </select>
              {state.isProjecting ? (
                <button style={styles.button} onClick={handleStopProjection}>
                  停止投影
                </button>
              ) : (
                <button style={styles.button} onClick={handleStartProjection}>
                  开始投影
                </button>
              )}
            </>
          )}
        </div>

        {/* Settings Buttons */}
        <button
          style={styles.button}
          onClick={() => setShowStyleEditor(true)}
        >
          歌词显示设置
        </button>

        <button
          style={styles.button}
          onClick={() => setShowStandbyManager(true)}
        >
          待机图片管理
        </button>
      </div>

      {/* Tab Bar */}
      <div style={styles.tabBar}>
        {(['投影预览', '歌词列表', '日志'] as TabType[]).map((tab) => (
          <div
            key={tab}
            style={{
              ...styles.tab,
              ...(activeTab === tab ? styles.tabActive : {}),
            }}
            onClick={() => setActiveTab(tab)}
          >
            {tab}
          </div>
        ))}
      </div>

      {/* Content Area */}
      <div style={styles.content}>
        <div style={styles.tabContent}>
          {/* Projection Preview Tab */}
          {activeTab === '投影预览' && (
            <div style={styles.projectionPreview}>
              {state.currentSong ? (
                <div style={{ width: '100%' }}>
                  <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                    <div style={{ fontSize: '16px', fontWeight: 'bold' }}>
                      {state.currentSong.title}
                    </div>
                    <div style={{ fontSize: '14px', color: '#ccc', marginTop: '4px' }}>
                      {state.currentSong.artist}
                    </div>
                  </div>

                  {visibleLines.length > 0 ? (
                    <div style={{ padding: '20px', textAlign: 'center' }}>
                      {visibleLines.map((line, idx) => (
                        <div
                          key={idx}
                          style={{
                            fontSize: state.style.fontSize || 32,
                            color:
                              line.state === 'current'
                                ? colorToCSS(state.style.currentLineColor)
                                : colorToCSS(state.style.otherLineColor),
                            opacity:
                              line.state === 'upcoming'
                                ? 0.5
                                : 1,
                            fontFamily: state.style.fontName,
                            marginBottom: '12px',
                            fontWeight: line.state === 'current' ? 'bold' : 'normal',
                          }}
                        >
                          {line.text}
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div style={styles.emptyState}>
                      {state.lyrics.length === 0 ? '等待歌词...' : '无歌词'}
                    </div>
                  )}

                  {/* Progress Bar */}
                  <div style={{ padding: '0 20px' }}>
                    <div style={styles.progressBar}>
                      <div
                        style={{
                          ...styles.progressFill,
                          width: `${progress * 100}%`,
                        }}
                      />
                    </div>
                    <div style={styles.timeDisplay}>
                      {formatTime(state.currentTime)} / {formatTime(totalDuration)}
                    </div>
                  </div>
                </div>
              ) : (
                <div style={styles.emptyState}>未加载歌曲</div>
              )}
            </div>
          )}

          {/* Lyrics List Tab */}
          {activeTab === '歌词列表' && (
            <div style={styles.lyricsContainer}>
              {state.lyrics.length > 0 ? (
                state.lyrics.map((line, idx) => {
                  let lineStyle = { ...styles.lyricLine };

                  if (idx === state.currentLineIndex) {
                    lineStyle = { ...lineStyle, ...styles.lyricLineCurrentHighlight };
                  } else if (idx < state.currentLineIndex) {
                    lineStyle = { ...lineStyle, ...styles.lyricLinePast };
                  } else if (idx === state.currentLineIndex + 1) {
                    lineStyle = { ...lineStyle, ...styles.lyricLineNext };
                  } else if (idx > state.currentLineIndex + 1) {
                    lineStyle = { ...lineStyle, ...styles.lyricLineUpcoming };
                  }

                  return (
                    <div key={idx} style={lineStyle}>
                      <div style={{ fontSize: '12px', color: 'inherit', opacity: 0.7 }}>
                        {formatTime(line.time)}
                      </div>
                      <div style={{ marginTop: '4px' }}>{line.text}</div>
                    </div>
                  );
                })
              ) : (
                <div style={styles.emptyState}>无歌词</div>
              )}
            </div>
          )}

          {/* Logs Tab */}
          {activeTab === '日志' && (
            <div>
              <div style={{ marginBottom: '12px' }}>
                <button
                  style={styles.buttonSecondary}
                  onClick={() => {
                    dispatch({ type: 'CLEAR_LOGS' });
                  }}
                >
                  清除日志
                </button>
              </div>
              <div style={styles.logContainer}>
                {state.logs.length > 0 ? (
                  state.logs.map((log, idx) => {
                    return (
                      <div key={idx} style={{ ...styles.logEntry, ...styles.logEntryInfo }}>
                        <div style={{ display: 'flex', gap: '12px' }}>
                          <div style={{ color: '#999', flexShrink: 0 }}>
                            {new Date(log.time).toLocaleTimeString()}
                          </div>
                          <div style={{ color: 'inherit' }}>
                            {log.message}
                          </div>
                        </div>
                      </div>
                    );
                  })
                ) : (
                  <div style={styles.emptyState}>无日志</div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Style Editor Modal */}
      {showStyleEditor && (
        <div style={styles.modalOverlay}>
          <div style={{ width: '90%', maxWidth: '1200px', height: '90vh', overflow: 'auto', borderRadius: '8px' }}>
            <StyleEditorView
              style={state.style}
              onStyleChange={(newStyle: LyricsStyle) => {
                dispatch({ type: 'SET_STYLE', payload: newStyle });
                if (window.electronAPI?.saveStyle) {
                  window.electronAPI.saveStyle(newStyle);
                }
              }}
              onClose={() => setShowStyleEditor(false)}
            />
          </div>
        </div>
      )}

      {/* Standby Image Manager Modal */}
      {showStandbyManager && (
        <StandbyImageSheet
          standbyGroups={state.standbyGroups}
          selectedGroupId={state.selectedGroupId}
          standbyDelay={state.standbyDelay}
          onGroupsChange={(groups) => {
            dispatch({ type: 'SET_STANDBY_GROUPS', payload: groups });
            if (window.electronAPI?.saveStandbyGroups) {
              window.electronAPI.saveStandbyGroups(groups);
            }
          }}
          onDelayChange={(delay) => {
            dispatch({ type: 'SET_STANDBY_DELAY', payload: delay });
          }}
          onSelectedGroupChange={(id) => {
            dispatch({ type: 'SET_SELECTED_GROUP', payload: id });
          }}
          onClose={() => setShowStandbyManager(false)}
        />
      )}
    </div>
  );
}
