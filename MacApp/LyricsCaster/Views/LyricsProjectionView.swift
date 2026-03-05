// LyricsProjectionView.swift
// Mac端 - 歌词投影视图
// 全屏显示在投影仪上，支持多种动画效果
// 通过HDMI连接投影仪，在第二屏幕全屏显示

import SwiftUI

struct LyricsProjectionView: View {
    @EnvironmentObject var appState: AppState

    // 律动动画状态
    @State private var pulseScale: CGFloat = 1.0
    @State private var wavePhase: Double = 0
    @State private var typewriterVisibleChars: Int = 0
    @State private var typewriterTimer: Timer? = nil
    @State private var slideOffset: CGFloat = 0
    // 逐字弹入 / 散落 / 3D浮现
    @State private var charBounceCount: Int = 0
    @State private var charBounceTimer: Timer? = nil
    // 逐字弹入 - 上一行记忆（仿视频：同时显示当前行+上一行在不同位置）
    @State private var prevCharBounceLineIdx: Int = -1
    // 逐字弹入 - 行结束散落动画（字符随机飘散/坠落/上升）
    @State private var charBounceExitActive: Bool = false        // 是否正在播放退出动画
    @State private var charBounceExitOffsets: [CGSize] = []      // 每个字的退出偏移
    @State private var charBounceExitOpacity: Double = 1.0       // 退出透明度
    @State private var charBounceExitScale: CGFloat = 1.0        // 退出缩放
    @State private var charBounceExitChars: [Character] = []     // 缓存退出行的字符
    @State private var charBounceExitPos: CGPoint = .zero        // 退出行的位置
    // 整句渐现 + 颜色淡入
    @State private var charBounceColorFade: Double = 0           // 0=淡 1=亮，用于整体颜色渐变
    @State private var charBounceLineScale: CGFloat = 0.3        // 整句缩放：从0.3渐变到1.0
    @State private var charBounceLineOpacity: Double = 0         // 整句透明度：从0渐变到1
    @State private var charBounceEntryDone: Bool = false         // 整句渐现是否完成（完成后才开始逐字弹入）
    @State private var charBounceGeoSize: CGSize? = nil          // 缓存 GeometryReader 尺寸
    // 随机大小律动动画
    @State private var randomSizeLineScale: CGFloat = 0.3       // 整句进场缩放
    @State private var randomSizeLineOpacity: Double = 0        // 整句进场透明度
    @State private var randomSizeLineBlur: CGFloat = 12         // 整句进场模糊
    @State private var randomSizeEntryDone: Bool = false        // 进场动画完成
    @State private var randomSizeExitIdx: Int = -1              // 正在退场的行索引
    @State private var randomSizeExitOpacity: Double = 1.0      // 退场透明度
    @State private var randomSizeExitOffset: CGFloat = 0        // 退场滑出偏移
    @State private var randomSizeExitActive: Bool = false       // 是否正在退场
    @State private var randomSizePreExitStarted: Bool = false  // 是否已触发预退场（lineProgress驱动）
    @State private var randomSizeLineDuration: Double = 3.0    // 当前行时长（秒）

