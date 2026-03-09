// WebSocketClient.swift
// iOS端 - WebSocket 客户端（连接 Windows 版 LyricsCaster）
// 通过 Bonjour/mDNS 发现 Windows 端，建立 WebSocket 连接
// 与 MultipeerClient 并存：MultipeerConnectivity 连 Mac，WebSocket 连 Windows

import Foundation
import Network
import UIKit

class WebSocketClient: NSObject, ObservableObject {
    // Bonjour 发现
    private var browser: NWBrowser?
    private let serviceType = "_lyricscaster._tcp"

    // WebSocket 连接
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // 状态
    @Published var isSearching = false
    @Published var isConnected = false
    @Published var connectedName = ""
    @Published var statusMessage = "未连接Windows"
    @Published var discoveredEndpoints: [(name: String, host: String, port: Int)] = []

    // 重连
    private var shouldReconnect = true
    private var reconnectTimer: Timer?

    override init() {
        super.init()
    }

    deinit {
        stopSearching()
        disconnect()
    }

    // MARK: - Bonjour 发现

    func startSearching() {
        guard !isSearching else { return }

        let params = NWParameters()
        params.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)

        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isSearching = true
                    self?.statusMessage = "搜索Windows中..."
                    print("[WebSocketClient] Bonjour 搜索已启动")
                case .failed(let error):
                    self?.statusMessage = "搜索失败: \(error.localizedDescription)"
                    print("[WebSocketClient] Bonjour 搜索失败: \(error)")
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results)
        }

        browser?.start(queue: .main)
    }

    func stopSearching() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            // 所有 _lyricscaster._tcp 服务都是 LyricsCaster，直接连接
            if !isConnected {
                resolveEndpoint(result)
                break  // 只连接第一个发现的服务
            }
        }
    }

    private func resolveEndpoint(_ result: NWBrowser.Result) {
        let params = NWParameters.tcp
        let connection = NWConnection(to: result.endpoint, using: params)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // 获取远端地址
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    let hostStr: String
                    switch host {
                    case .ipv4(let addr):
                        hostStr = "\(addr)"
                    case .ipv6(let addr):
                        hostStr = "\(addr)"
                    case .name(let name, _):
                        hostStr = name
                    @unknown default:
                        hostStr = "unknown"
                    }
                    let portInt = Int(port.rawValue)

                    DispatchQueue.main.async {
                        let name = result.endpoint.debugDescription
                        print("[WebSocketClient] 发现Windows端: \(hostStr):\(portInt)")

                        // 自动连接
                        self?.connectWebSocket(host: hostStr, port: portInt, name: name)
                    }
                }
                connection.cancel()
            case .failed(let error):
                print("[WebSocketClient] 解析端点失败: \(error)")
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: .global())
    }

    // MARK: - WebSocket 连接

    func connectWebSocket(host: String, port: Int, name: String) {
        guard !isConnected else { return }

        let urlString = "ws://\(host):\(port)"
        guard let url = URL(string: urlString) else {
            statusMessage = "无效地址: \(urlString)"
            return
        }

        statusMessage = "正在连接 \(name)..."

        let session = URLSession(configuration: .default)
        urlSession = session

        let task = session.webSocketTask(with: url)
        webSocketTask = task

        task.resume()

        // 发送设备标识
        let deviceInfo: [String: String] = [
            "type": "identify",
            "name": UIDevice.current.name
        ]
        if let data = try? JSONEncoder().encode(deviceInfo),
           let str = String(data: data, encoding: .utf8) {
            task.send(.string(str)) { [weak self] error in
                if let error = error {
                    print("[WebSocketClient] 发送标识失败: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self?.isConnected = true
                        self?.connectedName = name
                        self?.statusMessage = "已连接: Windows (\(host))"
                        self?.stopSearching()
                        print("[WebSocketClient] 已连接到 \(host):\(port)")
                    }
                }
            }
        }

        // 开始接收消息（当前版本 Windows→iOS 暂不处理）
        receiveMessages()
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("[WebSocketClient] 收到Windows消息: \(text.prefix(100))")
                case .data(let data):
                    print("[WebSocketClient] 收到Windows数据: \(data.count) bytes")
                @unknown default:
                    break
                }
                // 继续监听
                self?.receiveMessages()
            case .failure(let error):
                print("[WebSocketClient] 接收失败: \(error)")
                DispatchQueue.main.async {
                    self?.handleDisconnect()
                }
            }
        }
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.connectedName = ""
            self?.statusMessage = "已断开Windows"
        }
    }

    private func handleDisconnect() {
        isConnected = false
        connectedName = ""
        statusMessage = "Windows连接断开"

        // 自动重连
        if shouldReconnect {
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    if !(self?.isConnected ?? true) {
                        self?.startSearching()
                    }
                }
            }
        }
    }

    // MARK: - 发送数据到 Windows

    func sendToWindows(_ message: PeerMessage) {
        guard isConnected, let task = webSocketTask else {
            print("[WebSocketClient] 未连接Windows，无法发送")
            return
        }

        guard let data = try? JSONEncoder().encode(message) else {
            print("[WebSocketClient] 消息编码失败")
            return
        }

        guard let jsonStr = String(data: data, encoding: .utf8) else {
            print("[WebSocketClient] 消息转字符串失败")
            return
        }

        task.send(.string(jsonStr)) { error in
            if let error = error {
                print("[WebSocketClient] 发送到Windows失败: \(error)")
            } else {
                print("[WebSocketClient] 发送成功: \(message.type.rawValue)")
            }
        }
    }

    /// 发送歌曲和歌词到Windows
    func sendSongLoaded(song: SongInfo, lyrics: [LyricLine]) {
        sendToWindows(.songLoaded(song: song, lyrics: lyrics))
    }

    /// 发送播放进度到Windows
    func sendPlaybackSync(currentTime: Double, isPlaying: Bool, lineProgress: Double = 0) {
        sendToWindows(.playbackSync(currentTime: currentTime, isPlaying: isPlaying, lineProgress: lineProgress))
    }

    /// 发送当前行变化到Windows
    func sendLineChanged(lineIndex: Int, currentTime: Double) {
        sendToWindows(.lineChanged(lineIndex: lineIndex, currentTime: currentTime))
    }

    /// 发送播放控制到Windows
    func sendPlaybackControl(action: PlaybackAction) {
        sendToWindows(.playbackControl(action: action))
    }
}

