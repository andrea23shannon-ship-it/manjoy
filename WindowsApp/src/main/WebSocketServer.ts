// WebSocketServer.ts
// Windows端 - WebSocket 服务端
// 接收 iOS LyricsSinger 发来的歌词数据
// 使用原生 ws 库（非 Socket.IO），因为 iOS 端用的是原生 URLSessionWebSocketTask

import { WebSocketServer as WSServer, WebSocket } from 'ws';
import { createServer, IncomingMessage } from 'http';
import { EventEmitter } from 'events';

interface ClientInfo {
  ws: WebSocket;
  name: string;
}

/**
 * WebSocket 服务端
 * 监听端口 9600，接收 iOS 发来的 JSON PeerMessage
 */
export class WebSocketServer extends EventEmitter {
  private port: number;
  private httpServer: ReturnType<typeof createServer> | null = null;
  private wss: WSServer | null = null;
  private clients: Map<string, ClientInfo> = new Map();
  private isRunning = false;
  private clientIdCounter = 0;

  constructor(port: number) {
    super();
    this.port = port;
  }

  start(): void {
    if (this.isRunning) return;

    this.httpServer = createServer();
    this.wss = new WSServer({ server: this.httpServer });

    this.wss.on('connection', (ws: WebSocket, req: IncomingMessage) => {
      const clientId = `client_${++this.clientIdCounter}`;
      let deviceName = 'Unknown';

      console.log(`[WebSocketServer] 新连接: ${clientId}`);

      // 保存客户端
      this.clients.set(clientId, { ws, name: deviceName });

      ws.on('message', (data: Buffer | string) => {
        try {
          const str = typeof data === 'string' ? data : data.toString('utf-8');
          const parsed = JSON.parse(str);

          // 检查是否是设备标识消息
          if (parsed.type === 'identify' && parsed.name) {
            deviceName = parsed.name;
            this.clients.set(clientId, { ws, name: deviceName });
            console.log(`[WebSocketServer] 设备标识: ${deviceName}`);
            this.emit('connection', true, deviceName);
            return;
          }

          // PeerMessage 格式: { type: "songLoaded"|"playbackSync"|..., payload: "<base64>" }
          if (parsed.type && parsed.payload !== undefined) {
            // iOS 的 JSONEncoder 将 Data 编码为 base64 字符串
            // 解码 payload
            let decodedPayload: any;
            if (typeof parsed.payload === 'string') {
              const buf = Buffer.from(parsed.payload, 'base64');
              decodedPayload = JSON.parse(buf.toString('utf-8'));
            } else {
              // payload 已经是对象（不应该发生，但兼容处理）
              decodedPayload = parsed.payload;
            }

            const message = {
              type: parsed.type,
              payload: decodedPayload,
            };

            console.log(`[WebSocketServer] 收到消息: ${message.type} from ${deviceName}`);
            this.emit('message', message);
          }
        } catch (error) {
          console.error('[WebSocketServer] 解析消息失败:', error);
        }
      });

      ws.on('close', () => {
        this.clients.delete(clientId);
        console.log(`[WebSocketServer] 断开: ${clientId} (${deviceName})`);
        if (this.clients.size === 0) {
          this.emit('connection', false, deviceName);
        }
      });

      ws.on('error', (error: Error) => {
        console.error(`[WebSocketServer] 错误 ${clientId}:`, error.message);
      });

      // 首次连接也发一次事件
      this.emit('connection', true, deviceName);
    });

    this.httpServer.listen(this.port, () => {
      this.isRunning = true;
      console.log(`[WebSocketServer] 启动在端口 ${this.port}`);
    });

    this.httpServer.on('error', (error: Error) => {
      console.error('[WebSocketServer] HTTP服务器错误:', error);
    });
  }

  stop(): void {
    if (!this.isRunning) return;

    this.clients.forEach(({ ws }) => {
      try { ws.close(); } catch (e) { /* ignore */ }
    });
    this.clients.clear();

    if (this.wss) {
      this.wss.close();
      this.wss = null;
    }
    if (this.httpServer) {
      this.httpServer.close();
      this.httpServer = null;
    }

    this.isRunning = false;
    console.log('[WebSocketServer] 已停止');
  }

  getConnectedCount(): number {
    return this.clients.size;
  }

  broadcast(data: any): void {
    const str = JSON.stringify(data);
    this.clients.forEach(({ ws }) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(str);
      }
    });
  }
}
