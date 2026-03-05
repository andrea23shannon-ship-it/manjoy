// MultipeerClient.swift
// iOS端 - MultipeerConnectivity 客户端
// 自动发现Mac端，建立连接，发送歌词数据

import Foundation
import MultipeerConnectivity
import UIKit

class MultipeerClient: NSObject, ObservableObject {
    private let serviceType = "lyricscaster"  // 必须与Mac端一致

    private let myPeerID: MCPeerID
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!

    @Published var isSearching = false
    @Published var isConnected = false
    @Published var connectedMacName = ""
    @Published var statusMessage = "未连接"
    @Published var discoveredPeers: [MCPeerID] = []

    override init() {
        self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
        setupSession()
    }

    private func setupSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
    }

    // MARK: - 控制
    func startSearching() {
        browser.startBrowsingForPeers()
        isSearching = true
        statusMessage = "搜索Mac中..."
        print("[MultipeerClient] 开始搜索Mac")
    }

    func stopSearching() {
        browser.stopBrowsingForPeers()
        isSearching = false
    }

    func disconnect() {
        session.disconnect()
        isConnected = false
        connectedMacName = ""
        statusMessage = "已断开"
    }

    // MARK: - 发送数据到Mac
    func sendToMac(_ message: PeerMessage) {
        guard !session.connectedPeers.isEmpty else {
            print("[MultipeerClient] 未连接Mac，无法发送")
            return
        }
        guard let data = try? JSONEncoder().encode(message) else {
            print("[MultipeerClient] 消息编码失败")
            return
        }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("[MultipeerClient] 发送成功: \(message.type.rawValue), \(data.count) bytes")
        } catch {
            print("[MultipeerClient] 发送失败: \(error)")
        }
    }

    /// 发送歌曲和歌词到Mac
    func sendSongLoaded(song: SongInfo, lyrics: [LyricLine]) {
        sendToMac(.songLoaded(song: song, lyrics: lyrics))
    }

    /// 发送播放进度到Mac（含行内逐字进度）
    func sendPlaybackSync(currentTime: Double, isPlaying: Bool, lineProgress: Double = 0) {
        sendToMac(.playbackSync(currentTime: currentTime, isPlaying: isPlaying, lineProgress: lineProgress))
    }

    /// 发送当前行变化到Mac
    func sendLineChanged(lineIndex: Int, currentTime: Double) {
        sendToMac(.lineChanged(lineIndex: lineIndex, currentTime: currentTime))
    }

    /// 发送播放控制到Mac
    func sendPlaybackControl(action: PlaybackAction) {
        sendToMac(.playbackControl(action: action))
    }
}

// MARK: - MCSessionDelegate
extension MultipeerClient: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
                self.connectedMacName = peerID.displayName
                self.statusMessage = "已连接: \(peerID.displayName)"
                self.stopSearching()
                print("[MultipeerClient] 已连接到 \(peerID.displayName)")
            case .notConnected:
                self.isConnected = false
                self.connectedMacName = ""
                self.statusMessage = "连接断开"
                // 自动重新搜索
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if !self.isConnected {
                        self.startSearching()
                    }
                }
                print("[MultipeerClient] \(peerID.displayName) 断开连接")
            case .connecting:
                self.statusMessage = "正在连接..."
                print("[MultipeerClient] 正在连接 \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Mac→手机的消息（如样式同步等，当前版本暂不处理）
        print("[MultipeerClient] 收到Mac消息: \(data.count) bytes")
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerClient: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("[MultipeerClient] 发现Mac: \(peerID.displayName)")
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
        // 自动连接（如果 discoveryInfo 匹配）
        if info?["app"] == "LyricsCaster" {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            DispatchQueue.main.async {
                self.statusMessage = "正在连接 \(peerID.displayName)..."
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
        print("[MultipeerClient] Mac消失: \(peerID.displayName)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "搜索失败: \(error.localizedDescription)"
        }
        print("[MultipeerClient] 搜索失败: \(error)")
    }
}
