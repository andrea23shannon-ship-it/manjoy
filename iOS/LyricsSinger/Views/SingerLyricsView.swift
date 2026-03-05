// SingerLyricsView.swift
// iOS端 - 歌手歌词显示页面
// 歌手在台上看这个界面，同时实时同步歌词到Mac

import SwiftUI

struct SingerLyricsView: View {
    @EnvironmentObject var client: MultipeerClient
    let song: SongInfo
    @Binding var lyrics: [LyricLine]
    var autoPlay: Bool = true  // 默认自动播放

    @State private var currentLineIndex: Int = -1
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var playbackTimer: Timer?
    @State private var scrollMode: ScrollMode = .auto
    @State private var showControls = true
    @State private var lineProgress: Double = 0  // 当前行进度 0~1
    @State private var hasAutoPlayed = false  // 防止重复自动播放
    @State private var suppressOnChange = false // 防止 jumpToLine 后 onChange 重复发送

    // 设置相关
    @State private var showSettingsMenu = false
    @State private var showFontSizeSheet = false
    @State private var showSpeedSheet = false
    @State private var lyricsFontSize: Double = 20  // 默认字号
    @State private var currentFontSize: Double = 26  // 当前行字号
    @State private var speedOffset: Double = 0       // 歌词进度偏移（秒），正=提前，负=延后
    @State private var karaokeMode: Bool = true       // 卡拉OK模式（逐字变色）

    enum ScrollMode {
        case auto    // 自动按时间滚动
        case manual  // 手动点击切换行
    }

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部信息栏
                if showControls {
                    topBar
                }

                // 歌词滚动区域
                lyricsScrollView

