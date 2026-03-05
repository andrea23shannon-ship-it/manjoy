// MultipeerServer.swift
// Mac端 - MultipeerConnectivity 服务端
// 自动广播，等待手机连接，接收歌词数据
// MultipeerConnectivity 走WiFi直连+蓝牙，完全绕过HTTP代理

import Foundation
import MultipeerConnectivity
import Combine

class MultipeerServer: NSObject, ObservableObject {
    // 服务标识（Mac和iOS必须相同）
    private let serviceType = "lyricscaster"

    private let myPeerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!

    @Published var isAdvertising = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var statusMessage = "未启动"

    var onMessageReceived: ((PeerMessage) -> Void)?
    var onConnectionChanged: ((Bool, String) -> Void)?

    override init() {
        self.myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac-LyricsCaster")
        super.init()
        setupSession()
    }

    private func setupSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["app": "LyricsCaster", "role": "projector"],
            serviceType: serviceType
        )
        advertiser.delegate = self
    }

    // MARK: - 控制
    func startAdvertising() {
        advertiser.startAdvertisingPeer()
        isAdvertising = true
        statusMessage = "等待手机连接..."
        print("[MultipeerServer] 开始广播，等待手机连接")
    }

    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
        statusMessage = "已停止"
        print("[MultipeerServer] 停止广播")
    }

    // MARK: - 向手机发送消息（如样式同步）
    func sendToAllPeers(_ data: Data) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[MultipeerServer] 发送失败: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerServer: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            switch state {
            case .connected:
                self.statusMessage = "已连接: \(peerID.displayName)"
                self.onConnectionChanged?(true, peerID.displayName)
                print("[MultipeerServer] \(peerID.displayName) 已连接")
            case .notConnected:
                if session.connectedPeers.isEmpty {
                    self.statusMessage = "等待手机连接..."
                } else {
                    self.statusMessage = "已连接 \(session.connectedPeers.count) 台设备"
                }
                self.onConnectionChanged?(false, peerID.displayName)
                print("[MultipeerServer] \(peerID.displayName) 已断开")
            case .connecting:
                self.statusMessage = "正在连接 \(peerID.displayName)..."
                print("[MultipeerServer] 正在连接 \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // 收到手机发来的歌词数据
        if let message = try? JSONDecoder().decode(PeerMessage.self, from: data) {
            print("[MultipeerServer] 收到消息: \(message.type.rawValue) from \(peerID.displayName)")
            DispatchQueue.main.async {
                self.onMessageReceived?(message)
            }
        } else {
            print("[MultipeerServer] 无法解析消息, 大小: \(data.count) bytes")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerServer: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 自动接受所有连接请求
        print("[MultipeerServer] 收到连接请求: \(peerID.displayName), 自动接受")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "广播失败: \(error.localizedDescription)"
        }
        print("[MultipeerServer] 广播失败: \(error)")
    }
}
