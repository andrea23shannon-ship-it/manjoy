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
    @StateObject private var searchService = LyricsSearchService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
                .environmentObject(searchService)
                .onAppear {
                    // 自动开始搜索Mac
                    client.startSearching()
                    // 保持屏幕常亮（歌手在台上需要一直看）
                    UIApplication.shared.isIdleTimerDisabled = true
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
    @EnvironmentObject var searchService: LyricsSearchService
    @State private var selectedSong: SongInfo?
    @State private var loadedLyrics: [LyricLine] = []
    @State private var showLyricsView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部：Mac连接状态
                ConnectionView()
                    .environmentObject(client)
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
            }
            .navigationDestination(isPresented: $showLyricsView) {
                if let song = selectedSong {
                    SingerLyricsView(song: song, lyrics: $loadedLyrics)
                        .environmentObject(client)
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