                // 底部控制栏 - 参考"歌词音箱"布局
                if showControls {
                    bottomBar
                }
            }
        }
        .statusBarHidden(!showControls)
        .onTapGesture(count: 2) {
            withAnimation { showControls.toggle() }
        }
        .onAppear {
            loadSettings()
            if autoPlay && !hasAutoPlayed && !lyrics.isEmpty {
                hasAutoPlayed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startPlayback()
                }
            }
        }
        .onDisappear {
            stopPlayback()
        }
        .sheet(isPresented: $showSettingsMenu) {
            settingsMenuSheet
        }
        .sheet(isPresented: $showFontSizeSheet) {
            fontSizeSheet
        }
        .sheet(isPresented: $showSpeedSheet) {
            speedSheet
        }
    }

    // MARK: - 顶部信息栏
    private var topBar: some View {
        VStack(spacing: 4) {
            Text(song.title)
                .font(.headline)
                .foregroundColor(.white)
            Text(song.artist)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            // Mac连接状态
            HStack(spacing: 4) {
                Circle()
                    .fill(client.isConnected ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(client.isConnected ? "Mac已连接" : "Mac未连接")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.8))
    }

    // MARK: - 歌词滚动
    private var lyricsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // 上方空白
                Spacer().frame(height: UIScreen.main.bounds.height * 0.35)

                LazyVStack(spacing: 24) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        Button(action: {
                            jumpToLine(index)
                        }) {
                            VStack(spacing: 6) {
                                if index == currentLineIndex {
                                    if karaokeMode {
                                        karaokeText(line.text, progress: lineProgress)
                                            .multilineTextAlignment(.center)
                                            .scaleEffect(1.05)
                                            .animation(.easeInOut(duration: 0.3), value: currentLineIndex)
                                    } else {
                                        Text(line.text)
                                            .font(.system(size: currentFontSize, weight: .bold))
                                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                                            .multilineTextAlignment(.center)
                                            .scaleEffect(1.05)
                                            .animation(.easeInOut(duration: 0.3), value: currentLineIndex)
                                    }
                                } else {
                                    Text(line.text)
                                        .font(.system(size: lyricsFontSize, weight: .regular))
                                        .foregroundColor(lineColor(index: index))
                                        .multilineTextAlignment(.center)
                                }

                                if let trans = line.translation, !trans.isEmpty {
                                    if index == currentLineIndex {
                                        if karaokeMode {
                                            karaokeText(trans, progress: lineProgress, fontSize: currentFontSize * 0.6)
                                                .multilineTextAlignment(.center)
                                        } else {
                                            Text(trans)
                                                .font(.system(size: currentFontSize * 0.6, weight: .bold))
                                                .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.7))
                                                .multilineTextAlignment(.center)
                                        }
                                    } else {
                                        Text(trans)
                                            .font(.system(size: lyricsFontSize * 0.7))
                                            .foregroundColor(lineColor(index: index).opacity(0.7))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                    }
                }

                // 下方空白
                Spacer().frame(height: UIScreen.main.bounds.height * 0.35)
            }
            .onChange(of: currentLineIndex, perform: { newIdx in
                guard newIdx >= 0 && newIdx < lyrics.count else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(lyrics[newIdx].id, anchor: .center)
                }
                // jumpToLine 已经发过消息，不重复发送
                if suppressOnChange {
                    suppressOnChange = false
                } else {
                    client.sendLineChanged(lineIndex: newIdx, currentTime: currentTime)
                }
            })
        }
    }

    // MARK: - 底部控制栏（参考歌词音箱布局）
    private var bottomBar: some View {
        VStack(spacing: 0) {
            // 进度信息行
            if !lyrics.isEmpty {
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("\(max(0, currentLineIndex + 1))/\(lyrics.count)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            // 功能按钮行（参考图1布局：一排小图标）
            HStack(spacing: 0) {
                // 模式切换
                bottomIconButton(
                    icon: scrollMode == .auto ? "timer" : "hand.tap",
                    label: scrollMode == .auto ? "自动" : "手动"
                ) {
                    toggleScrollMode()
                }

                // 上一行
                bottomIconButton(icon: "backward.end.fill", label: "上一句") {
                    previousLine()
                }

                // 词（歌词设置）
                bottomIconButton(icon: "text.quote", label: "词") {
                    showSettingsMenu = true
                }

                // 重头
                bottomIconButton(icon: "arrow.counterclockwise", label: "重头") {
                    restart()
                }

                Spacer()

                // 播放/暂停（大按钮，右下角）
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.85))
    }

    // 底部小图标按钮
    private func bottomIconButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.7))
            .frame(width: 60, height: 50)
        }
    }

    // MARK: - 歌词设置菜单（图2）
    private var settingsMenuSheet: some View {
        NavigationView {
            List {
                Button(action: {
                    showSettingsMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showFontSizeSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "textformat.size")
                            .frame(width: 28)
                            .foregroundColor(.primary)
                        Text("字体字号")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    showSettingsMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSpeedSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left.chevron.right")
                            .frame(width: 28)
                            .foregroundColor(.primary)
                        Text("调整快慢")
                            .foregroundColor(.primary)
                        Spacer()
                        if speedOffset != 0 {
                            Text(speedOffset > 0 ? "提前\(String(format: "%.1f", speedOffset))秒" : "延后\(String(format: "%.1f", abs(speedOffset)))秒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $karaokeMode) {
                    HStack {
                        Image(systemName: "music.mic")
                            .frame(width: 28)
                            .foregroundColor(.primary)
                        Text("卡拉OK模式")
                            .foregroundColor(.primary)
                    }
                }
                .onChange(of: karaokeMode) { _ in saveSettings() }

                Button(action: {
                    showSettingsMenu = false
                    restart()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 28)
                            .foregroundColor(.primary)
                        Text("重新开始")
                            .foregroundColor(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("歌词设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showSettingsMenu = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 字体字号设置（图3）
    private var fontSizeSheet: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // 预览文字
                Text("预览歌词文字大小")
                    .font(.system(size: currentFontSize, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                    .padding()

                Text("普通歌词文字大小")
                    .font(.system(size: lyricsFontSize))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 20)

                Spacer()

                // 字号大小滑块
                VStack(spacing: 12) {
                    Text("字号大小")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 16) {
                        Text("小")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $lyricsFontSize, in: 14...36, step: 2)
                            .tint(Color(red: 0.2, green: 0.9, blue: 0.4))
                            .onChange(of: lyricsFontSize, perform: { _ in
                                currentFontSize = lyricsFontSize + 6
                                saveSettings()
                            })
                        Text("超大")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 档位标记
                    HStack {
                        Text("小").font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("标准").font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("大").font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("超大").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("字体字号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showFontSizeSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 调整快慢设置（图4）
    private var speedSheet: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // 偏移量显示
                VStack(spacing: 8) {
                    Text("歌词进度")
                        .font(.headline)
                        .foregroundColor(.white)
                    if speedOffset == 0 {
                        Text("标准")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                    } else if speedOffset > 0 {
                        Text("提前 \(String(format: "%.1f", speedOffset)) 秒")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                    } else {
                        Text("延后 \(String(format: "%.1f", abs(speedOffset))) 秒")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                // 调整按钮（参考图4）
                HStack(spacing: 40) {
                    // 延后
                    VStack(spacing: 8) {
                        Button(action: {
                            speedOffset = max(speedOffset - 0.1, -5.0)
                            saveSettings()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.title2.weight(.bold))
                            }
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                        Text("延后0.1秒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 重置
                    VStack(spacing: 8) {
                        Button(action: {
                            speedOffset = 0
                            saveSettings()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.title2.weight(.bold))
                            }
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                        Text("重置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 提前
                    VStack(spacing: 8) {
                        Button(action: {
                            speedOffset = min(speedOffset + 0.1, 5.0)
                            saveSettings()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.title2.weight(.bold))
                            }
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                        Text("提前0.1秒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("调整快慢")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showSpeedSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 卡拉OK逐字变色（AttributedString方式，支持自动换行）
    private func karaokeText(_ text: String, progress: Double, fontSize: CGFloat = 0) -> some View {
        let size = fontSize > 0 ? fontSize : currentFontSize
        let clampedProgress = min(max(progress, 0), 1)
        let chars = Array(text)
        let total = chars.count
        let filledCount = Double(total) * clampedProgress
        let fullFilled = Int(filledCount)

        var attr = AttributedString(text)
        attr.font = .system(size: size, weight: .bold)
        attr.foregroundColor = .white

        // 逐字设置颜色
        let greenColor = UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
        var currentIndex = attr.startIndex
        for i in 0..<total {
            let nextIndex = attr.index(afterCharacter: currentIndex)
            let range = currentIndex..<nextIndex
            if i < fullFilled {
                attr[range].foregroundColor = Color(greenColor)
            } else if i == fullFilled {
                let partial = filledCount - Double(fullFilled)
                let r = 0.2 + 0.8 * (1 - partial)
                let g = 0.9 + 0.1 * (1 - partial)
                let b = 0.4 - 0.4 * (1 - partial)
                attr[range].foregroundColor = Color(red: r, green: g, blue: b)
            }
            // else: keep white
            currentIndex = nextIndex
        }

        return Text(attr)
            .multilineTextAlignment(.center)
    }

    // MARK: - 颜色
    private func lineColor(index: Int) -> Color {
        if index == currentLineIndex {
            return Color(red: 0.2, green: 0.9, blue: 0.4)
        } else if index < currentLineIndex {
            return .white.opacity(0.3)
        } else {
            return .white.opacity(0.6)
        }
    }

    // MARK: - 播放控制
    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        isPlaying = true
        client.sendPlaybackControl(action: .play)

        if scrollMode == .auto {
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime += 0.1
                updateCurrentLineByTime()
                // 每0.1秒发送一次同步（含lineProgress，供Mac逐字动画对齐）
                client.sendPlaybackSync(currentTime: currentTime, isPlaying: true, lineProgress: lineProgress)
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        client.sendPlaybackControl(action: .pause)
        client.sendPlaybackSync(currentTime: currentTime, isPlaying: false, lineProgress: lineProgress)
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        client.sendPlaybackControl(action: .stop)
    }

    private func restart() {
        pausePlayback()
        currentTime = 0
        currentLineIndex = -1
        lineProgress = 0
        client.sendPlaybackSync(currentTime: 0, isPlaying: false, lineProgress: 0)
    }

    // MARK: - 行导航
    private func nextLine() {
        let newIdx = min(currentLineIndex + 1, lyrics.count - 1)
        jumpToLine(newIdx)
    }

    private func previousLine() {
        let newIdx = max(currentLineIndex - 1, 0)
        jumpToLine(newIdx)
    }

    private func jumpToLine(_ index: Int) {
        suppressOnChange = true  // 防止 onChange 重复发送
        currentLineIndex = index
        if index >= 0 && index < lyrics.count {
            // 减去 speedOffset，使 adjustedTime (currentTime + speedOffset) 刚好等于行起始时间
            // 这样逐字进度从第一个字开始
            currentTime = lyrics[index].time - speedOffset
        }
        lineProgress = 0
        // 只在这里发一次，onChange 里会跳过
        client.sendLineChanged(lineIndex: index, currentTime: currentTime)
        client.sendPlaybackSync(currentTime: currentTime, isPlaying: isPlaying, lineProgress: 0)
    }

    private func toggleScrollMode() {
        if scrollMode == .auto {
            scrollMode = .manual
            pausePlayback()
        } else {
            scrollMode = .auto
        }
    }

    // MARK: - 时间→行 + 行内进度（含速度偏移）
    private func updateCurrentLineByTime() {
        guard !lyrics.isEmpty else { return }
        // 应用速度偏移：提前=加上偏移，延后=减去偏移
        let adjustedTime = currentTime + speedOffset
        var newIdx = currentLineIndex
        for (i, line) in lyrics.enumerated() {
            if adjustedTime >= line.time {
                newIdx = i
            } else {
                break
            }
        }
        if newIdx != currentLineIndex {
            currentLineIndex = newIdx
        }
        updateLineProgress(adjustedTime: adjustedTime)
    }

    private func updateLineProgress(adjustedTime: Double? = nil) {
        guard currentLineIndex >= 0 && currentLineIndex < lyrics.count else {
            lineProgress = 0
            return
        }
        let time = adjustedTime ?? (currentTime + speedOffset)
        let lineStart = lyrics[currentLineIndex].time
        let lineEnd: Double
        if currentLineIndex + 1 < lyrics.count {
            lineEnd = lyrics[currentLineIndex + 1].time
        } else {
            lineEnd = lineStart + 10.0
        }
        let duration = lineEnd - lineStart
        guard duration > 0 else {
            lineProgress = 1.0
            return
        }
        lineProgress = min(max((time - lineStart) / duration, 0), 1)
    }

    // MARK: - 设置持久化
    private func loadSettings() {
        lyricsFontSize = UserDefaults.standard.double(forKey: "lyrics_font_size")
        if lyricsFontSize < 14 { lyricsFontSize = 20 }
        currentFontSize = lyricsFontSize + 6
        speedOffset = UserDefaults.standard.double(forKey: "lyrics_speed_offset")
        // 卡拉OK模式默认开启，只有明确关闭过才为 false
        if UserDefaults.standard.object(forKey: "lyrics_karaoke_mode") != nil {
            karaokeMode = UserDefaults.standard.bool(forKey: "lyrics_karaoke_mode")
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(lyricsFontSize, forKey: "lyrics_font_size")
        UserDefaults.standard.set(speedOffset, forKey: "lyrics_speed_offset")
        UserDefaults.standard.set(karaokeMode, forKey: "lyrics_karaoke_mode")
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
