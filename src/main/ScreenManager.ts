import { screen } from 'electron';

/**
 * Screen information object
 */
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

/**
 * Screen manager for detecting and managing displays
 * Detects primary and external displays using Electron's screen API
 */
export class ScreenManager {
  /**
   * Get information about all available screens
   */
  getScreens(): ScreenInfo[] {
    const displays = screen.getAllDisplays();
    const primaryDisplay = screen.getPrimaryDisplay();

    return displays.map((display) => ({
      id: display.id,
      label: `Display ${display.id}`,
      bounds: {
        x: display.bounds.x,
        y: display.bounds.y,
        width: display.bounds.width,
        height: display.bounds.height,
      },
      workArea: {
        x: display.workArea.x,
        y: display.workArea.y,
        width: display.workArea.width,
        height: display.workArea.height,
      },
      scaleFactor: display.scaleFactor,
      isPrimary: display.id === primaryDisplay.id,
      isExternal: display.id !== primaryDisplay.id,
      rotation: display.rotation,
    }));
  }

  /**
   * Get information about the primary display
   */
  getPrimaryScreen(): ScreenInfo | null {
    const primaryDisplay = screen.getPrimaryDisplay();
    const screens = this.getScreens();
    return screens.find((s) => s.isPrimary) || null;
  }

  /**
   * Get information about external displays (non-primary)
   */
  getExternalScreens(): ScreenInfo[] {
    return this.getScreens().filter((s) => s.isExternal);
  }

  /**
   * Get screen by ID
   */
  getScreenById(displayId: number): ScreenInfo | null {
    return this.getScreens().find((s) => s.id === displayId) || null;
  }

  /**
   * Get the number of available screens
   */
  getScreenCount(): number {
    return screen.getAllDisplays().length;
  }

  /**
   * Check if an external display is available
   */
  hasExternalDisplay(): boolean {
    return this.getExternalScreens().length > 0;
  }

  /**
   * Get the best external display for projection
   * Returns the first external display, or the largest if multiple exist
   */
  getBestProjectionScreen(): ScreenInfo | null {
    const externalScreens = this.getExternalScreens();
    if (externalScreens.length === 0) {
      return null;
    }

    if (externalScreens.length === 1) {
      return externalScreens[0];
    }

    // Return the largest display by area
    return externalScreens.reduce((largest, current) => {
      const largestArea = largest.bounds.width * largest.bounds.height;
      const currentArea = current.bounds.width * current.bounds.height;
      return currentArea > largestArea ? current : largest;
    });
  }

  /**
   * Get display bounds (including position offsets for multi-monitor setups)
   */
  getDisplayBounds(): { x: number; y: number; width: number; height: number } {
    const displays = screen.getAllDisplays();
    if (displays.length === 0) {
      return { x: 0, y: 0, width: 1920, height: 1080 };
    }

    const minX = Math.min(...displays.map((d) => d.bounds.x));
    const minY = Math.min(...displays.map((d) => d.bounds.y));
    const maxX = Math.max(...displays.map((d) => d.bounds.x + d.bounds.width));
    const maxY = Math.max(...displays.map((d) => d.bounds.y + d.bounds.height));

    return {
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    };
  }

  /**
   * Format screen info for display in UI
   */
  getFormattedScreenLabel(screenInfo: ScreenInfo): string {
    const typeLabel = screenInfo.isPrimary ? 'Primary' : 'External';
    const resolutionLabel = `${screenInfo.bounds.width}x${screenInfo.bounds.height}`;
    return `${typeLabel} (${resolutionLabel})`;
  }
}
