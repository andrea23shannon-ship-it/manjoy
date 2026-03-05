// MainControlView.swift
// Mac端 - 主控制界面
// 左侧：连接状态+歌词预览  右侧：样式编辑器

import SwiftUI

struct MainControlView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var server: MultipeerServer
    @EnvironmentObject var screenManager: ScreenManager
    @State private var selectedTab = 0
    @State private var showStyleEditor = false
    @State private var showStandbyManager = false

    var body: some View {
        // 主界面全宽布局
        leftPanel
            .frame(minWidth: 500)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    // 连接状态
                    HStack(spacing: 6) {
                        Circle()
                            .fill(server.connectedPeers.isEmpty ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(server.connectedPeers.isEmpty ? "未连接" : "\(server.connectedPeers.count)台设备")
                            .font(.caption)
                    }

                    Divider()

                    // 投影控制按钮
                    projectionButton

                    Divider()

                    // 歌词显示设置入口
                    Button(action: { showStyleEditor = true }) {
                        Label("歌词显示设置", systemImage: "paintbrush")
                    }
                    .help("打开歌词样式设置")
                }
            }
            .sheet(isPresented: $showStyleEditor) {
                StyleEditorSheet()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showStandbyManager) {
                StandbyImageSheet()
                    .environmentObject(appState)
            }
    }

    // MARK: - 投影按钮
    @ViewBuilder
    private var projectionButton: some View {
        if screenManager.hasExternalScreen {
            // 有外接屏幕
            if screenManager.isProjecting {
                Button(action: { screenManager.closeProjection() }) {
                    Label("停止投影", systemImage: "rectangle.on.rectangle.slash")
                }
                .help("停止在投影仪上显示歌词")
                .tint(.red)
            } else {
                Button(action: { screenManager.startProjection(appState: appState) }) {
                    Label("开始投影", systemImage: "rectangle.on.rectangle")
                }
                .help("在投影仪上全屏显示歌词")
                .tint(.blue)
            }
        } else {
            // 无外接屏幕
            Button(action: {}) {
                Label("无投影仪", systemImage: "display.trianglebadge.exclamationmark")
            }
            .disabled(true)
            .help("请连接投影仪（外接屏幕）后再投影")
        }
    }

    // MARK: - 左侧面板
    private var leftPanel: some View {
        VStack(spacing: 0) {
            // 顶部：连接状态卡片
            connectionCard
                .padding()

            // 投影仪状态卡片
            projectorCard
                .padding(.horizontal)
                .padding(.bottom, 8)

            // 歌词显示设置入口按钮
            Button(action: { showStyleEditor = true }) {
                HStack {
                    Image(systemName: "paintbrush")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("歌词显示设置")
                            .font(.subheadline.weight(.medium))
                        Text("字体、颜色、动画、主题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // 待机图片管理入口按钮
            Button(action: { showStandbyManager = true }) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("待机图片管理")
                            .font(.subheadline.weight(.medium))
                        Text("\(appState.standbyGroups.count)个分组 · 延迟\(Int(appState.standbyDelay))秒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let group = appState.activeStandbyGroup {
                        Text(group.name)
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.1)))
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Tab切换
            Picker("", selection: $selectedTab) {
                Text("投影预览").tag(0)
                Text("歌词列表").tag(1)
                Text("日志").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // 内容
            if selectedTab == 0 {
                projectionPreviewPanel
            } else if selectedTab == 1 {
                lyricsListPanel
            } else {
                logPanel
            }
        }
    }

    // MARK: - 连接状态卡片
    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: server.connectedPeers.isEmpty
                    ? "wifi.slash" : "wifi")
                    .foregroundColor(server.connectedPeers.isEmpty ? .red : .green)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.statusMessage)
                        .font(.headline)
                    if let song = appState.currentSong {
                        Text("\(song.title) - \(song.artist)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 广播控制
                Button(server.isAdvertising ? "停止广播" : "开始广播") {
                    if server.isAdvertising {
                        server.stopAdvertising()
                    } else {
                        server.startAdvertising()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(server.isAdvertising ? .red : .blue)
            }

            // 播放状态
            if appState.currentSong != nil {
                HStack {
                    Image(systemName: appState.isPlaying ? "play.fill" : "pause.fill")
                        .foregroundColor(appState.isPlaying ? .green : .yellow)
                    Text(formatTime(appState.currentTime))
                        .font(.caption.monospacedDigit())
                    if let duration = appState.currentSong?.duration {
                        Text("/ \(formatTime(duration))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("第 \(max(0, appState.currentLineIndex + 1)) / \(appState.lyrics.count) 行")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    // MARK: - 投影仪状态卡片
    private var projectorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: screenManager.hasExternalScreen ? "display.2" : "display.trianglebadge.exclamationmark")
                    .foregroundColor(screenManager.hasExternalScreen ? .green : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    if screenManager.hasExternalScreen {
                        Text("检测到投影仪")
                            .font(.subheadline.weight(.medium))
                        // 如果有多个外接屏幕，显示选择器
                        if screenManager.externalScreens.count > 1 {
                            Picker("目标屏幕", selection: $screenManager.selectedScreenIndex) {
                                ForEach(0..<screenManager.externalScreens.count, id: \.self) { i in
                                    Text(screenManager.screenDescription(screenManager.externalScreens[i]))
                                        .tag(i)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        } else if let screen = screenManager.targetScreen {
                            Text(screenManager.screenDescription(screen))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未检测到投影仪")
                            .font(.subheadline.weight(.medium))
                        Text("请通过HDMI连接投影仪")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 投影开关按钮
                if screenManager.hasExternalScreen {
                    Button(action: {
                        screenManager.toggleProjection(appState: appState)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: screenManager.isProjecting ? "stop.fill" : "play.fill")
                            Text(screenManager.isProjecting ? "停止投影" : "开始投影")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(screenManager.isProjecting ? .red : .green)
                }
            }

            // 投影状态指示
            if screenManager.isProjecting {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("正在投影中...")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    // MARK: - 投影预览（与投影仪画面完全同步）
    private var projectionPreviewPanel: some View {
        VStack(spacing: 0) {
            // 预览标签 + 缩放选择
            HStack(spacing: 8) {
                Circle()
                    .fill(screenManager.isProjecting ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(screenManager.isProjecting ? "投影中 - 实时预览" : "预览 - 未投影")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let screen = screenManager.targetScreen {
                    Text("\(Int(screen.frame.width))x\(Int(screen.frame.height))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                // 缩放比例按钮组
                HStack(spacing: 2) {
                    ForEach([1.0, 0.7, 0.5, 0.3], id: \.self) { scale in
                        Button("\(Int(scale * 100))%") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                screenManager.previewScale = scale
                            }
                        }
                        .font(.caption2.weight(screenManager.previewScale == scale ? .bold : .regular))
                        .foregroundColor(screenManager.previewScale == scale ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(screenManager.previewScale == scale ? Color.accentColor : Color.clear)
                        )
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // 投影画面预览
            // 核心原理：按投影仪的实际分辨率渲染内容，再等比缩小到预览区域
            // 这样文字换行、布局和投影仪完全一致
            GeometryReader { geo in
                let viewportScale = screenManager.previewScale

                // 投影仪实际分辨率（渲染基准）
                let projW: CGFloat = screenManager.targetScreen?.frame.width ?? 1280
                let projH: CGFloat = screenManager.targetScreen?.frame.height ?? 720

                // 微调后的渲染尺寸
                let renderW = max(200, projW + screenManager.previewWidthAdjust)
                let renderH = max(120, projH + screenManager.previewHeightAdjust)

                // 可用的预览视口 = 区域 × 缩放
                let viewportW = geo.size.width * viewportScale
                let viewportH = geo.size.height * viewportScale

                // 把渲染内容等比缩到视口内
                let downScale = min(viewportW / renderW, viewportH / renderH)

                LyricsProjectionView()
                    .environmentObject(appState)
                    .frame(width: renderW, height: renderH)
                    .scaleEffect(downScale, anchor: .center)
                    .frame(width: renderW * downScale, height: renderH * downScale)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .clipped()

            Divider()
                .padding(.top, 2)

            // 渲染尺寸微调（基于投影仪分辨率微调）
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("宽")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 16, alignment: .trailing)
                    Slider(value: $screenManager.previewWidthAdjust, in: -400...400, step: 5)
                    Text("\(Int(screenManager.targetScreen?.frame.width ?? 1280) + Int(screenManager.previewWidthAdjust))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack(spacing: 6) {
                    Text("高")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 16, alignment: .trailing)
                    Slider(value: $screenManager.previewHeightAdjust, in: -400...400, step: 5)
                    Text("\(Int(screenManager.targetScreen?.frame.height ?? 720) + Int(screenManager.previewHeightAdjust))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Spacer()
                    Button("重置") {
                        screenManager.previewWidthAdjust = 0
                        screenManager.previewHeightAdjust = 0
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    // MARK: - 歌词列表
    private var lyricsListPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: appState.style.alignment.horizontal, spacing: 8) {
                    if appState.lyrics.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("等待手机发送歌词...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(Array(appState.lyrics.enumerated()), id: \.element.id) { index, line in
                            HStack(spacing: 8) {
                                Text(formatTime(line.time))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .frame(width: 45)

                                Text(line.text)
                                    .font(.body)
                                    .foregroundColor(
                                        index == appState.currentLineIndex ? appState.style.currentLineColor.color :
                                        index < appState.currentLineIndex ? .secondary :
                                        .primary
                                    )
                                    .fontWeight(index == appState.currentLineIndex ? .bold : .regular)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                index == appState.currentLineIndex
                                    ? RoundedRectangle(cornerRadius: 6).fill(appState.style.currentLineColor.color.opacity(0.1))
                                    : nil
                            )
                            .id(line.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: appState.currentLineIndex, perform: { newIdx in
                guard newIdx >= 0 && newIdx < appState.lyrics.count else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(appState.lyrics[newIdx].id, anchor: .center)
                }
            })
        }
    }

    // MARK: - 日志面板
    private var logPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(appState.logs) { log in
                        HStack(alignment: .top, spacing: 8) {
                            Text(log.timeString)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                            Text(log.message)
                                .font(.caption)
                        }
                        .id(log.id)
                    }
                }
                .padding()
            }
            .onChange(of: appState.logs.count, perform: { _ in
                if let last = appState.logs.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            })
        }
    }

    // MARK: - 辅助
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
