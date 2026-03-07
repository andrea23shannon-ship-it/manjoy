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