    var body: some View {
        ZStack {
            // 背景层
            appState.style.backgroundColor.color
                .opacity(appState.style.backgroundOpacity)
                .ignoresSafeArea()

            // 待机图片 / 歌词层
            if appState.shouldShowStandby {
                standbyImageView
            } else if appState.lyrics.isEmpty {
                waitingView
            } else {
                lyricsContentView
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 待机触发逻辑已移至 AppState.isPlaying didSet，无需在此处 onChange
    }

    // MARK: - 待机图片
    private var standbyImageView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            let paths = appState.activeStandbyImagePaths
            if appState.currentStandbyIndex < paths.count {
                let path = paths[appState.currentStandbyIndex]
                if let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        .id("standby_\(appState.currentStandbyIndex)")
                        .animation(.easeInOut(duration: 1.0), value: appState.currentStandbyIndex)
                }
            }
        }
    }

    // MARK: - 等待状态
    private var waitingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            Text("等待歌词...")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            if !appState.isPhoneConnected {
                Text("请连接手机")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
    }

    // MARK: - 歌词内容
    @ViewBuilder
    private var lyricsContentView: some View {
        let style = appState.style
        let currentIdx = appState.currentLineIndex

        switch style.animationStyle {
        case .none:
            staticLyricsView(style: style, currentIdx: currentIdx)
        case .smooth:
            smoothScrollView(style: style, currentIdx: currentIdx)
        case .fade:
            fadeLyricsView(style: style, currentIdx: currentIdx)
        case .scale:
            scaleLyricsView(style: style, currentIdx: currentIdx)
        case .karaoke:
            karaokeLyricsView(style: style, currentIdx: currentIdx)
        case .bounce:
            bounceLyricsView(style: style, currentIdx: currentIdx)
        case .wave:
            waveLyricsView(style: style, currentIdx: currentIdx)
        case .pulse:
            pulseLyricsView(style: style, currentIdx: currentIdx)
        case .typewriter:
            typewriterLyricsView(style: style, currentIdx: currentIdx)
        case .slideIn:
            slideInLyricsView(style: style, currentIdx: currentIdx)
        case .charBounce:
            charBounceLyricsView(style: style, currentIdx: currentIdx)
        case .scatter:
            scatterLyricsView(style: style, currentIdx: currentIdx)
        case .float3D:
            float3DLyricsView(style: style, currentIdx: currentIdx)
        case .randomSize:
            randomSizeLyricsView(style: style, currentIdx: currentIdx)
        }
    }

    // MARK: - 静态模式：只显示当前行，居中
    private func staticLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(spacing: style.lineSpacing) {
            if currentIdx >= 0 && currentIdx < appState.lyrics.count {
                let line = appState.lyrics[currentIdx]
                styledText(line.text, style: style, state: .current)
                if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                    styledText(trans, style: style, state: .current, isTranslation: true)
                }
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 平滑滚动模式
    private func smoothScrollView(style: LyricsStyle, currentIdx: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
                    Spacer().frame(height: 300).id("top-spacer")

                    ForEach(Array(appState.lyrics.enumerated()), id: \.element.id) { index, line in
                        let state = lineState(index: index, currentIdx: currentIdx)
                        VStack(spacing: 4) {
                            styledText(line.text, style: style, state: state)
                            if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                                styledText(trans, style: style, state: state, isTranslation: true)
                            }
                        }
                        .id(line.id)
                    }

                    Spacer().frame(height: 300)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, style.padding)
            }
            .onChange(of: appState.currentLineIndex, perform: { newIdx in
                guard newIdx >= 0 && newIdx < appState.lyrics.count else { return }
                withAnimation(.easeInOut(duration: style.animationSpeed)) {
                    proxy.scrollTo(appState.lyrics[newIdx].id, anchor: .center)
                }
            })
        }
    }

    // MARK: - 淡入淡出模式
    private func fadeLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
            ForEach(visibleLines(currentIdx: currentIdx, count: style.visibleLineCount), id: \.element.id) { index, line in
                let state = lineState(index: index, currentIdx: currentIdx)
                VStack(spacing: 4) {
                    styledText(line.text, style: style, state: state)
                    if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                        styledText(trans, style: style, state: state, isTranslation: true)
                    }
                }
                .opacity(state == .current ? 1.0 : (state == .past ? 0.3 : 0.5))
                .animation(.easeInOut(duration: style.animationSpeed), value: currentIdx)
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 缩放高亮模式
    private func scaleLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
            ForEach(visibleLines(currentIdx: currentIdx, count: style.visibleLineCount), id: \.element.id) { index, line in
                let state = lineState(index: index, currentIdx: currentIdx)
                let scale: CGFloat = state == .current ? 1.15 : 0.85
                VStack(spacing: 4) {
                    styledText(line.text, style: style, state: state)
                    if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                        styledText(trans, style: style, state: state, isTranslation: true)
                    }
                }
                .scaleEffect(scale)
                .animation(.spring(response: style.animationSpeed, dampingFraction: 0.7), value: currentIdx)
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 卡拉OK模式：当前行+下一行居中
    private func karaokeLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(spacing: style.lineSpacing * 1.5) {
            // 当前行
            if currentIdx >= 0 && currentIdx < appState.lyrics.count {
                let line = appState.lyrics[currentIdx]
                styledText(line.text, style: style, state: .current)
                    .id("current_\(currentIdx)")
                if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                    styledText(trans, style: style, state: .current, isTranslation: true)
                }
            }

            // 下一行预览
            if currentIdx + 1 < appState.lyrics.count {
                let nextLine = appState.lyrics[currentIdx + 1]
                styledText(nextLine.text, style: style, state: .upcoming)
                    .opacity(0.4)
                    .id("next_\(currentIdx + 1)")
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: style.animationSpeed), value: currentIdx)
    }

    // MARK: - 弹跳节拍模式：当前行弹跳上移，带弹簧回弹
    private func bounceLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
            ForEach(visibleLines(currentIdx: currentIdx, count: style.visibleLineCount), id: \.element.id) { index, line in
                let state = lineState(index: index, currentIdx: currentIdx)
                VStack(spacing: 4) {
                    styledText(line.text, style: style, state: state)
                    if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                        styledText(trans, style: style, state: state, isTranslation: true)
                    }
                }
                .offset(y: state == .current ? -12 : 0)
                .scaleEffect(state == .current ? 1.08 : 0.92)
                .opacity(state == .current ? 1.0 : (state == .past ? 0.3 : 0.55))
                .animation(
                    .spring(response: style.animationSpeed * 0.5, dampingFraction: 0.4, blendDuration: 0.1),
                    value: currentIdx
                )
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 波浪律动模式：所有行带波浪偏移，当前行振幅最大
    private func waveLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
            ForEach(visibleLines(currentIdx: currentIdx, count: style.visibleLineCount), id: \.element.id) { index, line in
                let state = lineState(index: index, currentIdx: currentIdx)
                let relativeIndex = index - currentIdx
                let amplitude: CGFloat = state == .current ? 8 : 4
                let yOffset = amplitude * CGFloat(sin(wavePhase + Double(relativeIndex) * 0.8))
                let xOffset = (state == .current ? 6 : 3) * CGFloat(cos(wavePhase + Double(relativeIndex) * 0.6))

                VStack(spacing: 4) {
                    styledText(line.text, style: style, state: state)
                    if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                        styledText(trans, style: style, state: state, isTranslation: true)
                    }
                }
                .offset(x: xOffset, y: yOffset)
                .scaleEffect(state == .current ? 1.05 : 0.9)
                .opacity(state == .current ? 1.0 : (state == .past ? 0.3 : 0.5))
                .animation(.easeInOut(duration: style.animationSpeed), value: currentIdx)
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startWaveAnimation(speed: style.animationSpeed) }
        .onDisappear { wavePhase = 0 }
    }

    private func startWaveAnimation(speed: Double) {
        // 用 withAnimation + 递归或 TimelineView 驱动波浪
        withAnimation(.linear(duration: max(0.8, 2.0 * (1.1 - speed))).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }
    }

    // MARK: - 脉冲呼吸模式：当前行持续缩放呼吸
    private func pulseLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
            ForEach(visibleLines(currentIdx: currentIdx, count: style.visibleLineCount), id: \.element.id) { index, line in
                let state = lineState(index: index, currentIdx: currentIdx)
                VStack(spacing: 4) {
                    styledText(line.text, style: style, state: state)
                    if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                        styledText(trans, style: style, state: state, isTranslation: true)
                    }
                }
                .scaleEffect(state == .current ? pulseScale : 0.88)
                .opacity(state == .current ? 1.0 : (state == .past ? 0.3 : 0.5))
                .animation(.easeInOut(duration: style.animationSpeed * 0.5), value: currentIdx)
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startPulseAnimation(speed: style.animationSpeed) }
        .onChange(of: currentIdx) { _ in
            // 每次换行重新触发脉冲
            startPulseAnimation(speed: style.animationSpeed)
        }
    }

    private func startPulseAnimation(speed: Double) {
        let duration = max(0.4, 0.8 * (1.1 - speed))
        pulseScale = 1.0
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            pulseScale = 1.12
        }
    }

    // MARK: - 打字机模式：当前行逐字显现
    private func typewriterLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing * 1.2) {
            // 当前行 - 逐字出现
            if currentIdx >= 0 && currentIdx < appState.lyrics.count {
                let line = appState.lyrics[currentIdx]
                let fullText = line.text
                let visibleText = String(fullText.prefix(typewriterVisibleChars))
                let hiddenText = String(fullText.dropFirst(typewriterVisibleChars))

                HStack(spacing: 0) {
                    Text(visibleText)
                        .font(.custom(style.fontName, size: style.fontSize))
                        .fontWeight(style.fontWeight.swiftUI)
                        .foregroundColor(style.currentLineColor.color)
                        .shadow(
                            color: style.currentLineGlow ? style.currentLineColor.color.opacity(0.6) : .clear,
                            radius: style.currentLineGlow ? 15 : 0
                        )
                    Text(hiddenText)
                        .font(.custom(style.fontName, size: style.fontSize))
                        .fontWeight(style.fontWeight.swiftUI)
                        .foregroundColor(.clear)
                }
                .multilineTextAlignment(style.alignment.swiftUI)
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: style.alignment.horizontal, vertical: .center))

                if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                    styledText(trans, style: style, state: .current, isTranslation: true)
                        .opacity(typewriterVisibleChars >= fullText.count ? 1.0 : 0.3)
                }
            }

            // 下一行预告
            if currentIdx + 1 < appState.lyrics.count {
                styledText(appState.lyrics[currentIdx + 1].text, style: style, state: .upcoming)
                    .opacity(0.35)
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: currentIdx) { _ in
            typewriterVisibleChars = 0
        }
        // 由 lineProgress 驱动逐字显示
        .onChange(of: appState.lineProgress) { _ in
            if style.animationStyle == .typewriter {
                syncTypewriterFromProgress()
            }
        }
        .onAppear {
            typewriterVisibleChars = 0
        }
    }

    /// 根据 lineProgress 同步打字机可见字数
    private func syncTypewriterFromProgress() {
        guard appState.currentLineIndex >= 0 && appState.currentLineIndex < appState.lyrics.count else { return }
        let total = appState.lyrics[appState.currentLineIndex].text.count
        guard total > 0 else { return }
        let target = Int(appState.lineProgress * Double(total))
        let clamped = max(0, min(total, target))
        if clamped > typewriterVisibleChars {
            typewriterVisibleChars = clamped
        }
    }

    // MARK: - 滑入聚焦模式：当前行从侧面滑入
    private func slideInLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
            ForEach(visibleLines(currentIdx: currentIdx, count: style.visibleLineCount), id: \.element.id) { index, line in
                let state = lineState(index: index, currentIdx: currentIdx)
                VStack(spacing: 4) {
                    styledText(line.text, style: style, state: state)
                    if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                        styledText(trans, style: style, state: state, isTranslation: true)
                    }
                }
                .offset(x: state == .current ? 0 : (state == .past ? -60 : 60))
                .opacity(state == .current ? 1.0 : (state == .past ? 0.15 : 0.4))
                .scaleEffect(state == .current ? 1.05 : 0.85)
                .animation(
                    .spring(response: style.animationSpeed * 0.6, dampingFraction: 0.65),
                    value: currentIdx
                )
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 逐字弹入模式：1:1复刻视频MV效果
    // 特征：逐字弹入+随机分行+结束散落(上升/坠落)+颜色淡入淡出+散落多行布局+多层3D阴影
    private func charBounceLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 缓存几何尺寸供 onChange 使用
                Color.clear.onAppear { charBounceGeoSize = geo.size }
                    .onChange(of: geo.size) { newSize in charBounceGeoSize = newSize }

                // === 退出动画层：上一行字符散落飘散 ===
                if charBounceExitActive && !charBounceExitChars.isEmpty {
                    charBounceExitView(style: style)
                }

                // === 上一行（已唱过，静态残影）===
                if !charBounceExitActive && prevCharBounceLineIdx >= 0
                    && prevCharBounceLineIdx < appState.lyrics.count
                    && prevCharBounceLineIdx != currentIdx {
                    let prevLine = appState.lyrics[prevCharBounceLineIdx]
                    let prevPos = charBounceLinePosition(index: prevCharBounceLineIdx, width: w, height: h, role: .past)

                    charBounceFullLineView(text: prevLine.text, style: style, state: .past)
                        .position(x: prevPos.x, y: prevPos.y)
                        .opacity(0.25)
                        .scaleEffect(0.72)
                        .animation(.easeOut(duration: 0.6), value: currentIdx)
                }

                // === 当前行：两阶段动画 ===
                // 阶段1：整句从小变大+淡入渐现
                // 阶段2：渐现完成后，逐字弹入特效
                if currentIdx >= 0 && currentIdx < appState.lyrics.count {
                    let line = appState.lyrics[currentIdx]
                    let chars = Array(line.text)
                    let curPos = charBounceLinePosition(index: currentIdx, width: w, height: h, role: .current)
                    let segments = charBounceSplitLine(chars: chars, seed: currentIdx)

                    ZStack {
                        // --- 阶段1：整句文字（渐现完成前显示，完成后隐藏）---
                        if !charBounceEntryDone {
                            VStack(spacing: 10) {
                                ForEach(0..<segments.count, id: \.self) { si in
                                    let segment = segments[si]
                                    let segXOff: CGFloat = CGFloat(sin(Double(si + currentIdx) * 2.1 + 0.7)) * (w * 0.06)
                                    Text(String(segment))
                                        .font(.custom(style.fontName, size: style.fontSize))
                                        .fontWeight(style.fontWeight.swiftUI)
                                        .foregroundColor(style.currentLineColor.color)
                                        .shadow(color: style.currentLineGlow ? style.currentLineColor.color.opacity(0.5) : .clear,
                                                radius: style.currentLineGlow ? 20 : 0)
                                        .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 3)
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 3, y: 5)
                                        .offset(x: segXOff)
                                }
                            }
                            .scaleEffect(charBounceLineScale)
                            .opacity(charBounceLineOpacity)
                            .animation(.easeOut(duration: 0.45), value: charBounceLineScale)
                            .animation(.easeOut(duration: 0.45), value: charBounceLineOpacity)
                        }

                        // --- 阶段2：逐字弹入（渐现完成后显示）---
                        if charBounceEntryDone {
                            VStack(spacing: 10) {
                                ForEach(0..<segments.count, id: \.self) { si in
                                    let segment = segments[si]
                                    let segXOff: CGFloat = CGFloat(sin(Double(si + currentIdx) * 2.1 + 0.7)) * (w * 0.06)

                                    charBounceCharsRow(
                                        chars: segment,
                                        charOffset: segments[0..<si].reduce(0) { $0 + $1.count },
                                        style: style
                                    )
                                    .offset(x: segXOff)
                                }

                                // 翻译（全部弹完后显示）
                                if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                                    Text(trans)
                                        .font(.custom(style.fontName, size: style.fontSize * 0.55))
                                        .foregroundColor(style.currentLineColor.color.opacity(0.7))
                                        .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 2)
                                        .opacity(charBounceCount >= chars.count ? 1.0 : 0)
                                        .animation(.easeIn(duration: 0.3), value: charBounceCount)
                                }
                            }
                        }
                    }
                    .position(x: curPos.x, y: curPos.y)
                }

                // === 下一行预告 ===
                if currentIdx + 1 < appState.lyrics.count {
                    let nextLine = appState.lyrics[currentIdx + 1]
                    let nextPos = charBounceLinePosition(index: currentIdx + 1, width: w, height: h, role: .upcoming)

                    charBounceFullLineView(text: nextLine.text, style: style, state: .upcoming)
                        .position(x: nextPos.x, y: nextPos.y)
                        .opacity(0.18)
                        .scaleEffect(0.68)
                        .animation(.easeInOut(duration: 0.5), value: currentIdx)
                }
            }
        }
        .onChange(of: currentIdx) { newIdx in
            // 触发上一行的退出散落动画
            if let geo = charBounceGeoSize {
                let exitPos = charBounceLinePosition(index: newIdx - 1, width: geo.width, height: geo.height, role: .current)
                charBounceExitPos = exitPos
            }
            triggerCharBounceExit(forPrevIdx: newIdx - 1, style: style)
            prevCharBounceLineIdx = max(0, newIdx - 1)

            // === 阶段1：整句从小变大+淡入 ===
            charBounceEntryDone = false
            charBounceLineScale = 0.3
            charBounceLineOpacity = 0
            charBounceColorFade = 0
            resetCharBounceForNewLine()

            // 启动渐现动画（0.45秒由小变大）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                charBounceLineScale = 1.0
                charBounceLineOpacity = 1.0
            }

            // === 阶段2：渐现完成后切换到逐字弹入模式 ===
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                charBounceEntryDone = true
                charBounceColorFade = 1.0
                // 逐字弹入从当前 lineProgress 追赶
                syncCharBounceFromProgress()
            }
        }
        // 核心：监听 lineProgress 实时同步逐字弹入（仅阶段2生效）
        .onChange(of: appState.lineProgress) { _ in
            if style.animationStyle == .charBounce && charBounceEntryDone {
                syncCharBounceFromProgress()
            }
        }
        .onAppear {
            if currentIdx > 0 { prevCharBounceLineIdx = currentIdx - 1 }
            // 首次加载直接进入阶段2
            charBounceEntryDone = true
            charBounceLineScale = 1.0
            charBounceLineOpacity = 1.0
            charBounceColorFade = 1.0
            charBounceCount = 0
        }
    }

    /// 将歌词字符随机分行（仿视频：一句歌词拆成2-3段显示）
    private func charBounceSplitLine(chars: [Character], seed: Int) -> [[Character]] {
        let total = chars.count
        // 短句不分行
        if total <= 6 { return [chars] }
        // 中等长度分2行
        if total <= 14 {
            let mid = total / 2 + Int(sin(Double(seed) * 1.3)) % 2
            let safeMid = max(2, min(total - 2, mid))
            return [Array(chars[0..<safeMid]), Array(chars[safeMid..<total])]
        }
        // 长句分3行
        let p1 = total / 3 + Int(sin(Double(seed) * 2.1)) % 2
        let p2 = total * 2 / 3 + Int(cos(Double(seed) * 1.7)) % 2
        let safeP1 = max(2, min(total - 4, p1))
        let safeP2 = max(safeP1 + 2, min(total - 2, p2))
        return [
            Array(chars[0..<safeP1]),
            Array(chars[safeP1..<safeP2]),
            Array(chars[safeP2..<total])
        ]
    }

    /// 逐字弹入字符行 - 每字带超大缩放+随机Y抖动+多层阴影
    @ViewBuilder
    private func charBounceCharsRow(chars: [Character], charOffset: Int, style: LyricsStyle) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<chars.count, id: \.self) { ci in
                let globalIdx = ci + charOffset  // 在全句中的真实索引
                let isVisible = globalIdx < charBounceCount
                let isPopping = globalIdx == charBounceCount - 1
                // 伪随机Y抖动：每字略有上下偏移
                let yJitter: CGFloat = CGFloat(sin(Double(globalIdx) * 1.7 + 0.5)) * 6
                // 弹入缩放：正在弹入的字 2.2x → 最终 1.0x
                let charScale: CGFloat = isVisible ? (isPopping ? 2.2 : 1.0) : 0.01

                Text(String(chars[ci]))
                    .font(.custom(style.fontName, size: style.fontSize))
                    .fontWeight(style.fontWeight.swiftUI)
                    .foregroundColor(style.currentLineColor.color)
                    // 多层阴影 - 3D浮雕质感
                    .shadow(color: style.currentLineGlow ? style.currentLineColor.color.opacity(0.7) : .clear,
                            radius: style.currentLineGlow ? 25 : 0)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 2, y: 3)
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 3, y: 5)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 4, y: 8)
                    .scaleEffect(charScale)
                    .opacity(isVisible ? 1.0 : 0)
                    .offset(y: isPopping ? -14 + yJitter : (isVisible ? yJitter : 20))
                    .rotation3DEffect(
                        .degrees(isPopping ? -8 : 0),
                        axis: (x: 1, y: 0.2, z: 0),
                        perspective: 0.4
                    )
                    .animation(
                        .spring(response: 0.28, dampingFraction: 0.45, blendDuration: 0.05),
                        value: charBounceCount
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// 退出散落动画视图 - 上一行的字符随机上升/坠落/飘散
    @ViewBuilder
    private func charBounceExitView(style: LyricsStyle) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<charBounceExitChars.count, id: \.self) { ci in
                let exitOff = ci < charBounceExitOffsets.count ? charBounceExitOffsets[ci] : .zero
                Text(String(charBounceExitChars[ci]))
                    .font(.custom(style.fontName, size: style.fontSize * 0.85))
                    .fontWeight(style.fontWeight.swiftUI)
                    .foregroundColor(style.currentLineColor.color)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 2)
                    .offset(exitOff)
                    .scaleEffect(charBounceExitScale)
                    .opacity(charBounceExitOpacity)
            }
        }
        .position(x: charBounceExitPos.x, y: charBounceExitPos.y)
    }

    /// 触发上一行的退出散落动画
    private func triggerCharBounceExit(forPrevIdx prevIdx: Int, style: LyricsStyle) {
        guard prevIdx >= 0 && prevIdx < appState.lyrics.count else { return }
        let prevText = appState.lyrics[prevIdx].text
        let chars = Array(prevText)
        guard !chars.isEmpty else { return }

        // 缓存退出行数据
        charBounceExitChars = chars
        charBounceExitOpacity = 1.0
        charBounceExitScale = 1.0
        // 生成每个字的随机散落方向（部分上升、部分坠落）
        charBounceExitOffsets = chars.enumerated().map { _ in CGSize.zero }

        // 获取退出行的原始位置
        // 注意：此时 GeometryReader 不可用，使用估算
        charBounceExitActive = true

        // 延迟一帧后启动散落动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeIn(duration: 0.8)) {
                charBounceExitOpacity = 0
                charBounceExitScale = 0.6
                // 每个字随机方向
                charBounceExitOffsets = chars.enumerated().map { (ci, _) in
                    let seed = Double(ci)
                    let xDrift = CGFloat(sin(seed * 3.7 + 1.2)) * 80
                    // 随机上升或坠落：sin值正→上升（负Y），负→坠落（正Y）
                    let direction: CGFloat = sin(seed * 2.3 + 0.8) > 0 ? -1 : 1
                    let yDrift = direction * (60 + CGFloat(abs(cos(seed * 1.9))) * 100)
                    return CGSize(width: xDrift, height: yDrift)
                }
            }

            // 动画结束后清除
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                charBounceExitActive = false
                charBounceExitChars = []
                charBounceExitOffsets = []
            }
        }
    }

    /// 整行文字（用于上一行/下一行的整体显示）
    @ViewBuilder
    private func charBounceFullLineView(text: String, style: LyricsStyle, state: LineDisplayState) -> some View {
        let color: Color = state == .past ? style.pastLineColor.color : style.otherLineColor.color
        Text(text)
            .font(.custom(style.fontName, size: style.fontSize * 0.8))
            .fontWeight(style.fontWeight.swiftUI)
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .shadow(color: .black.opacity(0.6), radius: 3, x: 2, y: 2)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 3, y: 5)
    }

    /// 散落布局位置 - 每行根据角色生成不同位置
    private enum LineRole { case past, current, upcoming }
    private func charBounceLinePosition(index: Int, width: CGFloat, height: CGFloat, role: LineRole) -> CGPoint {
        let seed = Double(index)
        let xRatio: CGFloat
        switch role {
        case .current:
            xRatio = 0.5 + CGFloat(sin(seed * 2.3)) * 0.08
        case .past:
            xRatio = 0.35 + CGFloat(sin(seed * 3.1 + 1.0)) * 0.15
        case .upcoming:
            xRatio = 0.6 + CGFloat(cos(seed * 2.7 + 0.5)) * 0.12
        }
        let yPos: CGFloat
        switch role {
        case .past:    yPos = height * 0.22
        case .current: yPos = height * 0.48
        case .upcoming: yPos = height * 0.82
        }
        return CGPoint(x: width * xRatio, y: yPos)
    }

    /// 根据手机端同步的 lineProgress 更新逐字弹入数量（替代本地Timer）
    private func syncCharBounceFromProgress() {
        guard appState.currentLineIndex >= 0 && appState.currentLineIndex < appState.lyrics.count else { return }
        let total = appState.lyrics[appState.currentLineIndex].text.count
        guard total > 0 else { return }
        // lineProgress 0~1 → 显示字数 0~total
        let target = Int(appState.lineProgress * Double(total))
        let clamped = max(0, min(total, target))
        // 只允许往前走（避免网络抖动导致字数回退）
        if clamped > charBounceCount {
            charBounceCount = clamped
        }
    }

    /// 换行时重置逐字弹入状态
    private func resetCharBounceForNewLine() {
        charBounceTimer?.invalidate()
        charBounceCount = 0
    }

    // MARK: - 随机大小律动模式：字体随机大小+由小变大模糊渐现+退场滑出
    // 特征：1.每字随机大小，1-2个字特别大 2.整句由小变大+模糊变清晰进场 3.唱完退场颜色渐浅滑出
    private func randomSizeLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // === 退场动画层：上一句颜色渐浅+滑出屏幕 ===
                if randomSizeExitActive && randomSizeExitIdx >= 0 && randomSizeExitIdx < appState.lyrics.count {
                    let exitChars = Array(appState.lyrics[randomSizeExitIdx].text)
                    randomSizeCharsView(
                        chars: exitChars,
                        style: style,
                        seed: randomSizeExitIdx,
                        color: style.pastLineColor.color
                    )
                    .position(x: w * 0.5, y: h * 0.48)
                    .opacity(randomSizeExitOpacity)
                    .offset(y: randomSizeExitOffset)
                }

                // === 当前行：两阶段 ===
                if currentIdx >= 0 && currentIdx < appState.lyrics.count {
                    let line = appState.lyrics[currentIdx]
                    let chars = Array(line.text)

                    VStack(spacing: 12) {
                        // 主歌词 - 随机大小字体
                        randomSizeCharsView(
                            chars: chars,
                            style: style,
                            seed: currentIdx,
                            color: style.currentLineColor.color
                        )
                        .frame(maxWidth: w * 0.92)  // 限制最大宽度为屏幕92%

                        // 翻译
                        if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                            Text(trans)
                                .font(.custom(style.fontName, size: style.fontSize * 0.5))
                                .foregroundColor(style.currentLineColor.color.opacity(0.65))
                                .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 2)
                                .opacity(randomSizeEntryDone ? 1.0 : 0)
                                .animation(.easeIn(duration: 0.4), value: randomSizeEntryDone)
                        }
                    }
                    .scaleEffect(randomSizeLineScale)
                    .opacity(randomSizeLineOpacity)
                    .blur(radius: randomSizeLineBlur)
                    .position(x: w * 0.5, y: h * 0.48)
                }

                // === 下一行预告 ===
                if currentIdx + 1 < appState.lyrics.count {
                    let nextLine = appState.lyrics[currentIdx + 1]
                    Text(nextLine.text)
                        .font(.custom(style.fontName, size: style.fontSize * 0.55))
                        .fontWeight(style.fontWeight.swiftUI)
                        .foregroundColor(style.otherLineColor.color)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 1, y: 2)
                        .opacity(0.25)
                        .position(x: w * 0.5, y: h * 0.82)
                        .animation(.easeInOut(duration: 0.5), value: currentIdx)
                }
            }
        }
        .onChange(of: currentIdx) { newIdx in
            // 计算当前行时长
            randomSizeLineDuration = randomSizeCalcLineDuration(index: newIdx)
            let entryDur = max(0.3, min(1.2, randomSizeLineDuration * 0.18))  // 进场占18%行时长
            let exitDur = max(0.4, min(1.0, randomSizeLineDuration * 0.15))   // 退场占15%行时长

            // --- 退场动画（如果预退场未触发，则在换行时立即退场）---
            let prevIdx = newIdx - 1
            if prevIdx >= 0 && prevIdx < appState.lyrics.count && !randomSizePreExitStarted {
                triggerRandomSizeExit(prevIdx: prevIdx, duration: exitDur)
            }
            randomSizePreExitStarted = false

            // --- 进场动画：由小变大+模糊变清晰，时长与行时长关联 ---
            randomSizeEntryDone = false
            randomSizeLineScale = 0.3
            randomSizeLineOpacity = 0
            randomSizeLineBlur = 12

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                withAnimation(.easeOut(duration: entryDur)) {
                    randomSizeLineScale = 1.0
                    randomSizeLineOpacity = 1.0
                    randomSizeLineBlur = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + entryDur + 0.05) {
                randomSizeEntryDone = true
            }
        }
        // 监听 lineProgress：在行末尾提前触发退场预动画
        .onChange(of: appState.lineProgress) { progress in
            if style.animationStyle == .randomSize
                && progress > 0.88
                && !randomSizePreExitStarted
                && currentIdx >= 0 && currentIdx < appState.lyrics.count {
                randomSizePreExitStarted = true
                let exitDur = max(0.4, min(1.0, randomSizeLineDuration * 0.12))
                // 当前行开始提前退场（颜色渐浅）
                withAnimation(.easeIn(duration: exitDur)) {
                    randomSizeLineOpacity = 0.3
                    randomSizeLineScale = 0.92
                }
            }
        }
        .onAppear {
            randomSizeEntryDone = true
            randomSizeLineScale = 1.0
            randomSizeLineOpacity = 1.0
            randomSizeLineBlur = 0
            if currentIdx >= 0 {
                randomSizeLineDuration = randomSizeCalcLineDuration(index: currentIdx)
            }
        }
    }

    /// 计算随机大小参数：每个字的 (字号, 是否特大)
    /// 特大字比例随 baseSize 动态调整，避免大字号时溢出屏幕
    private func randomSizeParams(count: Int, baseSize: CGFloat, seed: Int) -> [(CGFloat, Bool)] {
        let bigIdx1 = abs(Int(sin(Double(seed) * 3.7 + 1.2) * Double(count))) % max(1, count)
        let bigIdx2 = abs(Int(cos(Double(seed) * 2.3 + 0.8) * Double(count))) % max(1, count)
        let bigIdx3 = abs(Int(sin(Double(seed) * 5.1 + 2.7) * Double(count))) % max(1, count)
        let hasTwoBig = count > 3
        let hasThreeBig = count > 6
        // 特大字比例：更加明显的放大
        let bigRatioBase: CGFloat = baseSize > 100 ? 1.35 : (baseSize > 60 ? 1.55 : 1.85)
        let bigRatioRange: CGFloat = baseSize > 100 ? 0.2 : (baseSize > 60 ? 0.3 : 0.45)
        // 普通字大小固定 1.0
        let normalMin: CGFloat = 1.0
        let normalRange: CGFloat = 0.0
        var result: [(CGFloat, Bool)] = []
        for i in 0..<count {
            let isBig = i == bigIdx1 || (hasTwoBig && i == bigIdx2) || (hasThreeBig && i == bigIdx3)
            let ratio: CGFloat = isBig
                ? bigRatioBase + CGFloat(abs(sin(Double(i) * 2.9 + Double(seed) * 0.7))) * bigRatioRange
                : normalMin + CGFloat(abs(sin(Double(i) * 1.7 + Double(seed) * 1.3 + 0.5) * cos(Double(i) * 3.1 + Double(seed) * 0.4))) * normalRange
            result.append((baseSize * ratio, isBig))
        }
        return result
    }

    /// 随机大小 - 单个字符视图
    @ViewBuilder
    private func randomSizeCharView(char: Character, fontSize: CGFloat, isBig: Bool, fontName: String, fontWeight: Font.Weight, color: Color, glow: Bool) -> some View {
        let glowRadius: CGFloat = glow ? (isBig ? 20 : 12) : 0
        let glowColor = glow ? color.opacity(0.5) : Color.clear
        Text(String(char))
            .font(.custom(fontName, size: fontSize))
            .fontWeight(isBig ? .heavy : fontWeight)
            .foregroundColor(color)
            .shadow(color: glowColor, radius: glowRadius)
            .shadow(color: .black.opacity(0.7), radius: 2, x: 2, y: 3)
            .shadow(color: .black.opacity(0.35), radius: 6, x: 3, y: 5)
    }

    /// 随机大小 - 一行字符
    @ViewBuilder
    private func randomSizeRowView(segment: [Character], globalOffset: Int, params: [(CGFloat, Bool)], style: LyricsStyle, color: Color) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: -1) {
            ForEach(0..<segment.count, id: \.self) { ci in
                let gIdx = ci + globalOffset
                let p = gIdx < params.count ? params[gIdx] : (style.fontSize, false)
                // 每个字随机上下偏移，打破行内整齐
                let charYShift = CGFloat(sin(Double(gIdx) * 2.3 + Double(globalOffset) * 1.1 + 0.8)) * style.fontSize * 0.12
                randomSizeCharView(
                    char: segment[ci],
                    fontSize: p.0,
                    isBig: p.1,
                    fontName: style.fontName,
                    fontWeight: style.fontWeight.swiftUI,
                    color: color,
                    glow: style.currentLineGlow
                )
                .offset(y: charYShift)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 随机大小字体歌词视图 - 每字不同大小，1-2个字特别大
    @ViewBuilder
    private func randomSizeCharsView(chars: [Character], style: LyricsStyle, seed: Int, color: Color) -> some View {
        let params = randomSizeParams(count: chars.count, baseSize: style.fontSize, seed: seed)
        let segments = randomSizeSplitLine(chars: chars, seed: seed)

        GeometryReader { geo in
            let w = geo.size.width
            // 预设交错位置：左-右-中-右-左... 确保相邻行明显错开
            let slotPattern: [CGFloat] = [0.05, 0.8, 0.4, 0.9, 0.15, 0.7, 0.3, 0.85]
            VStack(alignment: .leading, spacing: -style.fontSize * 0.2) {
                ForEach(0..<segments.count, id: \.self) { si in
                    let segment = segments[si]
                    let globalOffset = segments[0..<si].reduce(0) { $0 + $1.count }
                    // 估算本行宽度
                    let rowW: CGFloat = segment.indices.reduce(CGFloat(0)) { acc, ci in
                        let gIdx = ci + globalOffset
                        let sz = gIdx < params.count ? params[gIdx].0 : style.fontSize
                        return acc + sz * 0.85
                    }
                    // 可用偏移空间（屏幕宽 - 行宽）
                    let available = max(0, w - rowW)
                    // 从交错位置表取值，加 seed 扰动让每句歌词不同
                    let slotIdx = (si + abs(seed)) % slotPattern.count
                    let basePos = slotPattern[slotIdx]
                    let jitter = CGFloat(sin(Double(si + seed) * 3.7 + 1.1)) * 0.1
                    let pos = min(1.0, max(0.0, basePos + jitter))
                    randomSizeRowView(segment: segment, globalOffset: globalOffset, params: params, style: style, color: color)
                        .offset(x: available * pos)
                }
            }
            .frame(maxWidth: w, maxHeight: .infinity, alignment: .leading)
        }
    }

    /// 随机大小模式的分行逻辑（根据字号动态调整分行阈值）
    private func randomSizeSplitLine(chars: [Character], seed: Int) -> [[Character]] {
        let total = chars.count
        // 大字号时更积极分行，避免溢出
        let fontSize = appState.style.fontSize
        let threshold1 = fontSize > 100 ? 4 : (fontSize > 60 ? 6 : 8)   // 不分行的上限
        let threshold2 = fontSize > 100 ? 8 : (fontSize > 60 ? 12 : 16) // 分2行的上限

        if total <= threshold1 { return [chars] }
        if total <= threshold2 {
            let mid = total / 2 + (seed % 3 - 1)
            let safeMid = max(2, min(total - 2, mid))
            return [Array(chars[0..<safeMid]), Array(chars[safeMid..<total])]
        }
        let p1 = total / 3 + (seed % 3 - 1)
        let p2 = total * 2 / 3 + ((seed + 1) % 3 - 1)
        let safeP1 = max(2, min(total - 4, p1))
        let safeP2 = max(safeP1 + 2, min(total - 2, p2))
        return [
            Array(chars[0..<safeP1]),
            Array(chars[safeP1..<safeP2]),
            Array(chars[safeP2..<total])
        ]
    }

    /// 计算指定行的时长（秒），用于动画时间关联
    private func randomSizeCalcLineDuration(index: Int) -> Double {
        let lyrics = appState.lyrics
        guard index >= 0 && index < lyrics.count else { return 3.0 }
        let startTime = lyrics[index].time
        let endTime: Double
        if index + 1 < lyrics.count {
            endTime = lyrics[index + 1].time
        } else {
            // 最后一行默认4秒
            endTime = startTime + 4.0
        }
        return max(1.0, endTime - startTime)
    }

    /// 触发退场动画（上一行颜色渐浅+滑出）
    private func triggerRandomSizeExit(prevIdx: Int, duration: Double) {
        guard prevIdx >= 0 && prevIdx < appState.lyrics.count else { return }
        randomSizeExitIdx = prevIdx
        randomSizeExitOpacity = 1.0
        randomSizeExitOffset = 0
        randomSizeExitActive = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeIn(duration: duration)) {
                self.randomSizeExitOpacity = 0
                self.randomSizeExitOffset = prevIdx % 2 == 0 ? 120 : -120
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            self.randomSizeExitActive = false
        }
    }

    // MARK: - 散落歌词模式：歌词散落在屏幕不同位置，仿视频MV风格
    private func scatterLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 显示当前行和前两行
                ForEach(max(0, currentIdx - 2)...min(appState.lyrics.count - 1, currentIdx + 1), id: \.self) { index in
                    let line = appState.lyrics[index]
                    let state = lineState(index: index, currentIdx: currentIdx)
                    let offset = scatterOffset(index: index, currentIdx: currentIdx, width: w, height: h)

                    VStack(spacing: 4) {
                        styledText(line.text, style: style, state: state)
                        if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                            styledText(trans, style: style, state: state, isTranslation: true)
                        }
                    }
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
                    .position(x: offset.x, y: offset.y)
                    .opacity(state == .current ? 1.0 : (state == .past ? 0.35 : 0.5))
                    .scaleEffect(state == .current ? 1.0 : 0.8)
                    .animation(.spring(response: style.animationSpeed * 0.6, dampingFraction: 0.7), value: currentIdx)
                }
            }
        }
        .padding(.horizontal, style.padding * 0.5)
    }

    /// 根据行号生成散落位置（伪随机但确定性）
    private func scatterOffset(index: Int, currentIdx: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let relIdx = index - currentIdx  // -2, -1, 0, 1
        let seed = Double(index)
        // 用 sin/cos 生成伪随机位置
        let xRatio = 0.5 + 0.3 * sin(seed * 2.7 + 1.3)
        let baseY: CGFloat
        switch relIdx {
        case -2: baseY = height * 0.15
        case -1: baseY = height * 0.35
        case 0:  baseY = height * 0.55  // 当前行偏中下
        default: baseY = height * 0.78  // 下一行底部
        }
        let xJitter = 0.15 * cos(seed * 3.1)
        return CGPoint(x: width * (xRatio + xJitter), y: baseY)
    }

    // MARK: - 3D浮现模式：文字带透视旋转，从远处浮入
    private func float3DLyricsView(style: LyricsStyle, currentIdx: Int) -> some View {
        VStack(alignment: style.alignment.horizontal, spacing: style.lineSpacing) {
            ForEach(visibleLines(currentIdx: currentIdx, count: style.visibleLineCount), id: \.element.id) { index, line in
                let state = lineState(index: index, currentIdx: currentIdx)
                let relIdx = index - currentIdx
                // 3D 透视参数
                let rotationX: Double = state == .current ? 0 : Double(relIdx) * 12
                let zOffset: CGFloat = state == .current ? 0 : CGFloat(abs(relIdx)) * -30

                VStack(spacing: 4) {
                    styledText(line.text, style: style, state: state)
                    if style.showTranslation, let trans = line.translation, !trans.isEmpty {
                        styledText(trans, style: style, state: state, isTranslation: true)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 6, x: 3, y: 3)
                .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .offset(y: zOffset)
                .scaleEffect(state == .current ? 1.08 : max(0.65, 1.0 - CGFloat(abs(relIdx)) * 0.15))
                .opacity(state == .current ? 1.0 : max(0.15, 1.0 - Double(abs(relIdx)) * 0.3))
                .animation(.spring(response: style.animationSpeed * 0.5, dampingFraction: 0.7), value: currentIdx)
            }
        }
        .padding(.horizontal, style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 辅助方法

    enum LineDisplayState {
        case past, current, upcoming
    }

    private func lineState(index: Int, currentIdx: Int) -> LineDisplayState {
        if index == currentIdx { return .current }
        if index < currentIdx { return .past }
        return .upcoming
    }

    private func visibleLines(currentIdx: Int, count: Int) -> [(offset: Int, element: LyricLine)] {
        let start = max(0, currentIdx - count)
        let end = min(appState.lyrics.count - 1, currentIdx + count)
        guard start <= end else { return [] }
        return Array(appState.lyrics.enumerated())[start...end].map { ($0.offset, $0.element) }
    }

    @ViewBuilder
    private func styledText(_ text: String, style: LyricsStyle, state: LineDisplayState, isTranslation: Bool = false) -> some View {
        let color: Color = {
            switch state {
            case .current: return style.currentLineColor.color
            case .past: return style.pastLineColor.color
            case .upcoming: return style.otherLineColor.color
            }
        }()

        let size = isTranslation ? style.fontSize * 0.6 : style.fontSize
        let weight = isTranslation ? Font.Weight.regular : style.fontWeight.swiftUI

        Text(text)
            .font(.custom(style.fontName, size: size))
            .fontWeight(weight)
            .foregroundColor(color)
            .multilineTextAlignment(style.alignment.swiftUI)
            .lineLimit(nil)
            .minimumScaleFactor(0.5)
            .shadow(
                color: state == .current && style.currentLineGlow
                    ? style.currentLineColor.color.opacity(0.6)
                    : .clear,
                radius: state == .current && style.currentLineGlow ? 15 : 0
            )
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: style.alignment.horizontal, vertical: .center))
    }
}
