import { PeerMessage, LyricsStyle, SongInfo, LyricLine, StandbyImageGroup, ScreenInfo } from '../shared/types';

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}

export interface ElectronAPI {
  /**
   * Start the WebSocket server for peer communication
   */
  startServer(): void;

  /**
   * Stop the WebSocket server
   */
  stopServer(): void;

  /**
   * Start projection on the specified screen
   * @param screenIndex - Index of the screen to project to
   */
  startProjection(screenIndex: number): void;

  /**
   * Stop the active projection
   */
  stopProjection(): void;

  /**
   * Get list of available external screens
   */
  getScreens(): Promise<ScreenInfo[]>;

  /**
   * Open file dialog for selecting files
   * @param options - Dialog options
   */
  openFileDialog(options: any): Promise<string[]>;

  /**
   * Save lyrics style to persistent storage
   * @param style - The lyrics style configuration
   */
  saveStyle(style: LyricsStyle): void;

  /**
   * Load lyrics style from persistent storage
   */
  loadStyle(): Promise<LyricsStyle | null>;

  /**
   * Save standby image groups to persistent storage
   * @param groups - Array of standby image groups
   */
  saveStandbyGroups(groups: StandbyImageGroup[]): void;

  /**
   * Load standby image groups from persistent storage
   */
  loadStandbyGroups(): Promise<StandbyImageGroup[]>;

  /**
   * Import a font file into the system
   * @param filePath - Path to the font file
   */
  importFont(filePath: string): Promise<{ name: string; path: string }>;

  /**
   * Get list of available fonts
   */
  getFonts(): Promise<{ name: string; path: string }[]>;

  /**
   * Remove a font from the system
   * @param name - Name of the font to remove
   */
  removeFont(name: string): void;

  /**
   * Register a listener for peer messages from connected devices
   * @param callback - Called when a peer message is received
   */
  onPeerMessage(callback: (message: PeerMessage) => void): void;

  /**
   * Register a listener for connection status changes
   * @param callback - Called when connection status changes
   */
  onConnectionChanged(callback: (connected: boolean, deviceName: string) => void): void;

  /**
   * Register a listener for screen updates
   * @param callback - Called when available screens change
   */
  onScreensUpdated(callback: (screens: ScreenInfo[]) => void): void;
}
