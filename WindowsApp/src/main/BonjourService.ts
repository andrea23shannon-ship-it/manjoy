import { Bonjour, Service } from 'bonjour-service';
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

  start(): void {
    if (this.isRunning) {
      console.warn('Bonjour service is already running');
      return;
    }

    try {
      this.bonjour = new Bonjour();

      this.service = this.bonjour.publish({
        name: 'LyricsCaster',
        type: 'lyricscaster',
        port: this.port,
        protocol: 'tcp',
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

      this.service.on('error', (error: Error) => {
        console.error('Bonjour service error:', error);
        this.emit('error', error);
      });
    } catch (error) {
      console.error('Failed to start Bonjour service:', error);
      this.cleanup();
    }
  }

  stop(): void {
    if (!this.isRunning) {
      return;
    }

    try {
      if (this.service != null) {
        const svc: any = this.service;
        svc.stop();
        this.service = null;
      }

      if (this.bonjour != null) {
        (this.bonjour as Bonjour).destroy();
        this.bonjour = null;
      }

      this.isRunning = false;
      console.log('Bonjour service stopped');
    } catch (error) {
      console.error('Error stopping Bonjour service:', error);
      this.cleanup();
    }
  }

  isActive(): boolean {
    return this.isRunning;
  }

  private cleanup(): void {
    try {
      if (this.service != null) {
        try { const svc: any = this.service; svc.stop(); } catch (_e) { /* ignore */ }
        this.service = null;
      }

      if (this.bonjour != null) {
        try { (this.bonjour as Bonjour).destroy(); } catch (_e) { /* ignore */ }
        this.bonjour = null;
      }

      this.isRunning = false;
    } catch (error) {
      console.error('Error during Bonjour cleanup:', error);
    }
  }
}
