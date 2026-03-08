// LyricsSingerApp.swift
// 歌词投屏 - 歌手端 (iOS)
//
// 功能：
// 1. 搜索歌曲（网易云/QQ音乐/酷狗）
// 2. 显示歌词给歌手看（台上用）
// 3. 通过 MultipeerConnectivity 实时发送歌词到Mac
// 4. 支持自动滚动和手动点击切换行
//
// Mac端接收后自定义样式，通过HDMI投影给观众

import SwiftUI

@main
struct LyricsSingerApp: App {
    @StateObject private var client = MultipeerClient()
    @StateObject private var wsClient = WebSocketClient()
    @StateObject private var searchService = LyricsSearchService()
    @StateObject private var apiConfigManager = APIConfigManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
                .environmentObject(wsClient)
                .environmentObject(searchService)
                .environmentObject(apiConfigManager)
                .onAppear {
                    // 注入API配置管理器到搜索服务
                    searchService.configManager = apiConfigManager

                    // 注册Mac→iOS消息回调（接收API配置推送）
                    client.onMessageReceived = { message in
                        if message.type == .apiConfigUpdate {
                            if let payload = try? JSONDecoder().decode(APIConfigPayload.self, from: message.payload) {
                                print("[LyricsSinger] 收到Mac推送的API配置 v\(payload.version)")
                                apiConfigManager.applyPushedConfig(payload: payload)
                            }
                        }
                    }

                    // 自动开始搜索Mac（MultipeerConnectivity）
                    client.startSearching()
                    // 自动开始搜索Windows（WebSocket/Bonjour）
                    wsClient.startSearching()
                    // 保持屏幕常亮（歌手在台上需要一直看）
                    UIApplication.shared.isIdleTimerDisabled = true

                    // 启动时拉取远程配置
                    Task {
                        await apiConfigManager.fetchRemoteConfig()
                    }
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
        }
    }
}

// MARK: - 主界面
struct ContentView: View {
    @EnvironmentObject var client: MultipeerClient
    @EnvironmentObject var wsClient: WebSocketClient
    @EnvironmentObject var searchService: LyricsSearchService
    @State private var selectedSong: SongInfo?
    @State private var loadedLyrics: [LyricLine] = []
    @State private var showLyricsView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部：连接状态（Mac + Windows）
                ConnectionView()
                    .environmentObject(client)
                    .environmentObject(wsClient)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 搜索页面
                SongSearchView(
                    selectedSong: $selectedSong,
                    loadedLyrics: $loadedLyrics,
                    showLyricsView: $showLyricsView
                )
                .environmentObject(searchService)
                .environmentObject(client)
                .environmentObject(wsClient)
            }
            .navigationDestination(isPresented: $showLyricsView) {
                if let song = selectedSong {
                    SingerLyricsView(song: song, lyrics: $loadedLyrics)
                        .environmentObject(client)
                        .environmentObject(wsClient)
                        .navigationBarBackButtonHidden(false)
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                VStack(spacing: 1) {
                                    Text(song.title)
                                        .font(.caption.weight(.semibold))
                                    Text(song.artist)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                }
            }
        }
        .preferredColorScheme(.dark) // 舞台上用深色模式
    }
}
