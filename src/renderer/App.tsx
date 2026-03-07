import React, { useEffect } from 'react';
import { AppStateProvider, useAppDispatch, setupIPCListeners } from './models/AppState';
import MainControlView from './components/MainControlView';

/**
 * App component - main entry point
 * Sets up the AppStateProvider and initializes IPC listeners
 */
function AppContent() {
  const dispatch = useAppDispatch();

  useEffect(() => {
    // Set up IPC listeners on mount
    setupIPCListeners(dispatch);

    // Query initial server status (server auto-starts before renderer loads)
    const api = (window as any).electronAPI;
    if (api?.getServerStatus) {
      api.getServerStatus().then((status: any) => {
        if (status?.isRunning) {
          dispatch({ type: 'SET_SERVER_RUNNING', payload: true });
          dispatch({ type: 'ADD_LOG', payload: { message: '服务器已自动启动 (WebSocket: 9600, Bonjour已广播)' } });
        }
      });
    }

    // Load screens on mount
    if (api?.getScreens) {
      api.getScreens().then((screens: any[]) => {
        if (screens && screens.length > 0) {
          dispatch({ type: 'SET_SCREENS', payload: screens });
        }
      });
    }

    // Load saved style
    if (api?.loadStyle) {
      api.loadStyle().then((result: any) => {
        if (result?.success && result.style) {
          dispatch({ type: 'SET_STYLE', payload: result.style });
        }
      });
    }

    // Load saved standby groups
    if (api?.loadStandbyGroups) {
      api.loadStandbyGroups().then((result: any) => {
        if (result?.success && result.groups) {
          dispatch({ type: 'SET_STANDBY_GROUPS', payload: result.groups });
        }
      });
    }
  }, [dispatch]);

  return <MainControlView />;
}

export default function App() {
  return (
    <AppStateProvider>
      <AppContent />
    </AppStateProvider>
  );
}
