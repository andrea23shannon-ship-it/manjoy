// ScreenManager.swift
// Mac端 - 外接屏幕（投影仪）管理
// 检测副屏，在副屏上全屏显示歌词窗口

import SwiftUI
import AppKit

class ScreenManager: ObservableObject {
    @Published var externalScreens: [NSScreen] = []
    @Published var isProjecting = false
    @Published var selectedScreenIndex: Int = 0

    // 预览缩放比例
    @Published var previewScale: CGFloat = 1.0  // 1.0 = 100%, 0.7 = 70%, 0.5 = 50%

    // 在缩放基础上微调宽高（像素）
    @Published var previewWidthAdjust: CGFloat = 0
    @Published var previewHeightAdjust: CGFloat = 0

    private var projectionWindow: NSWindow?
    private var projectionHostingView: NSHostingView<AnyView>?
    private var screenObserver: Any?

    init() {
        updateScreens()
        // 监听屏幕连接/断开
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateScreens()
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        projectionWindow?.orderOut(nil)
    }

    /// 刷新可用屏幕列表
    func updateScreens() {
        let allScreens = NSScreen.screens
        // 排除主屏幕，只保留外接屏幕
        if allScreens.count > 1 {
            externalScreens = Array(allScreens.dropFirst())
        } else {
            externalScreens = []
        }

        // 如果正在投影但屏幕断开了，关闭投影
        if isProjecting && externalScreens.isEmpty {
            closeProjection()
        }

        // 校正选中索引
        if selectedScreenIndex >= externalScreens.count {
            selectedScreenIndex = max(0, externalScreens.count - 1)
        }
    }

    /// 有外接屏幕可用
    var hasExternalScreen: Bool {
        !externalScreens.isEmpty
    }

    /// 当前选中的外接屏幕
    var targetScreen: NSScreen? {
        guard selectedScreenIndex < externalScreens.count else { return nil }
        return externalScreens[selectedScreenIndex]
    }

    /// 在外接屏幕上全屏显示歌词
    func startProjection(appState: AppState) {
        guard let screen = targetScreen else { return }

        let frame = screen.frame

        // 复用或创建窗口
        let window: NSWindow
        if let existing = projectionWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver          // 最高层级，覆盖菜单栏和Dock
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.fullScreenNone, .canJoinAllSpaces, .stationary]
            window.acceptsMouseMovedEvents = true
            window.hidesOnDeactivate = false        // 切到其他app时不隐藏
            window.canHide = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbar = nil
            // 防止窗口关闭时释放（由我们手动管理生命周期）
            window.isReleasedWhenClosed = false
            projectionWindow = window
        }

        // 设置 SwiftUI 内容
        let hostingView = NSHostingView(
            rootView: AnyView(
                LyricsProjectionView()
                    .environmentObject(appState)
                    .ignoresSafeArea()
            )
        )
        hostingView.layer?.backgroundColor = NSColor.black.cgColor
        window.contentView = hostingView
        projectionHostingView = hostingView

        // 全屏覆盖整个外接屏幕（包括菜单栏区域）
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)

        // 在投影屏幕隐藏菜单栏
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]

        isProjecting = true
    }

    /// 关闭投影
    func closeProjection() {
        isProjecting = false

        // 恢复菜单栏和Dock
        NSApp.presentationOptions = []

        guard let window = projectionWindow else { return }

        // 1. 先隐藏窗口
        window.orderOut(nil)

        // 2. 替换 rootView 为空视图（安全解除 EnvironmentObject 绑定，不释放 NSHostingView）
        projectionHostingView?.rootView = AnyView(Color.black)
        projectionHostingView = nil

        // 窗口保留不 close，下次 startProjection 复用
        // 这样彻底避免 NSHostingView 释放链导致 EXC_BAD_ACCESS
    }

    /// 切换投影
    func toggleProjection(appState: AppState) {
        if isProjecting {
            closeProjection()
        } else {
            startProjection(appState: appState)
        }
    }

    /// 屏幕描述（用于UI展示）
    func screenDescription(_ screen: NSScreen) -> String {
        let size = screen.frame.size
        return "\(screen.localizedName) (\(Int(size.width))x\(Int(size.height)))"
    }
}
