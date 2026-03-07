import bonjour, { Bonjour, Service } from 'bonjour-service';
import { EventEmitter } from 'events';

export interface BonjourDiscoveryInfo {
  app: string;
  role: string;
}

/**
 * Bonjour/mDNS service for LyricsCaster
 * Publishes the service on the local network so iOS clients can discover it
 */
export class BonjourService extends EventEmitter {
  private port: number;
  private discoveryInfo: BonjourDiscoveryInfo;
  private bonjour: Bonjour | null = null;
  private service: Service | null = null;
  private isRunning: boolean = false;

  constructor(port: number, discoveryInfo: BonjourDiscoveryInfo) {
    super();
    this.port = port;
    this.discoveryInfo = discoveryInfo;
  }

  /**
   * Start the Bonjour service
   */
  start(): void {
    if (this.isRunning) {
      console.warn('Bonjour service is already running');
      return;
    }

    try {
      // Initialize bonjour instance
      this.bonjour = bonjour();

      // Create service configuration
      this.service = this.bonjour.publish({
        name: 'LyricsCaster',
        type: 'lyricscaster',
        port: this.port,
        protocol: 'tcp',
        subtypes: ['projector'],
        txt: {
          app: this.discoveryInfo.app,
          role: this.discoveryInfo.role,
          version: '1.0.0',
        },
      });

      this.isRunning = true;
      console.log(
        `Bonjour service published: _lyricscaster._tcp on port ${this.port}`
      );

      // Handle service errors
      this.service.on('error', (error: Error) => {
        console.error('Bonjour service error:', error);
        this.emit('error', error);
      });
    } catch (error) {
      console.error('Failed to start Bonjour service:', error);
      this.cleanup();
    }
  }

  /**
   * Stop the Bonjour service
   */
  stop(): void {
    if (!this.isRunning) {
      console.warn('Bonjour service is not running');
      return;
    }

    try {
      // Unpublish service
      if (this.service) {
        this.service.stop();
        this.service = null;
      }

      // Destroy bonjour instance
      if (this.bonjour) {
        this.bonjour.destroy();
        this.bonjour = null;
      }

      this.isRunning = false;
      console.log('Bonjour service stopped');
    } catch (error) {
      console.error('Error stopping Bonjour service:', error);
      this.cleanup();
    }
  }

  /**
   * Update service TXT records
   */
  updateTxtRecords(txt: Record<string, string>): void {
    if (!this.service) {
      console.warn('Service not initialized');
      return;
    }

    try {
      this.service.updateTxt(txt);
      console.log('Bonjour TXT records updated');
    } catch (error) {
      console.error('Failed to update TXT records:', error);
    }
  }

  /**
   * Get service status
   */
  isActive(): boolean {
    return this.isRunning;
  }

  /**
   * Cleanup resources
   */
  private cleanup(): void {
    try {
      if (this.service) {
        try {
          this.service.stop();
        } catch (e) {
          // Ignore errors during cleanup
        }
        this.service = null;
      }

      if (this.bonjour) {
        try {
          this.bonjour.destroy();
        } catch (e) {
          // Ignore errors during cleanup
        }
        this.bonjour = null;
      }

      this.isRunning = false;
    } catch (error) {
      console.error('Error during Bonjour cleanup:', error);
    }
  }
}
