// LyricsCasterApp.swift
// 歌词投屏 Mac端 - 主程序入口
//
// 架构说明：
// 1. 歌手手机上运行 LyricsSinger App（搜索/显示歌词）
// 2. 手机通过 MultipeerConnectivity 将歌词实时发送到Mac
// 3. Mac 接收歌词，应用自定义样式（字体/颜色/背景/动画）
// 4. Mac 检测外接投影仪（副屏），自动在副屏全屏显示歌词
//
// MultipeerConnectivity 走 WiFi直连 + 蓝牙，完全绕过HTTP代理

import SwiftUI

@main
struct LyricsCasterApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var server = MultipeerServer()
    @StateObject private var screenManager = ScreenManager()
    @StateObject private var apiConfigManager = APIConfigManager()
    // FontManager.shared 在 init 时自动加载并注册已导入的字体
    private let fontManager = FontManager.shared

    var body: some Scene {
        // 主控制窗口（Mac主屏幕上操作）
        WindowGroup("LyricsCaster 歌词投屏") {
            MainControlView()
                .environmentObject(appState)
                .environmentObject(server)
                .environmentObject(screenManager)
                .environmentObject(apiConfigManager)
                .frame(minWidth: 600, minHeight: 450)
                .onAppear {
                    setupServer()
                    setupAPIConfig()
                }
        }
        .defaultSize(width: 900, height: 600)
    }

    private func setupServer() {
        // 收到手机消息时，交给 AppState 处理
        server.onMessageReceived = { [weak appState] message in
            appState?.handleMessage(message)
        }

        // 连接状态变化
        server.onConnectionChanged = { [weak appState] connected, name in
            appState?.isPhoneConnected = connected
            appState?.connectedDeviceName = name
            appState?.addLog(connected ? "手机 \(name) 已连接" : "手机 \(name) 已断开")
        }

        // 自动开始广播
        server.startAdvertising()
        appState.addLog("Mac端已启动，等待手机连接...")
    }

    private func setupAPIConfig() {
        // 将 MultipeerServer 引用注入 APIConfigManager（用于推送配置）
        apiConfigManager.server = server

        // 启动时自动拉取远程配置并检测API健康状态
        Task {
            await apiConfigManager.fetchRemoteConfig()
            await apiConfigManager.checkAllAPIs()
            await MainActor.run {
                appState.addLog("API配置已加载 v\(apiConfigManager.configVersion)，健康检测完成")
            }
        }
    }
}
